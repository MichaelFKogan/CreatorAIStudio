import Foundation

// MARK: - VIDEO PRICING CONFIGURATION

/// Structure to represent video pricing configuration
/// Maps aspect ratio, resolution, and duration combinations to prices
struct VideoPricingConfiguration {
    /// Pricing key: (aspectRatio, resolution, duration) -> price
    /// aspectRatio: e.g., "16:9", "9:16", "1:1"
    /// resolution: e.g., "480p", "720p", "1080p"
    /// duration: e.g., 5.0, 10.0 (in seconds)
    let pricing: [String: [String: [Double: Decimal]]]

    /// Get price for a specific combination
    func price(aspectRatio: String, resolution: String, duration: Double)
        -> Decimal?
    {
        return pricing[aspectRatio]?[resolution]?[duration]
    }
}

// MARK: - PRICING MANAGER

/// Centralized pricing manager for image and video generation models.
/// Maps model names to their current prices, eliminating the need to update
/// prices in hundreds of JSON files when pricing changes.
class PricingManager {

    /// Singleton instance
    static let shared = PricingManager()

    /// Dictionary mapping model names to prices (for fixed pricing models)
    private let prices: [String: Decimal]

    /// Dictionary mapping model names to variable pricing configurations (for video models with variable pricing)
    private let variableVideoPricing: [String: VideoPricingConfiguration]
    
    /// Dictionary mapping model names to their default duration, aspect ratio, and resolution for display pricing
    /// Used to show the correct "starting from" price based on the model's default configuration
    private let defaultVideoConfigs: [String: (aspectRatio: String, resolution: String, duration: Double)] = [
        "Sora 2": ("9:16", "720p", 8.0),  // Sora 2 defaults to 8 seconds
        "Google Veo 3.1 Fast": ("9:16", "1080p", 8.0),  // Only option available
        "Seedance 1.0 Pro Fast": ("3:4", "480p", 5.0)  // Default to cheapest option
    ]

    private init() {

        // MARK: IMAGE PRICES
        // Initialize with current model prices (fixed pricing)
        prices = [
            "Google Gemini Flash 2.5 (Nano Banana)": 0.039,
            "Seedream 4.5": 0.04,
            "Seedream 4.0": 0.03,
            "FLUX.2 [dev]": 0.0122,
            "FLUX.1 Kontext [pro]": 0.04,
            "FLUX.1 Kontext [max]": 0.08,
            "Z-Image-Turbo": 0.003,
            "Wavespeed Ghibli": 0.005,
        ]

        // MARK: VIDEO PRICES
        // Initialize variable pricing for video models
        variableVideoPricing = [
            // Sora 2 pricing: 4s ($0.4), 8s ($0.8), 12s ($1.2) - only supports 720p
            "Sora 2": VideoPricingConfiguration(
                pricing: [
                    "16:9": [
                        "720p": [4.0: 0.4, 8.0: 0.8, 12.0: 1.2]
                    ],
                    "9:16": [
                        "720p": [4.0: 0.4, 8.0: 0.8, 12.0: 1.2]
                    ],
                ]
            ),
            // Google Veo 3.1 Fast pricing: Only supports 1080p at 8 seconds
            // Without audio: $0.80, With audio: $1.20
            // Base price is $1.20 (with audio) since audio is ON by default
            // Audio addon is negative (-$0.40) when audio is turned OFF
            "Google Veo 3.1 Fast": VideoPricingConfiguration(
                pricing: [
                    "16:9": [
                        "1080p": [8.0: 1.20]
                    ],
                    "9:16": [
                        "1080p": [8.0: 1.20]
                    ]
                ]
            ),
            // Seedance 1.0 Pro Fast pricing from Runware pricing page
            "Seedance 1.0 Pro Fast": VideoPricingConfiguration(
                pricing: [
                    "3:4": [
                        "480p": [5.0: 0.0304, 10.0: 0.0609],
                        "720p": [5.0: 0.0709, 10.0: 0.1417],
                        "1080p": [5.0: 0.1579, 10.0: 0.3159],
                    ],
                    "9:16": [
                        "480p": [5.0: 0.0315, 10.0: 0.0629],
                        "720p": [5.0: 0.0668, 10.0: 0.1336],
                        "1080p": [5.0: 0.1589, 10.0: 0.3177],
                    ],
                    "1:1": [
                        "480p": [5.0: 0.0311, 10.0: 0.0623],
                        "720p": [5.0: 0.0701, 10.0: 0.1402],
                        "1080p": [5.0: 0.1577, 10.0: 0.3154],
                    ],
                    "4:3": [
                        "480p": [5.0: 0.0304, 10.0: 0.0609],
                        "720p": [5.0: 0.0709, 10.0: 0.1417],
                        "1080p": [5.0: 0.1579, 10.0: 0.3159],
                    ],
                    "16:9": [
                        "480p": [5.0: 0.0315, 10.0: 0.0629],
                        "720p": [5.0: 0.0668, 10.0: 0.1336],
                        "1080p": [5.0: 0.1589, 10.0: 0.3177],
                    ],
                ]
            ),
        ]
    }

    // MARK: METHODS

