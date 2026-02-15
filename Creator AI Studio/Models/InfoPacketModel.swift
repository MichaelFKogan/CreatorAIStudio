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
    var referenceVideoName: String?  // Reference video name for motion control (used by dance filters)
    var referenceImageName: String?   // Reference image name for style (used by Spooky video filters, O1 reference-to-video)
    /// WaveSpeed video-effects API endpoint (e.g. video-effects/fishermen for mermaid-style). When set, detail page uses WaveSpeed image→video.
    var wavespeedVideoEffectEndpoint: String?

    // Tell the decoder to ignore 'id'
    enum CodingKeys: String, CodingKey {
        case display, apiConfig, prompt, cost, type, capabilities, category, referenceVideoName, referenceImageName, wavespeedVideoEffectEndpoint
        // Notice: 'id' is NOT listed here
    }
    
    /// Resolved cost from centralized PricingManager.
    /// For variable-priced video models, when the detail page has set an explicit cost (e.g. duration-specific),
    /// that value is used so the correct price is stored and deducted. Otherwise falls back to PricingManager
    /// (default config for display) or the stored cost property.
    var resolvedCost: Decimal? {
        let modelName = display.modelName ?? ""
        if PricingManager.shared.hasVariablePricing(for: modelName), let explicitCost = cost {
            return explicitCost
        }
        return PricingManager.shared.price(for: self) ?? cost
    }
    
    /// Resolved API configuration from centralized ModelConfigurationManager.
    /// Merges manager config with stored apiConfig, prioritizing stored values (especially aspectRatio).
    var resolvedAPIConfig: APIConfiguration {
        // Get base config from manager (or fallback)
        let baseConfig: APIConfiguration
        if let managerConfig = ModelConfigurationManager.shared.apiConfiguration(for: self) {
            baseConfig = managerConfig
        } else if let storedConfig = apiConfig {
            return storedConfig
        } else {
            // Last resort: return a default configuration
            baseConfig = APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: nil,
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: nil,
                falConfig: nil
            )
        }
        
        // If there's a stored apiConfig, merge it with base config, prioritizing stored values
        if let storedConfig = apiConfig {
            var mergedConfig = baseConfig
            // Prioritize stored aspectRatio if it's set
            if let storedAspectRatio = storedConfig.aspectRatio, !storedAspectRatio.isEmpty {
                mergedConfig.aspectRatio = storedAspectRatio
            }
            if let storedResolution = storedConfig.resolution, !storedResolution.isEmpty {
                mergedConfig.resolution = storedResolution
            }
            // Merge other stored values if they're set
            if storedConfig.provider != baseConfig.provider {
                mergedConfig.provider = storedConfig.provider
            }
            if !storedConfig.endpoint.isEmpty && storedConfig.endpoint != baseConfig.endpoint {
                mergedConfig.endpoint = storedConfig.endpoint
            }
            if let storedRunwareModel = storedConfig.runwareModel {
                mergedConfig.runwareModel = storedRunwareModel
            }
            // Merge nested configs if stored config has them
            if let storedWavespeedConfig = storedConfig.wavespeedConfig {
                mergedConfig.wavespeedConfig = storedWavespeedConfig
            }
            if let storedRunwareConfig = storedConfig.runwareConfig {
                mergedConfig.runwareConfig = storedRunwareConfig
            }
            if let storedFalConfig = storedConfig.falConfig {
                mergedConfig.falConfig = storedFalConfig
            }
            return mergedConfig
        }
        
        return baseConfig
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
    
    /// Resolved example images from centralized CategoryConfigurationManager.
    /// Falls back to the stored display.exampleImages property if CategoryConfigurationManager doesn't have example images for this category.
    var resolvedExampleImages: [String]? {
        guard let category = category else {
            return display.exampleImages
        }
        return CategoryConfigurationManager.shared.exampleImages(for: category) ?? display.exampleImages
    }
    
    /// Resolved more styles from centralized CategoryConfigurationManager.
    /// Falls back to the stored display.moreStyles property if CategoryConfigurationManager doesn't have more styles for this category.
    var resolvedMoreStyles: [[String]]? {
        guard let category = category else {
            return display.moreStyles
        }
        return CategoryConfigurationManager.shared.moreStyles(for: category) ?? display.moreStyles
    }
}

struct DisplayInfo: Codable, Hashable {
    var title: String
    var imageName: String
    var imageNameOriginal: String?
    /// Full video URL for the detail-page banner (Supabase Storage). Used only on video filter detail pages; Home/VideoRow keep using imageName (bundle).
    var detailVideoURL: String?
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
    /// Resolution tier for image models that support 1K/2K/4K (e.g. "1k", "2k", "4k"). Used by Nano Banana Pro.
    var resolution: String? = nil

    var wavespeedConfig: WaveSpeedConfig?
    var runwareConfig: RunwareConfig?
    var falConfig: FalConfig?
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
    // OpenAI image model quality: "low", "medium", "high", or "auto" (GPT Image 1.5 only)
    var openaiQuality: String?
}

struct FalConfig: Codable, Hashable {
    // Fal.ai model identifier (e.g., "fal-ai/z-image/turbo")
    var modelId: String?
    // Number of inference steps (default: 8 for z-image/turbo)
    var numInferenceSteps: Int?
    // Seed for reproducible generation
    var seed: Int?
    // Number of images to generate (default: 1)
    var numImages: Int?
    // Enable safety checker (default: true)
    var enableSafetyChecker: Bool?
    // Enable prompt expansion (default: false, increases cost)
    var enablePromptExpansion: Bool?
    // Output format: "jpeg", "png", "webp" (default: "png")
    var outputFormat: String?
    // Acceleration level: "none", "regular", "high" (default: "none")
    var acceleration: String?
    // Whether this model requires width/height
    var requiresDimensions: Bool?
    // Default compression quality for image conversion
    var imageCompressionQuality: Double?
}

enum APIProvider: String, Codable, Hashable {
    case wavespeed
    case runware
    case fal
}
