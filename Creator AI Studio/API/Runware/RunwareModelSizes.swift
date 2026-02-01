import SwiftUI

// MARK: - Allowed Runware Sizes (must be exact)

// Nano Banana
private let googleNanoBananaSizes: [String: (Int, Int)] = [
    "1:1": (1024, 1024),
    "4:3": (1184, 864),
    "3:4": (864, 1184),
    "9:16": (768, 1344),
    "16:9": (1344, 768),
    "auto": (0, 0),
]

// Google Gemini 3 Pro (Nano Banana 2)
private let googleNanoBanana2Sizes: [String: (Int, Int)] = [
    "1:1": (2048, 2048),
    "4:3": (2400, 1792),
    "3:4": (1792, 2400),
    "9:16": (1536, 2752),
    "16:9": (2752, 1536),
    "auto": (0, 0),
]

// Midjourney V7
private let midjourneyV7Sizes: [String: (Int, Int)] = [
    "1:1": (1024, 1024),
    "4:3": (1232, 928),
    "3:4": (928, 1232),
    "9:16": (816, 1456),
    "16:9": (1456, 816),
    "auto": (0, 0),
]

// Seedream 4.0
private let seedream40Sizes: [String: (Int, Int)] = [
    "1:1": (1024, 1024),
    "4:3": (1184, 880),
    "3:4": (880, 1184),
    "9:16": (752, 1392),
    "16:9": (1392, 752),
    "auto": (0, 0),
]

// Seedream 4.5
private let seedream45Sizes: [String: (Int, Int)] = [
    "1:1": (2048, 2048),
    "4:3": (2304, 1728),
    "3:4": (1728, 2304),
    "16:9": (2560, 1440),
    "9:16": (1440, 2560),
    "auto": (0, 0),
]

// FLUX.2 [dev]
private let flux2DevSizes: [String: (Int, Int)] = [
    "1:1": (1024, 1024),
    "4:3": (1184, 880),
    "3:4": (880, 1184),
    "9:16": (752, 1392),
    "16:9": (1392, 752),
    "auto": (0, 0),
]

// FLUX.1 Kontext [Pro]
private let fluxKontextSizes: [String: (Int, Int)] = [
    "1:1": (1024, 1024),
    "4:3": (1184, 880),
    "3:4": (880, 1184),
    "9:16": (752, 1392),
    "16:9": (1392, 752),
    "auto": (0, 0),
]

// Z-Image-Turbo
private let zimageturboSizes: [String: (Int, Int)] = [
    "1:1": (1024, 1024),
    "4:3": (1152, 896),
    "3:4": (896, 1152),
    "9:16": (768, 1344),
    "16:9": (1344, 768),
    "auto": (0, 0),
]

// Riverflow 2 (Fast, Standard, Max) - All versions support the same dimensions
// Using smallest tier dimensions (confirmed working via Runware API)
private let riverflow2Sizes: [String: (Int, Int)] = [
    "1:1": (1024, 1024),
    "4:3": (1152, 864),
    "3:4": (864, 1152),
    "16:9": (1280, 720),
    "9:16": (720, 1280),
    "auto": (0, 0),
]

// Seedance 1.0 Pro Fast - Video model dimensions
// Supports multiple resolutions: 480p, 720p, 1080p
// Using 1080p dimensions as default (highest quality)
private let seedanceProFastSizes: [String: (Int, Int)] = [
    "1:1": (1440, 1440),      // 1080p
    "4:3": (1664, 1248),      // 1080p
    "3:4": (1248, 1664),      // 1080p
    "16:9": (1920, 1088),     // 1080p
    "9:16": (1088, 1920),     // 1080p
    "21:9": (2176, 928),      // 1080p
    "9:21": (928, 2176),      // 1080p
    "auto": (0, 0),
]

// GPT Image 1.5 - OpenAI's flagship image model
// Supported dimensions: 1024×1024, 1536×1024, 1024×1536
private let gptImage15Sizes: [String: (Int, Int)] = [
    "2:3": (1024, 1536),
    "1:1": (1024, 1024),
    "3:2": (1536, 1024),
    "auto": (0, 0),
]

