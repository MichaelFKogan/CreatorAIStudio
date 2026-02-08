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
        // Each dictionary is built in a separate static method so the Swift
        // type checker handles them independently (avoids exponential inference
        // on large nested collection literals).
        apiConfigurations = Self.makeImageModelAPIConfigs()
            .merging(Self.makeVideoModelAPIConfigs()) { _, new in new }
        capabilitiesMap = Self.makeCapabilitiesMap()
        modelDescriptions = Self.makeModelDescriptions()
        modelImageNames = Self.makeModelImageNames()
        allowedDurationsMap = Self.makeAllowedDurationsMap()
        allowedAspectRatiosMap = Self.makeAllowedAspectRatiosMap()
        allowedResolutionsMap = Self.makeAllowedResolutionsMap()
    }

    // MARK: - Factory Methods (split to reduce type-checker load)

    // MARK: IMAGE MODELS API

    private static func makeImageModelAPIConfigs() -> [String: APIConfiguration] {
        return [
            "GPT Image 1.5": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "openai:4@1",
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
                    outputQuality: nil,
                    openaiQuality: "medium"
                )
            ),
            "Wan2.5-Preview Image": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "runware:201@10",
                aspectRatio: nil,
                wavespeedConfig: nil,
                runwareConfig: RunwareConfig(
                    imageToImageMethod: nil,  // Text-to-image only
                    strength: nil,
                    additionalTaskParams: nil,
                    requiresDimensions: true,
                    imageCompressionQuality: 0.9,
                    outputFormat: "JPEG",
                    outputType: nil,  // Will be set as array in API code
                    outputQuality: 85
                )
            ),
            "Nano Banana": APIConfiguration(
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
            "Nano Banana Pro": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "google:4@2",
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
        ]
    }

    // MARK: VIDEO MODELS API

    private static func makeVideoModelAPIConfigs() -> [String: APIConfiguration] {
        return [
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
            ),
            "Google Veo 3.1 Fast": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "google:3@3",
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
            "Kling VIDEO 2.6 Pro": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "klingai:kling-video@2.6-pro",
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
            "Wan2.6": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "alibaba:wan@2.6",
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
            "KlingAI 2.5 Turbo Pro": APIConfiguration(
                provider: .runware,
                endpoint: "https://api.runware.ai/v1",
                runwareModel: "klingai:6@1",
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
        ]
    }

    // MARK: CAPABILITIES PILLS

    private static func makeCapabilitiesMap() -> [String: [String]] {
        return [
            "GPT Image 1.5": ["Text to Image", "Image to Image"],
            "Wan2.5-Preview Image": ["Text to Image"],
            "Nano Banana": ["Text to Image", "Image to Image"],
            "Nano Banana Pro": ["Text to Image", "Image to Image"],
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
            "Google Veo 3.1 Fast": ["Text to Video", "Image to Video", "Audio"],
            "Kling AI": ["Text to Video", "Image to Video"],
            "Seedance 1.0 Pro Fast": ["Text to Video", "Image to Video"],
            "Kling VIDEO 2.6 Pro": ["Text to Video", "Image to Video", "Audio"],
            "Wan2.6": ["Text to Video", "Image to Video", "Audio"],
            "KlingAI 2.5 Turbo Pro": ["Text to Video", "Image to Video"],
        ]
    }

    // MARK: DESCRIPTIONS

    private static func makeModelDescriptions() -> [String: String] {
        return [
            "GPT Image 1.5": "OpenAI's flagship image model with fast generation and strong instruction following. Great for transformations, text rendering, and production workflows.",

            "Wan2.5-Preview Image": "Alibaba's high-fidelity single-frame model from the Wan2.5 video architecture. Strong prompt following and video-grade quality for production stills.",

            "Nano Banana": "Google's lightweight, fast image model for speed-driven creativity. Ideal for quick edits, social content, and rapid experimentation.",
            "Nano Banana Pro": "Google's step-up image model with higher quality and stronger detail than Nano Banana. Great for polished social content, product shots, and when you need better fidelity without sacrificing speed.",

            "Seedream 4.5": "Bytedance's aesthetic model with dreamy lighting and magazine-like polish. Produces vibrant lifestyle imagery, cinematic scenes, and soft artistic effects.",
            "Seedream 4.0": "An earlier Seedream version with gentle realism and pastel tones. Great for travel-style photos and soft artistic transformations.",

            "FLUX.2 [dev]": "Black Forest Labs' open, developer-focused model for deeper control over sampling and pipelines. Ideal for flexibility and advanced workflows.",

            "FLUX.1 Kontext [pro]": "Professional-grade model for sharp detail, consistent anatomy, and clean structure. Excellent for portraits, product photography, and commercial artwork.",
            "FLUX.1 Kontext [max]": "Top of the Kontext family for complex scenes and maximum realism. Ideal for cinematic artwork and high-impact visuals.",

            "Z-Image-Turbo": "Alibaba's ultra-fast image model built for speed and low cost. Delivers high-quality results for quick iterations and high-volume workflows.",
            // Video Models
            "Sora 2": "Cinematic video with stable motion, improved physics, and rich detail. Perfect for storytelling, ads, and high-impact content.",
            "Google Veo 3": "Focuses on clarity, smooth motion, and natural lighting. Great for lifestyle clips, outdoor scenes, and product demos.",
            "Google Veo 3.1 Fast": "Optimized for rapid generation with minimal latency and native audio. Perfect for short-form content and rapid prototyping.",
            "Kling AI": "Hyper-realistic motion and high-speed action with sharp detail. Strong for sports, sci-fi, and sweeping environments.",
            "Seedance 1.0 Pro Fast": "Accelerated video with high visual quality and cinematic capabilities. Supports dynamic camera, multiple aspect ratios, and up to 1080p.",
            "Kling VIDEO 2.6 Pro": "Next-gen video-and-audio model with cinematic visuals and synced audio. Strong prompt fidelity and artistic control for pro workflows.",
            "Wan2.6": "Alibaba's multimodal video with native audio and multi-shot sequencing. Emphasizes temporal stability for short-form narrative.",
            "KlingAI 2.5 Turbo Pro": "Turbocharged motion and cinematic visuals with precise prompt adherence. Pro-grade quality at 30 FPS for text and image-to-video.",
        ]
    }

    // MARK: IMAGE NAMES

    private static func makeModelImageNames() -> [String: String] {
        return [
            "GPT Image 1.5": "gptimage15",
            "Wan2.5-Preview Image": "wan25previewimage",
            "Nano Banana": "geminiflashimage25",
            "Nano Banana Pro": "geminiproimage3",
            "Seedream 4.5": "seedream45",
            "Seedream 4.0": "seedream40",
            "FLUX.2 [dev]": "flux2dev",
            "FLUX.1 Kontext [pro]": "fluxkontextpro",
            "FLUX.1 Kontext [max]": "fluxkontextmax",
            "Z-Image-Turbo": "zimageturbo",

            // Video Models
            "Sora 2": "sora2",
            "Google Veo 3": "veo3",
            "Google Veo 3.1 Fast": "veo31fast",
            "Kling AI": "klingai",
            "Seedance 1.0 Pro Fast": "seedance10profast",
            "Kling VIDEO 2.6 Pro": "klingvideo26pro",
            "Wan2.6": "wan26",
            "KlingAI 2.5 Turbo Pro": "klingai25turbopro",
        ]
    }

    // MARK: DURATIONS

    private static func makeAllowedDurationsMap() -> [String: [DurationOption]] {
        return [
            "Sora 2": [
                DurationOption(id: "4", label: "4 seconds", duration: 4.0, description: "Short duration"),
                DurationOption(id: "8", label: "8 seconds", duration: 8.0, description: "Standard duration"),
                DurationOption(id: "12", label: "12 seconds", duration: 12.0, description: "Maximum duration"),
            ],
            "Google Veo 3.1 Fast": [
                DurationOption(id: "8", label: "8 seconds", duration: 8.0, description: "Extended duration"),
            ],
            "Seedance 1.0 Pro Fast": [
                DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
                DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration"),
            ],
            "Kling VIDEO 2.6 Pro": [
                DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
                DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration"),
            ],
            "Wan2.6": [
                DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
                DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration"),
                DurationOption(id: "15", label: "15 seconds", duration: 15.0, description: "Maximum duration"),
            ],
            "KlingAI 2.5 Turbo Pro": [
                DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
                DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration"),
            ],
        ]
    }

    // MARK: ALLOWED SIZES

    private static func makeAllowedAspectRatiosMap() -> [String: [AspectRatioOption]] {
        return [
            "GPT Image 1.5": [
                AspectRatioOption(id: "2:3", label: "2:3", width: 2, height: 3, platforms: ["Portrait"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Square"]),
                AspectRatioOption(id: "3:2", label: "3:2", width: 3, height: 2, platforms: ["Landscape"]),
            ],
            "Wan2.5-Preview Image": [
                AspectRatioOption(id: "3:4", label: "3:4", width: 3, height: 4, platforms: ["Portrait"]),
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Square"]),
                AspectRatioOption(id: "4:3", label: "4:3", width: 4, height: 3, platforms: ["Landscape"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
            ],
            "Nano Banana Pro": [
                AspectRatioOption(id: "3:4", label: "3:4", width: 3, height: 4, platforms: ["Portrait"]),
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Square"]),
                AspectRatioOption(id: "4:3", label: "4:3", width: 4, height: 3, platforms: ["Landscape"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
            ],
            "Sora 2": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
            ],
            "Google Veo 3.1 Fast": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
            ],
            "Seedance 1.0 Pro Fast": [
                AspectRatioOption(id: "3:4", label: "3:4", width: 3, height: 4, platforms: ["Portrait"]),
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
                AspectRatioOption(id: "4:3", label: "4:3", width: 4, height: 3, platforms: ["Landscape"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
            ],
            "Kling VIDEO 2.6 Pro": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
            ],
            "Wan2.6": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
            ],
            "KlingAI 2.5 Turbo Pro": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
            ],
        ]
    }

    // MARK: ALLOWED RESOLUTIONS

    private static func makeAllowedResolutionsMap() -> [String: [ResolutionOption]] {
        return [
            "Sora 2": [
                ResolutionOption(id: "720p", label: "720p", description: "High quality"),
            ],
            "Google Veo 3.1 Fast": [
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD"),
            ],
            "Seedance 1.0 Pro Fast": [
                ResolutionOption(id: "480p", label: "480p", description: "Standard quality"),
                ResolutionOption(id: "720p", label: "720p", description: "High quality"),
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD"),
            ],
            "Kling VIDEO 2.6 Pro": [
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD"),
            ],
            "Wan2.6": [
                ResolutionOption(id: "720p", label: "720p", description: "High quality"),
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD"),
            ],
            "KlingAI 2.5 Turbo Pro": [
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD"),
            ],
            // Nano Banana Pro (image model) - resolution tier 1K/2K/4K (pricing shown in credits in sheet)
            "Nano Banana Pro": [
                ResolutionOption(id: "1k", label: "1K", description: nil),
                ResolutionOption(id: "2k", label: "2K", description: nil),
                ResolutionOption(id: "4k", label: "4K", description: nil),
            ],
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
