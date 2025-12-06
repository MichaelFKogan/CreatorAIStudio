import SwiftUI

// MARK: - Allowed Runware Sizes (must be exact)

// Google Gemini Flash 2.5 (Nano Banana)
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
    "9:16": (2560, 1440),
    "16:9": (1440, 2560),
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

// MARK: - Model to Size Set Mapping

/// Returns the appropriate allowed sizes dictionary for a given model identifier.
/// The model parameter can be either:
/// - The Runware model identifier (e.g., "google:4@1", "bfl:3@1")
/// - The display model name (e.g., "Google Gemini Flash 2.5 (Nano Banana)", "FLUX.1 Kontext [pro]")
///
/// Falls back to Google Nano Banana sizes if model is not recognized.
func getAllowedSizes(for model: String) -> [String: (Int, Int)] {
    let modelLower = model.lowercased()

    // Check by Runware model identifier

    // Google Gemini Flash 2.5 (Nano Banana)
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

    // Default fallback to Google Nano Banana sizes
    print("[Runware] Model '\(model)' not found in size mapping, using default (Google Nano Banana) sizes")
    return googleNanoBananaSizes
}
