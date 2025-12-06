// Yes, ProfileViewModel.swift is actively being used in the Profile View. Here's what it does:

// Usage in 5-ProfileView.swift:

// Instantiation (line 16):
// @StateObject private var viewModel = ProfileViewModel()

// Passed to Content View (line 21):
// ProfileViewContent(viewModel: viewModel)

// What it's Used For:
// The ProfileViewModel serves as the data management layer for the user's profile, specifically handling:

// 1. User Media Management
// Fetches all user-generated images and videos from Supabase (user_media table)
// Stores them in the userImages array with full metadata (prompt, model, cost, aspect ratio, etc.)
// Provides a simple images property that returns just the URLs for backward compatibility

// 2. Caching
// Persistently caches user images locally using @AppStorage
// Loads cached images on initialization so users see their content immediately
// Updates cache whenever new data is fetched from the database

// 3. Loading State
// Manages isLoading state to show/hide loading indicators
// Only shows loading if there are no cached images to display

// 4. Smart Fetching
// Tracks whether images have been fetched this session (hasFetchedFromDatabase)
// Only fetches from database once per session unless forceRefresh: true is passed
// Used in three places:
// On view appear (line 29)
// Pull-to-refresh (line 129)
// When notifications are dismissed (line 135)
// The ViewModel follows the MVVM pattern, separating data logic from the UI and providing reactive updates through @Published properties.

import Combine
import Supabase
import SwiftUI

struct UserImage: Codable, Identifiable {
    let id: String
    let image_url: String
    let model: String?
    let title: String?
    let cost: Double?
    let type: String?
    let endpoint: String?
    let created_at: String?
    let media_type: String? // "image" or "video"
    let file_extension: String? // e.g., "jpg", "mp4", "webm"
    let thumbnail_url: String? // Thumbnail for videos
    let prompt: String? // Prompt used for generation
    let aspect_ratio: String? // Aspect ratio used for generation
    var is_favorite: Bool? // Whether the image is favorited

    // Computed property for convenience
    var isVideo: Bool {
        media_type == "video"
    }

    var isImage: Bool {
        media_type == "image" || media_type == nil
    }

    // Custom coding keys to handle database field names
    enum CodingKeys: String, CodingKey {
        case id
        case image_url
        case model
        case title
        case cost
        case type
        case endpoint
        case created_at
        case media_type
        case file_extension
        case thumbnail_url
        case prompt
        case aspect_ratio
        case is_favorite
    }

    // Custom decoder to handle id as either Int or String
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode id as String first, then as Int
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            // Fallback to using image_url as id if id is missing
            let url = try container.decode(String.self, forKey: .image_url)
            id = url
        }

        image_url = try container.decode(String.self, forKey: .image_url)
        model = try? container.decode(String.self, forKey: .model)
        title = try? container.decode(String.self, forKey: .title)
        cost = try? container.decode(Double.self, forKey: .cost)
        type = try? container.decode(String.self, forKey: .type)
        endpoint = try? container.decode(String.self, forKey: .endpoint)
        created_at = try? container.decode(String.self, forKey: .created_at)
        media_type = try? container.decode(String.self, forKey: .media_type)
        file_extension = try? container.decode(String.self, forKey: .file_extension)
        thumbnail_url = try? container.decode(String.self, forKey: .thumbnail_url)
        prompt = try? container.decode(String.self, forKey: .prompt)
        aspect_ratio = try? container.decode(String.self, forKey: .aspect_ratio)
        is_favorite = try? container.decode(Bool.self, forKey: .is_favorite) ?? false
    }
}

