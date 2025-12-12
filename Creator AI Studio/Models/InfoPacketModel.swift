// Required:
// Title
// ImageName
// Provider
// Endpoint

import SwiftUI

struct InfoPacket: Codable, Identifiable, Hashable {
    var id: UUID = .init()
    var display: DisplayInfo
    var apiConfig: APIConfiguration?  // Now optional - resolved from ModelConfigurationManager based on modelName
    var prompt: String?
    var cost: Decimal?
    var type: String?
    var capabilities: [String]?
    var category: String?

    // Tell the decoder to ignore 'id'
    enum CodingKeys: String, CodingKey {
        case display, apiConfig, prompt, cost, type, capabilities, category
        // Notice: 'id' is NOT listed here
    }
    
    /// Resolved cost from centralized PricingManager.
    /// Falls back to the stored cost property if PricingManager doesn't have a price.
    var resolvedCost: Decimal? {
        return PricingManager.shared.price(for: self) ?? cost
    }
    
    /// Resolved API configuration from centralized ModelConfigurationManager.
    /// Uses modelName as the source of truth. Falls back to stored apiConfig only if manager doesn't have a configuration.
    var resolvedAPIConfig: APIConfiguration {
        // First try to get from centralized manager (modelName is source of truth)
        if let config = ModelConfigurationManager.shared.apiConfiguration(for: self) {
            return config
        }
        // Fallback to stored apiConfig if available (for backward compatibility during migration)
        if let storedConfig = apiConfig {
            return storedConfig
        }
        // Last resort: return a default configuration (should not happen if modelName is properly set)
        // This handles edge cases during migration or for photo filters without modelName
        return APIConfiguration(
            provider: .runware,
            endpoint: "https://api.runware.ai/v1",
            runwareModel: nil,
            aspectRatio: nil,
            wavespeedConfig: nil,
            runwareConfig: nil
        )
    }
    
    /// Resolved capabilities from centralized ModelConfigurationManager.
    /// Falls back to the stored capabilities property if ModelConfigurationManager doesn't have capabilities.
    var resolvedCapabilities: [String]? {
        return ModelConfigurationManager.shared.capabilities(for: self) ?? capabilities
    }
    
    /// Resolved model description from centralized ModelConfigurationManager.
    /// Falls back to the stored display.modelDescription property if ModelConfigurationManager doesn't have a description.
    var resolvedModelDescription: String? {
        return ModelConfigurationManager.shared.modelDescription(for: self) ?? display.modelDescription
    }
    
    /// Resolved model image name from centralized ModelConfigurationManager.
    /// Falls back to the stored display.modelImageName property if ModelConfigurationManager doesn't have an image name.
    var resolvedModelImageName: String? {
        return ModelConfigurationManager.shared.modelImageName(for: self) ?? display.modelImageName
    }
}

struct DisplayInfo: Codable, Hashable {
    var title: String
    var imageName: String
    var imageNameOriginal: String?
    var description: String?
    var modelName: String?
    var modelDescription: String?
    var modelImageName: String?
    var exampleImages: [String]?
    var moreStyles: [[String]]? = []
}

struct APIConfiguration: Codable, Hashable {
    var provider: APIProvider
    var endpoint: String
    var runwareModel: String?
    var aspectRatio: String?

    var wavespeedConfig: WaveSpeedConfig?
    var runwareConfig: RunwareConfig?
}

struct WaveSpeedConfig: Codable, Hashable {
    var outputFormat: String?
    var enableSyncMode: Bool?
    var enableBase64Output: Bool?
}

struct RunwareConfig: Codable, Hashable {
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

enum APIProvider: String, Codable, Hashable {
    case wavespeed
    case runware
}
