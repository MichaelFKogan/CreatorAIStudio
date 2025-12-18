import Supabase
import SwiftUI

// MARK: - Image Generation Task

/// A single end-to-end operation that sends an image to WaveSpeed,
/// fetches the transformed result, uploads it to storage,
/// saves metadata to your database, and returns the final outcome.
///
/// This is the worker object run by ImageGenerationCoordinator.
/// 
/// Supports two modes:
/// - **Polling mode** (default): Waits for result via polling, returns completed image
/// - **Webhook mode**: Submits job and returns immediately, result delivered via webhook
class ImageGenerationTask: MediaGenerationTask {
    // The model/item defining prompts, settings, display info, etc.
    let item: InfoPacket

    // The original user-selected image to send for transformation.
    let image: UIImage

    // The authenticated user performing this action.
    let userId: String
    
    // Whether to use webhook mode (returns immediately) or polling mode (waits for result)
    let useWebhook: Bool

    init(item: InfoPacket, image: UIImage, userId: String, useWebhook: Bool = false) {
        self.item = item
        self.image = image
        self.userId = userId
        self.useWebhook = useWebhook && WebhookConfig.useWebhooks
    }
    
    // MARK: - Helper: Generate Descriptive Progress Message
    
    /// Generates a descriptive message for progress notifications based on item type.
    /// - For Photo/Video Filters: Shows the filter name
    /// - For Image/Video Models: Shows a truncated version of the prompt
    private func generateProgressMessage() -> String {
        let itemType = item.type ?? ""
        
        // For filters, display the filter name
        if itemType == "Photo Filter" || itemType == "Video Filter" {
            let filterName = item.display.title
            return "Generating: \(filterName)"
        }
        
        // For image/video models, display truncated prompt
        if itemType == "Image Model" || itemType == "Video Model" {
            if let prompt = item.prompt, !prompt.isEmpty {
                // Truncate to first ~30 characters or 5 words, whichever is shorter
                let words = prompt.split(separator: " ").prefix(5).joined(separator: " ")
                let truncated = words.count > 30 ? String(words.prefix(30)) + "..." : words
                return "Generating: \(truncated)..."
            }
        }
        
        // Fallback to title if no prompt or unknown type
        if !item.display.title.isEmpty {
            return "Generating: \(item.display.title)"
        }
        
        return "Sending image to AI..."
    }

