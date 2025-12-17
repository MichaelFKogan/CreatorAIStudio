import Supabase
import SwiftUI

// MARK: - Video Generation Task

/// A single end-to-end operation that sends a video generation request to Runware,
/// fetches the generated video, uploads it to storage,
/// saves metadata to your database, and returns the final outcome.
///
/// This is the worker object run by VideoGenerationCoordinator.
class VideoGenerationTask: MediaGenerationTask {
    // The model/item defining prompts, settings, display info, etc.
    let item: InfoPacket

    // The original user-selected image (optional, for image-to-video)
    let image: UIImage?

    // The authenticated user performing this action.
    let userId: String
    
    // Video generation parameters
    let duration: Double
    let aspectRatio: String
    let resolution: String?

    init(item: InfoPacket, image: UIImage?, userId: String, duration: Double, aspectRatio: String, resolution: String? = nil) {
        self.item = item
        self.image = image
        self.userId = userId
        self.duration = duration
        self.aspectRatio = aspectRatio
        self.resolution = resolution
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
        
        return "Sending request to AI..."
    }
    
    /// Executes the full video generation pipeline:
    /// 1. Send request to Runware API
    /// 2. Download generated video
    /// 3. Generate thumbnail
    /// 4. Upload video and thumbnail to storage (Supabase)
    /// 5. Save metadata to database
    /// 6. Report success or failure to the coordinator
    ///
    /// This function surfaces progress updates and the final result via async callbacks.
    func execute(
        notificationId: UUID,
        onProgress: @escaping (TaskProgress) async -> Void,
        onComplete: @escaping (TaskResult) async -> Void
    ) async {
        // Use resolved API configuration from centralized manager
        let apiConfig = item.resolvedAPIConfig
        
        // Helpful debug information printed for each request.
        var debugInfo = """
        --- Runware Video Request Info ---
        ------------------------------
        Model: \(apiConfig.runwareModel ?? "unknown")
        Prompt: \(item.prompt ?? "(no prompt)")
        Duration: \(duration) seconds
        Aspect Ratio: \(aspectRatio)
        """
        if let resolution = resolution {
            debugInfo += "\nResolution: \(resolution)"
        }
        debugInfo += """
        Mode: \(image != nil ? "Image-to-Video" : "Text-to-Video")
        Cost: \(item.resolvedCost?.credits ?? 0) credits
        ------------------------------
        """
        print(debugInfo)
        
        do {
            // MARK: STEP 1 — SEND TO API
            
            await onProgress(TaskProgress(progress: 0.1, message: generateProgressMessage()))
            
            guard let runwareModel = apiConfig.runwareModel else {
                throw NSError(
                    domain: "APIError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing runware model configuration"]
                )
            }
            
            // Determine if this is image-to-video mode
            let isImageToVideo = self.image != nil && self.image!.size.width > 1 && self.image!.size.height > 1
            
            // Wrap API request in a 650-second timeout (videos can take longer)
            // Note: For async tasks, this will include polling time
            let response = try await withTimeout(seconds: 650) {
                try await sendVideoToRunware(
                    image: isImageToVideo ? self.image : nil,
                    prompt: self.item.prompt ?? "",
                    model: runwareModel,
                    aspectRatio: self.aspectRatio,
                    duration: self.duration,
                    resolution: self.resolution,
                    isImageToVideo: isImageToVideo,
                    runwareConfig: apiConfig.runwareConfig,
                    onPollingProgress: { attempt, maxAttempts in
                        let progress = 0.1 + (Double(attempt) / Double(maxAttempts)) * 0.4 // 0.1 to 0.5
                        Task { @MainActor in
                            await onProgress(TaskProgress(
                                progress: progress,
                                message: "Generating video... (\(attempt)/\(maxAttempts))"
                            ))
                        }
                    }
                )
            }
            
            await onProgress(TaskProgress(progress: 0.5, message: "Video generation complete!"))
            print("✅ Video request sent. Response received.")
            
            // MARK: STEP 2 — DOWNLOAD GENERATED VIDEO
            
            // Check for videoURL first (for videos), then fallback to imageURL
            let urlString = response.data.first?.videoURL ?? response.data.first?.imageURL
            guard let urlString = urlString,
                  let url = URL(string: urlString) else {
                throw NSError(
                    domain: "APIError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No video URL returned from Runware API"]
                )
            }
            
            await onProgress(TaskProgress(progress: 0.5, message: "Downloading video..."))
            print("[Runware] Fetching generated video from: \(urlString)")
            
            // Download video with a 120-second timeout
            let (videoData, urlResponse) = try await withTimeout(seconds: 120) {
                try await URLSession.shared.data(from: url)
            }
            
            print("[Runware] Video downloaded, size: \(videoData.count) bytes (\(Double(videoData.count) / 1_000_000) MB)")
            
            // Detect file extension from MIME type or URL
            var fileExtension = "mp4"
            if let mimeType = (urlResponse as? HTTPURLResponse)?.mimeType {
                if mimeType.contains("webm") {
                    fileExtension = "webm"
                } else if mimeType.contains("quicktime") {
                    fileExtension = "mov"
                }
            } else if urlString.hasSuffix(".webm") {
                fileExtension = "webm"
            } else if urlString.hasSuffix(".mov") {
                fileExtension = "mov"
            }
            
