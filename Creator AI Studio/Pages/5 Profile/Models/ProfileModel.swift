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
    @Published var isLoadingMore = false
    @Published var hasMorePages = true

    private struct CachedUserMediaEntry: Codable {
        let images: [UserImage]
        let lastFetchedAt: Date
    }

    private let client = SupabaseManager.shared.client
    private var hasFetchedFromDatabase = false
    private var currentPage = 0
    private let pageSize = 50 // Fetch 50 images at a time
    private let cacheStaleInterval: TimeInterval = 5 * 60 // 5 minutes
    
    // Notification observer for new image saves
    private var imageSavedObserver: NSObjectProtocol?

    var userId: String? {
        didSet {
            guard oldValue != userId, let userId else { return }
            handleUserChange(userId: userId)
        }
    }

    // ✅ Cache user images persistently between launches, keyed per user
    @AppStorage("cachedUserImagesV3") private var cachedUserImagesData: Data = .init()
    private var cachedUserImagesMap: [String: CachedUserMediaEntry] = [:]
    private var lastFetchedAt: Date?

    // Convenience computed property for backward compatibility (just URLs)
    var images: [String] {
        userImages.map { $0.image_url }
    }

    init() {
        decodeCacheStore()
        setupImageSavedNotification()
    }
    
    deinit {
        // Remove notification observer when view model is deallocated
        if let observer = imageSavedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Notification Setup
    
    /// Sets up notification observer for when new images are saved to the database
    private func setupImageSavedNotification() {
        imageSavedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ImageSavedToDatabase"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleImageSavedNotification(notification)
        }
    }
    
    /// Handles the notification when a new image is saved to the database
    /// Fetches the latest image immediately so it appears on the Profile page
    private func handleImageSavedNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let savedUserId = userInfo["userId"] as? String,
              let currentUserId = userId,
              savedUserId == currentUserId else {
            // Notification is for a different user, ignore it
            return
        }
        
        // Fetch the latest image immediately
        Task {
            await fetchLatestImage()
        }
    }

    private func decodeCacheStore() {
        if let decoded = try? JSONDecoder().decode([String: CachedUserMediaEntry].self, from: cachedUserImagesData) {
            cachedUserImagesMap = decoded
        } else {
            cachedUserImagesMap = [:]
        }
    }

    private func handleUserChange(userId: String) {
        // Reset pagination state for the new user
        currentPage = 0
        hasMorePages = true
        hasFetchedFromDatabase = false

        // Load cached data for this user if available
        loadCachedImages(for: userId)
    }

    private func loadCachedImages(for userId: String) {
        // Ensure cache is decoded
        if cachedUserImagesMap.isEmpty {
            decodeCacheStore()
        }

        if let entry = cachedUserImagesMap[userId] {
            userImages = entry.images
            lastFetchedAt = entry.lastFetchedAt
            // Set the page based on cached count so pagination continues correctly
            currentPage = Int(ceil(Double(entry.images.count) / Double(pageSize)))
            hasMorePages = entry.images.count >= pageSize

            // If the cache is fresh, skip the initial fetch to avoid egress
            if isCacheFresh {
                hasFetchedFromDatabase = true
            }
        } else {
            userImages = []
            lastFetchedAt = nil
            hasFetchedFromDatabase = false
            currentPage = 0
        }
    }

    private func saveCachedImages(for userId: String) {
        let now = Date()
        lastFetchedAt = lastFetchedAt ?? now
        cachedUserImagesMap[userId] = CachedUserMediaEntry(
            images: userImages,
            lastFetchedAt: lastFetchedAt ?? now
        )
        if let encoded = try? JSONEncoder().encode(cachedUserImagesMap) {
            cachedUserImagesData = encoded
        }
    }

    private var isCacheFresh: Bool {
        guard let lastFetchedAt else { return false }
        return Date().timeIntervalSince(lastFetchedAt) < cacheStaleInterval
    }

    func fetchUserImages(forceRefresh: Bool = false) async {
        guard let userId = userId else { return }

        // If we have fresh cached data and this is not a forced refresh, avoid a network call
        if !forceRefresh, isCacheFresh {
            hasFetchedFromDatabase = true
            return
        }

        // If we've already fetched during this session and there's no force refresh, skip
        guard !hasFetchedFromDatabase || forceRefresh else { return }

        // For force refresh, try to fetch only the newest items since the last cache entry
        if forceRefresh {
            await refreshLatest(for: userId)
            return
        }

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
                .limit(pageSize)
                .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                .execute()

            let newImages = response.value ?? []

            // If we got fewer images than pageSize, we've reached the end
            hasMorePages = newImages.count == pageSize

            // Append new images (or replace if it's the first page)
            if currentPage == 0 {
                userImages = newImages
            } else {
                userImages.append(contentsOf: newImages)
            }

            lastFetchedAt = Date()
            saveCachedImages(for: userId) // ✅ Store new images locally
            hasFetchedFromDatabase = true
            currentPage += 1
        } catch {
            print("❌ Failed to fetch user images: \(error)")
        }

        if shouldShowLoading {
            isLoading = false
        }
    }

    // MARK: - Refresh latest without re-downloading everything

    private func refreshLatest(for userId: String) async {
        guard !isLoading else { return }

        let latestTimestamp = userImages.compactMap { $0.created_at }.max()

        do {
            // Fetch the latest page (server-side filtered to newest items)
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .range(from: 0, to: pageSize - 1)
                .execute()

            let fetched = response.value ?? []

            guard !fetched.isEmpty else {
                lastFetchedAt = Date()
                saveCachedImages(for: userId)
                hasFetchedFromDatabase = true
                return
            }

            // If we have a cached timestamp, keep only new items compared to cache
            let freshItems: [UserImage]
            if let latestTimestamp {
                freshItems = fetched.filter { ($0.created_at ?? "") > latestTimestamp }
            } else {
                freshItems = fetched
            }

            guard !freshItems.isEmpty else {
                lastFetchedAt = Date()
                saveCachedImages(for: userId)
                hasFetchedFromDatabase = true
                return
            }

            // Deduplicate and prepend new items
            let existingIds = Set(userImages.map { $0.id })
            let dedupedFresh = freshItems.filter { !existingIds.contains($0.id) }
            userImages.insert(contentsOf: dedupedFresh, at: 0)

            // Update pagination marker to reflect total cached items
            currentPage = Int(ceil(Double(userImages.count) / Double(pageSize)))

            lastFetchedAt = Date()
            saveCachedImages(for: userId)
            hasFetchedFromDatabase = true
        } catch {
            print("❌ Failed to refresh user images: \(error)")
        }
    }
    
    // MARK: - Load More Images (Pagination)
    
    /// Loads the next page of images
    func loadMoreImages() async {
        guard let userId = userId else { return }
        guard hasMorePages, !isLoadingMore else { return }
        
        isLoadingMore = true
        
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                .execute()
            
            let newImages = response.value ?? []
            
            // If we got fewer images than pageSize, we've reached the end
            hasMorePages = newImages.count == pageSize
            
            // Append new images
            userImages.append(contentsOf: newImages)
            lastFetchedAt = Date()
            saveCachedImages(for: userId)
            currentPage += 1
//            print("✅ Loaded more images, page \(currentPage), total: \(userImages.count), hasMore: \(hasMorePages)")
            
        } catch {
            print("❌ Failed to load more images: \(error)")
        }
        
        isLoadingMore = false
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
        saveCachedImages(for: userId)

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
            saveCachedImages(for: userId)
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
    
    // MARK: - Remove Image
    
    /// Removes an image from the local array and cache
    /// - Parameter imageId: The ID of the image to remove
    func removeImage(imageId: String) {
        guard let userId = userId else { return }
        
        // Remove from local array
        userImages.removeAll { $0.id == imageId }
        
        // Update cache
        saveCachedImages(for: userId)
    }
    
    // MARK: - Add Image
    
    /// Adds a new image to the local array and cache
    /// - Parameter image: The UserImage to add
    func addImage(_ image: UserImage) {
        guard let userId = userId else { return }
        
        // Check if image already exists (avoid duplicates)
        guard !userImages.contains(where: { $0.id == image.id }) else {
            return
        }
        
        // Insert at the beginning (newest first)
        userImages.insert(image, at: 0)
        
        // Update cache
        saveCachedImages(for: userId)
    }
    
    /// Fetches a single image by URL and adds it to the list
    /// - Parameter imageUrl: The URL of the image to fetch
    func fetchAndAddImage(imageUrl: String) async {
        guard let userId = userId else { return }
        
        do {
            // Fetch the image by URL
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("image_url", value: imageUrl)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            
            if let newImage = response.value.first {
                await MainActor.run {
                    addImage(newImage)
                }
            }
        } catch {
            print("❌ Failed to fetch new image: \(error)")
        }
    }
    
    /// Fetches the most recent image and adds it to the list
    func fetchLatestImage() async {
        guard let userId = userId else { return }
        
        do {
            // Fetch the most recent image for this user
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            
            if let latestImage = response.value.first {
                await MainActor.run {
                    // Only add if it's not already in the list
                    if !userImages.contains(where: { $0.id == latestImage.id }) {
                        addImage(latestImage)
                    }
                }
            }
        } catch {
            print("❌ Failed to fetch latest image: \(error)")
        }
    }
}