    /// Returns the price for a given InfoPacket based on its model name.
    /// For variable pricing models (video), returns the default configuration price.
    ///
    /// - Parameter item: The InfoPacket to look up pricing for
    /// - Returns: The price as a Decimal, or nil if not found
    func price(for item: InfoPacket) -> Decimal? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }

        // First check fixed prices
        if let fixedPrice = prices[modelName] {
            return fixedPrice
        }

        // Then check variable pricing - return default config price for display purposes
        if let variableConfig = variableVideoPricing[modelName] {
            // Use default config if available, otherwise fall back to minimum price
            if let defaultConfig = defaultVideoConfigs[modelName] {
                if let defaultPrice = variableConfig.price(
                    aspectRatio: defaultConfig.aspectRatio,
                    resolution: defaultConfig.resolution,
                    duration: defaultConfig.duration
                ) {
                    return defaultPrice
                }
            }
            return basePrice(from: variableConfig)
        }

        return nil
    }

    /// Returns the minimum/base price from a variable pricing configuration.
    /// Used for display purposes in grid/list views.
    ///
    /// - Parameter config: The variable pricing configuration
    /// - Returns: The minimum price from all combinations
    private func basePrice(from config: VideoPricingConfiguration) -> Decimal? {
        var minPrice: Decimal?

        for (_, resolutions) in config.pricing {
            for (_, durations) in resolutions {
                for (_, price) in durations {
                    if minPrice == nil || price < minPrice! {
                        minPrice = price
                    }
                }
            }
        }

        return minPrice
    }

    /// Returns the variable price for a video model based on aspect ratio, resolution, and duration.
    ///
    /// - Parameters:
    ///   - modelName: The name of the video model
    ///   - aspectRatio: The aspect ratio (e.g., "16:9", "9:16", "1:1")
    ///   - resolution: The resolution (e.g., "480p", "720p", "1080p")
    ///   - duration: The duration in seconds (e.g., 5.0, 10.0)
    /// - Returns: The price as a Decimal, or nil if not found
    func variablePrice(
        for modelName: String, aspectRatio: String, resolution: String,
        duration: Double
    ) -> Decimal? {
        guard let config = variableVideoPricing[modelName] else { return nil }
        return config.price(
            aspectRatio: aspectRatio, resolution: resolution, duration: duration
        )
    }

    /// Checks if a model has variable pricing
    ///
    /// - Parameter modelName: The name of the model
    /// - Returns: True if the model has variable pricing, false otherwise
    func hasVariablePricing(for modelName: String) -> Bool {
        return variableVideoPricing[modelName] != nil
    }
    
    /// Returns the full pricing configuration for a model
    /// Used for displaying pricing tables
    ///
    /// - Parameter modelName: The name of the model
    /// - Returns: The VideoPricingConfiguration, or nil if model doesn't have variable pricing
    func pricingConfiguration(for modelName: String) -> VideoPricingConfiguration? {
        return variableVideoPricing[modelName]
    }
    
    // MARK: AUDIO PRICING
    
    /// Audio generation price difference for video models that support it
    /// Base prices INCLUDE audio (since audio is ON by default)
    /// This value is SUBTRACTED when audio is turned OFF
    private static let audioPriceAddons: [String: Decimal] = [
        // Google Veo 3.1 Fast: Base $1.20 (with audio), $0.80 without audio
        // Difference: $0.40 (subtracted when audio OFF)
        "Google Veo 3.1 Fast": 0.40
    ]
    
    /// Returns the audio price difference for a given model
    /// This amount is subtracted from the base price when audio is turned OFF
    ///
    /// - Parameter modelName: The name of the video model
    /// - Returns: The price difference as a Decimal, or nil if model doesn't support audio pricing
    func audioPriceAddon(for modelName: String) -> Decimal? {
        return PricingManager.audioPriceAddons[modelName]
    }

    // MARK: DIMENSIONS??? WHY?

    /// Determines resolution string from width and height dimensions
    /// Used to map dimensions to pricing resolution keys (480p, 720p, 1080p)
    ///
    /// - Parameters:
    ///   - width: Video width in pixels
    ///   - height: Video height in pixels
    /// - Returns: Resolution string (e.g., "480p", "720p", "1080p")
    static func resolutionFromDimensions(width: Int, height: Int) -> String {
        // Determine resolution based on the larger dimension
        let maxDimension = max(width, height)

        if maxDimension <= 960 {
            return "480p"
        } else if maxDimension <= 1280 {
            return "720p"
        } else {
            return "1080p"
        }
    }

    /// Gets dimensions for a given aspect ratio and resolution
    /// Returns the standard dimensions for Seedance 1.0 Pro Fast
    ///
    /// - Parameters:
    ///   - aspectRatio: Aspect ratio string (e.g., "16:9", "9:16")
    ///   - resolution: Resolution string (e.g., "480p", "720p", "1080p")
    /// - Returns: Tuple of (width, height) or nil if not found
    static func dimensionsForAspectRatioAndResolution(
        aspectRatio: String, resolution: String
    ) -> (width: Int, height: Int)? {
        // Seedance 1.0 Pro Fast dimensions from documentation
        let dimensions: [String: [String: (Int, Int)]] = [
            "480p": [
                "16:9": (864, 480),
                "9:16": (480, 864),
                "4:3": (736, 544),
                "3:4": (544, 736),
                "1:1": (640, 640),
                "21:9": (960, 416),
                "9:21": (416, 960),
            ],
            "720p": [
                "16:9": (1280, 720),
                "9:16": (720, 1280),
                "4:3": (960, 720),
                "3:4": (720, 960),
                "1:1": (1024, 1024),
                "21:9": (1680, 720),
                "9:21": (720, 1680),
            ],
            "1080p": [
                "16:9": (1920, 1088),
                "9:16": (1088, 1920),
                "4:3": (1664, 1248),
                "3:4": (1248, 1664),
                "1:1": (1440, 1440),
                "21:9": (2176, 928),
                "9:21": (928, 2176),
            ],
        ]

        return dimensions[resolution]?[aspectRatio]
    }
}