            // MARK: STEP 3 — GENERATE AND UPLOAD THUMBNAIL
            
            await onProgress(TaskProgress(progress: 0.6, message: "Generating thumbnail..."))
            
            let thumbnail = await SupabaseManager.shared.generateVideoThumbnail(from: videoData)
            var thumbnailUrl: String? = nil
            
            if let thumbnail = thumbnail {
                await onProgress(TaskProgress(progress: 0.65, message: "Uploading thumbnail..."))
                
                do {
                    let modelName = item.display.modelName ?? "video"
                    thumbnailUrl = try await SupabaseManager.shared.uploadImage(
                        image: thumbnail,
                        userId: userId,
                        modelName: "\(modelName)_thumbnail",
                        maxRetries: 2
                    )
                    print("✅ Thumbnail uploaded: \(thumbnailUrl ?? "none")")
                } catch {
                    print("⚠️ Failed to upload thumbnail (continuing anyway): \(error)")
                }
            } else {
                print("⚠️ Could not generate thumbnail (continuing anyway)")
            }
            
            // MARK: STEP 4 — UPLOAD VIDEO TO STORAGE (SUPABASE)
            
            await onProgress(TaskProgress(progress: 0.75, message: "Uploading video to storage..."))
            
            let modelName = item.display.modelName ?? ""
            let supabaseVideoURL = try await SupabaseManager.shared.uploadVideo(
                videoData: videoData,
                userId: userId,
                modelName: modelName.isEmpty ? "unknown" : modelName,
                fileExtension: fileExtension
            )
            print("✅ Video uploaded to Supabase Storage: \(supabaseVideoURL)")
            
            // MARK: STEP 5 — SAVE METADATA TO DATABASE
            
            await onProgress(TaskProgress(progress: 0.9, message: "Saving to profile..."))
            
            let metadata = VideoMetadata(
                userId: userId,
                videoUrl: supabaseVideoURL,
                thumbnailUrl: thumbnailUrl,
                model: modelName.isEmpty ? nil : modelName,
                title: item.display.title.isEmpty ? nil : item.display.title,
                cost: (item.resolvedCost != nil && item.resolvedCost! > 0 ? NSDecimalNumber(decimal: item.resolvedCost!).doubleValue : nil),
                type: item.type?.isEmpty == false ? item.type : nil,
                endpoint: apiConfig.endpoint.isEmpty ? nil : apiConfig.endpoint,
                fileExtension: fileExtension,
                prompt: (item.prompt?.isEmpty == false ? item.prompt : nil),
                aspectRatio: aspectRatio
            )
            
            print("📝 Saving video metadata: title=\(metadata.title ?? "none"), cost=\(metadata.cost ?? 0), type=\(metadata.type ?? "none"), extension=\(fileExtension)")
            
            // Save with retry logic
            try await saveMetadataWithRetry(metadata)
            
            // Small delay to ensure database transaction is fully committed
            try? await Task.sleep(for: .milliseconds(500))
            
            // Post notification that video was saved to database
            await MainActor.run {
                var userInfo: [String: Any] = [
                    "userId": userId,
                    "videoUrl": supabaseVideoURL
                ]
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("VideoSavedToDatabase"),
                    object: nil,
                    userInfo: userInfo
                )
            }
            
            // MARK: STEP 6 — SUCCESS CALLBACK
            
            await onComplete(.videoSuccess(videoUrl: supabaseVideoURL))
            
            // MARK: ERROR HANDLING STARTS HERE
        } catch let error as TimeoutError {
            // Handles request, download, or API timeouts.
            print("❌ Timeout: \(error.localizedDescription)")
            
            await onComplete(.failure(
                NSError(
                    domain: "TimeoutError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Request timed out. Videos can take several minutes."]
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
                message = "Request timed out. Videos can take longer to generate."
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
            print("❌ Runware video error: \(error)")
            await onComplete(.failure(error))
        }
    }
    
    // MARK: - Private Helpers
    
    /// Saves the generated video metadata to Supabase with exponential backoff.
    /// Attempts up to 3 times, doubling wait time after each failure.
    private func saveMetadataWithRetry(_ metadata: VideoMetadata) async throws {
        var saveSuccessful = false
        var retryCount = 0
        let maxRetries = 3
        
        while !saveSuccessful && retryCount < maxRetries {
            do {
                try await SupabaseManager.shared.client.database
                    .from("user_media")
                    .insert(metadata)
                    .execute()
                print("✅ Video metadata saved to database")
                saveSuccessful = true
            } catch {
                retryCount += 1
                print("⚠️ Save attempt \(retryCount) failed: \(error)")
                
                if retryCount < maxRetries {
                    try await Task.sleep(for: .seconds(pow(2.0, Double(retryCount))))
                } else {
                    print("❌ Failed to save to database after \(maxRetries) attempts: \(error)")
                    throw error
                }
            }
        }
    }
}
