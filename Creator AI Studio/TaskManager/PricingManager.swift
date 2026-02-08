import Foundation

// MARK: - PRICE DISPLAY MODE

/// Enum to control how prices are displayed throughout the app
enum PriceDisplayMode: String {
    case dollars
    case credits
    
    /// Conversion rate: 1 credit = $0.01 (100 credits = $1.00)
    static let creditsPerDollar: Decimal = 100
}

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
    
    /// Image models with resolution-based pricing (1k, 2k, 4k). Key: model name, value: [resolution: price].
    private let imageResolutionPricing: [String: [String: Decimal]]
    
    /// GPT Image 1.5 only: [aspectRatio][quality] -> price (e.g. "1:1", "2:3", "3:2" x "low", "medium", "high").
    private let gptImage15Pricing: [String: [String: Decimal]]
    
    /// Dictionary mapping model names to their default duration, aspect ratio, and resolution for display pricing
    /// Used to show the correct "starting from" price based on the model's default configuration
    private let defaultVideoConfigs: [String: (aspectRatio: String, resolution: String, duration: Double)] = [
        "Sora 2": ("9:16", "720p", 8.0),  // Sora 2 defaults to 8 seconds
        "Google Veo 3.1 Fast": ("9:16", "1080p", 8.0),  // Only option available
        "Seedance 1.0 Pro Fast": ("3:4", "480p", 5.0),  // Default to cheapest option
        "Kling VIDEO 2.6 Pro": ("9:16", "1080p", 5.0),  // Default to 5 seconds with audio
        "Wan2.6": ("9:16", "720p", 5.0),  // Default to 5 seconds
        "KlingAI 2.5 Turbo Pro": ("9:16", "1080p", 5.0)  // Default to 5 seconds
    ]

    private init() {
        // Each pricing config is built separately with explicit types so the
        // Swift type checker handles them independently (avoids exponential
        // inference on deeply nested collection literals).
        prices = Self.makeImagePrices()
        variableVideoPricing = Self.makeVariableVideoPricing()
        imageResolutionPricing = Self.makeImageResolutionPricing()
        gptImage15Pricing = Self.makeGPTImage15Pricing()
    }

    // MARK: - Factory Methods (split to reduce type-checker load)

    // MARK: IMAGE PRICES
    // Prices in dollars (same unit as balance). Display: 100 credits = $1.
    // GPT Image 1.5 uses gptImage15Pricing (aspect + quality), not fixed price.
    private static func makeImagePrices() -> [String: Decimal] {
        return [
            "Wan2.5-Preview Image": 0.027,
            "Nano Banana": 0.039,
            "Nano Banana Pro": 0.138,
            "Seedream 4.5": 0.04,
            "Seedream 4.0": 0.03,
            "FLUX.2 [dev]": 0.0122,
            "FLUX.1 Kontext [pro]": 0.04,
            "FLUX.1 Kontext [max]": 0.08,
            "Z-Image-Turbo": 0.005,  // $0.005 (displays as 0.5 credits; 100 credits = $1)
            "Wavespeed Ghibli": 0.005,
        ]
    }

    // MARK: VIDEO PRICES
    // Each VideoPricingConfiguration is built as a separate variable to avoid
    // a single massive nested dictionary literal.
    private static func makeVariableVideoPricing() -> [String: VideoPricingConfiguration] {
        // Sora 2 pricing: 4s ($0.4), 8s ($0.8), 12s ($1.2) - only supports 720p
        let sora2: VideoPricingConfiguration = VideoPricingConfiguration(
            pricing: [
                "16:9": ["720p": [4.0: 0.4, 8.0: 0.8, 12.0: 1.2]],
                "9:16": ["720p": [4.0: 0.4, 8.0: 0.8, 12.0: 1.2]],
            ]
        )

        // Google Veo 3.1 Fast pricing: Only supports 1080p at 8 seconds
        // Without audio: $0.80, With audio: $1.20
        // Base price is $1.20 (with audio) since audio is ON by default
        // Audio addon is negative (-$0.40) when audio is turned OFF
        let veo31Fast: VideoPricingConfiguration = VideoPricingConfiguration(
            pricing: [
                "16:9": ["1080p": [8.0: 1.20]],
                "9:16": ["1080p": [8.0: 1.20]],
            ]
        )

        // Seedance 1.0 Pro Fast pricing from Runware pricing page
        let seedance: VideoPricingConfiguration = VideoPricingConfiguration(
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
        )

        // Kling VIDEO 2.6 Pro pricing from Runware pricing page
        // Base prices include audio (audio ON by default): $0.14/s
        // Without audio: $0.07/s
        let kling26Pro: VideoPricingConfiguration = VideoPricingConfiguration(
            pricing: [
                "16:9": ["1080p": [5.0: 0.70, 10.0: 1.40]],
                "9:16": ["1080p": [5.0: 0.70, 10.0: 1.40]],
                "1:1": ["1080p": [5.0: 0.70, 10.0: 1.40]],
            ]
        )

        // Wan2.6 pricing from Runware pricing page
        let wan26: VideoPricingConfiguration = VideoPricingConfiguration(
            pricing: [
                "16:9": [
                    "720p": [5.0: 0.5, 10.0: 1.0, 15.0: 1.5],
                    "1080p": [5.0: 0.75, 10.0: 1.5, 15.0: 2.25],
                ],
                "9:16": [
                    "720p": [5.0: 0.5, 10.0: 1.0, 15.0: 1.5],
                    "1080p": [5.0: 0.75, 10.0: 1.5, 15.0: 2.25],
                ],
                "1:1": [
                    "720p": [5.0: 0.5, 10.0: 1.0, 15.0: 1.5],
                    "1080p": [5.0: 0.75, 10.0: 1.5, 15.0: 2.25],
                ],
            ]
        )

        // KlingAI 2.5 Turbo Pro pricing from Runware pricing page
        // 1080p: 5s = $0.35, 10s = $0.70
        let kling25TurboPro: VideoPricingConfiguration = VideoPricingConfiguration(
            pricing: [
                "16:9": ["1080p": [5.0: 0.35, 10.0: 0.70]],
                "9:16": ["1080p": [5.0: 0.35, 10.0: 0.70]],
                "1:1": ["1080p": [5.0: 0.35, 10.0: 0.70]],
            ]
        )

        return [
            "Sora 2": sora2,
            "Google Veo 3.1 Fast": veo31Fast,
            "Seedance 1.0 Pro Fast": seedance,
            "Kling VIDEO 2.6 Pro": kling26Pro,
            "Wan2.6": wan26,
            "KlingAI 2.5 Turbo Pro": kling25TurboPro,
        ]
    }

    // MARK: IMAGE RESOLUTION PRICING (Nano Banana Pro: 1K/2K $0.138, 4K $0.244)
    private static func makeImageResolutionPricing() -> [String: [String: Decimal]] {
        return [
            "Nano Banana Pro": ["1k": 0.138, "2k": 0.138, "4k": 0.244],
        ]
    }

    // MARK: GPT IMAGE 1.5 QUALITY PRICING (Runware: aspect × quality)
    // 1024×1024 (1:1), 1024×1536 (2:3), 1536×1024 (3:2) × low, medium, high
    private static func makeGPTImage15Pricing() -> [String: [String: Decimal]] {
        return [
            "1:1": ["low": 0.009, "medium": 0.034, "high": 0.133],
            "2:3": ["low": 0.013, "medium": 0.051, "high": 0.20],
            "3:2": ["low": 0.013, "medium": 0.05, "high": 0.199],
        ]
    }

    // MARK: METHODS

    /// Returns the price for an image model by name (used at deduction time and on detail page).
    /// - Parameters:
    ///   - modelName: The display/model name (e.g. "Z-Image-Turbo", "GPT Image 1.5")
    ///   - resolution: Optional resolution tier for models with resolution-based pricing (e.g. "1k", "2k", "4k" for Nano Banana Pro)
    ///   - aspectRatio: Optional aspect ratio for GPT Image 1.5 (e.g. "1:1", "2:3", "3:2")
    ///   - quality: Optional quality for GPT Image 1.5 ("low", "medium", "high"; "auto" treated as "medium")
    /// - Returns: The price in dollars as Double, or nil if not found (use metadata cost as fallback)
    func priceForImageModel(_ modelName: String, resolution: String? = nil, aspectRatio: String? = nil, quality: String? = nil) -> Double? {
        // GPT Image 1.5: aspect + quality
        if modelName == "GPT Image 1.5" {
            let aspect = aspectRatio ?? "1:1"
            let qualityNorm = (quality == "auto" || quality == nil) ? "medium" : quality!
            guard let byQuality = gptImage15Pricing[aspect], let decimalPrice = byQuality[qualityNorm] else { return nil }
            return NSDecimalNumber(decimal: decimalPrice).doubleValue
        }
        if let resolutionPrices = imageResolutionPricing[modelName] {
            let res = (resolution ?? "2k").lowercased()
            guard let decimalPrice = resolutionPrices[res] ?? resolutionPrices["2k"] ?? resolutionPrices["1k"] else { return nil }
            return NSDecimalNumber(decimal: decimalPrice).doubleValue
        }
        guard let decimalPrice = prices[modelName] else { return nil }
        return NSDecimalNumber(decimal: decimalPrice).doubleValue
    }

    /// Returns the price for a given InfoPacket based on its model name.
    /// For variable pricing models (video), returns the default configuration price.
    /// For GPT Image 1.5, uses aspect ratio and quality from item's resolved config (defaults: 1:1, medium).
    ///
    /// - Parameter item: The InfoPacket to look up pricing for
    /// - Returns: The price as a Decimal, or nil if not found
    func price(for item: InfoPacket) -> Decimal? {
        let modelName = item.display.modelName ?? ""
        guard !modelName.isEmpty else { return nil }

        // GPT Image 1.5: aspect + quality (default 1:1, medium for list/grid)
        if modelName == "GPT Image 1.5" {
            let aspect = item.resolvedAPIConfig.aspectRatio ?? "1:1"
            let qualityRaw = item.resolvedAPIConfig.runwareConfig?.openaiQuality ?? "medium"
            let quality = (qualityRaw == "auto" ? "medium" : qualityRaw)
            if let byQuality = gptImage15Pricing[aspect], let price = byQuality[quality] {
                return price
            }
            // Fallback: 1:1 medium
            return gptImage15Pricing["1:1"]?["medium"]
        }

        // Fixed prices
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
    
    /// Audio generation price difference for video models that support it (fixed amount)
    /// Base prices INCLUDE audio (since audio is ON by default)
    /// This value is SUBTRACTED when audio is turned OFF
    private static let audioPriceAddons: [String: Decimal] = [
        // Google Veo 3.1 Fast: Base $1.20 (with audio), $0.80 without audio
        // Difference: $0.40 (subtracted when audio OFF)
        "Google Veo 3.1 Fast": 0.40
    ]
    
    /// Audio generation price difference per second for video models with variable durations
    /// Used when audio addon varies based on duration
    /// This rate is multiplied by duration and SUBTRACTED when audio is turned OFF
    private static let audioPricePerSecond: [String: Decimal] = [
        // Kling VIDEO 2.6 Pro: $0.14/s with audio, $0.07/s without audio
        // Difference: $0.07/s (subtracted when audio OFF)
        "Kling VIDEO 2.6 Pro": 0.07
    ]
    
    /// Returns the audio price difference for a given model
    /// This amount is subtracted from the base price when audio is turned OFF
    ///
    /// - Parameter modelName: The name of the video model
    /// - Returns: The price difference as a Decimal, or nil if model doesn't support audio pricing
    func audioPriceAddon(for modelName: String) -> Decimal? {
        return PricingManager.audioPriceAddons[modelName]
    }
    
    /// Returns the audio price difference for a given model and duration
    /// This amount is subtracted from the base price when audio is turned OFF
    /// Supports both fixed addons and per-second rate addons
    ///
    /// - Parameters:
    ///   - modelName: The name of the video model
    ///   - duration: The video duration in seconds
    /// - Returns: The price difference as a Decimal, or nil if model doesn't support audio pricing
    func audioPriceAddon(for modelName: String, duration: Double) -> Decimal? {
        // First check for fixed addon
        if let fixedAddon = PricingManager.audioPriceAddons[modelName] {
            return fixedAddon
        }
        
        // Then check for per-second rate
        if let perSecondRate = PricingManager.audioPricePerSecond[modelName] {
            return perSecondRate * Decimal(duration)
        }
        
        return nil
    }
    
    /// Checks if a model supports audio pricing (has audio toggle that affects price)
    ///
    /// - Parameter modelName: The name of the video model
    /// - Returns: True if the model has audio-dependent pricing
    func hasAudioPricing(for modelName: String) -> Bool {
        return PricingManager.audioPriceAddons[modelName] != nil ||
               PricingManager.audioPricePerSecond[modelName] != nil
    }

    // MARK: MOTION CONTROL PRICING

    /// Motion control pricing per second by model and tier.
    /// Tier: "standard" (Fal.ai standard) or "pro" (Fal.ai pro); both are Fal.ai motion control.
    /// Motion control transfers movements from a reference video to a character image.
    private static let motionControlPricePerSecondByTier: [String: [String: Decimal]] = [
        "Kling VIDEO 2.6 Pro": [
            "standard": 0.08,  // Fal.ai v2.6/standard/motion-control — 8 credits/sec
            "pro": 0.12        // Fal.ai v2.6/pro/motion-control — 12 credits/sec
        ]
    ]

    /// Returns the motion control price per second for a given model and tier.
    /// - Parameters:
    ///   - modelName: The name of the video model
    ///   - tier: "standard" or "pro"
    /// - Returns: The per-second price as a Decimal, or nil if not configured
    func motionControlPricePerSecond(for modelName: String, tier: String) -> Decimal? {
        return PricingManager.motionControlPricePerSecondByTier[modelName]?[tier]
    }

    /// Returns the motion control price per second for a given model (first available tier, for backward compatibility).
    func motionControlPricePerSecond(for modelName: String) -> Decimal? {
        let tiers = PricingManager.motionControlPricePerSecondByTier[modelName]
        return tiers?["pro"] ?? tiers?["standard"]
    }

    /// Returns the total motion control price for a given model, tier, and duration.
    func motionControlPrice(for modelName: String, tier: String, durationSeconds: Double) -> Decimal? {
        guard let perSecondRate = motionControlPricePerSecond(for: modelName, tier: tier) else {
            return nil
        }
        return perSecondRate * Decimal(durationSeconds)
    }

    /// Returns the total motion control price for a given model and duration (uses first available tier).
    func motionControlPrice(for modelName: String, durationSeconds: Double) -> Decimal? {
        guard let perSecondRate = motionControlPricePerSecond(for: modelName) else {
            return nil
        }
        return perSecondRate * Decimal(durationSeconds)
    }

    /// Checks if a model supports motion control pricing (any tier).
    func hasMotionControlPricing(for modelName: String) -> Bool {
        return PricingManager.motionControlPricePerSecondByTier[modelName] != nil
    }

    /// Returns supported motion control tiers for a model in display order (e.g. ["standard", "pro"]).
    func motionControlTiers(for modelName: String) -> [String] {
        guard let tiers = PricingManager.motionControlPricePerSecondByTier[modelName] else {
            return []
        }
        let order = ["standard", "pro"]
        return order.filter { tiers[$0] != nil }
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
    /// Returns model-specific dimensions if model is provided, otherwise defaults to Seedance 1.0 Pro Fast dimensions
    ///
    /// - Parameters:
    ///   - aspectRatio: Aspect ratio string (e.g., "16:9", "9:16")
    ///   - resolution: Resolution string (e.g., "480p", "720p", "1080p")
    ///   - model: Optional model identifier (e.g., "google:3@3") for model-specific dimensions
    /// - Returns: Tuple of (width, height) or nil if not found
    // Dimension lookup tables extracted as static lets so they are built once
    // and don't trigger nested-literal type inference on every call.

    private static let veoDimensions: [String: [String: (Int, Int)]] = [
        "720p": ["16:9": (1280, 720), "9:16": (720, 1280)],
        "1080p": ["16:9": (1920, 1080), "9:16": (1080, 1920)],
    ]

    private static let kling26ProDimensions: [String: [String: (Int, Int)]] = [
        "1080p": ["16:9": (1920, 1080), "9:16": (1080, 1920), "1:1": (1440, 1440)],
    ]

    private static let kling25TurboProDimensions: [String: [String: (Int, Int)]] = [
        "1080p": ["16:9": (1920, 1080), "9:16": (1080, 1920), "1:1": (1080, 1080)],
    ]

    private static let defaultDimensions: [String: [String: (Int, Int)]] = [
        "480p": [
            "16:9": (864, 480), "9:16": (480, 864),
            "4:3": (736, 544), "3:4": (544, 736),
            "1:1": (640, 640),
            "21:9": (960, 416), "9:21": (416, 960),
        ],
        "720p": [
            "16:9": (1280, 720), "9:16": (720, 1280),
            "4:3": (960, 720), "3:4": (720, 960),
            "1:1": (1024, 1024),
            "21:9": (1680, 720), "9:21": (720, 1680),
        ],
        "1080p": [
            "16:9": (1920, 1088), "9:16": (1088, 1920),
            "4:3": (1664, 1248), "3:4": (1248, 1664),
            "1:1": (1440, 1440),
            "21:9": (2176, 928), "9:21": (928, 2176),
        ],
    ]

    static func dimensionsForAspectRatioAndResolution(
        aspectRatio: String, resolution: String, model: String? = nil
    ) -> (width: Int, height: Int)? {
        // Google Veo 3.1 Fast (google:3@3) - requires exact dimensions
        if let model = model, model.lowercased().contains("google:3@3") {
            return veoDimensions[resolution]?[aspectRatio]
        }

        // Kling VIDEO 2.6 Pro (klingai:kling-video@2.6-pro) - requires exact dimensions
        if let model = model, model.lowercased().contains("kling-video@2.6-pro") || model.lowercased().contains("klingai:kling-video@2.6-pro") {
            return kling26ProDimensions[resolution]?[aspectRatio]
        }

        // KlingAI 2.5 Turbo Pro (klingai:6@1) - requires exact dimensions
        if let model = model, model.lowercased().contains("klingai:6@1") {
            return kling25TurboProDimensions[resolution]?[aspectRatio]
        }

        // Default: Seedance 1.0 Pro Fast dimensions from documentation
        return defaultDimensions[resolution]?[aspectRatio]
    }
}

// MARK: - PRICE DISPLAY FORMATTING

extension PricingManager {
    /// The current price display mode (dollars or credits)
    /// Change this to switch between display modes app-wide
    static var displayMode: PriceDisplayMode {
        get {
            // Load from UserDefaults for persistence
            if let rawValue = UserDefaults.standard.string(forKey: "priceDisplayMode"),
               let mode = PriceDisplayMode(rawValue: rawValue) {
                return mode
            }
            return .credits // Default to credits
            // return .dollars // Default to credits
        }
        set {
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(newValue.rawValue, forKey: "priceDisplayMode")
        }
    }
    
    /// Converts a dollar amount to credits
    /// - Parameter dollars: The dollar amount as Decimal
    /// - Returns: The equivalent number of credits
    static func dollarsToCredits(_ dollars: Decimal) -> Decimal {
        dollars * PriceDisplayMode.creditsPerDollar
    }
    
    /// Formats a price according to the current display mode
    /// - Parameter price: The price as Decimal (in dollars)
    /// - Returns: Formatted string (e.g., "$0.50" or "50")
    static func formatPrice(_ price: Decimal) -> String {
        switch displayMode {
        case .dollars:
            return formatDollars(price)
        case .credits:
            return formatCredits(price)
        }
    }
    
    /// Formats a price as dollars
    /// - Parameter price: The price as Decimal
    /// - Returns: Formatted dollar string (e.g., "$0.50")
    static func formatDollars(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "$\(NSDecimalNumber(decimal: price).stringValue)"
    }
    
    /// Formats a price as credits (without "credits" label)
    /// - Parameter price: The price as Decimal (in dollars)
    /// - Returns: Formatted credits string (e.g., "50", "1.22")
    static func formatCredits(_ price: Decimal) -> String {
        let credits = dollarsToCredits(price)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: credits))
            ?? NSDecimalNumber(decimal: credits).stringValue
    }
    
    /// Formats a price with unit label (e.g., "50 credits" or "$0.50")
    /// - Parameter price: The price as Decimal
    /// - Returns: Formatted string with unit
    static func formatPriceWithUnit(_ price: Decimal) -> String {
        switch displayMode {
        case .dollars:
            return formatDollars(price)
        case .credits:
            return "\(formatCredits(price)) credits"
        }
    }
    
    /// Formats an optional price
    /// - Parameter price: Optional price as Decimal
    /// - Returns: Formatted string or "0" if nil
    static func formatPrice(_ price: Decimal?) -> String {
        guard let price = price else {
            return displayMode == .dollars ? "$0" : "0"
        }
        return formatPrice(price)
    }
    
    /// Formats an optional price with unit label
    /// - Parameter price: Optional price as Decimal
    /// - Returns: Formatted string with unit or "0" if nil
    static func formatPriceWithUnit(_ price: Decimal?) -> String {
        guard let price = price else {
            return displayMode == .dollars ? "$0" : "0 credits"
        }
        return formatPriceWithUnit(price)
    }
}
