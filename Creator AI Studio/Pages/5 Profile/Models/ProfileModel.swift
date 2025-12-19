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
    let provider: String? // Provider used for generation (e.g., "wavespeed", "runware")
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
        case provider
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
        provider = try? container.decode(String.self, forKey: .provider)
        is_favorite = try? container.decode(Bool.self, forKey: .is_favorite) ?? false
    }
}

// MARK: - UserStats

struct UserStats: Codable {
    let id: String?
    let user_id: String
    var favorite_count: Int
    var model_counts: [String: Int]  // JSONB in DB, decoded as dictionary
    var video_model_counts: [String: Int]  // JSONB in DB, decoded as dictionary
    let created_at: String?
    let updated_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case favorite_count
        case model_counts
        case video_model_counts
        case created_at
        case updated_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try? container.decode(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        favorite_count = try container.decode(Int.self, forKey: .favorite_count)
        created_at = try? container.decode(String.self, forKey: .created_at)
        updated_at = try? container.decode(String.self, forKey: .updated_at)
        
        // Decode JSONB fields as dictionaries
        if let modelCountsData = try? container.decode([String: Int].self, forKey: .model_counts) {
            model_counts = modelCountsData
        } else {
            model_counts = [:]
        }
        
        if let videoCountsData = try? container.decode([String: Int].self, forKey: .video_model_counts) {
            video_model_counts = videoCountsData
        } else {
            video_model_counts = [:]
        }
    }
    
    // Encoding helper to convert dictionaries to JSONB
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(favorite_count, forKey: .favorite_count)
        try container.encode(model_counts, forKey: .model_counts)
        try container.encode(video_model_counts, forKey: .video_model_counts)
    }
    
    // Regular initializer for creating new stats
    init(id: String? = nil, user_id: String, favorite_count: Int, model_counts: [String: Int], video_model_counts: [String: Int], created_at: String? = nil, updated_at: String? = nil) {
        self.id = id
        self.user_id = user_id
        self.favorite_count = favorite_count
        self.model_counts = model_counts
        self.video_model_counts = video_model_counts
        self.created_at = created_at
        self.updated_at = updated_at
    }
}