// MARK: - ViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userImages: [UserImage] = []
    @Published var isLoading = false

    private let client = SupabaseManager.shared.client
    private var hasFetchedFromDatabase = false
    var userId: String?

    // ✅ Cache user images persistently between launches
    // Note: Changed key from "cachedUserImages" to "cachedUserImagesV2" after adding metadata support
    @AppStorage("cachedUserImagesV2") private var cachedUserImagesData: Data = .init()

    // Convenience computed property for backward compatibility (just URLs)
    var images: [String] {
        userImages.map { $0.image_url }
    }

    init() {
        loadCachedImages()
    }

    private func loadCachedImages() {
        if let decoded = try? JSONDecoder().decode([UserImage].self, from: cachedUserImagesData) {
            userImages = decoded
//            print("📦 Loaded cached user images (\(userImages.count))")
        }
    }

    private func saveCachedImages() {
        if let encoded = try? JSONEncoder().encode(userImages) {
            cachedUserImagesData = encoded
        }
    }

    func fetchUserImages(forceRefresh: Bool = false) async {
        guard let userId = userId else { return }

        // If we've already fetched this session and it's not a forced refresh, skip
        guard !hasFetchedFromDatabase || forceRefresh else { return }

        // Only show loading state if we don't have any cached images to display
        let shouldShowLoading = userImages.isEmpty

        if shouldShowLoading {
            isLoading = true
        }

        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()

            userImages = response.value ?? []
            saveCachedImages() // ✅ Store new images locally
            hasFetchedFromDatabase = true
//            print("✅ Fetched and cached \(userImages.count) images from Supabase")

        } catch {
            print("❌ Failed to fetch user images: \(error)")
        }

        if shouldShowLoading {
            isLoading = false
        }
    }

    // MARK: - Fetch Images by Model

    /// Fetches user images filtered by a specific model name
    /// - Parameters:
    ///   - modelName: The model name to filter by (from item.display.modelName)
    ///   - limit: Maximum number of images to fetch (default: 50)
    ///   - forceRefresh: Whether to force a refresh from database
    /// - Returns: Array of UserImage filtered by model
    func fetchModelImages(modelName: String, limit: Int = 50, forceRefresh: Bool = false) async -> [UserImage] {
        guard let userId = userId else { return [] }

        // First, try to filter from cached images if available and not forcing refresh
        if !forceRefresh, !userImages.isEmpty {
            let filtered = userImages.filter { $0.model == modelName }
            if !filtered.isEmpty {
                return Array(filtered.prefix(limit))
            }
        }

        // If no cached results or force refresh, query database
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("model", value: modelName)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()

            return response.value ?? []
        } catch {
            print("❌ Failed to fetch model images for \(modelName): \(error)")
            return []
        }
    }

    // MARK: - Favorites Management

    /// Toggles the favorite status of an image
    /// - Parameter imageId: The ID of the image to toggle
    func toggleFavorite(imageId: String) async {
        guard let userId = userId else { return }

        // Find the image in local array
        guard let index = userImages.firstIndex(where: { $0.id == imageId }) else { return }

        // Toggle local state
        let currentFavorite = userImages[index].is_favorite ?? false
        let newFavorite = !currentFavorite

        // Create updated image with new favorite status
        var updatedImage = userImages[index]
        updatedImage.is_favorite = newFavorite

        // Update array to trigger @Published
        userImages[index] = updatedImage

        // Save to cache
        saveCachedImages()

        // Update database
        do {
            try await client.database
                .from("user_media")
                .update(["is_favorite": newFavorite])
                .eq("id", value: imageId)
                .eq("user_id", value: userId)
                .execute()
        } catch {
            print("❌ Failed to update favorite status: \(error)")
            // Revert local change on error
            var revertedImage = userImages[index]
            revertedImage.is_favorite = currentFavorite
            userImages[index] = revertedImage
            saveCachedImages()
        }
    }

    /// Gets all favorited images
    var favoriteImages: [UserImage] {
        userImages.filter { $0.is_favorite == true }
    }

    /// Gets unique list of models from user images
    var uniqueModels: [String] {
        let models = userImages.compactMap { $0.model }
        return Array(Set(models)).sorted()
    }

    /// Filters images by model name
    /// - Parameter modelName: The model name to filter by (nil for all)
    func filteredImages(by modelName: String?) -> [UserImage] {
        guard let modelName = modelName else {
            return userImages
        }
        return userImages.filter { $0.model == modelName }
    }

    /// Filters images by favorites
    /// - Parameter favoritesOnly: If true, returns only favorited images
    func filteredImages(favoritesOnly: Bool) -> [UserImage] {
        if favoritesOnly {
            return favoriteImages
        }
        return userImages
    }

    /// Filters images by both model and favorites
    /// - Parameters:
    ///   - modelName: The model name to filter by (nil for all)
    ///   - favoritesOnly: If true, returns only favorited images
    func filteredImages(by modelName: String?, favoritesOnly: Bool) -> [UserImage] {
        var filtered = favoritesOnly ? favoriteImages : userImages

        if let modelName = modelName {
            filtered = filtered.filter { $0.model == modelName }
        }

        return filtered
    }
}
