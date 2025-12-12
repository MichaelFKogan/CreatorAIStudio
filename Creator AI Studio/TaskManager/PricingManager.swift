import Foundation

/// Centralized pricing manager for image generation models.
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
        ]
    }
    
    /// Returns the price for a given InfoPacket based on its model name.
    /// 
    /// Special handling:
    /// - If modelName is empty and endpoint contains "ghibli", returns 0.005
    /// - Returns nil if model name is empty or not found
    ///
    /// - Parameter item: The InfoPacket to look up pricing for
    /// - Returns: The price as a Decimal, or nil if not found
    func price(for item: InfoPacket) -> Decimal? {
        let modelName = item.display.modelName ?? ""
        
        // Special case: empty modelName with wavespeed/ghibli endpoint
        if modelName.isEmpty {
            let endpoint = item.apiConfig.endpoint.lowercased()
            if endpoint.contains("ghibli") && item.apiConfig.provider == .wavespeed {
                return 0.005
            }
            return nil
        }
        
        // Look up price by model name
        return prices[modelName]
    }
}
