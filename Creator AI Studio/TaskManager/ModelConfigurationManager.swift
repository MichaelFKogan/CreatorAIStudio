import Foundation
import SwiftUI

/// Centralized configuration manager for image and video generation models.
/// Maps model names to their API configurations and capabilities, eliminating the need
/// to update hundreds of JSON files when API endpoints, models, or capabilities change.
class ModelConfigurationManager {
    // MARK: - PROPERTIES
    
    /// Singleton instance
    static let shared = ModelConfigurationManager()
    
    /// Dictionary mapping model names to complete API configurations
    private let apiConfigurations: [String: APIConfiguration]
    
    /// Dictionary mapping model names to capabilities arrays
    private let capabilitiesMap: [String: [String]]
    
    /// Dictionary mapping model names to model descriptions
    private let modelDescriptions: [String: String]
    
    /// Dictionary mapping model names to model image names
    private let modelImageNames: [String: String]
    
    /// Dictionary mapping model names to allowed durations for video models
    private let allowedDurationsMap: [String: [DurationOption]]
    
    /// Dictionary mapping model names to allowed aspect ratios for video models
    private let allowedAspectRatiosMap: [String: [AspectRatioOption]]
    
    /// Dictionary mapping model names to allowed resolutions for video models
    private let allowedResolutionsMap: [String: [ResolutionOption]]
    
    
    private init() {
// MARK: IMAGE MODELS API
        
        // Initialize API configurations for all models
        apiConfigurations = [
            "Google Gemini Flash 2.5 (Nano Banana)": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "google:4@1",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: "referenceImages",
                    strength: nil,
                    additionalTaskParams: nil,
                    requiresDimensions: true,
                    imageCompressionQuality: 0.9,
                    outputFormat: nil,
                    outputType: nil,
                    outputQuality: nil
                )
            ),
            "Seedream 4.5": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "bytedance:seedream@4.5",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: "referenceImages",
                    strength: nil,
                    additionalTaskParams: nil,
                    requiresDimensions: true,
                    imageCompressionQuality: 0.9,
                    outputFormat: nil,
                    outputType: nil,
                    outputQuality: nil
                )
            ),
            "Seedream 4.0": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "bytedance:5@0",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: "referenceImages",
                    strength: nil,
                    additionalTaskParams: nil,
                    requiresDimensions: true,
                    imageCompressionQuality: 0.9,
                    outputFormat: nil,
                    outputType: nil,
                    outputQuality: nil
                )
            ),
            "FLUX.2 [dev]": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "runware:400@1",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: "referenceImages",
                    strength: nil,
                    additionalTaskParams: nil,
                    requiresDimensions: true,
                    imageCompressionQuality: 0.85,
                    outputFormat: nil,
                    outputType: nil,
                    outputQuality: nil
                )
            ),
            "FLUX.1 Kontext [pro]": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "bfl:3@1",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: "referenceImages",
                    strength: nil,
                    additionalTaskParams: nil,
                    requiresDimensions: true,
                    imageCompressionQuality: 0.85,
                    outputFormat: "JPG",
                    outputType: "URL",
                    outputQuality: 85
                )
            ),
            "FLUX.1 Kontext [max]": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "bfl:4@1",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: "referenceImages",
                    strength: 0.7,
                    additionalTaskParams: nil,
                    requiresDimensions: true,
                    imageCompressionQuality: 0.85,
                    outputFormat: nil,
                    outputType: nil,
                    outputQuality: nil
                )
            ),
            "Z-Image-Turbo": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "runware:z-image@turbo",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: "referenceImages",
                    strength: 0.7,
                    additionalTaskParams: nil,
                    requiresDimensions: true,
                    imageCompressionQuality: 0.85,
                    outputFormat: nil,
                    outputType: nil,
                    outputQuality: nil
                )
            ),
            "Wavespeed Ghibli": APIConfiguration(
                provider: .wavespeed,
                endpoint: "https://api.wavespeed.ai/api/v3/wavespeed-ai/ghibli",
                runwareModel: nil,
                aspectRatio: "",
                wavespeedConfig: WaveSpeedConfig(
                    outputFormat: "jpeg",
                    enableSyncMode: true,
                    enableBase64Output: false
                ),
                runwareConfig: nil
            ),

// MARK: VIDEO MODELS API
            "Sora 2": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "openai:3@1",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: "frameImages",
                    strength: nil,
                    additionalTaskParams: [
                        "taskType": "videoInference",
                        "deliveryMethod": "async"
                    ],
                    requiresDimensions: true,
                    imageCompressionQuality: 0.9,
                    outputFormat: "MP4",
                    outputType: "URL",
                    outputQuality: nil
                )
            ),
            "Seedance 1.0 Pro Fast": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "bytedance:2@2",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: "frameImages",
                    strength: nil,
                    additionalTaskParams: [
                        "taskType": "videoInference",
                        "deliveryMethod": "async"
                    ],
                    requiresDimensions: true,
                    imageCompressionQuality: 0.9,
                    outputFormat: "MP4",
                    outputType: "URL",
                    outputQuality: 85
                )
            )
        ]
        
