import Foundation
import UIKit

// MARK: - Fal.ai API Key

let falAIApiKey = "d119566f-f726-4fc8-981e-e2122c0cb1a3:5042f27c968ca32e642d156b677de5ff" // TODO: Replace with your actual fal.ai API key

// MARK: - Fal.ai Response Structures

struct FalAIResponse: Decodable {
    let video: FalAIVideoFile?
    let requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case video
        case requestId = "request_id"
    }
}

struct FalAIVideoFile: Decodable {
    let url: String
    let fileSize: Int?
    let fileName: String?
    let contentType: String?
    
    enum CodingKeys: String, CodingKey {
        case url
        case fileSize = "file_size"
        case fileName = "file_name"
        case contentType = "content_type"
    }
}

struct FalAIQueueResponse: Decodable {
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
    }
}

// MARK: - Fal.ai Webhook Submission Response

struct FalAIWebhookSubmissionResponse {
    let requestId: String
    let submitted: Bool
}

// MARK: - Submit Video to Fal.ai with Webhook

/// Submits a motion control video generation request to fal.ai with a webhook URL
/// The result will be delivered via the webhook callback
/// 
/// Note: Reference videos are expected to already be uploaded to Supabase with public URLs
func submitVideoToFalAIWithWebhook(
    requestId: String,
    image: UIImage,
    videoURL: URL,
    prompt: String? = nil,
    characterOrientation: String = "video",
    keepOriginalSound: Bool = true,
    userId: String
) async throws -> FalAIWebhookSubmissionResponse {
    print("[Fal.ai] Preparing motion control request…")
    print("[Fal.ai] Request ID: \(requestId)")
    print("[Fal.ai] Character orientation: \(characterOrientation)")
    print("[Fal.ai] Keep original sound: \(keepOriginalSound)")
    
    // MARK: Step 1 - Upload user's image to Supabase to get public URL
    print("[Fal.ai] Uploading user image to Supabase...")
    let imageURL = try await SupabaseManager.shared.uploadImage(
        image: image,
        userId: userId,
        modelName: "falai-motion-control",
        maxRetries: 2
    )
    print("[Fal.ai] Image uploaded, URL: \(imageURL)")
    
    // MARK: Step 2 - Use reference video URL directly (already in Supabase)
    // The reference videos are already uploaded to Supabase, so we can use the URL directly
    let videoPublicURL: String
    
    if videoURL.scheme == "file" || videoURL.isFileURL {
        // This shouldn't happen for reference videos, but handle it just in case
        print("[Fal.ai] Warning: Reference video is a local file, uploading to Supabase...")
        let videoData = try Data(contentsOf: videoURL)
        let fileExtension = videoURL.pathExtension.isEmpty ? "mp4" : videoURL.pathExtension
        videoPublicURL = try await SupabaseManager.shared.uploadVideo(
            videoData: videoData,
            userId: userId,
            modelName: "falai-reference-video",
            fileExtension: fileExtension,
            maxRetries: 2
        )
        print("[Fal.ai] Video uploaded, URL: \(videoPublicURL)")
    } else {
        // Already a remote URL (Supabase URL) - use directly
        videoPublicURL = videoURL.absoluteString
        print("[Fal.ai] Using existing reference video URL: \(videoPublicURL)")
    }
    
    // MARK: Step 3 - Build request body (without webhook - it goes in query parameter)
    var requestBody: [String: Any] = [
        "image_url": imageURL,
        "video_url": videoPublicURL,
        "character_orientation": characterOrientation,
        "keep_original_sound": keepOriginalSound
    ]
    
    // Add optional prompt if provided
    if let prompt = prompt, !prompt.isEmpty {
        requestBody["prompt"] = prompt
    }
    
    // MARK: Step 4 - Submit to fal.ai queue API with webhook as query parameter
    // fal.ai requires webhook URL as query parameter: ?fal_webhook=URL
    let webhookURL = WebhookConfig.webhookURL(for: "falai")
    print("[Fal.ai] Webhook URL: \(webhookURL)")
    let encodedWebhookURL = webhookURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? webhookURL
    let endpoint = "https://queue.fal.run/fal-ai/kling-video/v2.6/standard/motion-control?fal_webhook=\(encodedWebhookURL)"
    print("[Fal.ai] Full endpoint URL: \(endpoint)")
    let url = URL(string: endpoint)!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Key \(falAIApiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    // Debug log (masked API key)
    if let requestJSON = try? JSONSerialization.data(withJSONObject: requestBody),
       let requestString = String(data: requestJSON, encoding: .utf8) {
        let maskedRequest = requestString.replacingOccurrences(
            of: "\"Key [^\"]+\"",
            with: "\"Key ***\"",
            options: .regularExpression
        )
        print("[Fal.ai] Request body: \(maskedRequest)")
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
    print("[Fal.ai] Response status code: \(statusCode)")
    
    guard let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode) else {
        // Log error response body
        if let errorString = String(data: data, encoding: .utf8) {
            print("[Fal.ai] Error response body: \(errorString)")
        }
        throw NSError(
            domain: "FalAIAPI",
            code: statusCode,
            userInfo: [
                NSLocalizedDescriptionKey: "Fal.ai returned HTTP \(statusCode)"
            ]
        )
    }
    
    // Log the actual response for debugging
    if let responseString = String(data: data, encoding: .utf8) {
        print("[Fal.ai] Response body: \(responseString)")
    }
    
    // Parse response to get requestId - fal.ai returns request_id and gateway_request_id
    var extractedRequestId: String = requestId // Default to the one we passed in
    
    // First, try to parse as JSON
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        // fal.ai returns request_id and gateway_request_id
        // Use request_id first (preferred), fallback to gateway_request_id
        if let id = json["request_id"] as? String {
            extractedRequestId = id
            print("[Fal.ai] Using request_id from response: \(id)")
        } else if let id = json["gateway_request_id"] as? String {
            extractedRequestId = id
            print("[Fal.ai] Using gateway_request_id from response: \(id)")
        } else if let id = json["requestId"] as? String {
            extractedRequestId = id
            print("[Fal.ai] Using requestId from response: \(id)")
        } else {
            // If we can't find request_id, use the taskId we passed in
            print("[Fal.ai] Warning: Could not find request_id in response, using provided requestId: \(requestId)")
            extractedRequestId = requestId
        }
    } else {
        // If JSON parsing fails, use the taskId we passed in
        print("[Fal.ai] Warning: Could not parse response as JSON, using provided requestId: \(requestId)")
        extractedRequestId = requestId
    }
    
    print("[Fal.ai] Motion control request submitted successfully, requestId: \(extractedRequestId)")
    return FalAIWebhookSubmissionResponse(requestId: extractedRequestId, submitted: true)
}

