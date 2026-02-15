import SwiftUI

@MainActor
class VideoFiltersViewModel: ObservableObject {
    @Published var filters: [InfoPacket] = []
    @Published var spookyVideoFilters: [InfoPacket] = []
    @Published var mermaidVideoFilters: [InfoPacket] = []
    @Published var animeVideoFilters: [InfoPacket] = []
    @Published var yetiVideoFilters: [InfoPacket] = []
    @Published var wavespeedVideoFilters: [InfoPacket] = []
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
    
    /// WaveSpeed video-effect filters for a given Home row category (e.g. "Magical", "Fashion", "Video Games").
    func wavespeedFilters(forCategory category: String) -> [InfoPacket] {
        return wavespeedVideoFilters.filter { $0.category == category }
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
        
        // Load Spooky Video Filters (Kling O1 reference-to-video)
        var spooky: [InfoPacket] = []
        if let spookyURL = Bundle.main.url(forResource: "SpookyVideoFilters", withExtension: "json") {
            loadFromFile(url: spookyURL, categoryName: "Spooky Video", allFilters: &spooky, categorized: &categorized)
        }
        
        // Load Mermaid Video Filters (WaveSpeed video-effects, e.g. fishermen)
        var mermaid: [InfoPacket] = []
        if let mermaidURL = Bundle.main.url(forResource: "MermaidVideoFilters", withExtension: "json") {
            loadFromFile(url: mermaidURL, categoryName: "Mermaid Video", allFilters: &mermaid, categorized: &categorized)
        }

        // Load Anime Video Filters (Kling 2.6 image-to-video)
        var anime: [InfoPacket] = []
        if let animeURL = Bundle.main.url(forResource: "AnimeVideoFilters", withExtension: "json") {
            loadFromFile(url: animeURL, categoryName: "Anime Video", allFilters: &anime, categorized: &categorized)
        }

        // Load Yeti Video Filters
        var yeti: [InfoPacket] = []
        if let yetiURL = Bundle.main.url(forResource: "YetiVideoFilters", withExtension: "json") {
            loadFromFile(url: yetiURL, categoryName: "Yeti Video", allFilters: &yeti, categorized: &categorized)
        }
        
        // Load WaveSpeed video-effect filters (Fairy, Runway Model, Minecraft, etc.) with per-item category
        var wavespeed: [InfoPacket] = []
        if let wavespeedURL = Bundle.main.url(forResource: "WavespeedVideoFilters", withExtension: "json") {
            loadWavespeedFilters(url: wavespeedURL, allFilters: &wavespeed)
        }
        
        // Update published properties
        categorizedFiltersDict = categorized
        filters = allFilters
        spookyVideoFilters = spooky
        mermaidVideoFilters = mermaid
        animeVideoFilters = anime
        yetiVideoFilters = yeti
        wavespeedVideoFilters = wavespeed
    }
    
    /// Loads WaveSpeed video-effect JSON; preserves each item's category from JSON (for Home row grouping).
    private func loadWavespeedFilters(url: URL, allFilters: inout [InfoPacket]) {
        do {
            let data = try Data(contentsOf: url)
            var decoded = try JSONDecoder().decode([InfoPacket].self, from: data)
            decoded = decoded.map { var item = $0
                item.type = "Video Filter"
                // Keep item.category from JSON (do not overwrite)
                return item
            }
            allFilters.append(contentsOf: decoded)
        } catch {
            print("Failed to decode \(url.lastPathComponent): \(error)")
        }
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
            print("Failed to decode \(url.lastPathComponent): \(error)")
        }
    }
}

