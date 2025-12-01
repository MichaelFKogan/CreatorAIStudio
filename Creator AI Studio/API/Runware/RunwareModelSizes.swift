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

// FLUX.1 Kontext [Pro]
private let fluxKontextSizes: [String: (Int, Int)] = [
    "1:1": (1024, 1024),
    "4:3": (1184, 880),
    "3:4": (880, 1184),
    "9:16": (752, 1392),
    "16:9": (1392, 752),
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
    if modelLower.contains("google:4@1") ||
        modelLower.contains("google:4@2")
    {
        return googleNanoBananaSizes
    }

    // Check for FLUX.1 Kontext [Pro]
    if modelLower.contains("runware:106@1") ||
        modelLower.contains("bfl:3@1") ||
        modelLower.contains("bfl:4@1")
    {
        return fluxKontextSizes
    }

    if modelLower.contains("bytedance:5@0") {
        return seedream40Sizes
    }

    // Default fallback to Google Nano Banana sizes
    print("[Runware] Model '\(model)' not found in size mapping, using default (Google Nano Banana) sizes")
    return googleNanoBananaSizes
}
