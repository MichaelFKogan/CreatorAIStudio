import Foundation

/// Centralized configuration manager for category-specific data.
/// This is the SINGLE SOURCE OF TRUTH for all category configuration including:
/// - Display order
/// - File names (for loading JSON files)
/// - Icons
/// - Example images
/// - More styles
///
/// To add a new category, update the arrays below in this file only.
class CategoryConfigurationManager {
    /// Singleton instance
    static let shared = CategoryConfigurationManager()
    
    // MARK: - Category Configuration (Single Source of Truth)
    
    /// Mapping of category display names to their JSON file names (without .json extension)
    let categoryFileNames: [String: String] = [
        "Anime": "Anime",
        "Art": "Art",
        "Character": "Character",
        "Video Games": "VideoGames",
        "Photography": "Photography",
        "Spooky": "Spooky",
        "Professional": "LinkedInHeadshots",
        "Fashion": "Fashion",
        "Luxury": "Luxury",
        "Chibi": "Chibi",
        "Just For Fun": "JustForFun",
        "Instagram": "Instagram",
        "Photobooth": "Photobooth",
        "Social Media": "SocialMedia",
        "Fitness": "Fitness",
        "Travel": "Travel",
        "Back In Time": "BackInTime",
        "Men's": "Mens",
    ]

        /// The display order for categories in the UI.
    /// Categories will appear in this order. Categories not in this list will appear at the end, sorted alphabetically.
    let categoryDisplayOrder: [String] = [
        "Anime",
        "Art",
        "Character",
        "Video Games",

        "Photography",
        "Instagram",
        "Photobooth",
        "Fashion",
        "Spooky",
        
        "Luxury",
        "Professional",

        "Chibi",
        "Just For Fun",
        "Social Media",
        "Fitness",
        "Travel",
        "Back In Time",
        "Men's",
    ]
    
    /// Mapping of category names to their SF Symbol icon names
    let categoryIcons: [String: String] = [
        "Anime": "sparkles.rectangle.stack.fill",
        "Art": "paintbrush.fill",
        "Character": "figure.stand",
        "Video Games": "gamecontroller.fill",
        "Photography": "camera.fill",
        "Spooky": "moon.stars.fill",
        "Professional": "person.crop.circle",
        "Fashion": "bag.fill",
        "Luxury": "diamond.fill",
        "Chibi": "face.smiling.inverse",
        "Just For Fun": "face.smiling.inverse",
        "Instagram": "camera.fill",
        "Photobooth": "camera.fill",
        "Social Media": "person.2.fill",
        "Fitness": "figure.walk.motion",
        "Travel": "globe.americas.fill",
        "Back In Time": "back.in.time.fill",
        "Men's": "person",
    ]
    
    /// Mapping of category names to their emoji icons
    let categoryEmojis: [String: String] = [
        "Anime": "✨",
        "Art": "🎨",
        "Character": "👤",
        "Video Games": "🎮",
        "Photography": "📸",
        "Spooky": "👻",
        "Professional": "💼",
        "Fashion": "👗",
        "Luxury": "💎",
        "Chibi": "😊",
        "Just For Fun": "🎉",
        "Instagram": "📷",
        "Photobooth": "📸",
        "Social Media": "📱",
        "Fitness": "💪",
        "Travel": "✈️",
        "Back In Time": "⏰",
        "Men's": "👔",
    ]
    
    /// Dictionary mapping category names to example images arrays
    private let exampleImagesByCategory: [String: [String]]
    
    /// Dictionary mapping category names to more styles arrays
    private let moreStylesByCategory: [String: [[String]]]
    
    private init() {
        // Initialize example images by category
        exampleImagesByCategory = [
            "Anime": [
                "anime2",
                "anime3",
                "anime4",
                "anime5",
                "anime6",
                "anime7"
            ],
            // Add other categories as needed
            // Categories without exampleImages will return nil (fallback to display.exampleImages)
        ]
        
        // Initialize more styles by category
        moreStylesByCategory = [
            "Anime": [
                ["Caricature"],
                ["photobooth"],
                ["halloween"],
                ["artist"],
                ["luxury"],
                ["videogamesItems"],
                ["chibi"],
                ["cute"]
            ],
            // Add other categories as needed
            // Categories without moreStyles will return nil (fallback to display.moreStyles)
        ]
    }
    
