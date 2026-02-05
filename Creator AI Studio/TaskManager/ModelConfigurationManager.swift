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
            // "Z-Image-Turbo": APIConfiguration(
            //     provider: .fal,
            //     endpoint: "https://queue.fal.run/fal-ai/z-image/turbo",
            //     runwareModel: nil,
            //     aspectRatio: nil,
            //     wavespeedConfig: nil,
            //     runwareConfig: nil,
            //     falConfig: FalConfig(
            //         modelId: "fal-ai/z-image/turbo",
            //         numInferenceSteps: 8,
            //         seed: nil,
            //         numImages: 1,
            //         enableSafetyChecker: true,
            //         enablePromptExpansion: false,
            //         outputFormat: "png",
            //         acceleration: "none",
            //         requiresDimensions: true,
            //         imageCompressionQuality: 0.85
            //     )
            // ),
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
            )
        ]
        
// MARK: CAPABILITIES PILLS
        
        // Initialize capabilities mapping
        capabilitiesMap = [
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
            "KlingAI 2.5 Turbo Pro": ["Text to Video", "Image to Video"]
        ]
        
// MARK: DESCRIPTIONS
        
        // Initialize model descriptions mapping
        modelDescriptions = [

            "GPT Image 1.5": "OpenAI's GPT Image 1.5 is the flagship image model powering ChatGPT Images, delivering significantly faster generation with enhanced instruction following and precise edits that preserve original details. Excels at believable transformations, dense text rendering, and detailed design tasks—ideal for practical creative workflows and production use cases.",
            
            "Wan2.5-Preview Image": "Alibaba's Wan2.5-Preview Image delivers high-fidelity single frame generation built from the Wan2.5 video architecture. This model focuses on detailed depth structure, strong prompt following, multilingual text rendering, and video-grade visual quality for production-ready stills.",

            "Nano Banana": "Google's lightweight and extremely fast image model optimized for speed-driven creativity. Perfect for quick edits, simple transformations, and fast turnarounds while still producing sharp, balanced results. Ideal for social content and rapid experimentation.",

            "Seedream 4.5": "Seedream is a Bytedance-built aesthetic image model known for dreamy lighting, smooth gradients, and magazine-like visual polish. Version 4.5 produces vibrant lifestyle imagery, cinematic outdoor scenes, stylized portraits, and soft artistic effects.",
            "Seedream 4.0": "An earlier but still beautiful version of Bytedance's Seedream model, focusing on gentle realism, pastel tones, and atmospheric lighting. Great for travel-style photos, creative illustration, and soft artistic transformations.",

            "FLUX.2 [dev]": "A fully open and developer-focused model from Black Forest Labs, designed for anyone who wants deeper control over sampling, composition, and custom pipelines. Ideal for creators who want flexibility, experimentation, and advanced workflows with consistent high quality.",

            "FLUX.1 Kontext [pro]": "A professional-grade model from Black Forest Labs built for sharp detail, consistent anatomy, accurate lighting, and clean visual structure. Excellent for portraits, branding images, product photography, and polished commercial-quality artwork.",
            "FLUX.1 Kontext [max]": "The highest-performing model in the Kontext family—built for complex scenes, rich textures, dramatic lighting, and maximum realism. Ideal for cinematic artwork, large compositions, and high-impact creative visuals.",

            "Z-Image-Turbo": "Z-Image-Turbo is an ultra-fast image generation model developed by Tongyi-MAI, Alibaba's advanced AI research division. Built using modern distillation techniques, it's designed to deliver high-quality results at exceptional speed and low cost. Ideal for quick creative iterations, high-volume workflows, and fast drafts without sacrificing clarity.",
            // Video Models
            "Sora 2": "Sora 2 is designed for cinematic-quality video generation with extremely stable motion, improved physics accuracy, expressive character animation, and rich scene detail. Perfect for storytelling, ads, and high-impact creative content.",
            "Google Veo 3": "Veo 3 focuses on clarity, smooth motion, and natural lighting. It excels at dynamic environments, realistic textures, and clean camera transitions—ideal for lifestyle clips, outdoor scenes, product demos, and fast-paced creative content.",
            "Google Veo 3.1 Fast": "Google Veo 3.1 Fast is optimized for rapid video generation with minimal latency, ideal for quick creative iterations. It supports native audio generation including dialogue, ambient sounds, and sound effects. Perfect for short-form content, rapid prototyping, and responsive creative workflows.",
            "Kling AI": "Kling AI specializes in hyper-realistic motion and high-speed action scenes. With sharp detail and stable, precise frame-to-frame movement, it's a strong choice for sports, sci-fi shots, fast motion, and large sweeping environments.",
            "Seedance 1.0 Pro Fast": "Seedance 1.0 Pro Fast delivers accelerated video generation while maintaining the high visual quality and cinematic capabilities of Seedance 1.0 Pro. Optimized for faster iteration and production workflows, it supports dynamic camera movements, multiple aspect ratios, and resolutions up to 1080p. Perfect for rapid prototyping, quick content creation, and efficient video production.",
            "Kling VIDEO 2.6 Pro": "Kling VIDEO 2.6 Pro is a next-generation video-and-audio AI model that delivers cinematic-quality visuals and native synchronized audio including dialogue, sound effects, and ambience. This model combines strong prompt fidelity with scene consistency and flexible artistic control for professional video production workflows.",
            "Wan2.6": "Alibaba's Wan2.6 model delivers multimodal video generation with native audio support and multi-shot sequencing capabilities. This model emphasizes temporal stability, consistent visual structure across shots, and reliable alignment between visuals and audio for short-form narrative video production.",
            "KlingAI 2.5 Turbo Pro": "KlingAI's 2.5 Turbo Pro model delivers next-level creativity with turbocharged motion and cinematic visuals. Featuring precise prompt adherence for both text-to-video and image-to-video workflows, this model combines enhanced motion fluidity with professional-grade cinematic capabilities at 30 FPS."
        ]
        