    /// Executes the full 6-step pipeline:
    /// 1. Upload image to API
    /// 2. Poll for result (or return immediately in webhook mode)
    /// 3. Download generated image
    /// 4. Upload final image to storage (Supabase)
    /// 5. Save metadata to database
    /// 6. Report success or failure to the coordinator
    ///
    /// This function surfaces progress updates and the final result via async callbacks.
    func execute(
        notificationId _: UUID,
        onProgress: @escaping (TaskProgress) async -> Void,
        onComplete: @escaping (TaskResult) async -> Void
    ) async {
        // Use resolved API configuration from centralized manager
        let apiConfig = item.resolvedAPIConfig
        
        // Helpful debug information printed for each request.
        print("""
        --- Request Info ---
        ------------------------------
        Provider: \(apiConfig.provider)
        Endpoint: \(apiConfig.endpoint)
        Prompt: \(((item.prompt?.isEmpty) != nil) ? "(no prompt)" : "\(item.prompt)")
        Aspect Ratio: \(apiConfig.aspectRatio ?? "default")
        Output Format: \(apiConfig.wavespeedConfig?.outputFormat)
        Enable Sync Mode: \(apiConfig.wavespeedConfig?.enableSyncMode)
        Enable Base64 Output: \(apiConfig.wavespeedConfig?.enableBase64Output)
        Cost: $\(NSDecimalNumber(decimal: item.resolvedCost ?? 0).stringValue)
        Use Webhook: \(useWebhook)
        ------------------------------
        """)
        
        // MARK: - WEBHOOK MODE
        if useWebhook {
            await executeWithWebhook(apiConfig: apiConfig, onProgress: onProgress, onComplete: onComplete)
            return
        }
        
        // MARK: - POLLING MODE (existing behavior)

        do {
            // MARK: STEP 1 — SEND TO API

            await onProgress(TaskProgress(progress: 0.1, message: generateProgressMessage()))

            // Determine if this is image-to-image mode (check if image is not a placeholder)
            let isImageToImage = image.size.width > 1 && image.size.height > 1

            // Determine output URL based on provider
            let urlString: String

//            MARK: SEND TO WAVESPEED
            switch apiConfig.provider {
            case .wavespeed:
                // Wrap API request in a 360-second timeout to protect against infinite waits.
                let response = try await withTimeout(seconds: 360) {
                    try await sendImageToWaveSpeed(
                        image: self.image,
                        prompt: self.item.prompt ?? "",
                        endpoint: apiConfig.endpoint,
                        
                        aspectRatio: apiConfig.aspectRatio,
                        
                        outputFormat: apiConfig.wavespeedConfig?.outputFormat ?? "",
                        enableSyncMode: apiConfig.wavespeedConfig?.enableSyncMode ?? false,
                        enableBase64Output: apiConfig.wavespeedConfig?.enableBase64Output ?? false,
                        
                        maxPollingAttempts: 60,
                        userId: self.userId
                    )
                }

                guard let outputURL = response.data.outputs?.first else {
                    throw NSError(
                        domain: "APIError",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No output URL returned from WaveSpeed API"]
                    )
                }
                urlString = outputURL

//            MARK: SEND TO RUNWARE
                
            case .runware:
                // Get model name from display info or extract from endpoint
                let modelName = item.display.modelName ?? extractModelFromEndpoint(apiConfig.endpoint) ?? ""

                // Wrap API request in a 360-second timeout to protect against infinite waits.
                let response = try await withTimeout(seconds: 360) {
                    try await sendImageToRunware(
                        image: isImageToImage ? self.image : nil,
                        prompt: self.item.prompt ?? "",
                        model: apiConfig.runwareModel ?? "",
                        aspectRatio: apiConfig.aspectRatio,
                        isImageToImage: isImageToImage,
                        runwareConfig: apiConfig.runwareConfig
                    )
                }

                guard let outputURL = response.data.first?.imageURL else {
                    throw NSError(
                        domain: "APIError",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No output URL returned from Runware API"]
                    )
                }
                urlString = outputURL
            }

            await onProgress(TaskProgress(progress: 0.5, message: "Processing transformation..."))
            print("✅ Image sent. Response received.")

            // MARK: STEP 2 — DOWNLOAD GENERATED IMAGE

            // Validate and create URL from the output string
            guard let url = URL(string: urlString) else {
                throw NSError(
                    domain: "APIError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid output URL returned from API"]
                )
            }

            await onProgress(TaskProgress(progress: 0.6, message: "Downloading result..."))
            print("[\(apiConfig.provider == .runware ? "Runware" : "WaveSpeed")] Fetching generated image…")

            // Download final image with a 30-second timeout window.
            let (imageData, _) = try await withTimeout(seconds: 30) {
                try await URLSession.shared.data(from: url)
            }

            // Ensure the returned data is a valid UIImage.
            guard let downloadedImage = UIImage(data: imageData) else {
                throw NSError(
                    domain: "ImageError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"]
                )
            }

            print("[\(apiConfig.provider == .runware ? "Runware" : "WaveSpeed")] Generated image loaded successfully.")

            // MARK: STEP 3 — UPLOAD RESULT TO STORAGE (SUPABASE)

            await onProgress(TaskProgress(progress: 0.75, message: "Uploading to storage..."))

            let modelName = item.display.modelName ?? ""
            let supabaseImageURL = try await SupabaseManager.shared.uploadImage(
                image: downloadedImage,
                userId: userId,
                modelName: modelName.isEmpty ? "unknown" : modelName
            )

            print("✅ Image uploaded to Supabase Storage: \(supabaseImageURL)")

            // MARK: STEP 4 — SAVE METADATA TO DATABASE

            await onProgress(TaskProgress(progress: 0.9, message: "Saving to profile..."))

