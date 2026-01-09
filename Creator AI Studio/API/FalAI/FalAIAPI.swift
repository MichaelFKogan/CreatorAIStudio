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

// MARK: - Fal.ai Image Response Structures

struct FalAIImageResponse: Decodable {
    let images: [FalAIImageFile]
    let timings: FalAITimings?
    let seed: Int?
    let hasNsfwConcepts: [Bool]?
    let prompt: String?
    
    enum CodingKeys: String, CodingKey {
        case images
        case timings
        case seed
        case hasNsfwConcepts = "has_nsfw_concepts"
        case prompt
    }
}

struct FalAIImageFile: Decodable {
    let url: String
    let width: Int?
    let height: Int?
    let contentType: String?
    let fileName: String?
    let fileSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case url
        case width
        case height
        case contentType = "content_type"
        case fileName = "file_name"
        case fileSize = "file_size"
    }
}

struct FalAITimings: Decodable {
    let inference: Double?
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
    
    // Properly encode the webhook URL for use as a query parameter value
    // We need to encode the entire URL, including ? and & characters
    var allowedCharacters = CharacterSet.urlQueryAllowed
    allowedCharacters.remove(charactersIn: "?&") // Remove ? and & from allowed set so they get encoded
    let encodedWebhookURL = webhookURL.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? webhookURL
    
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

// MARK: - Helper: Convert Aspect Ratio to Fal.ai Image Size

/// Converts an aspect ratio string to Fal.ai image_size format
/// Returns either an enum string (e.g., "landscape_4_3") or a custom size object
func convertAspectRatioToFalImageSize(aspectRatio: String?, width: Int? = nil, height: Int? = nil) -> Any {
    // If custom width/height are provided, use them
    if let w = width, let h = height {
        return ["width": w, "height": h]
    }
    
    // Map common aspect ratios to Fal.ai enum values
    guard let ratio = aspectRatio?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        return "landscape_4_3" // Default
    }
    
    let ratioLower = ratio.lowercased()
    
    // Map to Fal.ai enum values
    switch ratioLower {
    case "1:1", "square":
        return "square"
    case "3:4", "4:3":
        // Determine portrait vs landscape based on ratio format
        if ratio.contains("3:4") {
            return "portrait_4_3"
        } else {
            return "landscape_4_3"
        }
    case "9:16", "16:9":
        if ratio.contains("9:16") {
            return "portrait_16_9"
        } else {
            return "landscape_16_9"
        }
    case "2:3", "3:2":
        if ratio.contains("2:3") {
            return "portrait_4_3" // Closest match
        } else {
            return "landscape_4_3"
        }
    default:
        // For custom ratios, try to parse and return custom size
        // If we can't parse, return default
        return "landscape_4_3"
    }
}

// MARK: - Send Image to Fal.ai (Polling Mode)