// MARK: IMAGE NAMES
        
        // Initialize model image names mapping
        modelImageNames = [
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
            "KlingAI 2.5 Turbo Pro": "klingai25turbopro"
        ]
        
// MARK: DURATIONS
        
        // Initialize allowed durations mapping for video models
        allowedDurationsMap = [
            "Sora 2": [
                DurationOption(id: "4", label: "4 seconds", duration: 4.0, description: "Short duration"),
                DurationOption(id: "8", label: "8 seconds", duration: 8.0, description: "Standard duration"),
                DurationOption(id: "12", label: "12 seconds", duration: 12.0, description: "Maximum duration")
            ],
            "Google Veo 3.1 Fast": [
                DurationOption(id: "8", label: "8 seconds", duration: 8.0, description: "Extended duration")
            ],
            "Seedance 1.0 Pro Fast": [
                DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
                DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration"),
            ],
            "Kling VIDEO 2.6 Pro": [
                DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
                DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration")
            ],
            "Wan2.6": [
                DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
                DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration"),
                DurationOption(id: "15", label: "15 seconds", duration: 15.0, description: "Maximum duration")
            ],
            "KlingAI 2.5 Turbo Pro": [
                DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
                DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration")
            ]
        ]
        
// MARK: ALLOWED SIZES
        
        // Initialize allowed aspect ratios mapping for video models
        allowedAspectRatiosMap = [
            // Add to allowedAspectRatiosMap initialization:
            "GPT Image 1.5": [
                AspectRatioOption(id: "2:3", label: "2:3", width: 2, height: 3, platforms: ["Portrait"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Square"]),
                AspectRatioOption(id: "3:2", label: "3:2", width: 3, height: 2, platforms: ["Landscape"])
            ],
            "Wan2.5-Preview Image": [
                AspectRatioOption(id: "3:4", label: "3:4", width: 3, height: 4, platforms: ["Portrait"]),
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Square"]),
                AspectRatioOption(id: "4:3", label: "4:3", width: 4, height: 3, platforms: ["Landscape"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
            ],
            "Nano Banana Pro": [
                AspectRatioOption(id: "3:4", label: "3:4", width: 3, height: 4, platforms: ["Portrait"]),
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Square"]),
                AspectRatioOption(id: "4:3", label: "4:3", width: 4, height: 3, platforms: ["Landscape"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
            ],
            "Sora 2": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
                ],
            "Google Veo 3.1 Fast": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
            ],
            "Seedance 1.0 Pro Fast": [
                AspectRatioOption(id: "3:4", label: "3:4", width: 3, height: 4, platforms: ["Portrait"]),
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
                AspectRatioOption(id: "4:3", label: "4:3", width: 4, height: 3, platforms: ["Landscape"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
            ],
            "Kling VIDEO 2.6 Pro": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
            ],
            "Wan2.6": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
            ],
            "KlingAI 2.5 Turbo Pro": [
                AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
                AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
                AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
            ]
        ]
        
// MARK: ALLOWED RESOLUTIONS
        
        // Initialize allowed resolutions mapping for video models
        allowedResolutionsMap = [
            "Sora 2": [
                ResolutionOption(id: "720p", label: "720p", description: "High quality"),
            ],
            "Google Veo 3.1 Fast": [
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD")
            ],
            "Seedance 1.0 Pro Fast": [
                ResolutionOption(id: "480p", label: "480p", description: "Standard quality"),
                ResolutionOption(id: "720p", label: "720p", description: "High quality"),
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD")
            ],
            "Kling VIDEO 2.6 Pro": [
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD")
            ],
            "Wan2.6": [
                ResolutionOption(id: "720p", label: "720p", description: "High quality"),
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD")
            ],
            "KlingAI 2.5 Turbo Pro": [
                ResolutionOption(id: "1080p", label: "1080p", description: "Full HD")
            ],
            // Nano Banana Pro (image model) - resolution tier 1K/2K/4K (pricing shown in credits in sheet)
            "Nano Banana Pro": [
                ResolutionOption(id: "1k", label: "1K", description: nil),
                ResolutionOption(id: "2k", label: "2K", description: nil),
                ResolutionOption(id: "4k", label: "4K", description: nil)
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
