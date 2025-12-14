import SwiftUI

// MARK: - Runware API Response Structure

struct RunwareResponse: Decodable {
    struct DataItem: Decodable {
        let imageURL: String?
        let videoURL: String?
        let status: String?
        let taskUUID: String?
        let taskType: String?

        enum CodingKeys: String, CodingKey {
            case imageURL
            case imageUrl
            case image_url
            case videoURL
            case videoUrl
            case video_url
            case status
            case taskUUID
            case taskUuid
            case task_uuid
            case taskType
            case task_type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            imageURL =
                (try? container.decode(String.self, forKey: .imageURL))
                    ?? (try? container.decode(String.self, forKey: .imageUrl))
                    ?? (try? container.decode(String.self, forKey: .image_url))
            videoURL =
                (try? container.decode(String.self, forKey: .videoURL))
                    ?? (try? container.decode(String.self, forKey: .videoUrl))
                    ?? (try? container.decode(String.self, forKey: .video_url))
            status = try? container.decode(String.self, forKey: .status)
            taskUUID =
                (try? container.decode(String.self, forKey: .taskUUID))
                    ?? (try? container.decode(String.self, forKey: .taskUuid))
                    ?? (try? container.decode(String.self, forKey: .task_uuid))
            taskType =
                (try? container.decode(String.self, forKey: .taskType))
                    ?? (try? container.decode(String.self, forKey: .task_type))
        }
    }

    let data: [DataItem]
    let status: String?
    let error: String?
}

// MARK: - Runware API Key

// Personal API Key
// let runwareApiKey = "JNyjLQK12U5NVmiM7aX9YTjxVvNXyYyJ"

// RunSpeedAI API Key
let runwareApiKey = "zNNJ1KwqNUadOYKQmm58U84JqDjr5qMV"

// MARK: - Image Upload Response Structure

struct RunwareImageUploadResponse: Decodable {
    struct DataItem: Decodable {
        let imageUUID: String?

        enum CodingKeys: String, CodingKey {
            case imageUUID
            case imageUuid
            case image_uuid
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            imageUUID =
                (try? container.decode(String.self, forKey: .imageUUID))
                    ?? (try? container.decode(String.self, forKey: .imageUuid))
                    ?? (try? container.decode(String.self, forKey: .image_uuid))
        }
    }

    let data: DataItem
    let status: String?
    let error: String?
}

// MARK: - Upload Image to Runware

