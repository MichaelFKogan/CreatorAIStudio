import SwiftUI

// MARK: - Video Generation Task
/// Handles the complete workflow for video generation
class VideoGenerationTask: MediaGenerationTask {
    let item: InfoPacket
    let image: UIImage
    let userId: String
    
    init(item: InfoPacket, image: UIImage, userId: String) {
        self.item = item
        self.image = image
        self.userId = userId
    }
    
    func execute(
        notificationId: UUID,
        onProgress: @escaping (TaskProgress) async -> Void,
        onComplete: @escaping (TaskResult) async -> Void
    ) async {
        print("""
        --- WaveSpeed Video Request Info ---
        ------------------------------------
        Endpoint: \(item.apiConfig.endpoint)
        Prompt: \(item.prompt.isEmpty ? "(no prompt)" : "\(item.prompt)")
        Aspect Ratio: \(item.apiConfig.aspectRatio ?? "default")
        Output Format: \(item.apiConfig.outputFormat)
        Enable Sync Mode: \(item.apiConfig.enableSyncMode)
        Cost: $\(NSDecimalNumber(decimal: item.cost).stringValue)
        ------------------------------------
        """)
        
        do {
            // Step 1: Send to API
            await onProgress(TaskProgress(progress: 0.1, message: "Sending image to AI..."))
            
            let response = try await withTimeout(seconds: 650) {
                try await sendImageToWaveSpeed(
                    image: self.image,
                    prompt: self.item.prompt,
                    aspectRatio: self.item.apiConfig.aspectRatio,
                    outputFormat: self.item.apiConfig.outputFormat,
                    enableSyncMode: self.item.apiConfig.enableSyncMode,
                    enableBase64Output: self.item.apiConfig.enableBase64Output,
                    endpoint: self.item.apiConfig.endpoint,
                    maxPollingAttempts: 120,
                    userId: self.userId
                )
            }
            
            await onProgress(TaskProgress(progress: 0.3, message: "Processing video generation..."))
            print("✅ Video request sent. Response received.")
            
            // Step 2: Download video
            guard let urlString = response.data.outputs?.first,
                  let url = URL(string: urlString) else {
                throw NSError(domain: "APIError", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No output URL returned from API"])
            }
            
            await onProgress(TaskProgress(progress: 0.5, message: "Downloading video..."))
            print("[WaveSpeed] Fetching generated video from: \(urlString)")
            
            let (videoData, urlResponse) = try await withTimeout(seconds: 120) {
                try await URLSession.shared.data(from: url)
            }
            
            print("[WaveSpeed] Video downloaded, size: \(videoData.count) bytes")
            
            // Detect file extension
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
            
            // Step 3: Generate and upload thumbnail
            await onProgress(TaskProgress(progress: 0.6, message: "Generating thumbnail..."))
            
            let thumbnail = await SupabaseManager.shared.generateVideoThumbnail(from: videoData)
            var thumbnailUrl: String? = nil
            
            if let thumbnail = thumbnail {
                await onProgress(TaskProgress(progress: 0.65, message: "Uploading thumbnail..."))
                
                do {
                    thumbnailUrl = try await SupabaseManager.shared.uploadImage(
                        image: thumbnail,
                        userId: userId,
                        modelName: "\(item.display.modelName)_thumbnail",
                        maxRetries: 2
                    )
                    print("✅ Thumbnail uploaded: \(thumbnailUrl ?? "none")")
                } catch {
                    print("⚠️ Failed to upload thumbnail (continuing anyway): \(error)")
                }
            } else {
                print("⚠️ Could not generate thumbnail (continuing anyway)")
            }
            
            // Step 4: Upload video to Supabase Storage
            await onProgress(TaskProgress(progress: 0.75, message: "Uploading video to storage..."))
            
            let modelName = item.display.modelName
            let supabaseVideoURL = try await SupabaseManager.shared.uploadVideo(
                videoData: videoData,
                userId: userId,
                modelName: modelName.isEmpty ? "unknown" : modelName,
                fileExtension: fileExtension
            )
            print("✅ Video uploaded to Supabase Storage: \(supabaseVideoURL)")
            
            // Step 5: Save metadata to database
            await onProgress(TaskProgress(progress: 0.9, message: "Saving to profile..."))
            
            let metadata = VideoMetadata(
                userId: userId,
                videoUrl: supabaseVideoURL,
                thumbnailUrl: thumbnailUrl,
                model: modelName.isEmpty ? nil : modelName,
                title: item.display.title.isEmpty ? nil : item.display.title,
                cost: (item.cost > 0 ? Double(truncating: item.cost as NSNumber) : nil),
                type: item.type?.isEmpty == false ? item.type : nil,
                endpoint: item.apiConfig.endpoint.isEmpty ? nil : item.apiConfig.endpoint,
                fileExtension: fileExtension,
                prompt: item.prompt.isEmpty ? nil : item.prompt,
                aspectRatio: item.apiConfig.aspectRatio
            )
            
            print("📝 Saving video metadata: title=\(metadata.title ?? "none"), cost=\(metadata.cost ?? 0), type=\(metadata.type ?? "none"), extension=\(fileExtension)")
            
            // Save with retry logic
            try await saveMetadataWithRetry(metadata)
            
            // Success!
            await onComplete(.videoSuccess(videoUrl: supabaseVideoURL))
            
        } catch let error as TimeoutError {
            print("❌ Timeout: \(error.localizedDescription)")
            await onComplete(.failure(NSError(
                domain: "TimeoutError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Request timed out. Videos can take several minutes."]
            )))
        } catch let error as URLError {
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
            print("❌ WaveSpeed video error: \(error)")
            await onComplete(.failure(error))
        }
    }
    
    // MARK: - Private Helpers
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

