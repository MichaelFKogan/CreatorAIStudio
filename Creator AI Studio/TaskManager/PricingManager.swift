import Foundation

/// Centralized pricing manager for image and video generation models.
/// Maps model names to their current prices, eliminating the need to update
/// prices in hundreds of JSON files when pricing changes.
class PricingManager {
    /// Singleton instance
    static let shared = PricingManager()
    
    /// Dictionary mapping model names to prices
    private let prices: [String: Decimal]
    
    private init() {
        // Initialize with current model prices
        prices = [
            "Google Gemini Flash 2.5 (Nano Banana)": 0.039,
            "Seedream 4.5": 0.04,
            "Seedream 4.0": 0.03,
            "FLUX.2 [dev]": 0.0122,
            "FLUX.1 Kontext [pro]": 0.04,
            "FLUX.1 Kontext [max]": 0.08,
            "Z-Image-Turbo": 0.003,
            "Wavespeed Ghibli": 0.005,
            // Video Models
            "Sora 2": 0.8,
            "Google Veo 3": 1.2,
            "Kling AI": 0.8,
            "Wan 2.5": 1.0,
        ]
    }
    
    /// Returns the price for a given InfoPacket based on its model name.
    ///
    /// - Parameter item: The InfoPacket to look up pricing for
    /// - Returns: The price as a Decimal, or nil if not found
    func price(for item: InfoPacket) -> Decimal? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }
        
        // Look up price by model name (source of truth)
        return prices[modelName]
    }
}