func uploadImageToRunware(image: UIImage) async throws -> String {
    print("[Runware] Uploading image to get UUID…")

    // Fix orientation before converting to base64
    let orientedImage = image.fixedOrientation()

    guard let jpegData = orientedImage.jpegData(compressionQuality: 0.9) else {
        throw NSError(
            domain: "RunwareAPI", code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert image to JPEG",
            ]
        )
    }

    let base64 = jpegData.base64EncodedString()
    let dataURI = "data:image/jpeg;base64,\(base64)"

    let uploadTask: [String: Any] = [
        "taskType": "imageUpload",
        "taskUUID": UUID().uuidString,
        "image": dataURI,
    ]

    let requestBody: [[String: Any]] = [
        ["taskType": "authentication", "apiKey": runwareApiKey],
        uploadTask,
    ]

    let url = URL(string: "https://api.runware.ai/v1")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode)
    else {
        print("[Runware] Image upload HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        throw NSError(
            domain: "RunwareAPI",
            code: (response as? HTTPURLResponse)?.statusCode ?? -1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Runware image upload returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)",
            ]
        )
    }

    // Parse the response - Runware can return different formats
    let json = try JSONSerialization.jsonObject(with: data)

    // Debug: print raw response (first 500 chars)
    if let jsonString = String(data: data, encoding: .utf8) {
        print("[Runware] Upload response (first 500 chars): \(String(jsonString.prefix(500)))")
    }

    // Try parsing as dictionary with data array (actual format from Runware)
    if let responseDict = json as? [String: Any],
       let dataArray = responseDict["data"] as? [[String: Any]]
    {
        // The data array contains objects with imageUUID
        for item in dataArray {
            if let imageUUID = (item["imageUUID"] as? String)
                ?? (item["imageUuid"] as? String)
                ?? (item["image_uuid"] as? String)
            {
                print("[Runware] Image uploaded successfully, UUID: \(imageUUID)")
                return imageUUID
            }
        }
    }

    // Try parsing as array of responses (alternative format)
    if let responseArray = json as? [[String: Any]] {
        // Find the response that contains the imageUUID (skip authentication response)
        for response in responseArray {
            if let dataDict = response["data"] as? [String: Any] {
                let imageUUID = (dataDict["imageUUID"] as? String)
                    ?? (dataDict["imageUuid"] as? String)
                    ?? (dataDict["image_uuid"] as? String)

                if let uuid = imageUUID {
                    print("[Runware] Image uploaded successfully, UUID: \(uuid)")
                    return uuid
                }
            }
            // Also check if imageUUID is directly in the response
            if let imageUUID = (response["imageUUID"] as? String)
                ?? (response["imageUuid"] as? String)
                ?? (response["image_uuid"] as? String)
            {
                print("[Runware] Image uploaded successfully, UUID: \(imageUUID)")
                return imageUUID
            }
        }
    }

    // Try parsing as single dictionary with nested data dictionary
    if let responseDict = json as? [String: Any] {
        // Check if data is a dictionary
        if let dataDict = responseDict["data"] as? [String: Any] {
            let imageUUID = (dataDict["imageUUID"] as? String)
                ?? (dataDict["imageUuid"] as? String)
                ?? (dataDict["image_uuid"] as? String)

            if let uuid = imageUUID {
                print("[Runware] Image uploaded successfully, UUID: \(uuid)")
                return uuid
            }
        }

        // Check if imageUUID is directly in the response
        if let imageUUID = (responseDict["imageUUID"] as? String)
            ?? (responseDict["imageUuid"] as? String)
            ?? (responseDict["image_uuid"] as? String)
        {
            print("[Runware] Image uploaded successfully, UUID: \(imageUUID)")
            return imageUUID
        }
    }

    // Try decoding with Decoder as last resort
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    if let uploadResponse = try? decoder.decode(RunwareImageUploadResponse.self, from: data),
       let imageUUID = uploadResponse.data.imageUUID
    {
        print("[Runware] Image uploaded successfully, UUID: \(imageUUID)")
        return imageUUID
    }

    // If all parsing attempts fail, throw error with response info
    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
    throw NSError(
        domain: "RunwareAPI", code: -1,
        userInfo: [
            NSLocalizedDescriptionKey: "Invalid response format from image upload",
            "response": responseString,
        ]
    )
}

// MARK: - Async Send Image to Runware

