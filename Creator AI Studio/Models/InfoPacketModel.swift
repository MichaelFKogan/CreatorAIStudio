// Required:
// Title
// ImageName
// Provider
// Endpoint

import SwiftUI

struct InfoPacket: Codable, Identifiable {
    var id: UUID = .init()
    var display: DisplayInfo
    var apiConfig: APIConfiguration
    var prompt: String?
    var cost: Decimal?
    var type: String?
    var capabilities: [String]?

    // Tell the decoder to ignore 'id'
    enum CodingKeys: String, CodingKey {
        case display, apiConfig, prompt, cost, type, capabilities
        // Notice: 'id' is NOT listed here
    }
}

struct DisplayInfo: Codable {
    var title: String
    var imageName: String
    var imageNameOriginal: String?
    var description: String?
    var modelName: String?
    var modelDescription: String?
    var modelImageName: String?
    var exampleImages: [String]?
}

struct APIConfiguration: Codable {
    var provider: APIProvider
    var endpoint: String
    var runwareModel: String?
    var aspectRatio: String?

    var wavespeedConfig: WaveSpeedConfig?
    var runwareConfig: RunwareConfig?
}

struct WaveSpeedConfig: Codable {
    var outputFormat: String?
    var enableSyncMode: Bool?
    var enableBase64Output: Bool?
}

struct RunwareConfig: Codable {
    // How to handle image-to-image: "referenceImages" or "seedImage"
    var imageToImageMethod: String? // "referenceImages" or "seedImage"
    // Strength for image-to-image (only used with seedImage method)
    var strength: Double?
    // Additional task parameters specific to this model
    var additionalTaskParams: [String: String]?
    // Whether this model requires width/height (some models might not)
    var requiresDimensions: Bool?
    // Default compression quality for image conversion
    var imageCompressionQuality: Double?
    // Output format for the generated image (e.g., "JPEG", "PNG")
    var outputFormat: String?
    // Output type(s) for the response (e.g., ["dataURI", "URL"])
    var outputType: String?
    // Output quality for JPEG images (0-100)
    var outputQuality: Int?
}

enum APIProvider: String, Codable {
    case wavespeed
    case runware
}