// MARK: - ViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userImages: [UserImage] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMorePages = true

    // New properties for counts and cached data
    @Published var favoriteCount: Int = 0
    @Published var cachedFavoriteImages: [UserImage] = []
    @Published var isLoadingFavorites = false
    @Published var isLoadingMoreFavorites = false
    @Published var hasMoreFavoritePages = true
    @Published var modelCounts: [String: Int] = [:] // model name -> count
    @Published var videoModelCounts: [String: Int] = [:] // model name -> count
    @Published var hasLoadedStats = false // Track if stats have been fetched

    private struct CachedUserMediaEntry: Codable {
        let images: [UserImage]
        let lastFetchedAt: Date
    }

    private let client = SupabaseManager.shared.client
    private var hasFetchedFromDatabase = false
    private var currentPage = 0
    private let pageSize = 50 // Fetch 50 images at a time
    private let cacheStaleInterval: TimeInterval = 30 * 60 // ✅ Changed from 5 to 30 minutes
    
    // Cache for model-specific images to avoid repeated queries
    private var modelImagesCache: [String: (images: [UserImage], fetchedAt: Date)] = [:]
    private let modelCacheStaleInterval: TimeInterval = 10 * 60 // 10 minutes
    
    // Pagination for favorites
    private var favoritesCurrentPage = 0
    private var hasFetchedFavorites = false
    
    // Notification observers for new media saves
    private var imageSavedObserver: NSObjectProtocol?
    private var videoSavedObserver: NSObjectProtocol?

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
        setupVideoSavedNotification()
    }
    
    deinit {
        // Remove notification observers when view model is deallocated
        if let observer = imageSavedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = videoSavedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Notification Setup
    
    /// Sets up notification observer for when new images are saved to the database
    private func setupImageSavedNotification() {
        print("📢 ProfileViewModel: Setting up ImageSavedToDatabase notification observer")
        imageSavedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ImageSavedToDatabase"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📢 ProfileViewModel: Notification received in observer closure")
            self?.handleImageSavedNotification(notification)
        }
        print("✅ ProfileViewModel: Notification observer set up successfully")
    }
    
    /// Sets up notification observer for when new videos are saved to the database
    private func setupVideoSavedNotification() {
        print("📢 ProfileViewModel: Setting up VideoSavedToDatabase notification observer")
        videoSavedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VideoSavedToDatabase"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📢 ProfileViewModel: Video notification received in observer closure")
            self?.handleImageSavedNotification(notification) // Reuse same handler
        }
        print("✅ ProfileViewModel: Video notification observer set up successfully")
    }
    
    /// Handles the notification when a new image or video is saved to the database
    /// Fetches the latest image immediately so it appears on the Profile page
    private func handleImageSavedNotification(_ notification: Notification) {
        print("📢 ProfileViewModel received ImageSavedToDatabase notification")
        
        guard let userInfo = notification.userInfo else {
            print("⚠️ Notification missing userInfo")
            return
        }
        
        guard let savedUserId = userInfo["userId"] as? String else {
            print("⚠️ Notification missing userId")
            return
        }
        
        // Support both imageUrl and videoUrl (videos use videoUrl key)
        let mediaUrl = (userInfo["imageUrl"] as? String) ?? (userInfo["videoUrl"] as? String)
        guard let mediaUrl = mediaUrl else {
            print("⚠️ Notification missing imageUrl or videoUrl")
            return
        }
        
        let imageId = userInfo["imageId"] as? String
        print("📢 Notification details - savedUserId: \(savedUserId), imageId: \(imageId ?? "nil"), mediaUrl: \(mediaUrl)")
        print("📢 Current ProfileViewModel userId: \(userId ?? "nil")")
        
        // If userId is not set yet, we'll check again after a short delay
        // This handles the case where the Profile view hasn't appeared yet
        guard let currentUserId = userId else {
            print("⚠️ ProfileViewModel userId not set yet, will retry in 1 second")
            Task {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    if let userId = self.userId, userId == savedUserId {
                        print("📢 Retrying fetch after userId was set")
                        Task {
                            // Small delay to ensure database transaction is committed
                            try? await Task.sleep(for: .milliseconds(500))
                            if let imageId = imageId {
                                await self.fetchAndAddImageById(imageId: imageId)
                            } else {
                                await self.fetchLatestImage()
                            }
                        }
                    }
                }
            }
            return
        }
        
        guard savedUserId == currentUserId else {
            print("⚠️ Notification is for different user (saved: \(savedUserId), current: \(currentUserId))")
            return
        }
        
        print("✅ Fetching image (preferring ID, then URL, then latest)")
        // Add a delay to ensure database transaction is fully committed
        // Increased delay for concurrent saves to prevent race conditions
        Task {
            // Increased delay to ensure database transaction is committed
            // This is especially important when multiple images are saved concurrently
            try? await Task.sleep(for: .milliseconds(1000))
            
            // Priority 1: Fetch by ID if available (most reliable)
            if let imageId = imageId {
                await fetchAndAddImageById(imageId: imageId)
                let imageWasAdded = await MainActor.run {
                    return userImages.contains(where: { $0.id == imageId })
                }
                if imageWasAdded {
                    print("✅ Image added successfully by ID: \(imageId)")
                    return
                } else {
                    print("⚠️ Image not found by ID after fetch, will try URL")
                }
            }
            
            // Priority 2: Try fetching by URL (with retry logic built-in)
            await fetchAndAddImage(imageUrl: mediaUrl)
            let imageWasAdded = await MainActor.run {
                return userImages.contains(where: { $0.image_url == mediaUrl })
            }
            
            if imageWasAdded {
                print("✅ Image added successfully by URL")
            } else {
                // Priority 3: Fall back to fetching the latest image
                print("⚠️ Image not found by ID/URL, falling back to fetching latest image")
                await fetchLatestImage()
            }
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
        
        // Reset favorites pagination
        favoritesCurrentPage = 0
        cachedFavoriteImages = []
        hasFetchedFavorites = false
        hasMoreFavoritePages = true
        favoriteCount = 0
        modelCounts = [:]
        videoModelCounts = [:]
        hasLoadedStats = false

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

        // For force refresh, try to fetch only the newest items since the last cache entry
        if forceRefresh {
            await refreshLatest(for: userId)
            return
        }

        // ✅ OPTIMIZATION: Always check for new images in background, even if cache is fresh
        // This ensures newly uploaded images appear even if cache hasn't expired
        if !userImages.isEmpty {
            if isCacheFresh {
                print("✅ Profile: Using fresh cache (\(userImages.count) images), but checking for new images in background")
                // Always do a background refresh to check for new images, even if cache is fresh
                // This ensures images uploaded while cache is still valid will appear
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    await self.refreshLatest(for: userId)
                }
                hasFetchedFromDatabase = true
                return
            } else {
                print("🔄 Profile: Cache stale, refreshing to check for new images")
                // Do a background refresh to check for new images
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    await self.refreshLatest(for: userId)
                }
                // Mark as fetched so we don't do a full fetch below
                hasFetchedFromDatabase = true
                return
            }
        }

        // If we've already fetched during this session and there's no force refresh, skip
        guard !hasFetchedFromDatabase else { return }

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
        guard !isLoading else { 
            print("⚠️ refreshLatest: Already loading, skipping")
            return 
        }

        let latestTimestamp = userImages.compactMap { $0.created_at }.max()
        print("🔄 refreshLatest: Checking for new images (latest cached timestamp: \(latestTimestamp ?? "none"), cached count: \(userImages.count))")

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
            print("🔄 refreshLatest: Fetched \(fetched.count) images from database")

            guard !fetched.isEmpty else {
                print("⚠️ refreshLatest: No images found in database")
                lastFetchedAt = Date()
                saveCachedImages(for: userId)
                hasFetchedFromDatabase = true
                return
            }

            // Check for new items by comparing IDs (most reliable method)
            // Also use timestamp as a secondary check for edge cases
            let existingIds = Set(userImages.map { $0.id })
            let freshItems: [UserImage]
            
            if let latestTimestamp {
                // Primary check: images not in cache by ID
                // Secondary check: images with newer timestamp (handles edge cases where ID might not match)
                freshItems = fetched.filter { image in
                    // If ID doesn't exist in cache, it's definitely new
                    if !existingIds.contains(image.id) {
                        return true
                    }
                    // If ID exists but timestamp is newer, it might be an update (rare case)
                    // But to avoid duplicates, we'll skip it if ID already exists
                    // The timestamp check is mainly for logging/debugging
                    if let imageTimestamp = image.created_at, imageTimestamp > latestTimestamp {
                        print("⚠️ refreshLatest: Found image with existing ID but newer timestamp: \(image.id)")
                    }
                    return false
                }
            } else {
                // No timestamp, check by ID only
                freshItems = fetched.filter { !existingIds.contains($0.id) }
            }

            print("🔄 refreshLatest: Found \(freshItems.count) potentially new images (after ID filtering)")

            guard !freshItems.isEmpty else {
                print("✅ refreshLatest: No new images found")
                lastFetchedAt = Date()
                saveCachedImages(for: userId)
                hasFetchedFromDatabase = true
                return
            }

            // Final deduplication check (should be redundant but ensures safety)
            let dedupedFresh = freshItems.filter { !existingIds.contains($0.id) }
            
            if !dedupedFresh.isEmpty {
                print("✅ refreshLatest: Adding \(dedupedFresh.count) new image(s) to list")
                for image in dedupedFresh {
                    print("  - Added image: id=\(image.id), url=\(image.image_url)")
                }
                userImages.insert(contentsOf: dedupedFresh, at: 0)
            } else {
                print("⚠️ refreshLatest: All fresh items were duplicates, nothing to add")
            }

            // Update pagination marker to reflect total cached items
            currentPage = Int(ceil(Double(userImages.count) / Double(pageSize)))

            lastFetchedAt = Date()
            saveCachedImages(for: userId)
            hasFetchedFromDatabase = true
            print("✅ refreshLatest: Complete. Total images: \(userImages.count)")
        } catch {
            print("❌ Failed to refresh user images: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            // Don't mark as fetched on error, so we can retry on next appear
            // But still update timestamp to avoid immediate retry loops
            lastFetchedAt = Date()
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
    ///   - limit: Maximum number of images to fetch (default: 1000, effectively unlimited)
    ///   - forceRefresh: Whether to force a refresh from database
    /// - Returns: Array of UserImage filtered by model
    func fetchModelImages(modelName: String, limit: Int = 1000, forceRefresh: Bool = false) async -> [UserImage] {
        guard let userId = userId else { return [] }

        // Check model-specific cache first (if not forcing refresh)
        if !forceRefresh {
            if let cached = modelImagesCache[modelName] {
                let cacheAge = Date().timeIntervalSince(cached.fetchedAt)
                if cacheAge < modelCacheStaleInterval {
                    print("✅ Using cached model images for \(modelName): \(cached.images.count) images")
                    return cached.images
                } else {
                    print("⏰ Model cache stale for \(modelName), refreshing...")
                }
            }
        }

        // Try to use main userImages cache if it seems complete (has >= 50 images)
        // This indicates we likely have a full cache loaded
        if !forceRefresh, userImages.count >= 50 {
            let filtered = userImages.filter { $0.model == modelName }
            if !filtered.isEmpty {
                print("✅ Using main cache for \(modelName): \(filtered.count) images")
                // Cache the filtered results for future use
                modelImagesCache[modelName] = (filtered, Date())
                return filtered
            }
        }

        // Query database - use a high limit to get all images for this model
        print("📡 Querying database for model images: \(modelName)")
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("model", value: modelName)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()

            let images = response.value ?? []
            
            // Cache the results
            modelImagesCache[modelName] = (images, Date())
            print("✅ Fetched and cached \(images.count) images for model \(modelName)")
            
            return images
        } catch {
            print("❌ Failed to fetch model images for \(modelName): \(error)")
            return []
        }
    }
    
    /// Clears the model-specific cache (useful when new images are created)
    func clearModelCache() {
        modelImagesCache.removeAll()
    }
    
    /// Clears cache for a specific model
    func clearModelCache(for modelName: String) {
        modelImagesCache.removeValue(forKey: modelName)
    }

    // MARK: - Fetch User Stats (from user_stats table)
    
    /// Fetches user stats from the user_stats table (very cheap - just one row)
    func fetchUserStats() async {
        guard let userId = userId else { return }
        
        do {
            let response: PostgrestResponse<[UserStats]> = try await client.database
                .from("user_stats")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            
            if let stats = response.value.first {
                // Update published properties from stats
                print("📊 Current favoriteCount before update: \(favoriteCount)")
                favoriteCount = stats.favorite_count
                modelCounts = stats.model_counts
                videoModelCounts = stats.video_model_counts
                hasLoadedStats = true
                print("✅ Fetched user stats: \(stats.favorite_count) favorites, \(stats.model_counts.count) image models, \(stats.video_model_counts.count) video models")
                print("✅ Model counts: \(stats.model_counts)")
                print("📊 favoriteCount after update: \(favoriteCount)")
            } else {
                // Stats don't exist yet, initialize them
                print("⚠️ User stats not found, initializing...")
                await initializeUserStats()
            }
        } catch {
            print("❌ Failed to fetch user stats: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            
            // Check if error is because table doesn't exist
            let errorString = String(describing: error).lowercased()
            if errorString.contains("user_stats") || errorString.contains("relation") || errorString.contains("does not exist") {
                print("⚠️ user_stats table doesn't exist. Please run the DATABASE_MIGRATION_user_stats.sql migration in Supabase.")
                print("⚠️ Falling back to computing counts from loaded images...")
                
                // Fallback: compute counts from all user_media (similar to initialization)
                await computeStatsFromDatabase()
            }
        }
    }
    
    /// Re-syncs user stats by recomputing from database (useful if stats are out of sync)
    func resyncUserStats() async {
        print("🔄 Re-syncing user stats from database...")
        await initializeUserStats()
    }
    
    /// Fallback method to compute stats directly from user_media when user_stats table doesn't exist
    private func computeStatsFromDatabase() async {
        guard let userId = userId else { return }
        
        do {
            // Fetch all media to compute counts
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select("model,media_type,is_favorite")
                .eq("user_id", value: userId)
                .limit(10000) // High limit to get all
                .execute()
            
            let allMedia = response.value ?? []
            
            // Compute counts
            var computedFavoriteCount = 0
            var computedModelCounts: [String: Int] = [:]
            var computedVideoModelCounts: [String: Int] = [:]
            
            print("📊 Computing stats from \(allMedia.count) media items...")
            for media in allMedia {
                // Count favorites (handle both true and nil as false)
                if media.is_favorite == true {
                    computedFavoriteCount += 1
                }
                
                // Count by model
                if let model = media.model {
                    if media.isImage {
                        computedModelCounts[model, default: 0] += 1
                    } else if media.isVideo {
                        computedVideoModelCounts[model, default: 0] += 1
                    }
                }
            }
            
            // Update published properties on main thread
            print("📊 Before update - favoriteCount: \(self.favoriteCount), computed: \(computedFavoriteCount)")
            await MainActor.run {
                self.favoriteCount = computedFavoriteCount
                self.modelCounts = computedModelCounts
                self.videoModelCounts = computedVideoModelCounts
                self.hasLoadedStats = true
                
                print("📊 After update - favoriteCount: \(self.favoriteCount)")
                print("✅ Computed stats from database: \(computedFavoriteCount) favorites, \(computedModelCounts.count) image models, \(computedVideoModelCounts.count) video models")
                print("✅ Model counts dictionary: \(computedModelCounts)")
                print("✅ Video model counts dictionary: \(computedVideoModelCounts)")
            }
        } catch {
            print("❌ Failed to compute stats from database: \(error)")
        }
    }
    
    /// Initializes user stats if they don't exist (computes counts from user_media)
    private func initializeUserStats() async {
        guard let userId = userId else { return }
        
        print("📊 Initializing user stats by computing counts from user_media...")
        
        // Compute counts from user_media (one-time expensive operation)
        do {
            // Fetch all media to compute counts
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select("model,media_type,is_favorite")
                .eq("user_id", value: userId)
                .limit(10000) // High limit to get all
                .execute()
            
            let allMedia = response.value ?? []
            
            print("📊 Computing stats from \(allMedia.count) media items...")
            
            // Compute counts
            var favoriteCount = 0
            var modelCounts: [String: Int] = [:]
            var videoModelCounts: [String: Int] = [:]
            
            for media in allMedia {
                // Count favorites (handle both true and nil as false)
                if media.is_favorite == true {
                    favoriteCount += 1
                }
                
                // Count by model
                if let model = media.model {
                    if media.isImage {
                        modelCounts[model, default: 0] += 1
                    } else if media.isVideo {
                        videoModelCounts[model, default: 0] += 1
                    }
                }
            }
            
            // Create stats record
            let stats = UserStats(
                id: nil,
                user_id: userId,
                favorite_count: favoriteCount,
                model_counts: modelCounts,
                video_model_counts: videoModelCounts,
                created_at: nil,
                updated_at: nil
            )
            
            // Check if stats already exist (for re-sync)
            let existingResponse: PostgrestResponse<[UserStats]> = try await client.database
                .from("user_stats")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            
            if existingResponse.value.first != nil {
                // Update existing stats
                print("📊 Updating existing user stats...")
                try await client.database
                    .from("user_stats")
                    .update(stats)
                    .eq("user_id", value: userId)
                    .execute()
            } else {
                // Insert new stats
                print("📊 Inserting new user stats...")
                try await client.database
                    .from("user_stats")
                    .insert(stats)
                    .execute()
            }
            
            // Update published properties
            print("📊 Before update - favoriteCount: \(self.favoriteCount), computed: \(favoriteCount)")
            self.favoriteCount = favoriteCount
            self.modelCounts = modelCounts
            self.videoModelCounts = videoModelCounts
            self.hasLoadedStats = true
            print("📊 After update - favoriteCount: \(self.favoriteCount)")
            
            print("✅ Initialized user stats: \(favoriteCount) favorites, \(modelCounts.count) image models, \(videoModelCounts.count) video models")
        } catch {
            print("❌ Failed to initialize user stats: \(error)")
        }
    }
    
    // MARK: - Update User Stats
    
    /// Updates user stats in the database (incremental updates)
    private func updateUserStats() async {
        guard let userId = userId else { return }
        
        do {
            // Create a UserStats object for updating
            let statsUpdate = UserStats(
                id: nil,
                user_id: userId,
                favorite_count: favoriteCount,
                model_counts: modelCounts,
                video_model_counts: videoModelCounts,
                created_at: nil,
                updated_at: nil
            )
            
            try await client.database
                .from("user_stats")
                .update(statsUpdate)
                .eq("user_id", value: userId)
                .execute()
            
            print("✅ Updated user stats in database")
        } catch {
            print("❌ Failed to update user stats: \(error)")
        }
    }
    
    /// Increments favorite count when an image is favorited
    private func incrementFavoriteCount() async {
        favoriteCount += 1
        await updateUserStats()
    }
    
    /// Decrements favorite count when an image is unfavorited
    private func decrementFavoriteCount() async {
        favoriteCount = max(0, favoriteCount - 1)
        await updateUserStats()
    }
    
    /// Updates model counts when an image is added
    private func updateModelCountsForImage(_ image: UserImage, increment: Bool) async {
        guard let model = image.model else { return }
        
        if image.isImage {
            if increment {
                modelCounts[model, default: 0] += 1
            } else {
                modelCounts[model, default: 0] = max(0, (modelCounts[model] ?? 0) - 1)
                // Remove model from counts if count reaches 0
                if modelCounts[model] == 0 {
                    modelCounts.removeValue(forKey: model)
                }
            }
        } else if image.isVideo {
            if increment {
                videoModelCounts[model, default: 0] += 1
            } else {
                videoModelCounts[model, default: 0] = max(0, (videoModelCounts[model] ?? 0) - 1)
                // Remove model from counts if count reaches 0
                if videoModelCounts[model] == 0 {
                    videoModelCounts.removeValue(forKey: model)
                }
            }
        }
        
        await updateUserStats()
    }
    
    // MARK: - Fetch Favorites with Pagination
    
    /// Fetches the first page of favorites (called when favorites tab is clicked)
    func fetchFavorites(forceRefresh: Bool = false) async {
        guard let userId = userId else { return }
        
        print("📊 fetchFavorites called - current favoriteCount: \(favoriteCount), cachedFavoriteImages.count: \(cachedFavoriteImages.count)")
        
        // Reset pagination if forcing refresh
        if forceRefresh {
            favoritesCurrentPage = 0
            cachedFavoriteImages = []
            hasFetchedFavorites = false
            hasMoreFavoritePages = true
        }
        
        // If we've already fetched and not forcing refresh, skip
        guard !hasFetchedFavorites else { 
            print("⏭️ Already fetched favorites, skipping")
            return 
        }
        
        isLoadingFavorites = true
        
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("is_favorite", value: true)
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: favoritesCurrentPage * pageSize, to: (favoritesCurrentPage + 1) * pageSize - 1)
                .execute()
            
            let favorites = response.value ?? []
            
            // If we got fewer favorites than pageSize, we've reached the end
            hasMoreFavoritePages = favorites.count == pageSize
            
            // Set the favorites (replace if it's the first page)
            if favoritesCurrentPage == 0 {
                cachedFavoriteImages = favorites
            } else {
                cachedFavoriteImages.append(contentsOf: favorites)
            }
            
            favoritesCurrentPage += 1
            hasFetchedFavorites = true
            
            print("✅ Fetched \(favorites.count) favorites (page \(favoritesCurrentPage - 1)), total cached: \(cachedFavoriteImages.count)")
            print("📊 favoriteCount after fetchFavorites: \(favoriteCount) (should NOT change)")
        } catch {
            print("❌ Failed to fetch favorites: \(error)")
        }
        
        isLoadingFavorites = false
    }
    
    /// Loads the next page of favorites
    func loadMoreFavorites() async {
        guard let userId = userId else { return }
        guard hasMoreFavoritePages, !isLoadingMoreFavorites else { return }
        
        isLoadingMoreFavorites = true
        
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("is_favorite", value: true)
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: favoritesCurrentPage * pageSize, to: (favoritesCurrentPage + 1) * pageSize - 1)
                .execute()
            
            let newFavorites = response.value ?? []
            
            // If we got fewer favorites than pageSize, we've reached the end
            hasMoreFavoritePages = newFavorites.count == pageSize
            
            // Append new favorites
            cachedFavoriteImages.append(contentsOf: newFavorites)
            favoritesCurrentPage += 1
            
            print("✅ Loaded more favorites, page \(favoritesCurrentPage - 1), total: \(cachedFavoriteImages.count), hasMore: \(hasMoreFavoritePages)")
        } catch {
            print("❌ Failed to load more favorites: \(error)")
        }
        
        isLoadingMoreFavorites = false
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
            
            // Update stats
            if newFavorite {
                await incrementFavoriteCount()
            } else {
                await decrementFavoriteCount()
            }
        } catch {
            print("❌ Failed to update favorite status: \(error)")
            // Revert local change on error
            var revertedImage = userImages[index]
            revertedImage.is_favorite = currentFavorite
            userImages[index] = revertedImage
            saveCachedImages(for: userId)
        }
    }

    /// Gets all favorited images (uses cached favorites if available, otherwise filters from userImages)
    var favoriteImages: [UserImage] {
        // If we have cached favorites, use them (they contain paginated favorites)
        if !cachedFavoriteImages.isEmpty {
            return cachedFavoriteImages
        }
        // Otherwise, fall back to filtering from userImages (limited to first 50)
        return userImages.filter { $0.is_favorite == true }
    }

    /// Gets unique list of models from user images (images only)
    var uniqueModels: [String] {
        let models = userImages.filter { $0.isImage }.compactMap { $0.model }
        return Array(Set(models)).sorted()
    }
    
    /// Gets unique list of video models from user videos
    var uniqueVideoModels: [String] {
        let models = userImages.filter { $0.isVideo }.compactMap { $0.model }
        return Array(Set(models)).sorted()
    }
    
    /// Gets all video items
    var userVideos: [UserImage] {
        userImages.filter { $0.isVideo }
    }
    
    /// Gets favorited videos
    var favoriteVideos: [UserImage] {
        userImages.filter { $0.isVideo && $0.is_favorite == true }
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
    
    /// Filters videos by model name
    /// - Parameter modelName: The model name to filter by (nil for all)
    func filteredVideos(by modelName: String?) -> [UserImage] {
        guard let modelName = modelName else {
            return userVideos
        }
        return userVideos.filter { $0.model == modelName }
    }
    
    /// Filters videos by both model and favorites
    /// - Parameters:
    ///   - modelName: The model name to filter by (nil for all)
    ///   - favoritesOnly: If true, returns only favorited videos
    func filteredVideos(by modelName: String?, favoritesOnly: Bool) -> [UserImage] {
        var filtered = favoritesOnly ? favoriteVideos : userVideos
        
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
    
    /// Deletes multiple images from the database and storage, then removes them from the local array
    /// - Parameter imageIds: Array of image IDs to delete
    func deleteImages(imageIds: [String]) async {
        guard let userId = userId else { return }
        
        for imageId in imageIds {
            // Find the image to get its details
            guard let image = userImages.first(where: { $0.id == imageId }) else { continue }
            
            let maxRetries = 3
            var lastError: Error?
            
            for attempt in 1...maxRetries {
                do {
                    let imageUrl = image.image_url
                    let isVideo = image.isVideo
                    
                    // Delete from database first
                    try await retryOperation(maxAttempts: 2) {
                        try await client.database
                            .from("user_media")
                            .delete()
                            .eq("id", value: imageId)
                            .execute()
                    }
                    
                    // Determine which storage bucket to use
                    let bucketName = isVideo ? "user-generated-videos" : "user-generated-images"
                    let bucketPath = isVideo ? "/user-generated-videos/" : "/user-generated-images/"
                    
                    // Extract the storage path from the URL
                    var storagePath: String?
                    
                    if let bucketIndex = imageUrl.range(of: bucketPath) {
                        storagePath = String(imageUrl[bucketIndex.upperBound...])
                    } else if let publicIndex = imageUrl.range(of: "/public\(bucketPath)") {
                        storagePath = String(imageUrl[publicIndex.upperBound...])
                    } else if let url = URL(string: imageUrl) {
                        let bucketComponent = isVideo ? "user-generated-videos" : "user-generated-images"
                        if let bucketIdx = url.pathComponents.firstIndex(of: bucketComponent) {
                            let pathAfterBucket = url.pathComponents.dropFirst(bucketIdx + 1)
                            storagePath = pathAfterBucket.joined(separator: "/")
                        }
                    }
                    
                    // URL-decode the storage path (important: URLs may have encoded characters like %20)
                    if let path = storagePath, let decodedPath = path.removingPercentEncoding {
                        storagePath = decodedPath
                        print("🔍 Decoded storage path: \(decodedPath)")
                    }
                    
                    // Delete thumbnail if it's a video (non-critical)
                    if isVideo, let thumbnailUrl = image.thumbnail_url {
                        var thumbnailPath: String?
                        if let bucketIndex = thumbnailUrl.range(of: "/user-generated-images/") {
                            thumbnailPath = String(thumbnailUrl[bucketIndex.upperBound...])
                        }
                        
                        if let thumbnailPath = thumbnailPath {
                            do {
                                try await retryOperation(maxAttempts: 2) {
                                    _ = try await client.storage
                                        .from("user-generated-images")
                                        .remove(paths: [thumbnailPath])
                                }
                            } catch {
                                print("⚠️ Thumbnail deletion failed (non-critical): \(error)")
                            }
                        }
                    }
                    
                    // Delete main storage file
                    if let storagePath = storagePath {
                        print("🗑️ Attempting to delete from storage - bucket: '\(bucketName)', path: '\(storagePath)'")
                        do {
                            let deleteResult = try await client.storage
                                .from(bucketName)
                                .remove(paths: [storagePath])
                            if deleteResult.isEmpty {
                                print("⚠️ Storage delete returned empty result for '\(storagePath)' - file may not have been deleted")
                            } else {
                                print("✅ Storage file deleted: \(deleteResult)")
                            }
                        } catch {
                            print("❌ Storage deletion FAILED for path '\(storagePath)': \(error)")
                        }
                    } else {
                        print("❌ Could not extract storage path from URL: \(imageUrl)")
                    }
                    
                    // Update stats before removing from local array
                    await updateModelCountsForImage(image, increment: false)
                    if image.is_favorite == true {
                        await decrementFavoriteCount()
                    }
                    
                    // Success - remove from local array
                    await MainActor.run {
                        userImages.removeAll { $0.id == imageId }
                    }
                    break // Success, exit retry loop
                    
                } catch {
                    lastError = error
                    if attempt < maxRetries {
                        let delaySeconds = Double(attempt) * 0.5
                        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    }
                }
            }
            
            if lastError != nil {
                print("❌ Failed to delete image \(imageId) after \(maxRetries) attempts")
            }
        }
        
        // Update cache after all deletions
        await MainActor.run {
            saveCachedImages(for: userId)
        }
    }
    
    // MARK: - Retry Helper
    
    private func retryOperation<T>(maxAttempts: Int, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let delay = 0.3 * Double(attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NSError(
            domain: "RetryError", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Operation failed after \(maxAttempts) attempts"]
        )
    }
    
    // MARK: - Add Image
    
    /// Adds a new image to the local array and cache
    /// - Parameter image: The UserImage to add
    func addImage(_ image: UserImage) async {
        guard let userId = userId else { return }
        
        // Check if image already exists (avoid duplicates)
        guard !userImages.contains(where: { $0.id == image.id }) else {
            return
        }
        
        // Insert at the beginning (newest first)
        userImages.insert(image, at: 0)
        
        // Clear model-specific cache for this image's model (if it has one)
        // This ensures the "Your Creations" section shows the new image
        if let modelName = image.model, !modelName.isEmpty {
            clearModelCache(for: modelName)
        }
        
        // Update cache
        saveCachedImages(for: userId)
        
        // Update stats (increment model count, and favorite count if favorited)
        await updateModelCountsForImage(image, increment: true)
        if image.is_favorite == true {
            await incrementFavoriteCount()
        }
    }
    
    /// Fetches a single image by ID and adds it to the list
    /// - Parameter imageId: The ID of the image to fetch
    func fetchAndAddImageById(imageId: String) async {
        guard let userId = userId else {
            print("⚠️ fetchAndAddImageById: userId is nil")
            return
        }
        
        // Check if image already exists to avoid duplicates
        let alreadyExists = await MainActor.run {
            return userImages.contains(where: { $0.id == imageId })
        }
        
        if alreadyExists {
            print("✅ fetchAndAddImageById: Image \(imageId) already exists in list, skipping")
            return
        }
        
        print("🔍 fetchAndAddImageById: Fetching image with ID: \(imageId) for userId: \(userId)")
        
        // Retry logic: database might not be immediately available after insert
        // Increased retries and delays for concurrent saves
        var retryCount = 0
        let maxRetries = 5
        
        while retryCount < maxRetries {
            do {
                // Fetch the image by ID
                let response: PostgrestResponse<[UserImage]> = try await client.database
                    .from("user_media")
                    .select()
                    .eq("user_id", value: userId)
                    .eq("id", value: imageId)
                    .limit(1)
                    .execute()
                
                let images = response.value ?? []
                print("🔍 fetchAndAddImageById: Found \(images.count) image(s) with ID: \(imageId)")
                
                if let newImage = images.first {
                    print("✅ fetchAndAddImageById: Adding image to list (id: \(newImage.id), url: \(newImage.image_url))")
                    // Check if already exists before adding
                    let alreadyExists = await MainActor.run {
                        return userImages.contains(where: { $0.id == newImage.id })
                    }
                    
                    if !alreadyExists {
                        await addImage(newImage)
                        await MainActor.run {
                            print("✅ fetchAndAddImageById: Image added successfully. Total images: \(userImages.count)")
                        }
                    } else {
                        print("⚠️ fetchAndAddImageById: Image already exists in list, skipping")
                    }
                    return // Success, exit retry loop
                } else {
                    print("⚠️ fetchAndAddImageById: No image found with ID: \(imageId) (attempt \(retryCount + 1)/\(maxRetries))")
                }
            } catch {
                print("❌ fetchAndAddImageById: Error on attempt \(retryCount + 1)/\(maxRetries): \(error)")
            }
            
            // If we didn't find the image and have retries left, wait and try again
            retryCount += 1
            if retryCount < maxRetries {
                let delay = pow(2.0, Double(retryCount - 1)) // 1s, 2s, 4s, 8s delays
                print("⏳ fetchAndAddImageById: Retrying in \(delay) seconds... (attempt \(retryCount + 1)/\(maxRetries))")
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        
        print("❌ fetchAndAddImageById: Failed to fetch image after \(maxRetries) attempts")
    }
    
    /// Fetches a single image by URL and adds it to the list
    /// - Parameter imageUrl: The URL of the image to fetch
    func fetchAndAddImage(imageUrl: String) async {
        guard let userId = userId else {
            print("⚠️ fetchAndAddImage: userId is nil")
            return
        }
        
        // Check if image already exists to avoid duplicates
        let alreadyExists = await MainActor.run {
            return userImages.contains(where: { $0.image_url == imageUrl })
        }
        
        if alreadyExists {
            print("✅ fetchAndAddImage: Image with URL \(imageUrl) already exists in list, skipping")
            return
        }
        
        print("🔍 fetchAndAddImage: Fetching image with URL: \(imageUrl) for userId: \(userId)")
        
        // Retry logic: database might not be immediately available after insert
        // Increased retries for concurrent saves
        var retryCount = 0
        let maxRetries = 5
        
        while retryCount < maxRetries {
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
                
                let images = response.value ?? []
                print("🔍 fetchAndAddImage: Found \(images.count) image(s) with URL: \(imageUrl)")
                
                if let newImage = images.first {
                    print("✅ fetchAndAddImage: Adding image to list (id: \(newImage.id))")
                    // Check if already exists before adding
                    let alreadyExists = await MainActor.run {
                        return userImages.contains(where: { $0.id == newImage.id })
                    }
                    
                    if !alreadyExists {
                        await addImage(newImage)
                        await MainActor.run {
                            print("✅ fetchAndAddImage: Image added successfully. Total images: \(userImages.count)")
                        }
                    } else {
                        print("⚠️ fetchAndAddImage: Image already exists in list, skipping")
                    }
                    return // Success, exit retry loop
                } else {
                    print("⚠️ fetchAndAddImage: No image found with URL: \(imageUrl) (attempt \(retryCount + 1)/\(maxRetries))")
                }
            } catch {
                print("❌ fetchAndAddImage: Error on attempt \(retryCount + 1)/\(maxRetries): \(error)")
            }
            
            // If we didn't find the image and have retries left, wait and try again
            retryCount += 1
            if retryCount < maxRetries {
                let delay = pow(2.0, Double(retryCount - 1)) // 1s, 2s, 4s, 8s delays
                print("⏳ fetchAndAddImage: Retrying in \(delay) seconds... (attempt \(retryCount + 1)/\(maxRetries))")
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        
        print("❌ fetchAndAddImage: Failed to fetch image after \(maxRetries) attempts")
    }
    
    /// Fetches the most recent image and adds it to the list
    func fetchLatestImage() async {
        guard let userId = userId else {
            print("⚠️ fetchLatestImage: userId is nil")
            return
        }
        
        print("🔍 fetchLatestImage: Fetching most recent image for userId: \(userId)")
        
        do {
            // Fetch the most recent image for this user
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            
            let images = response.value ?? []
            print("🔍 fetchLatestImage: Found \(images.count) image(s)")
            
            if let latestImage = images.first {
                print("✅ fetchLatestImage: Found latest image (id: \(latestImage.id), url: \(latestImage.image_url))")
                // Only add if it's not already in the list
                let alreadyExists = await MainActor.run {
                    return userImages.contains(where: { $0.id == latestImage.id })
                }
                
                if !alreadyExists {
                    await addImage(latestImage)
                    await MainActor.run {
                        print("✅ fetchLatestImage: Image added successfully. Total images: \(userImages.count)")
                    }
                } else {
                    print("⚠️ fetchLatestImage: Image already exists in list, skipping")
                }
            } else {
                print("⚠️ fetchLatestImage: No images found")
            }
        } catch {
            print("❌ Failed to fetch latest image: \(error)")
        }
    }
}