func sendImageToRunware(
    image: UIImage?,
    prompt: String,
    model: String,
    aspectRatio: String? = nil,
    isImageToImage: Bool = false,
    runwareConfig: RunwareConfig? = nil
) async throws -> RunwareResponse {
    print("[Runware] Preparing request…")
    print("[Runware] Model: \(model)")
    print("[Runware] Prompt: \(prompt)")
    print("[Runware] Mode: \(isImageToImage ? "Image-to-Image" : "Text-to-Image")")
    if let config = runwareConfig {
        print("[Runware] Runware Config: \(config)")
    }

    // MARK: - Determine width/height

    // Get model-specific allowed sizes
    let allowedSizes = getAllowedSizes(for: model)

    var width = 1024
    var height = 1024
    if let ratio = aspectRatio?.trimmingCharacters(in: .whitespacesAndNewlines),
       let (w, h) = allowedSizes[ratio]
    {
        width = w
        height = h
        print("[Runware] Aspect ratio: \(ratio) -> \(width)x\(height)")
    } else {
        print("[Runware] Using default 1024x1024")
    }

    // MARK: - Build task body

    var task: [String: Any] = [
        "taskType": "imageInference",
        "taskUUID": UUID().uuidString,
        "model": model,
        "positivePrompt": prompt,
        "numberResults": 1,
        "includeCost": true,
    ]

    // Add dimensions if required (default: true)
    let requiresDimensions = runwareConfig?.requiresDimensions ?? true
    if requiresDimensions {
        task["width"] = width
        task["height"] = height
    }

    // MARK: - Image-to-image: handle reference images

    if isImageToImage, let seedImage = image {
        // Determine method from config (default: "referenceImages")
        let method = runwareConfig?.imageToImageMethod ?? "referenceImages"

        // FLUX.2 [dev] and Riverflow 2 models require referenceImages inside an inputs object
        let isFlux2Dev = model.lowercased().contains("runware:400@1")
        let isRiverflow2 = model.lowercased().contains("sourceful:2@") // Riverflow 2 Fast, Standard, Max
        let requiresInputsObject = isFlux2Dev || isRiverflow2

        // Riverflow 2 models require image upload to get UUID (not base64)
        if isRiverflow2 && method == "referenceImages" {
            // Upload image first to get UUID
            let imageUUID = try await uploadImageToRunware(image: seedImage)

            // Use UUID in inputs object
            var inputs: [String: Any] = [:]
            inputs["referenceImages"] = [imageUUID]
            task["inputs"] = inputs
            print("[Runware] Image-to-image enabled with referenceImages UUID in inputs object: \(imageUUID)")
        } else {
            // For other models, use base64 data URI
            let orientedImage = seedImage.fixedOrientation()
            let compressionQuality = runwareConfig?.imageCompressionQuality ?? 0.9

            guard let jpegData = orientedImage.jpegData(compressionQuality: compressionQuality) else {
                throw NSError(
                    domain: "RunwareAPI", code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to convert image to JPEG",
                    ]
                )
            }
            let base64 = jpegData.base64EncodedString()
            let dataURI = "data:image/jpeg;base64,\(base64)"

            switch method {
            case "referenceImages":
                if requiresInputsObject {
                    // FLUX.2 [dev] requires referenceImages inside inputs object
                    var inputs: [String: Any] = [:]
                    inputs["referenceImages"] = [dataURI]
                    task["inputs"] = inputs
                    print("[Runware] Image-to-image enabled with referenceImages in inputs object (Base64 preview): \(String(dataURI.prefix(100)))…")
                } else {
                    task["referenceImages"] = [dataURI]
                    print("[Runware] Image-to-image enabled with referenceImages (Base64 preview): \(String(dataURI.prefix(100)))…")
                }

            case "seedImage":
                task["seedImage"] = dataURI
                if let strength = runwareConfig?.strength {
                    task["strength"] = strength
                }
                print("[Runware] Image-to-image enabled with seedImage, strength: \(runwareConfig?.strength ?? 0.7) (Base64 preview): \(String(dataURI.prefix(100)))…")

            default:
                // Fallback to referenceImages for unknown methods
                if requiresInputsObject {
                    var inputs: [String: Any] = [:]
                    inputs["referenceImages"] = [dataURI]
                    task["inputs"] = inputs
                    print("[Runware] Unknown method '\(method)', defaulting to referenceImages in inputs object (Base64 preview): \(String(dataURI.prefix(100)))…")
                } else {
                    task["referenceImages"] = [dataURI]
                    print("[Runware] Unknown method '\(method)', defaulting to referenceImages (Base64 preview): \(String(dataURI.prefix(100)))…")
                }
            }
        }
    }

    // MARK: - Add output format parameters

    // Add output format if specified
    if let outputFormat = runwareConfig?.outputFormat {
        task["outputFormat"] = outputFormat
        print("[Runware] Output format: \(outputFormat)")
    }

    // Add output type(s) if specified
    if let outputType = runwareConfig?.outputType {
        task["outputType"] = outputType
        print("[Runware] Output type: \(outputType)")
    }

    // Add output quality if specified (for JPEG)
    if let outputQuality = runwareConfig?.outputQuality {
        task["outputQuality"] = outputQuality
        print("[Runware] Output quality: \(outputQuality)")
    }

    // Add any additional model-specific parameters
    if let additionalParams = runwareConfig?.additionalTaskParams {
        for (key, value) in additionalParams {
            task[key] = value
        }
        print("[Runware] Added \(additionalParams.count) additional task parameters")
    }

    // MARK: - FLUX.2 [dev] specific parameters

    // FLUX.2 [dev] requires steps and CFGScale parameters
    if model.lowercased().contains("runware:400@1") {
        // Only add if not already provided via additionalTaskParams
        if task["steps"] == nil {
            task["steps"] = 30 // Default steps for FLUX.2 [dev]
            print("[Runware] Added default steps: 30 for FLUX.2 [dev]")
        }
        if task["CFGScale"] == nil {
            task["CFGScale"] = 4.0 // Default CFGScale for FLUX.2 [dev]
            print("[Runware] Added default CFGScale: 4.0 for FLUX.2 [dev]")
        }
    }

    // MARK: - Wrap task in authentication array (required!)

    let requestBody: [[String: Any]] = [
        ["taskType": "authentication", "apiKey": runwareApiKey],
        task,
    ]

    let url = URL(string: "https://api.runware.ai/v1")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    // MARK: - Send request

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode)
    else {
        print(
            "[Runware] HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
        )
        throw NSError(
            domain: "RunwareAPI",
            code: (response as? HTTPURLResponse)?.statusCode ?? -1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Runware returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)",
            ]
        )
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let runwareResponse = try decoder.decode(RunwareResponse.self, from: data)

    guard let first = runwareResponse.data.first,
          let urlStr = first.imageURL
    else {
        throw NSError(
            domain: "RunwareAPI", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "No image URL returned"]
        )
    }

    print("[Runware] Image URL: \(urlStr)")
    return runwareResponse
}