// MARK: CAPABILITIES PILLS
        
        // Initialize capabilities mapping
        capabilitiesMap = [
            "Google Gemini Flash 2.5 (Nano Banana)": ["Text to Image", "Image to Image"],
            "Seedream 4.5": ["Text to Image", "Image to Image"],
            "Seedream 4.0": ["Text to Image", "Image to Image"],
            "FLUX.2 [dev]": ["Text to Image", "Image to Image"],
            "FLUX.1 Kontext [pro]": ["Text to Image", "Image to Image"],
            "FLUX.1 Kontext [max]": ["Text to Image", "Image to Image"],
            "Z-Image-Turbo": ["Text to Image"],
            "Wavespeed Ghibli": ["Image to Image"],
            // Video Models
            "Sora 2": ["Text to Video", "Image to Video", "Audio"],
            "Google Veo 3": ["Text to Video", "Image to Video", "Audio"],
            "Kling AI": ["Text to Video", "Image to Video"],
            "Wan 2.5": ["Text to Video", "Image to Video", "Audio"],
            "Seedance 1.0 Pro Fast": ["Text to Video", "Image to Video"]
        ]
        
// MARK: MODEL DESCRIPTIONS
        
        // Initialize model descriptions mapping
        modelDescriptions = [

            "Google Gemini Flash 2.5 (Nano Banana)": "Google's lightweight and extremely fast image model optimized for speed-driven creativity. Perfect for quick edits, simple transformations, and fast turnarounds while still producing sharp, balanced results. Ideal for social content and rapid experimentation.",

            "Seedream 4.5": "Seedream is a Bytedance-built aesthetic image model known for dreamy lighting, smooth gradients, and magazine-like visual polish. Version 4.5 produces vibrant lifestyle imagery, cinematic outdoor scenes, stylized portraits, and soft artistic effects.",
            "Seedream 4.0": "An earlier but still beautiful version of Bytedance's Seedream model, focusing on gentle realism, pastel tones, and atmospheric lighting. Great for travel-style photos, creative illustration, and soft artistic transformations.",

            "FLUX.2 [dev]": "A fully open and developer-focused model from Black Forest Labs, designed for anyone who wants deeper control over sampling, composition, and custom pipelines. Ideal for creators who want flexibility, experimentation, and advanced workflows with consistent high quality.",

            "FLUX.1 Kontext [pro]": "A professional-grade model from Black Forest Labs built for sharp detail, consistent anatomy, accurate lighting, and clean visual structure. Excellent for portraits, branding images, product photography, and polished commercial-quality artwork.",
            "FLUX.1 Kontext [max]": "The highest-performing model in the Kontext family—built for complex scenes, rich textures, dramatic lighting, and maximum realism. Ideal for cinematic artwork, large compositions, and high-impact creative visuals.",

            "Z-Image-Turbo": "Z-Image-Turbo is an ultra-fast image generation model developed by Tongyi-MAI, Alibaba's advanced AI research division. Built using modern distillation techniques, it's designed to deliver high-quality results at exceptional speed and low cost. Ideal for quick creative iterations, high-volume workflows, and fast drafts without sacrificing clarity.",
            // Video Models
            "Sora 2": "Sora 2 is designed for cinematic-quality video generation with extremely stable motion, improved physics accuracy, expressive character animation, and rich scene detail. Perfect for storytelling, ads, and high-impact creative content.",
            "Google Veo 3": "Veo 3 focuses on clarity, smooth motion, and natural lighting. It excels at dynamic environments, realistic textures, and clean camera transitions—ideal for lifestyle clips, outdoor scenes, product demos, and fast-paced creative content.",
            "Kling AI": "Kling AI specializes in hyper-realistic motion and high-speed action scenes. With sharp detail and stable, precise frame-to-frame movement, it's a strong choice for sports, sci-fi shots, fast motion, and large sweeping environments.",
            "Wan 2.5": "Wan 2.5 delivers dramatic cinematic visuals, advanced character performance, atmospheric effects, and stylized world-building. It shines in fantasy, anime, surreal scenes, and richly creative storytelling.",
            "Seedance 1.0 Pro Fast": "Seedance 1.0 Pro Fast delivers accelerated video generation while maintaining the high visual quality and cinematic capabilities of Seedance 1.0 Pro. Optimized for faster iteration and production workflows, it supports dynamic camera movements, multiple aspect ratios, and resolutions up to 1080p. Perfect for rapid prototyping, quick content creation, and efficient video production."
        ]
        
