import SwiftUI

// MARK: - Image Generation Task

/// A single end-to-end operation that sends an image to WaveSpeed,
/// fetches the transformed result, uploads it to storage,
/// saves metadata to your database, and returns the final outcome.
///
/// This is the worker object run by ImageGenerationCoordinator.
class ImageGenerationTask: MediaGenerationTask {
    // The model/item defining prompts, settings, display info, etc.
    let item: InfoPacket

    // The original user-selected image to send for transformation.
    let image: UIImage

    // The authenticated user performing this action.
    let userId: String

    init(item: InfoPacket, image: UIImage, userId: String) {
        self.item = item
        self.image = image
        self.userId = userId
    }

    /// Executes the full 6-step pipeline:
    /// 1. Upload image to API
    /// 2. Poll for result
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
        // Helpful debug information printed for each request.
        print("""
        --- Request Info ---
        ------------------------------
        Provider: \(item.apiConfig.provider)
        Endpoint: \(item.apiConfig.endpoint)
        Prompt: \(((item.prompt?.isEmpty) != nil) ? "(no prompt)" : "\(item.prompt)")
        Aspect Ratio: \(item.apiConfig.aspectRatio ?? "default")
        Output Format: \(item.apiConfig.wavespeedConfig?.outputFormat)
        Enable Sync Mode: \(item.apiConfig.wavespeedConfig?.enableSyncMode)
        Enable Base64 Output: \(item.apiConfig.wavespeedConfig?.enableBase64Output)
        Cost: $\(NSDecimalNumber(decimal: item.cost ?? 0).stringValue)
        ------------------------------
        """)

        do {
            // MARK: STEP 1 — SEND TO API

            await onProgress(TaskProgress(progress: 0.1, message: "Sending image to AI..."))

            // Determine if this is image-to-image mode (check if image is not a placeholder)
            let isImageToImage = image.size.width > 1 && image.size.height > 1

            // Determine output URL based on provider
            let urlString: String

//            MARK: SEND TO WAVESPEED
            switch item.apiConfig.provider {
            case .wavespeed:
                // Wrap API request in a 360-second timeout to protect against infinite waits.
                let response = try await withTimeout(seconds: 360) {
                    try await sendImageToWaveSpeed(
                        image: self.image,
                        prompt: self.item.prompt ?? "",
                        endpoint: self.item.apiConfig.endpoint,
                        
                        aspectRatio: self.item.apiConfig.aspectRatio,
                        
                        outputFormat: self.item.apiConfig.wavespeedConfig?.outputFormat ?? "",
                        enableSyncMode: self.item.apiConfig.wavespeedConfig?.enableSyncMode ?? false,
                        enableBase64Output: self.item.apiConfig.wavespeedConfig?.enableBase64Output ?? false,
                        
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
                let modelName = item.display.modelName ?? extractModelFromEndpoint(item.apiConfig.endpoint) ?? ""

                // Wrap API request in a 360-second timeout to protect against infinite waits.
                let response = try await withTimeout(seconds: 360) {
                    try await sendImageToRunware(
                        image: isImageToImage ? self.image : nil,
                        prompt: self.item.prompt ?? "",
                        model: self.item.apiConfig.runwareModel ?? "",
                        aspectRatio: self.item.apiConfig.aspectRatio,
                        isImageToImage: isImageToImage,
                        runwareConfig: self.item.apiConfig.runwareConfig
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
            print("[\(item.apiConfig.provider == .runware ? "Runware" : "WaveSpeed")] Fetching generated image…")

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

            print("[\(item.apiConfig.provider == .runware ? "Runware" : "WaveSpeed")] Generated image loaded successfully.")

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
                cost: (item.cost != nil && item.cost! > 0 ? NSDecimalNumber(decimal: item.cost!).doubleValue : nil),
                type: item.type?.isEmpty == false ? item.type : nil,
                endpoint: item.apiConfig.endpoint.isEmpty ? nil : item.apiConfig.endpoint,
                prompt: (item.prompt?.isEmpty == false ? item.prompt : nil),
                aspectRatio: item.apiConfig.aspectRatio
            )

            print("📝 Saving metadata: title=\(metadata.title ?? "none"), cost=\(metadata.cost ?? 0), type=\(metadata.type ?? "none")")

            // Saves with exponential backoff retry for reliability.
            try await saveMetadataWithRetry(metadata)

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
            print("❌ \(item.apiConfig.provider == .runware ? "Runware" : "WaveSpeed") error: \(error)")
            await onComplete(.failure(error))
        }
    }

    // MARK: - Save Metadata With Retry

    /// Saves the generated image metadata to Supabase with exponential backoff.
    /// Attempts up to 3 times, doubling wait time after each failure.
    private func saveMetadataWithRetry(_ metadata: ImageMetadata) async throws {
        var saveSuccessful = false
        var retryCount = 0
        let maxRetries = 3

        while !saveSuccessful, retryCount < maxRetries {
            do {
                try await SupabaseManager.shared.client.database
                    .from("user_media")
                    .insert(metadata)
                    .execute()

                print("✅ Image metadata saved to database")
                saveSuccessful = true

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