// MARK: - Send Video to Runware

func sendVideoToRunware(
    image: UIImage?,
    prompt: String,
    model: String,
    aspectRatio: String? = nil,
    duration: Double = 5.0,
    isImageToVideo: Bool = false,
    runwareConfig: RunwareConfig? = nil,
    onPollingProgress: ((Int, Int) -> Void)? = nil
) async throws -> RunwareResponse {
    print("[Runware] Preparing video request…")
    print("[Runware] Model: \(model)")
    print("[Runware] Prompt: \(prompt)")
    print("[Runware] Duration: \(duration) seconds")
    print("[Runware] Mode: \(isImageToVideo ? "Image-to-Video" : "Text-to-Video")")
    if let config = runwareConfig {
        print("[Runware] Runware Config: \(config)")
    }

    // MARK: - Determine width/height

    // Get model-specific allowed sizes
    let allowedSizes = getAllowedSizes(for: model)

    var width = 1920
    var height = 1088
    if let ratio = aspectRatio?.trimmingCharacters(in: .whitespacesAndNewlines),
       let (w, h) = allowedSizes[ratio]
    {
        width = w
        height = h
        print("[Runware] Aspect ratio: \(ratio) -> \(width)x\(height)")
    } else {
        print("[Runware] Using default 1920x1088")
    }

    // MARK: - Build task body

    var task: [String: Any] = [
        "taskType": "videoInference",
        "taskUUID": UUID().uuidString,
        "model": model,
        "positivePrompt": prompt,
        "duration": duration,
        "width": width,
        "height": height,
        "includeCost": true,
    ]

    // MARK: - Image-to-video: handle frame images

    if isImageToVideo, let seedImage = image {
        // Seedance 1.0 Pro Fast uses frameImages with first frame only
        let method = runwareConfig?.imageToImageMethod ?? "frameImages"
        
        if method == "frameImages" {
            let orientedImage = seedImage.fixedOrientation()
            let compressionQuality = runwareConfig?.imageCompressionQuality ?? 0.9

            guard let jpegData = orientedImage.jpegData(compressionQuality: compressionQuality) else {
                throw NSError(
                    domain: "RunwareAPI", code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to convert image to JPEG",
                    ]
                )
            }
            let base64 = jpegData.base64EncodedString()
            let dataURI = "data:image/jpeg;base64,\(base64)"

            // Upload image first to get UUID (required for frameImages)
            let imageUUID = try await uploadImageToRunware(image: seedImage)
            
            task["frameImages"] = [
                [
                    "inputImage": imageUUID,
                    "frame": "first"
                ]
            ]
            print("[Runware] Image-to-video enabled with frameImages (first frame): \(imageUUID)")
        }
    }

    // MARK: - Add output format parameters

    // Add output format if specified
    if let outputFormat = runwareConfig?.outputFormat {
        task["outputFormat"] = outputFormat
        print("[Runware] Output format: \(outputFormat)")
    }

    // Add output type(s) if specified
    if let outputType = runwareConfig?.outputType {
        task["outputType"] = outputType
        print("[Runware] Output type: \(outputType)")
    }

    // Add any additional model-specific parameters
    if let additionalParams = runwareConfig?.additionalTaskParams {
        for (key, value) in additionalParams {
            // Don't override taskType if it's already set
            if key != "taskType" {
                task[key] = value
            }
        }
        print("[Runware] Added \(additionalParams.count) additional task parameters")
    }

    // MARK: - Provider-specific settings for ByteDance models

    // Seedance 1.0 Pro Fast supports cameraFixed parameter
    if model.lowercased().contains("bytedance:2@2") {
        var providerSettings: [String: Any] = [:]
        var bytedanceSettings: [String: Any] = [:]
        // cameraFixed defaults to false (allows camera movement)
        // Can be set to true if needed for static shots
        bytedanceSettings["cameraFixed"] = false
        providerSettings["bytedance"] = bytedanceSettings
        task["providerSettings"] = providerSettings
        print("[Runware] Added ByteDance provider settings")
    }

    // MARK: - Wrap task in authentication array (required!)

    let requestBody: [[String: Any]] = [
        ["taskType": "authentication", "apiKey": runwareApiKey],
        task,
    ]

    // Debug: print request body (without API key for security)
    if let requestJSON = try? JSONSerialization.data(withJSONObject: requestBody),
       let requestString = String(data: requestJSON, encoding: .utf8) {
        // Mask API key in log
        let maskedRequest = requestString.replacingOccurrences(
            of: "\"apiKey\":\"[^\"]+\"",
            with: "\"apiKey\":\"***\"",
            options: .regularExpression
        )
        print("[Runware] Video request body: \(maskedRequest)")
    }

    let url = URL(string: "https://api.runware.ai/v1")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    // MARK: - Send request
    
    print("[Runware] Sending video request to: \(url.absoluteString)")

    let (data, response) = try await URLSession.shared.data(for: request)
    
    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
    print("[Runware] Video response status code: \(statusCode)")

    guard let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode)
    else {
        // Log error response body
        if let errorString = String(data: data, encoding: .utf8) {
            print("[Runware] Error response body: \(errorString)")
        }
        print(
            "[Runware] HTTP error: \(statusCode)"
        )
        throw NSError(
            domain: "RunwareAPI",
            code: statusCode,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Runware returned HTTP \(statusCode)",
            ]
        )
    }

    // Debug: print raw response
    if let jsonString = String(data: data, encoding: .utf8) {
        print("[Runware] Video response (first 1000 chars): \(String(jsonString.prefix(1000)))")
    }
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let runwareResponse = try decoder.decode(RunwareResponse.self, from: data)
    
    // Check if this is an async task that needs polling
    let isAsync = runwareConfig?.additionalTaskParams?["deliveryMethod"] as? String == "async"
    let taskUUID = task["taskUUID"] as? String
    
    // If async and no URL yet, poll for completion
    // Check for both videoURL and imageURL
    let hasURL = runwareResponse.data.first?.videoURL != nil || runwareResponse.data.first?.imageURL != nil
    if isAsync, let taskUUID = taskUUID, !hasURL {
        print("[Runware] Async task detected, polling for completion...")
        print("[Runware] Task UUID: \(taskUUID)")
        
        // Poll for the result
        let maxPollingAttempts = 120 // 10 minutes max (120 * 5 seconds)
        let pollInterval: UInt64 = 5_000_000_000 // 5 seconds
        
        // Initial delay before first poll (videos take time to start processing)
        print("[Runware] Waiting 10 seconds before first poll...")
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        for attempt in 0..<maxPollingAttempts {
            let attemptNumber = attempt + 1
            print("[Runware] Polling attempt \(attemptNumber)/\(maxPollingAttempts)...")
            
            // Report polling progress
            onPollingProgress?(attemptNumber, maxPollingAttempts)
            
            // Poll using the task UUID
            let pollResponse = try await pollRunwareTaskStatus(taskUUID: taskUUID)
            
            // Check the data item for status and URL
            guard let first = pollResponse.data.first else {
                print("[Runware] No data in polling response, continuing to poll...")
                if attempt < maxPollingAttempts - 1 {
                    try await Task.sleep(nanoseconds: pollInterval)
                }
                continue
            }
            
            // Check for video URL (prefer videoURL, fallback to imageURL)
            if let urlStr = first.videoURL ?? first.imageURL {
                print("[Runware] Video URL received after polling: \(urlStr)")
                // Create a response with the URL in imageURL field for compatibility
                var responseWithURL = pollResponse
                if responseWithURL.data.first?.imageURL == nil {
                    // We need to create a new data item with imageURL set
                    // Since DataItem is a struct, we'll need to reconstruct
                    // For now, return the response as-is since we'll check for videoURL in VideoGenerationTask
                }
                return pollResponse
            }
            
            // Check status from data item (not top-level)
            if let status = first.status {
                let statusLower = status.lowercased()
                if statusLower == "failed" || statusLower == "error" {
                    throw NSError(
                        domain: "RunwareAPI", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: pollResponse.error ?? "Video generation failed"]
                    )
                }
                if statusLower == "success" || statusLower == "completed" {
                    // If status is success but no URL yet, continue polling (might be delayed)
                    print("[Runware] Status: \(status), but no URL yet, continuing to poll...")
                } else if statusLower == "processing" {
                    print("[Runware] Status: \(status), continuing to poll...")
                } else {
                    print("[Runware] Status: \(status), continuing to poll...")
                }
            } else {
                // Check top-level status as fallback
                if let status = pollResponse.status {
                    let statusLower = status.lowercased()
                    if statusLower == "failed" || statusLower == "error" {
                        throw NSError(
                            domain: "RunwareAPI", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: pollResponse.error ?? "Video generation failed"]
                        )
                    }
                    print("[Runware] Top-level status: \(status), continuing to poll...")
                } else {
                    // No status field, assume still processing if no URL
                    print("[Runware] No status field, continuing to poll...")
                }
            }
            
            // Check for error in response
            if let error = pollResponse.error, !error.isEmpty {
                throw NSError(
                    domain: "RunwareAPI", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Video generation failed: \(error)"]
                )
            }
            
            // Sleep before next poll (except on last attempt)
            if attempt < maxPollingAttempts - 1 {
                try await Task.sleep(nanoseconds: pollInterval)
            }
        }
        
        throw NSError(
            domain: "RunwareAPI", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for video generation after \(maxPollingAttempts * 5) seconds"]
        )
    }

    // For sync requests, expect URL immediately
    guard let first = runwareResponse.data.first,
          let urlStr = first.imageURL
    else {
        // If async wasn't detected but no URL, provide more helpful error
        let errorMsg = isAsync 
            ? "Async task started but polling failed. Task UUID: \(taskUUID ?? "unknown")"
            : "No video URL returned. Response status: \(runwareResponse.status ?? "unknown"), Error: \(runwareResponse.error ?? "none")"
        throw NSError(
            domain: "RunwareAPI", code: -1,
            userInfo: [NSLocalizedDescriptionKey: errorMsg]
        )
    }

    print("[Runware] Video URL: \(urlStr)")
    return runwareResponse
}

