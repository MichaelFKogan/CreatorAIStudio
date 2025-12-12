import Foundation

/// Centralized configuration manager for image generation models.
/// Maps model names to their API configurations and capabilities, eliminating the need
/// to update hundreds of JSON files when API endpoints, models, or capabilities change.
class ModelConfigurationManager {
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
    
    private init() {
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
            )
        ]
        
        // Initialize capabilities mapping
        capabilitiesMap = [
            "Google Gemini Flash 2.5 (Nano Banana)": ["Text to Image", "Image to Image"],
            "Seedream 4.5": ["Text to Image", "Image to Image"],
            "Seedream 4.0": ["Text to Image", "Image to Image"],
            "FLUX.2 [dev]": ["Text to Image", "Image to Image"],
            "FLUX.1 Kontext [pro]": ["Text to Image", "Image to Image"],
            "FLUX.1 Kontext [max]": ["Text to Image", "Image to Image"],
            "Z-Image-Turbo": ["Text to Image"],
            "Wavespeed Ghibli": ["Image to Image"]
        ]
        
        // Initialize model descriptions mapping
        modelDescriptions = [

            "Google Gemini Flash 2.5 (Nano Banana)": "Google's lightweight and extremely fast image model optimized for speed-driven creativity. Perfect for quick edits, simple transformations, and fast turnarounds while still producing sharp, balanced results. Ideal for social content and rapid experimentation.",

            "Seedream 4.5": "Seedream is a Bytedance-built aesthetic image model known for dreamy lighting, smooth gradients, and magazine-like visual polish. Version 4.5 produces vibrant lifestyle imagery, cinematic outdoor scenes, stylized portraits, and soft artistic effects.",
            "Seedream 4.0": "An earlier but still beautiful version of Bytedance's Seedream model, focusing on gentle realism, pastel tones, and atmospheric lighting. Great for travel-style photos, creative illustration, and soft artistic transformations.",

            "FLUX.2 [dev]": "A fully open and developer-focused model from Black Forest Labs, designed for anyone who wants deeper control over sampling, composition, and custom pipelines. Ideal for creators who want flexibility, experimentation, and advanced workflows with consistent high quality.",

            "FLUX.1 Kontext [pro]": "A professional-grade model from Black Forest Labs built for sharp detail, consistent anatomy, accurate lighting, and clean visual structure. Excellent for portraits, branding images, product photography, and polished commercial-quality artwork.",
            "FLUX.1 Kontext [max]": "The highest-performing model in the Kontext family—built for complex scenes, rich textures, dramatic lighting, and maximum realism. Ideal for cinematic artwork, large compositions, and high-impact creative visuals.",

            "Z-Image-Turbo": "Z-Image-Turbo is an ultra-fast image generation model developed by Tongyi-MAI, Alibaba's advanced AI research division. Built using modern distillation techniques, it's designed to deliver high-quality results at exceptional speed and low cost. Ideal for quick creative iterations, high-volume workflows, and fast drafts without sacrificing clarity."
        ]
        
        // Initialize model image names mapping
        modelImageNames = [
            "Google Gemini Flash 2.5 (Nano Banana)": "geminiflashimage25",
            "Seedream 4.5": "seedream45",
            "Seedream 4.0": "seedream40",
            "FLUX.2 [dev]": "flux2dev",
            "FLUX.1 Kontext [pro]": "fluxkontextpro",
            "FLUX.1 Kontext [max]": "fluxkontextmax",
            "Z-Image-Turbo": "zimageturbo"
        ]
    }
    
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
}