            let metadata = ImageMetadata(
                userId: userId,
                imageUrl: supabaseImageURL,
                model: modelName.isEmpty ? nil : modelName,
                title: item.display.title.isEmpty ? nil : item.display.title,
                cost: (item.resolvedCost != nil && item.resolvedCost! > 0 ? NSDecimalNumber(decimal: item.resolvedCost!).doubleValue : nil),
                type: item.type?.isEmpty == false ? item.type : nil,
                endpoint: apiConfig.endpoint.isEmpty ? nil : apiConfig.endpoint,
                prompt: (item.prompt?.isEmpty == false ? item.prompt : nil),
                aspectRatio: apiConfig.aspectRatio,
                provider: apiConfig.provider.rawValue
            )

            print("📝 Saving metadata: title=\(metadata.title ?? "none"), cost=\(metadata.cost ?? 0), type=\(metadata.type ?? "none"), provider=\(metadata.provider ?? "none")")

            // Saves with exponential backoff retry for reliability.
            // Returns the inserted image so we can get the ID for the notification
            let insertedImage = try await saveMetadataWithRetry(metadata)

            // Increased delay to ensure database transaction is fully committed
            // This is especially important when multiple images are saved concurrently
            // The delay helps with eventual consistency in Supabase and prevents race conditions
            try? await Task.sleep(for: .milliseconds(1000))