// MARK: - Poll Runware Task Status

func pollRunwareTaskStatus(taskUUID: String) async throws -> RunwareResponse {
    // Use getResponse task type to poll for async task status
    let task: [String: Any] = [
        "taskType": "getResponse",
        "taskUUID": taskUUID
    ]
    
    let requestBody: [[String: Any]] = [
        ["taskType": "authentication", "apiKey": runwareApiKey],
        task,
    ]
    
    let url = URL(string: "https://api.runware.ai/v1")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let http = response as? HTTPURLResponse,
          (200 ... 299).contains(http.statusCode)
    else {
        // Log the error response for debugging
        if let errorData = String(data: data, encoding: .utf8) {
            print("[Runware] Polling error response: \(errorData)")
        }
        throw NSError(
            domain: "RunwareAPI",
            code: (response as? HTTPURLResponse)?.statusCode ?? -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Runware polling returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)",
            ]
        )
    }
    
    // Debug: print raw response
    if let jsonString = String(data: data, encoding: .utf8) {
        print("[Runware] Polling response: \(String(jsonString.prefix(500)))")
    }
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(RunwareResponse.self, from: data)
}

// MARK: - UIImage Extension

extension UIImage {
    func fixedOrientation() -> UIImage {
        // If image is already in correct orientation, return it
        if imageOrientation == .up {
            return self
        }

        // Create a graphics context and draw the image in correct orientation
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }
}
