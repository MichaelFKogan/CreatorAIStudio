import Foundation

/// Centralized configuration manager for category-specific data.
/// Maps categories to their exampleImages and moreStyles, eliminating the need
/// to duplicate this data in hundreds of JSON files.
class CategoryConfigurationManager {
    /// Singleton instance
    static let shared = CategoryConfigurationManager()
    
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
}