            // Post notification that image was saved to database
            // This allows ProfileViewModel to immediately fetch and display the new image
            await MainActor.run {
                var userInfo: [String: Any] = [
                    "userId": userId,
                    "imageUrl": supabaseImageURL
                ]
                
                // Include image ID if available (most reliable way to fetch)
                if let imageId = insertedImage?.id {
                    userInfo["imageId"] = imageId
                    print("📢 Posting ImageSavedToDatabase notification for userId: \(userId), imageId: \(imageId), imageUrl: \(supabaseImageURL)")
                } else {
                    print("⚠️ Posting ImageSavedToDatabase notification WITHOUT imageId for userId: \(userId), imageUrl: \(supabaseImageURL)")
                    print("⚠️ This may cause issues with concurrent image saves. Consider retrying the save.")
                }
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("ImageSavedToDatabase"),
                    object: nil,
                    userInfo: userInfo
                )
            }

            // MARK: STEP 6 — SUCCESS CALLBACK

            await onComplete(.imageSuccess(downloadedImage, url: supabaseImageURL))

            // MARK: ERROR HANDLING STARTS HERE
        } catch let error as TimeoutError {
            // Handles request, download, or API timeouts.
            print("❌ Timeout: \(error.localizedDescription)")

            await onComplete(.failure(
                NSError(
                    domain: "TimeoutError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."]
                )
            ))

        } catch let error as URLError {
            // Provides friendly, user-facing network messages.
            print("❌ Network error: \(error)")

            let message: String
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                message = "No internet connection. Please check your network."
            case .timedOut:
                message = "Request timed out. Please try again."
            case .cannotFindHost, .cannotConnectToHost:
                message = "Cannot reach server. Please try again later."
            default:
                message = "Network error: \(error.localizedDescription)"
            }

            await onComplete(.failure(NSError(
                domain: "NetworkError",
                code: error.code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: message]
            )))

        } catch {
            // Catches everything else — JSON errors, decode errors, unexpected exceptions.
            print("❌ \(apiConfig.provider == .runware ? "Runware" : "WaveSpeed") error: \(error)")
            await onComplete(.failure(error))
        }
    }

    // MARK: - Webhook Execution
    
    /// Executes the image generation using webhook mode
    /// Creates a pending job record and submits to API with webhook URL
    /// Returns immediately with "queued" status - result delivered via webhook
    private func executeWithWebhook(
        apiConfig: APIConfiguration,
        onProgress: @escaping (TaskProgress) async -> Void,
        onComplete: @escaping (TaskResult) async -> Void
    ) async {
        do {
            await onProgress(TaskProgress(progress: 0.1, message: "Preparing request..."))
            
            // Generate a unique task ID
            let taskId = UUID().uuidString
            
            // Determine if this is image-to-image mode
            let isImageToImage = image.size.width > 1 && image.size.height > 1
            let modelName = item.display.modelName ?? extractModelFromEndpoint(apiConfig.endpoint) ?? "unknown"
            
            // MARK: Step 1 - Create pending job record
            await onProgress(TaskProgress(progress: 0.2, message: "Creating job record..."))
            
            let jobMetadata = PendingJobMetadata(
                prompt: item.prompt,
                model: modelName,
                title: item.display.title,
                aspectRatio: apiConfig.aspectRatio,
                resolution: nil,
                duration: nil,
                cost: item.resolvedCost != nil ? NSDecimalNumber(decimal: item.resolvedCost!).doubleValue : nil,
                type: item.type,
                endpoint: apiConfig.endpoint
            )
            
            let pendingJob = PendingJob(
                userId: userId,
                taskId: taskId,
                provider: apiConfig.provider == .runware ? .runware : .wavespeed,
                jobType: .image,
                metadata: jobMetadata,
                deviceToken: nil // TODO: Add device token for push notifications
            )
            
            // Insert pending job into database
            try await SupabaseManager.shared.createPendingJob(pendingJob)
            print("✅ Pending job created with taskId: \(taskId)")
            
            // MARK: Step 2 - Submit to API with webhook
            await onProgress(TaskProgress(progress: 0.4, message: generateProgressMessage()))
            
            switch apiConfig.provider {
            case .wavespeed:
                let _ = try await submitImageToWaveSpeedWithWebhook(
                    taskId: taskId,
                    image: image,
                    prompt: item.prompt ?? "",
                    endpoint: apiConfig.endpoint,
                    aspectRatio: apiConfig.aspectRatio,
                    outputFormat: apiConfig.wavespeedConfig?.outputFormat ?? "jpeg",
                    userId: userId
                )
                print("✅ WaveSpeed webhook request submitted")
                
            case .runware:
                let _ = try await submitImageToRunwareWithWebhook(
                    taskUUID: taskId,
                    image: isImageToImage ? image : nil,
                    prompt: item.prompt ?? "",
                    model: apiConfig.runwareModel ?? "",
                    aspectRatio: apiConfig.aspectRatio,
                    isImageToImage: isImageToImage,
                    runwareConfig: apiConfig.runwareConfig
                )
                print("✅ Runware webhook request submitted")
            }
            
            // MARK: Step 3 - Return immediately with queued status
            // Note: Don't update progress here - the coordinator will set the appropriate progress for queued state
            await onComplete(.queued(taskId: taskId, jobType: .image))
            
        } catch {
            print("❌ Webhook submission error: \(error)")
            await onComplete(.failure(error))
        }
    }
    
    // MARK: - Save Metadata With Retry

    /// Saves the generated image metadata to Supabase with exponential backoff.
    /// Attempts up to 3 times, doubling wait time after each failure.
    /// Returns the inserted UserImage if successful, nil otherwise.
    private func saveMetadataWithRetry(_ metadata: ImageMetadata) async throws -> UserImage? {
        var saveSuccessful = false
        var retryCount = 0
        let maxRetries = 3

        while !saveSuccessful, retryCount < maxRetries {
            do {
                // Use .select() after .insert() to get the inserted row back
                let response: PostgrestResponse<[UserImage]> = try await SupabaseManager.shared.client.database
                    .from("user_media")
                    .insert(metadata)
                    .select()
                    .execute()

                print("✅ Image metadata saved to database")
                saveSuccessful = true
                
                // Return the inserted image (should be first and only item)
                let insertedImages = response.value ?? []
                return insertedImages.first

            } catch {
                retryCount += 1
                print("⚠️ Save attempt \(retryCount) failed: \(error)")

                // If retries remain, wait (2, 4, 8 seconds).
                if retryCount < maxRetries {
                    try await Task.sleep(for: .seconds(pow(2.0, Double(retryCount))))
                } else {
                    print("❌ Failed to save to database after \(maxRetries) attempts: \(error)")
                    throw error
                }
            }
        }
        
        return nil
    }

    // MARK: - Helper: Extract Model from Endpoint

    /// Attempts to extract model name from endpoint URL
    /// Falls back to a default model if extraction fails
    private func extractModelFromEndpoint(_ endpoint: String) -> String? {
        // Try to extract model name from common endpoint patterns
        // Example: "https://api.wavespeed.ai/api/v3/openai/gpt-image-1" -> "gpt-image-1"
        let components = endpoint.split(separator: "/")
        if let lastComponent = components.last {
            return String(lastComponent)
        }
        return nil
    }
}
