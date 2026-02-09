//
//  WaveSpeedAPI.swift
//  AI Photo Generation
//
//  Created by Mike K on 10/19/25.
//

import SwiftUI

struct WaveSpeedResponse: Decodable {
    struct DataItem: Decodable {
        let id: String
        let outputs: [String]?
        let status: String
        let error: String?
    }

    let code: Int
    let message: String
    let data: DataItem
}

// MARK: - WaveSpeed Proxy (API key stored in Supabase Edge Function secrets)

/// Sends a request to the WaveSpeed API via the wavespeed-proxy Edge Function.
/// Proxy injects WAVESPEED_API_KEY server-side; app sends Supabase auth only.
private func wavespeedProxyRequest(endpoint: String, body: [String: Any], methodGET: Bool = false) async throws -> Data {
    let session = try await SupabaseManager.shared.client.auth.session
    let proxyURL = URL(string: WebhookConfig.wavespeedProxyURL)!
    var proxyBody: [String: Any] = ["endpoint": endpoint]
    if methodGET {
        proxyBody["method"] = "GET"
        proxyBody["body"] = [String: Any]()
    } else {
        proxyBody["body"] = body
    }
    var request = URLRequest(url: proxyURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: proxyBody)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
        throw URLError(.badServerResponse)
    }
    return data
}

// MARK: - WaveSpeed Webhook Submission Response

/// Response from submitting a job with webhook (returns immediately)
struct WaveSpeedWebhookSubmissionResponse {
    let jobId: String
    let submitted: Bool
}

func sendImageToWaveSpeed(
    image: UIImage,
    prompt: String,
    endpoint: String,
    
    aspectRatio: String? = nil, // optional, e.g., "1:1", "16:9"
    outputFormat: String = "jpeg", // "jpeg" or "png"
    enableSyncMode: Bool = true,
    enableBase64Output: Bool = false,

    maxPollingAttempts: Int = 15, // Default 15 for images (30s), use higher for videos
    userId: String? = nil // Required for endpoints that need URL format (like nano-banana)

) async throws -> WaveSpeedResponse {
    // MARK: REQUEST SETUP (via proxy – API key in Supabase secrets)

    print("[WaveSpeed] Preparing request…")

    // MARK: DETERMINE ENDPOINT REQUIREMENTS

    // Check if this endpoint requires URL format instead of base64
    let requiresURLFormat = endpoint.contains("nano-banana") || endpoint.contains("google/")

    print("[WaveSpeed] Endpoint: \(endpoint)")
    print("[WaveSpeed] Requires URL format: \(requiresURLFormat)")

    var body: [String: Any] = [:]

    // MARK: BUILD (URL MODE)

    if requiresURLFormat {
        // Endpoints like nano-banana require images as URL array
        print("[WaveSpeed] 📤 Uploading image to Supabase to get public URL...")

        guard let userId = userId else {
            throw NSError(domain: "WaveSpeedAPI", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "userId is required for this endpoint",
            ])
        }

        // Upload image to Supabase to get a public URL
        let imageURL = try await SupabaseManager.shared.uploadImage(
            image: image,
            userId: userId,
            modelName: "temp-wavespeed"
        )

        print("[WaveSpeed] Image uploaded, public URL: \(imageURL)")

        // Use "images" array format for nano-banana
        // Note: nano-banana typically uses enable_sync_mode: false and polls for results
        body["images"] = [imageURL]
        body["output_format"] = outputFormat
        body["enable_sync_mode"] = false // nano-banana uses async mode with polling
        body["enable_base64_output"] = false

    } else {
        // MARK: BUILD (BASE64 MODE)

        // Standard base64 format for most endpoints
        print("[WaveSpeed] Using standard base64 format...")

        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            print("[WaveSpeed] Failed to convert UIImage to JPEG data.")
            throw URLError(.cannotDecodeRawData)
        }

        let base64String = jpegData.base64EncodedString()
//        let dataURL = "data:image/jpeg;base64,\(base64String)"