    // MARK: - Public Methods
    
    /// Returns the display order for categories.
    /// Categories not in the order list will appear at the end, sorted alphabetically.
    func sortedCategoryNames(from availableCategories: Set<String>) -> [String] {
        let orderedCategories = categoryDisplayOrder.filter { availableCategories.contains($0) }
        let unorderedCategories = availableCategories.filter { !categoryDisplayOrder.contains($0) }.sorted()
        return orderedCategories + unorderedCategories
    }
    
    /// Returns the file name (without .json extension) for a given category.
    ///
    /// - Parameter category: The category display name
    /// - Returns: The file name, or the category name itself if not found
    func fileName(for category: String) -> String {
        return categoryFileNames[category] ?? category
    }
    
    /// Returns the icon name (SF Symbol) for a given category.
    ///
    /// - Parameter category: The category name to look up
    /// - Returns: The icon name, or a default icon if not found
    func icon(for category: String) -> String {
        // First, try exact match
        if let icon = categoryIcons[category] {
            return icon
        }
        
        // Then, try case-insensitive partial match
        let lowercased = category.lowercased()
        if lowercased.contains("anime") {
            return "sparkles.rectangle.stack.fill"
        } else if lowercased.contains("character") || lowercased.contains("figure") {
            return "figure.stand"
        } else if lowercased.contains("art") || lowercased.contains("artistic") {
            return "paintbrush.fill"
        } else if lowercased.contains("game") || lowercased.contains("gaming") {
            return "gamecontroller.fill"
        } else if lowercased.contains("photo") || lowercased.contains("camera") {
            return "camera.fill"
        } else if lowercased.contains("creative") || lowercased.contains("design") {
            return "sparkles"
        } else {
            return "square.grid.2x2.fill" // Default icon
        }
    }
    
    /// Returns the emoji icon for a given category.
    ///
    /// - Parameter category: The category name to look up
    /// - Returns: The emoji, or a default emoji if not found
    func emoji(for category: String) -> String {
        // First, try exact match
        if let emoji = categoryEmojis[category] {
            return emoji
        }
        
        // Then, try case-insensitive partial match
        let lowercased = category.lowercased()
        if lowercased.contains("anime") {
            return "✨"
        } else if lowercased.contains("character") || lowercased.contains("figure") {
            return "👤"
        } else if lowercased.contains("art") || lowercased.contains("artistic") {
            return "🎨"
        } else if lowercased.contains("game") || lowercased.contains("gaming") {
            return "🎮"
        } else if lowercased.contains("photo") || lowercased.contains("camera") {
            return "📸"
        } else if lowercased.contains("spooky") || lowercased.contains("halloween") {
            return "👻"
        } else if lowercased.contains("professional") || lowercased.contains("business") {
            return "💼"
        } else if lowercased.contains("fashion") {
            return "👗"
        } else if lowercased.contains("luxury") {
            return "💎"
        } else if lowercased.contains("chibi") {
            return "😊"
        } else if lowercased.contains("fun") {
            return "🎉"
        } else if lowercased.contains("fitness") || lowercased.contains("workout") {
            return "💪"
        } else if lowercased.contains("travel") {
            return "✈️"
        } else if lowercased.contains("time") || lowercased.contains("vintage") {
            return "⏰"
        } else {
            return "📋" // Default emoji
        }
    }
    
    /// Returns the example images array for a given category.
    ///
    /// - Parameter category: The category name to look up
    /// - Returns: The example images array, or nil if not found
    func exampleImages(for category: String) -> [String]? {
        return exampleImagesByCategory[category]
    }
    
    /// Returns the more styles array for a given category.
    ///
    /// - Parameter category: The category name to look up
    /// - Returns: The more styles array, or nil if not found
    func moreStyles(for category: String) -> [[String]]? {
        return moreStylesByCategory[category]
    }
    
    /// Returns the category file order as an array of tuples (categoryName, fileName)
    /// for loading JSON files in the correct order.
    func categoryFileOrder() -> [(categoryName: String, fileName: String)] {
        return categoryDisplayOrder.compactMap { categoryName in
            guard let fileName = categoryFileNames[categoryName] else { return nil }
            return (categoryName: categoryName, fileName: fileName)
        }
    }
}
