import SwiftUI

// MARK: - Image Generation Task

/// Handles the complete workflow for image generation
class ImageGenerationTask: MediaGenerationTask {
    let item: InfoPacket
    let image: UIImage
    let userId: String

    init(item: InfoPacket, image: UIImage, userId: String) {
        self.item = item
        self.image = image
        self.userId = userId
    }

    func execute(
        notificationId _: UUID,
        onProgress: @escaping (TaskProgress) async -> Void,
        onComplete: @escaping (TaskResult) async -> Void
    ) async {
        print("""
        --- WaveSpeed Request Info ---
        ------------------------------
        Endpoint: \(item.apiConfig.endpoint)
        Prompt: \(item.prompt.isEmpty ? "(no prompt)" : "\(item.prompt)")
        Aspect Ratio: \(item.apiConfig.aspectRatio ?? "default")
        Output Format: \(item.apiConfig.outputFormat)
        Enable Sync Mode: \(item.apiConfig.enableSyncMode)
        Enable Base64 Output: \(item.apiConfig.enableBase64Output)
        Cost: $\(NSDecimalNumber(decimal: item.cost).stringValue)
        ------------------------------
        """)

        do {
            // MARK: STEP 1: SEND TO API

            await onProgress(TaskProgress(progress: 0.1, message: "Sending image to AI..."))

            let response = try await withTimeout(seconds: 360) {
                try await sendImageToWaveSpeed(
                    image: self.image,
                    prompt: self.item.prompt,
                    aspectRatio: self.item.apiConfig.aspectRatio,
                    outputFormat: self.item.apiConfig.outputFormat,
                    enableSyncMode: self.item.apiConfig.enableSyncMode,
                    enableBase64Output: self.item.apiConfig.enableBase64Output,
                    endpoint: self.item.apiConfig.endpoint,
                    maxPollingAttempts: 60,
                    userId: self.userId
                )
            }

            await onProgress(TaskProgress(progress: 0.5, message: "Processing transformation..."))
            print("✅ Image sent. Response received.")

            // MARK: STEP 2: DOWNLOAD

            guard let urlString = response.data.outputs?.first,
                  let url = URL(string: urlString)
            else {
                throw NSError(domain: "APIError", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "No output URL returned from API"])
            }

            await onProgress(TaskProgress(progress: 0.6, message: "Downloading result..."))
            print("[WaveSpeed] Fetching generated image…")

            let (imageData, _) = try await withTimeout(seconds: 30) {
                try await URLSession.shared.data(from: url)
            }

            guard let downloadedImage = UIImage(data: imageData) else {
                throw NSError(domain: "ImageError", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"])
            }

            print("[WaveSpeed] Generated image loaded successfully.")

            // MARK: STEP 3: UP TO DB

            await onProgress(TaskProgress(progress: 0.75, message: "Uploading to storage..."))

            let modelName = item.display.modelName
            let supabaseImageURL = try await SupabaseManager.shared.uploadImage(
                image: downloadedImage,
                userId: userId,
                modelName: modelName.isEmpty ? "unknown" : modelName
            )
            print("✅ Image uploaded to Supabase Storage: \(supabaseImageURL)")

            // MARK: 4: METADATA TO DB

            await onProgress(TaskProgress(progress: 0.9, message: "Saving to profile..."))

            let metadata = ImageMetadata(
                userId: userId,
                imageUrl: supabaseImageURL,
                model: modelName.isEmpty ? nil : modelName,
                title: item.display.title.isEmpty ? nil : item.display.title,
                cost: item.cost > 0 ? Double(truncating: item.cost as NSNumber) : nil,
                type: item.type?.isEmpty == false ? item.type : nil,
                endpoint: item.apiConfig.endpoint.isEmpty ? nil : item.apiConfig.endpoint,
                prompt: item.prompt.isEmpty ? nil : item.prompt,
                aspectRatio: item.apiConfig.aspectRatio
            )

            print("📝 Saving metadata: title=\(metadata.title ?? "none"), cost=\(metadata.cost ?? 0), type=\(metadata.type ?? "none")")

            try await saveMetadataWithRetry(metadata)

            // MARK: STEP 6: SUCCESS!

            await onComplete(.imageSuccess(downloadedImage, url: supabaseImageURL))

            // MARK: CHECK ERRORS

        } catch let error as TimeoutError {
            print("❌ Timeout: \(error.localizedDescription)")
            await onComplete(.failure(NSError(
                domain: "TimeoutError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."]
            )))
        } catch let error as URLError {
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
            print("❌ WaveSpeed error: \(error)")
            await onComplete(.failure(error))
        }
    }

    // MARK: func saveMetadata to DB

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