//        body["image"] = dataURL
        if endpoint.contains("/bytedance/") {
            // For Bytedance (e.g., seedream-v4)
            print("[WaveSpeed] Using Bytedance-compatible format (images array, raw base64).")
            body["images"] = [base64String] // raw base64, no data:image/jpeg prefix
        } else {
            // Default for Google or other endpoints
            body["image"] = "data:image/jpeg;base64,\(base64String)"
        }

        body["output_format"] = outputFormat
        body["enable_sync_mode"] = enableSyncMode
        body["enable_base64_output"] = enableBase64Output
    }

    // MARK: ADD OPTIONAL PARAMETERS

    // Only include prompt if it's not empty
    if !prompt.isEmpty {
        body["prompt"] = prompt
        print("[WaveSpeed] Including prompt: \(prompt)")
    } else {
        print("[WaveSpeed] No prompt provided, skipping prompt parameter")
    }

    // Only include optional params if they're set AND not empty
    if let aspectRatio = aspectRatio, !aspectRatio.isEmpty {
        body["aspect_ratio"] = aspectRatio
        print("[WaveSpeed] Including aspect_ratio: \(aspectRatio)")
    }

    // Debug: Print request body structure (without full base64 data)
    var debugBody = body
    if let imageData = debugBody["image"] as? String, imageData.hasPrefix("data:image") {
        debugBody["image"] = "data:image/jpeg;base64,[BASE64_DATA_TRUNCATED]"
    }
    if let bodyJSON = try? JSONSerialization.data(withJSONObject: debugBody),
       let bodyString = String(data: bodyJSON, encoding: .utf8)
    {
        print("[WaveSpeed] Request body: \(bodyString)")
    }

    // MARK: SEND REQUEST VIA PROXY + DECODE RESPONSE

    print("[WaveSpeed] Sending request via proxy…")

    do {
        let data = try await wavespeedProxyRequest(endpoint: endpoint, body: body)
        print("[WaveSpeed] Response received from API.")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let wavespeedResponse = try decoder.decode(WaveSpeedResponse.self, from: data)
        print("[WaveSpeed] Decoded response. Status: \(wavespeedResponse.data.status)")

        if wavespeedResponse.data.status == "created" {
            print("[WaveSpeed] Job created, polling for completion…")
            let jobId = wavespeedResponse.data.id
            var statusResponse: WaveSpeedResponse
            let pollInterval: UInt64 = 5_000_000_000 // 5 seconds between polls
            print("[WaveSpeed] Will poll up to \(maxPollingAttempts) times (every 5 seconds = \(maxPollingAttempts * 5)s max)")

            for attempt in 0 ..< maxPollingAttempts {
                try await Task.sleep(nanoseconds: pollInterval)
                print("[WaveSpeed] Polling attempt \(attempt + 1)/\(maxPollingAttempts)...")
                statusResponse = try await fetchWaveSpeedJobStatus(id: jobId)

                if statusResponse.data.status == "completed" {
                    print("[WaveSpeed] Job completed successfully!")
                    return statusResponse
                } else if statusResponse.data.status == "failed" {
                    throw NSError(domain: "WaveSpeedAPI", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: statusResponse.data.error ?? "WaveSpeed job failed.",
                    ])
                } else {
                    print("[WaveSpeed] Status: \(statusResponse.data.status), continuing to poll...")
                }
            }
            throw NSError(domain: "WaveSpeedAPI", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Timed out waiting for generation after \(maxPollingAttempts * 5) seconds.",
            ])

        } else if wavespeedResponse.data.status != "completed" {
            print("[WaveSpeed] Error from API: \(wavespeedResponse.data.error ?? "Unknown error")")
            throw NSError(domain: "WaveSpeedAPI", code: 0, userInfo: [
                NSLocalizedDescriptionKey: wavespeedResponse.data.error ?? "Unknown error",
            ])
        }

        if let urlString = wavespeedResponse.data.outputs?.first {
            print("[WaveSpeed] Generated image URL: \(urlString)")
        } else {
            print("[WaveSpeed] No outputs returned from API.")
        }

        return wavespeedResponse

    } catch {
        print("[WaveSpeed] Network or decoding error: \(error)")
        throw error
    }
}

// MARK: - FUNCTION FETCH JOB STATUS (POLLING HELPER)

func fetchWaveSpeedJobStatus(id: String) async throws -> WaveSpeedResponse {
    let statusURL = "https://api.wavespeed.ai/api/v3/predictions/\(id)/result"
    let data = try await wavespeedProxyRequest(endpoint: statusURL, body: [:], methodGET: true)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(WaveSpeedResponse.self, from: data)
}

// MARK: - Submit Image with Webhook (Returns Immediately)