// Wan2.5-Preview Image - Alibaba's image model
// Min: 768×768 (589,824 pixels), Max: 1440×1440 (2,073,600 pixels)
// Default: 1280×1280, aspect ratio between 1:4 and 4:1
// Both dimensions must be within 768-1440 range
private let wan25PreviewImageSizes: [String: (Int, Int)] = [
    "3:4": (960, 1280),      // 960×1280 = 1,228,800 pixels (exact 3:4 ratio)
    "9:16": (768, 1365),     // 768×1365 = 1,048,320 pixels (1365 < 1440 ✓)
    "1:1": (1280, 1280),     // 1280×1280 = 1,638,400 pixels
    "4:3": (1280, 960),      // 1280×960 = 1,228,800 pixels (exact 4:3 ratio)
    "16:9": (1365, 768),     // 1365×768 = 1,048,320 pixels (1365 < 1440 ✓)
    "auto": (0, 0),
]

// KlingAI 2.5 Turbo Pro (klingai:6@1) - Video model dimensions
// Supported: 1920x1080, 1080x1920, 1080x1080 (1080p) or 1280x720, 720x1280, 720x720 (720p)
// Only supports 16:9, 9:16, 1:1 aspect ratios
private let klingai25TurboProSizes: [String: (Int, Int)] = [
    "16:9": (1920, 1080),    // 1080p landscape
    "9:16": (1080, 1920),    // 1080p portrait
    "1:1": (1080, 1080),     // 1080p square
    "auto": (0, 0),
]

// MARK: - Model to Size Set Mapping

/// Returns the appropriate allowed sizes dictionary for a given model identifier.
/// The model parameter can be either:
/// - The Runware model identifier (e.g., "google:4@1", "bfl:3@1")
/// - The display model name (e.g., "Nano Banana", "FLUX.1 Kontext [pro]")
///
/// Falls back to Google Nano Banana sizes if model is not recognized.
func getAllowedSizes(for model: String) -> [String: (Int, Int)] {
    let modelLower = model.lowercased()

    // Check by Runware model identifier

    // Nano Banana
    if modelLower.contains("google:4@1") { return googleNanoBananaSizes }
    // Google Gemini 3 Pro (Nano Banana 2)
    if modelLower.contains("google:4@2") { return googleNanoBanana2Sizes }

    // Midjourney V7
    if modelLower.contains("midjourney:3@1") { return midjourneyV7Sizes }

    // Seedream 4.0
    if modelLower.contains("bytedance:5@0") { return seedream40Sizes }
    // Seedream 4.5
    if modelLower.contains("bytedance:seedream@4.5") { return seedream45Sizes }

    // FLUX.2 [dev]
    if modelLower.contains("runware:400@1") { return flux2DevSizes }
    // Check for FLUX.1 Kontext [Pro]
    if modelLower.contains("runware:106@1") || modelLower.contains("bfl:3@1") || modelLower.contains("bfl:4@1")
    { return fluxKontextSizes }

    // Z-Image-Turbo
    if modelLower.contains("runware:z-image@turbo") { return zimageturboSizes }

    // Riverflow 2 Fast
    if modelLower.contains("sourceful:2@2") { return riverflow2Sizes }
    // Riverflow 2 Standard
    if modelLower.contains("sourceful:2@1") { return riverflow2Sizes }
    // Riverflow 2 Max
    if modelLower.contains("sourceful:2@3") { return riverflow2Sizes }

    // Seedance 1.0 Pro Fast
    if modelLower.contains("bytedance:2@2") { return seedanceProFastSizes }

    // GPT Image 1.5 (OpenAI)
    if modelLower.contains("openai:4@1") { return gptImage15Sizes }

    // Wan2.5-Preview Image (Alibaba) - Runware model ID: runware:201@10
    if modelLower.contains("runware:201@10") { return wan25PreviewImageSizes }
    
    // KlingAI 2.5 Turbo Pro - Runware model ID: klingai:6@1
    if modelLower.contains("klingai:6@1") { return klingai25TurboProSizes }

    // Default fallback to Google Nano Banana sizes
    print("[Runware] Model '\(model)' not found in size mapping, using default (Google Nano Banana) sizes")
    return googleNanoBananaSizes
}