// MARK: MODEL IMAGE NAMES
        
        // Initialize model image names mapping
        modelImageNames = [
            "Google Gemini Flash 2.5 (Nano Banana)": "geminiflashimage25",
            "Seedream 4.5": "seedream45",
            "Seedream 4.0": "seedream40",
            "FLUX.2 [dev]": "flux2dev",
            "FLUX.1 Kontext [pro]": "fluxkontextpro",
            "FLUX.1 Kontext [max]": "fluxkontextmax",
            "Z-Image-Turbo": "zimageturbo",
            
            // Video Models
            "Sora 2": "sora2",
            "Google Veo 3": "veo3",
            "Kling AI": "klingai",
            "Wan 2.5": "wan25",
            "Seedance 1.0 Pro Fast": "seedance10profast"
        ]
        
// MARK: ALLOWED DURATIONS
        
        // Initialize allowed durations mapping for video models
        allowedDurationsMap = [
            "Sora 2": [
                DurationOption(id: "4", label: "4 seconds", duration: 4.0, description: "Standard duration"),
                DurationOption(id: "8", label: "8 seconds", duration: 8.0, description: "Extended duration"),
                DurationOption(id: "12", label: "12 seconds", duration: 12.0, description: "Maximum duration")
            ],
            "Seedance 1.0 Pro Fast": [
                DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
                DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration")
            ]
        ]
        
// MARK: ALLOWED SIZES
        
        // Initialize allowed aspect ratios mapping for video models
        allowedAspectRatiosMap = [
            "Sora 2": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
            "Seedance 1.0 Pro Fast": [
                AspectRatioOption(id: "3:4", label: "3:4", width: 3, height: 4, platforms: ["Portrait"]),
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
                AspectRatioOption(id: "4:3", label: "4:3", width: 4, height: 3, platforms: ["Landscape"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
            ]
        ]
        
// MARK: ALLOWED RESOLUTIONS
        
        // Initialize allowed resolutions mapping for video models
        allowedResolutionsMap = [
            "Sora 2": [
                ResolutionOption(id: "720p", label: "720p", description: "High quality"),
            ],
            "Seedance 1.0 Pro Fast": [
                ResolutionOption(id: "480p", label: "480p", description: "Standard quality"),
                ResolutionOption(id: "720p", label: "720p", description: "High quality"),
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD")
            ]
        ]
    }
    
    // MARK: - METHODS
    
    /// Returns the API configuration for a given InfoPacket based on its model name.
    ///
    /// - Parameter item: The InfoPacket to look up configuration for
    /// - Returns: The API configuration, or nil if not found (allowing fallback to JSON-stored config)
    func apiConfiguration(for item: InfoPacket) -> APIConfiguration? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }
        
        // Look up configuration by model name (source of truth)
        return apiConfigurations[modelName]
    }
    
    /// Returns the capabilities array for a given InfoPacket based on its model name.
    ///
    /// - Parameter item: The InfoPacket to look up capabilities for
    /// - Returns: The capabilities array, or nil if not found (allowing fallback to JSON-stored capabilities)
    func capabilities(for item: InfoPacket) -> [String]? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }
        
        // Look up capabilities by model name (source of truth)
        return capabilitiesMap[modelName]
    }
    
    /// Returns the model description for a given InfoPacket based on its model name.
    ///
    /// - Parameter item: The InfoPacket to look up description for
    /// - Returns: The model description, or nil if not found
    func modelDescription(for item: InfoPacket) -> String? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }
        return modelDescriptions[modelName]
    }
    
    /// Returns the model image name for a given InfoPacket based on its model name.
    ///
    /// - Parameter item: The InfoPacket to look up image name for
    /// - Returns: The model image name, or nil if not found
    func modelImageName(for item: InfoPacket) -> String? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }
        return modelImageNames[modelName]
    }
    
    /// Returns the allowed durations for a given video model InfoPacket.
    ///
    /// - Parameter item: The InfoPacket to look up durations for
    /// - Returns: The allowed durations array, or nil if not found (allowing fallback to default durations)
    func allowedDurations(for item: InfoPacket) -> [DurationOption]? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }
        return allowedDurationsMap[modelName]
    }
    
    /// Returns the allowed aspect ratios for a given video model InfoPacket.
    ///
    /// - Parameter item: The InfoPacket to look up aspect ratios for
    /// - Returns: The allowed aspect ratios array, or nil if not found (allowing fallback to default aspect ratios)
    func allowedAspectRatios(for item: InfoPacket) -> [AspectRatioOption]? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }
        return allowedAspectRatiosMap[modelName]
    }
    
    /// Returns the allowed resolutions for a given video model InfoPacket.
    ///
    /// - Parameter item: The InfoPacket to look up resolutions for
    /// - Returns: The allowed resolutions array, or nil if not found (allowing fallback to default resolutions)
    func allowedResolutions(for item: InfoPacket) -> [ResolutionOption]? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }
        return allowedResolutionsMap[modelName]
    }
}