/// Submits an image generation request with a webhook URL and returns immediately
/// The result will be delivered via the webhook callback
func submitImageToWaveSpeedWithWebhook(
    taskId: String,
    image: UIImage,
    prompt: String,
    endpoint: String,
    aspectRatio: String? = nil,
    outputFormat: String = "jpeg",
    userId: String? = nil
) async throws -> WaveSpeedWebhookSubmissionResponse {
    print("[WaveSpeed] Preparing webhook request…")
    print("[WaveSpeed] Task ID: \(taskId)")
    print("[WaveSpeed] Endpoint: \(endpoint)")
    
    // Build webhook URL - WaveSpeed uses query parameter
    let webhookURL = WebhookConfig.webhookURL(for: "wavespeed")
    let endpointWithWebhook: String
    if endpoint.contains("?") {
        endpointWithWebhook = "\(endpoint)&webhook=\(webhookURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? webhookURL)"
    } else {
        endpointWithWebhook = "\(endpoint)?webhook=\(webhookURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? webhookURL)"
    }
    
    print("[WaveSpeed] Endpoint with webhook: \(endpointWithWebhook)")
    
    // Check if this endpoint requires URL format instead of base64
    let requiresURLFormat = endpoint.contains("nano-banana") || endpoint.contains("google/")
    
    var body: [String: Any] = [:]
    
    if requiresURLFormat {
        guard let userId = userId else {
            throw NSError(domain: "WaveSpeedAPI", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "userId is required for this endpoint",
            ])
        }
        
        // Upload image to Supabase to get a public URL
        let imageURL = try await SupabaseManager.shared.uploadImage(
            image: image,
            userId: userId,
            modelName: "temp-wavespeed"
        )
        
        print("[WaveSpeed] Image uploaded for webhook, public URL: \(imageURL)")
        
        body["images"] = [imageURL]
        body["output_format"] = outputFormat
        body["enable_sync_mode"] = false // Must be false for webhook
        body["enable_base64_output"] = false
        
    } else {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        let base64String = jpegData.base64EncodedString()
        
        if endpoint.contains("/bytedance/") {
            body["images"] = [base64String]
        } else {
            body["image"] = "data:image/jpeg;base64,\(base64String)"
        }
        
        body["output_format"] = outputFormat
        body["enable_sync_mode"] = false // Must be false for webhook
        body["enable_base64_output"] = false
    }
    
    // Add prompt if provided
    if !prompt.isEmpty {
        body["prompt"] = prompt
    }
    
    // Add aspect ratio if provided
    if let aspectRatio = aspectRatio, !aspectRatio.isEmpty {
        body["aspect_ratio"] = aspectRatio
    }
    
    // Debug log
    var debugBody = body
    if let imageData = debugBody["image"] as? String, imageData.hasPrefix("data:image") {
        debugBody["image"] = "data:image/jpeg;base64,[BASE64_DATA_TRUNCATED]"
    }
    if let bodyJSON = try? JSONSerialization.data(withJSONObject: debugBody),
       let bodyString = String(data: bodyJSON, encoding: .utf8) {
        print("[WaveSpeed] Webhook request body: \(bodyString)")
    }
    
    print("[WaveSpeed] Sending webhook request via proxy…")
    
    let data = try await wavespeedProxyRequest(endpoint: endpointWithWebhook, body: body)
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let wavespeedResponse = try decoder.decode(WaveSpeedResponse.self, from: data)
    
    // The response should have status "created" since we're using async mode
    print("[WaveSpeed] Webhook request submitted successfully")
    print("[WaveSpeed] Job ID: \(wavespeedResponse.data.id)")
    print("[WaveSpeed] Status: \(wavespeedResponse.data.status)")
    
    return WaveSpeedWebhookSubmissionResponse(
        jobId: wavespeedResponse.data.id,
        submitted: true
    )
}

// MARK: - Video Effects (e.g. video-effects/fishermen — mermaid-style image-to-video)

/// Submits an image to a WaveSpeed video-effects endpoint (e.g. fishermen/mermaid).
/// Returns the WaveSpeed job ID; use it as pending_jobs.task_id so the webhook can update the row.
/// Image is uploaded to Supabase and passed as URL (API accepts URL or base64).
func submitVideoEffectToWaveSpeedWithWebhook(
    image: UIImage,
    endpoint: String,
    userId: String
) async throws -> String {
    print("[WaveSpeed] Video effect: preparing request, endpoint: \(endpoint)")
    
    let webhookURL = WebhookConfig.webhookURL(for: "wavespeed")
    let endpointWithWebhook = endpoint.contains("?")
        ? "\(endpoint)&webhook=\(webhookURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? webhookURL)"
        : "\(endpoint)?webhook=\(webhookURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? webhookURL)"
    
    let imageURL = try await SupabaseManager.shared.uploadImage(
        image: image,
        userId: userId,
        modelName: "temp-wavespeed-video-effect"
    )
    print("[WaveSpeed] Video effect: image uploaded, URL: \(imageURL)")
    
    let body: [String: Any] = ["image": imageURL]
    let data = try await wavespeedProxyRequest(endpoint: endpointWithWebhook, body: body)
    
    // API may return { data: { id, status } } or top-level { id, status }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    if let wrapped = try? decoder.decode(WaveSpeedResponse.self, from: data) {
        print("[WaveSpeed] Video effect job id: \(wrapped.data.id)")
        return wrapped.data.id
    }
    struct FlatResponse: Decodable { let id: String }
    let flat = try decoder.decode(FlatResponse.self, from: data)
    print("[WaveSpeed] Video effect job id (flat): \(flat.id)")
    return flat.id
}
