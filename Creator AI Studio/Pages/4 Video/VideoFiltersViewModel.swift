import SwiftUI

@MainActor
class VideoFiltersViewModel: ObservableObject {
    @Published var filters: [InfoPacket] = []
    @Published private var categorizedFiltersDict: [String: [InfoPacket]] = [:]
    
    // Use centralized category configuration manager
    private let categoryManager = CategoryConfigurationManager.shared
    
    // Shared instance for accessing filters from anywhere
    static let shared = VideoFiltersViewModel()
    
    // Quick filters - returns first N filters from all filters, or all filters if limit is nil
    func quickFilters(limit: Int? = nil) -> [InfoPacket] {
        if let limit = limit {
            return Array(filters.prefix(limit))
        } else {
            return filters
        }
    }
    
    // Categorized filters - loaded from separate JSON files by category
    var categorizedFilters: [String: [InfoPacket]] {
        return categorizedFiltersDict
    }
    
    // Get filters by category name
    func filters(for category: String) -> [InfoPacket] {
        return categorizedFiltersDict[category] ?? []
    }
    
    // Get all video filters (for the home row)
    var allVideoFilters: [InfoPacket] {
        return filters
    }
    
    // Get category names in the specified display order
    var sortedCategoryNames: [String] {
        return categoryManager.sortedCategoryNames(from: Set(categorizedFilters.keys))
    }
    
    init() {
        loadFiltersJSON()
    }
    
    private func loadFiltersJSON() {
        // Load video filters from bundle (similar to VideoModelData.json loading pattern)
        var allFilters: [InfoPacket] = []
        var categorized: [String: [InfoPacket]] = [:]
        
        // Try to load VideoFilters.json from bundle root
        // Note: The file should be added to Xcode project and will be copied to bundle root
        guard let url = Bundle.main.url(forResource: "VideoFilters", withExtension: "json") else {
            print("VideoFilters.json not found in bundle. Video filter row will be empty until data is added.")
            // Update published properties with empty arrays
            categorizedFiltersDict = categorized
            filters = allFilters
            return
        }
        
        loadFromFile(url: url, categoryName: "Video Filters", allFilters: &allFilters, categorized: &categorized)
        
        // Update published properties
        categorizedFiltersDict = categorized
        filters = allFilters
    }
    
    private func loadFromFile(url: URL, categoryName: String, allFilters: inout [InfoPacket], categorized: inout [String: [InfoPacket]]) {
        do {
            let data = try Data(contentsOf: url)
            var decoded = try JSONDecoder().decode([InfoPacket].self, from: data)
            // Automatically set category and type for all items in this file
            decoded = decoded.map { var item = $0
                item.category = categoryName
                item.type = "Video Filter"
                return item
            }
            categorized[categoryName] = decoded
            allFilters.append(contentsOf: decoded)
        } catch {
            print("Failed to decode VideoFilters.json: \(error)")
        }
    }
}