/// Generates an image using Fal.ai with polling (waits for result)
func sendImageToFalAI(
    prompt: String,
    modelId: String = "fal-ai/z-image/turbo",
    aspectRatio: String? = nil,
    width: Int? = nil,
    height: Int? = nil,
    numInferenceSteps: Int = 8,
    seed: Int? = nil,
    numImages: Int = 1,
    enableSafetyChecker: Bool = true,
    enablePromptExpansion: Bool = false,
    outputFormat: String = "png",
    acceleration: String = "none"
) async throws -> FalAIImageResponse {
    print("[Fal.ai] Preparing image generation request…")
    print("[Fal.ai] Model: \(modelId)")
    print("[Fal.ai] Prompt: \(prompt)")
    
    // Convert aspect ratio to Fal.ai format
    let imageSize = convertAspectRatioToFalImageSize(aspectRatio: aspectRatio, width: width, height: height)
    
    // Build request body
    var requestBody: [String: Any] = [
        "prompt": prompt,
        "image_size": imageSize,
        "num_inference_steps": numInferenceSteps,
        "num_images": numImages,
        "enable_safety_checker": enableSafetyChecker,
        "enable_prompt_expansion": enablePromptExpansion,
        "output_format": outputFormat,
        "acceleration": acceleration
    ]
    
    // Add optional seed if provided
    if let seed = seed {
        requestBody["seed"] = seed
    }
    
    // Use subscribe endpoint for synchronous/polling mode
    let endpoint = "https://fal.run/\(modelId)"
    print("[Fal.ai] Endpoint: \(endpoint)")
    
    let url = URL(string: endpoint)!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Key \(falAIApiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    // Debug log
    if let requestJSON = try? JSONSerialization.data(withJSONObject: requestBody),
       let requestString = String(data: requestJSON, encoding: .utf8) {
        print("[Fal.ai] Request body: \(requestString)")
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
    print("[Fal.ai] Response status code: \(statusCode)")
    
    guard let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode) else {
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
    
    // Parse response
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let imageResponse = try decoder.decode(FalAIImageResponse.self, from: data)
    
    print("[Fal.ai] Image generation completed, \(imageResponse.images.count) image(s) generated")
    return imageResponse
}

// MARK: - Submit Image to Fal.ai with Webhook

/// Submits an image generation request to Fal.ai with a webhook URL
/// The result will be delivered via the webhook callback
func submitImageToFalAIWithWebhook(
    requestId: String,
    prompt: String,
    modelId: String = "fal-ai/z-image/turbo",
    aspectRatio: String? = nil,
    width: Int? = nil,
    height: Int? = nil,
    numInferenceSteps: Int = 8,
    seed: Int? = nil,
    numImages: Int = 1,
    enableSafetyChecker: Bool = true,
    enablePromptExpansion: Bool = false,
    outputFormat: String = "png",
    acceleration: String = "none",
    userId: String
) async throws -> FalAIWebhookSubmissionResponse {
    print("[Fal.ai] Preparing image generation webhook request…")
    print("[Fal.ai] Request ID: \(requestId)")
    print("[Fal.ai] Model: \(modelId)")
    print("[Fal.ai] Prompt: \(prompt)")
    
    // Convert aspect ratio to Fal.ai format
    let imageSize = convertAspectRatioToFalImageSize(aspectRatio: aspectRatio, width: width, height: height)
    
    // Build request body
    var requestBody: [String: Any] = [
        "prompt": prompt,
        "image_size": imageSize,
        "num_inference_steps": numInferenceSteps,
        "num_images": numImages,
        "enable_safety_checker": enableSafetyChecker,
        "enable_prompt_expansion": enablePromptExpansion,
        "output_format": outputFormat,
        "acceleration": acceleration
    ]
    
    // Add optional seed if provided
    if let seed = seed {
        requestBody["seed"] = seed
    }
    
    // Submit to fal.ai queue API with webhook as query parameter
    let webhookURL = WebhookConfig.webhookURL(for: "falai")
    print("[Fal.ai] Webhook URL: \(webhookURL)")
    
    // Properly encode the webhook URL for use as a query parameter value
    // We need to encode the entire URL, including ? and & characters
    var allowedCharacters = CharacterSet.urlQueryAllowed
    allowedCharacters.remove(charactersIn: "?&") // Remove ? and & from allowed set so they get encoded
    let encodedWebhookURL = webhookURL.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? webhookURL
    
    let endpoint = "https://queue.fal.run/\(modelId)?fal_webhook=\(encodedWebhookURL)"
    print("[Fal.ai] Full endpoint URL: \(endpoint)")
    
    let url = URL(string: endpoint)!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Key \(falAIApiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    // Debug log
    if let requestJSON = try? JSONSerialization.data(withJSONObject: requestBody),
       let requestString = String(data: requestJSON, encoding: .utf8) {
        print("[Fal.ai] Request body: \(requestString)")
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
    print("[Fal.ai] Response status code: \(statusCode)")
    
    guard let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode) else {
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
    
    // Parse response to get requestId
    var extractedRequestId: String = requestId
    
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let id = json["request_id"] as? String {
            extractedRequestId = id
            print("[Fal.ai] Using request_id from response: \(id)")
        } else if let id = json["gateway_request_id"] as? String {
            extractedRequestId = id
            print("[Fal.ai] Using gateway_request_id from response: \(id)")
        } else {
            print("[Fal.ai] Warning: Could not find request_id in response, using provided requestId: \(requestId)")
            extractedRequestId = requestId
        }
    } else {
        print("[Fal.ai] Warning: Could not parse response as JSON, using provided requestId: \(requestId)")
        extractedRequestId = requestId
    }
    
    print("[Fal.ai] Image generation request submitted successfully, requestId: \(extractedRequestId)")
    return FalAIWebhookSubmissionResponse(requestId: extractedRequestId, submitted: true)
}
