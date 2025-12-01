import SwiftUI

// MARK: - Runware API Response Structure

struct RunwareResponse: Decodable {
    struct DataItem: Decodable {
        let imageURL: String?

        enum CodingKeys: String, CodingKey {
            case imageURL
            case imageUrl
            case image_url
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            imageURL =
                (try? container.decode(String.self, forKey: .imageURL))
                    ?? (try? container.decode(String.self, forKey: .imageUrl))
                    ?? (try? container.decode(String.self, forKey: .image_url))
        }
    }

    let data: [DataItem]
    let status: String?
    let error: String?
}

// MARK: - Runware API Key

let runwareApiKey = "JNyjLQK12U5NVmiM7aX9YTjxVvNXyYyJ"

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

    // MARK: - Image-to-image: add Base64 reference image

    if isImageToImage, let seedImage = image {
        // Fix orientation before converting to base64
        let orientedImage = seedImage.fixedOrientation()

        // Use compression quality from config (default: 0.9)
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

        // Determine method from config (default: "referenceImages")
        let method = runwareConfig?.imageToImageMethod ?? "referenceImages"

        switch method {
        case "referenceImages":
            task["referenceImages"] = [dataURI]
            print("[Runware] Image-to-image enabled with referenceImages (Base64 preview): \(String(dataURI.prefix(100)))…")

        case "seedImage":
            task["seedImage"] = dataURI
            if let strength = runwareConfig?.strength {
                task["strength"] = strength
            }
            print("[Runware] Image-to-image enabled with seedImage, strength: \(runwareConfig?.strength ?? 0.7) (Base64 preview): \(String(dataURI.prefix(100)))…")

        default:
            // Fallback to referenceImages for unknown methods
            task["referenceImages"] = [dataURI]
            print("[Runware] Unknown method '\(method)', defaulting to referenceImages (Base64 preview): \(String(dataURI.prefix(100)))…")
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
