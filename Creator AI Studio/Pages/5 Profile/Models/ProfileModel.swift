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

// ============================================================================
// DATABASE QUERY OPTIMIZATIONS (Cost & Egress Reduction)
// ============================================================================
// This ViewModel implements several optimizations to minimize database egress costs:
//
// 1. PAGINATION: All queries fetch 50 items at a time (pageSize = 50)
//    - Reduces initial load from potentially 1000s of records to just 50
//    - Users load more as they scroll
//
// 2. PERSISTENT CACHING: 30-minute cache using @AppStorage
//    - Avoids re-fetching on every app launch
//    - Only refreshes if cache is stale (>30 min)
//
// 3. STATS TABLE: Pre-computed counts in user_stats table
//    - Favorites count, image count, video count, model counts
//    - Single row query instead of scanning thousands of records
//    - Updates incrementally when items are added/deleted
//
// 4. OPTIMIZED refreshLatest():
//    - First checks for new items using lightweight query (id + created_at only)
//    - Only fetches full records if new items are found
//    - Saves ~96% egress when no new items exist (2KB vs 50KB per check)
//
// 5. MODEL-SPECIFIC CACHING: 10-minute cache for model queries
//    - Avoids re-querying when switching between models
//    - Falls back to main cache if available
//
// 6. SMART CACHE USAGE: Checks main cache before querying database
//    - Uses cached data when available and fresh
//    - Reduces unnecessary database queries
//
// ESTIMATED SAVINGS:
// - Initial load: ~96% reduction (50 items vs 1000s)
// - Refresh checks: ~96% reduction (2KB vs 50KB when no new items)
// - Stats queries: ~99% reduction (1 row vs scanning all records)
// - Overall egress: ~80-90% reduction compared to naive implementation

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
    let status: String? // "success" or "failed"
    let error_message: String? // Error message for failed generations
    let duration: Double? // Video duration in seconds (for videos only)
    let resolution: String? // Video resolution (e.g., "720p", "1080p") (for videos only)

    // Computed property for convenience
    var isVideo: Bool {
        media_type == "video"
    }

    var isImage: Bool {
        media_type == "image" || media_type == nil
    }
    
    var isFailed: Bool {
        status == "failed"
    }
    
    var isSuccess: Bool {
        status == "success" || status == nil // Default to success for backward compatibility
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
        case status
        case error_message
        case duration
        case resolution
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
        status = try? container.decode(String.self, forKey: .status)
        error_message = try? container.decode(String.self, forKey: .error_message)
        duration = try? container.decode(Double.self, forKey: .duration)
        resolution = try? container.decode(String.self, forKey: .resolution)
    }
}

// MARK: - UserStats

struct UserStats: Codable {
    let id: String?
    let user_id: String
    var favorite_count: Int
    var image_count: Int
    var video_count: Int
    var model_counts: [String: Int]  // JSONB in DB, decoded as dictionary
    var video_model_counts: [String: Int]  // JSONB in DB, decoded as dictionary
    let created_at: String?
    let updated_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case favorite_count
        case image_count
        case video_count
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
        // Handle image_count and video_count - default to 0 if not present (for backward compatibility)
        image_count = (try? container.decode(Int.self, forKey: .image_count)) ?? 0
        video_count = (try? container.decode(Int.self, forKey: .video_count)) ?? 0
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
        try container.encode(image_count, forKey: .image_count)
        try container.encode(video_count, forKey: .video_count)
        try container.encode(model_counts, forKey: .model_counts)
        try container.encode(video_model_counts, forKey: .video_model_counts)
    }
    
    // Regular initializer for creating new stats
    init(id: String? = nil, user_id: String, favorite_count: Int, image_count: Int = 0, video_count: Int = 0, model_counts: [String: Int], video_model_counts: [String: Int], created_at: String? = nil, updated_at: String? = nil) {
        self.id = id
        self.user_id = user_id
        self.favorite_count = favorite_count
        self.image_count = image_count
        self.video_count = video_count
        self.model_counts = model_counts
        self.video_model_counts = video_model_counts
        self.created_at = created_at
        self.updated_at = updated_at
    }
}

// MARK: - MediaStats (lightweight struct for stats computation)

/// Lightweight struct for computing stats - only includes fields needed for counting
private struct MediaStats: Codable {
    let model: String?
    let media_type: String?
    let is_favorite: Bool?
    let status: String? // "success", "failed", or nil
    
    var isImage: Bool {
        media_type == "image" || media_type == nil
    }
    
    var isVideo: Bool {
        media_type == "video"
    }
    
    /// Returns true if the media item is successful (not failed)
    /// Only count successful items in stats
    var isSuccess: Bool {
        status == "success" || status == nil // nil means success (backward compatibility)
    }
}

// MARK: - Lightweight structs for optimized queries

/// Lightweight struct for checking new items - only id and timestamp
private struct MediaCheck: Codable {
    let id: String
    let created_at: String?
}

/// Lightweight struct for list views - only fields needed for thumbnails
private struct UserImageListItem: Codable {
    let id: String
    let image_url: String
    let thumbnail_url: String?
    let model: String?
    let media_type: String?
    let is_favorite: Bool?
    let created_at: String?
    
    // Convert to full UserImage when needed (lazy loading)
    func toUserImage() -> UserImage? {
        // This will be used when we need full details
        // For now, we'll fetch full details separately when needed
        return nil
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
    @Published var imageCount: Int = 0
    @Published var videoCount: Int = 0
    @Published var cachedFavoriteImages: [UserImage] = []
    @Published var isLoadingFavorites = false
    @Published var isLoadingMoreFavorites = false
    @Published var hasMoreFavoritePages = true
    /// Images-only tab: items from DB filtered by media_type = "image" (paginated)
    @Published var tabImagesOnly: [UserImage] = []
    @Published var isLoadingImagesOnly = false
    @Published var hasMoreImagesOnlyPages = false
    @Published var isLoadingMoreImagesOnly = false
    /// Videos-only tab: items from DB filtered by media_type = "video" (paginated)
    @Published var tabVideosOnly: [UserImage] = []
    @Published var isLoadingVideosOnly = false
    @Published var hasMoreVideosOnlyPages = false
    @Published var isLoadingMoreVideosOnly = false
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
    
    // Request deduplication: track in-flight requests to prevent duplicate queries
    private var inFlightModelRequests: [String: Task<[UserImage], Never>] = [:]

    // Track in-flight image additions to prevent duplicates from race conditions
    // (notification handler + Realtime INSERT can both try to add the same image)
    private var inFlightImageIds: Set<String> = []
    
    // Pagination state for model-specific images (per model)
    private var modelCurrentPages: [String: Int] = [:] // model name -> current page
    private var modelHasMorePages: [String: Bool] = [:] // model name -> has more pages
    
    // Pagination for Images-only and Videos-only tabs
    private var imagesOnlyCurrentPage = 0
    private var videosOnlyCurrentPage = 0
    
    // Pagination for favorites
    private var favoritesCurrentPage = 0
    private var hasFetchedFavorites = false
        

    // Notification observers for new media saves
    private var imageSavedObserver: NSObjectProtocol?
    private var videoSavedObserver: NSObjectProtocol?
    
    // Realtime subscription for user_media DELETE events
    private var realtimeChannel: RealtimeChannelV2?

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
    
    // ✅ Cache user stats persistently between launches, keyed per user
    @AppStorage("cachedUserStats") private var cachedUserStatsData: Data = .init()
    @AppStorage("lastUserId") private var lastUserId: String = ""
    private var cachedUserStatsMap: [String: UserStats] = [:]

    // Convenience computed property for backward compatibility (just URLs)
    var images: [String] {
        userImages.map { $0.image_url }
    }

    init() {
        decodeCacheStore()
        decodeStatsCache() // Load stats cache immediately
        setupImageSavedNotification()
        setupVideoSavedNotification()
    }
    
    /// Decodes the stats cache (but doesn't load stats - wait for user to be set)
    /// This prevents loading stats for the wrong user if user switches accounts
    private func decodeStatsCache() {
        // Decode cached stats but DON'T load them yet
        // Wait until we know the current user to avoid loading wrong user's stats
        if let data = try? JSONDecoder().decode([String: UserStats].self, from: cachedUserStatsData),
           !data.isEmpty {
            cachedUserStatsMap = data
            print("✅ Decoded stats cache with \(data.count) user(s)")
        }
    }
    
    deinit {
        // Remove notification observers when view model is deallocated
        if let observer = imageSavedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = videoSavedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Stop Realtime subscription
        Task {
            await stopRealtimeSubscription()
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
                    if let userId = self.userId, userId.lowercased() == savedUserId.lowercased() {
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
        
        guard savedUserId.lowercased() == currentUserId.lowercased() else {
            print("⚠️ Notification is for different user (saved: \(savedUserId), current: \(currentUserId))")
            return
        }
        
        // IMPORTANT: NotificationCenter broadcasts to ALL devices/app instances
        // To prevent duplicates, we check if the image is already being added or exists
        // before processing the notification. This allows immediate feedback on the
        // device that generated it while preventing duplicates on other devices.
        
        Task {
            // Check immediately if image is already being added or exists
            // This prevents duplicates with Realtime INSERT handler
            if let imageId = imageId {
                let alreadyExistsOrInFlight = await MainActor.run {
                    if inFlightImageIds.contains(imageId) { return true }
                    if let existing = userImages.first(where: { $0.id == imageId }) {
                        return hasValidMediaUrl(existing)
                    }
                    return false
                }
                if alreadyExistsOrInFlight {
                    print("⏳ [handleImageSavedNotification] Image \(imageId) already being added or exists with valid URLs, skipping notification handler")
                    return
                }
            }
            
            // Small delay to ensure database transaction is committed
            // But keep it short for immediate appearance (250ms instead of 1000ms)
            try? await Task.sleep(for: .milliseconds(250))
            
            // Double-check after delay (Realtime handler might have added it by now)
            if let imageId = imageId {
                let alreadyExists = await MainActor.run {
                    if inFlightImageIds.contains(imageId) { return true }
                    if let existing = userImages.first(where: { $0.id == imageId }) {
                        return hasValidMediaUrl(existing)
                    }
                    return false
                }
                if alreadyExists {
                    print("✅ [handleImageSavedNotification] Image \(imageId) already added by Realtime handler, skipping")
                    return
                }
            }
            
            // Priority 1: Fetch by ID if available (most reliable)
            if let imageId = imageId {
                await fetchAndAddImageById(imageId: imageId)
                let imageWasAdded = await MainActor.run {
                    let count = userImages.count
                    let exists = userImages.contains(where: { $0.id == imageId })
                    print("🔍 [handleImageSavedNotification] After fetchAndAddImageById - count: \(count), exists: \(exists), imageId: \(imageId)")
                    return exists
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
        // CRITICAL: Clear userImages array immediately to prevent showing previous user's data
        userImages = []
        
        // Reset pagination state for the new user
        currentPage = 0
        hasMorePages = true
        hasFetchedFromDatabase = false
        
        // Reset favorites pagination
        favoritesCurrentPage = 0
        cachedFavoriteImages = []
        hasFetchedFavorites = false
        
    hasMoreFavoritePages = true
        
        // Clear model-specific caches when user changes
        modelImagesCache.removeAll()
        modelCurrentPages.removeAll()
        modelHasMorePages.removeAll()
        
        // Clear Images-only and Videos-only tab caches when user changes
        tabImagesOnly = []
        tabVideosOnly = []
        imagesOnlyCurrentPage = 0
        videosOnlyCurrentPage = 0
        hasMoreImagesOnlyPages = false
        hasMoreVideosOnlyPages = false
        
        // ALWAYS reset stats when user changes to prevent showing previous user's counts
        favoriteCount = 0
        imageCount = 0
        videoCount = 0
        modelCounts = [:]
        videoModelCounts = [:]
        hasLoadedStats = false

        // Load cached images for this user if available (for faster initial display)
        loadCachedImages(for: userId)
        
        // DON'T load cached stats here - wait for fresh stats from database via fetchUserStats()
        // This prevents showing wrong stats from cache when switching users
        // ProfileMainView will call fetchUserStats() which will fetch fresh stats from database
        
        // Start Realtime subscription for instant deletion sync
        Task {
            await startRealtimeSubscription(userId: userId)
        }
    }
    
    // MARK: - Realtime Subscription for Deletions
    
    /// Starts listening for INSERT + DELETE events on user_media table
    /// This ensures new media + deletions sync instantly across all devices without database queries
    private func startRealtimeSubscription(userId: String) async {
        // Stop any existing subscription first
        await stopRealtimeSubscription()
        
        let channel = client.realtimeV2.channel("user-media-\(userId)")
        
        // Listen for INSERT events
        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "user_media",
            filter: "user_id=eq.\(userId)"
        )
        
        // Listen for DELETE events
        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "user_media",
            filter: "user_id=eq.\(userId)"
        )
        
        // Handle inserts
        Task {
            for await insert in inserts {
                await handleMediaInsert(insert)
            }
        }
        
        // Handle deletions
        Task {
            for await deletion in deletions {
                await handleMediaDeletion(deletion)
            }
        }
        
        // Subscribe to the channel
        await channel.subscribe()
        realtimeChannel = channel
        
        print("✅ [ProfileViewModel] Realtime subscription active for user_media inserts/deletions")
    }
    
    /// Stops the Realtime subscription
    private func stopRealtimeSubscription() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
            print("🛑 [ProfileViewModel] Realtime subscription stopped")
        }
    }

    /// Ensures Realtime subscription is active for cross-device sync
    /// Call this when the Profile view appears to ensure INSERT/DELETE events are received
    func ensureRealtimeSubscription() async {
        guard let userId = userId else { return }

        // If no subscription exists, start one
        if realtimeChannel == nil {
            print("🔄 [ProfileViewModel] Restarting Realtime subscription on view appear")
            await startRealtimeSubscription(userId: userId)
        }
    }

    /// Syncs deletions from other devices by comparing local cache with database
    /// Call this when the view appears to catch deletions that happened while away
    func syncDeletions() async {
        guard let userId = userId else { return }
        guard !userImages.isEmpty else { return }

        do {
            // Lightweight query to get current IDs from database
            let response: PostgrestResponse<[MediaCheck]> = try await client.database
                .from("user_media")
                .select("id,created_at")
                .eq("user_id", value: userId)
                .or("status.is.null,status.eq.success")
                .order("created_at", ascending: false)
                .limit(pageSize)
                .execute()

            let databaseIds = Set((response.value ?? []).map { $0.id })
            let firstPageCachedIds = Set(userImages.prefix(pageSize).map { $0.id })
            let deletedIds = firstPageCachedIds.subtracting(databaseIds)

            if !deletedIds.isEmpty {
                print("🗑️ [syncDeletions] Detected \(deletedIds.count) deleted item(s) - removing from cache")
                await MainActor.run {
                    userImages.removeAll { deletedIds.contains($0.id) }
                    // Re-sort after deletion to maintain chronological order
                    sortUserImagesByDate()
                }
                saveCachedImages(for: userId)
                await fetchUserStats()
            }
        } catch {
            print("❌ [syncDeletions] Error: \(error)")
        }
    }

    /// Handles DELETE events from Realtime
    private func handleMediaDeletion(_ action: DeleteAction) async {
        // Extract the deleted record's ID from oldRecord
        let oldRecord = action.oldRecord
        if let idValue = oldRecord["id"],
           let deletedId = decodeIdString(from: idValue) {
            
            await MainActor.run {
                let removedCount = removeImagesLocally(imageIds: [deletedId])
                if removedCount > 0 {
                    print("🗑️ [ProfileViewModel] Removed deleted image from cache: \(deletedId)")
                    
                    // Update cache
                    if let userId = userId {
                        saveCachedImages(for: userId)
                    }
                    
                    // Refresh stats (database triggers handle the count updates)
                    Task {
                        await fetchUserStats()
                    }
                }
            }
        } else {
            print("⚠️ [ProfileViewModel] DELETE event missing usable id. oldRecord keys: \(oldRecord.keys)")
        }
    }

    /// Decode AnyJSON id as a stable String (handles numeric ids)
    private func decodeIdString(from value: AnyJSON) -> String? {
        // Try to extract as string first
        if case .string(let string) = value {
            return string
        }
        
        // Try to extract as number (integer or double)
        if let intValue = value.intValue {
            return String(intValue)
        }
        if let doubleValue = value.doubleValue {
            if doubleValue.rounded() == doubleValue {
                return String(Int(doubleValue))
            }
            return String(doubleValue)
        }
        
        // Try to extract as boolean
        if let boolValue = value.boolValue {
            return boolValue ? "true" : "false"
        }
        
        // Fallback: try to get string representation
        return String(describing: value)
    }
    
    /// Sorts userImages array by created_at descending (newest first)
    /// Call this after any operation that might affect the order (deletion, insertion, etc.)
    /// IMPORTANT: Must be called on MainActor to ensure SwiftUI detects changes
    private func sortUserImagesByDate() {
        assert(Thread.isMainThread, "sortUserImagesByDate must be called on MainActor")
        userImages.sort { (a, b) -> Bool in
            let aDate = a.created_at ?? ""
            let bDate = b.created_at ?? ""
            return aDate > bDate // Descending order (newest first)
        }
    }
    
    /// Removes images from local caches (main list, favorites, model cache)
    @discardableResult
    private func removeImagesLocally(imageIds: Set<String>) -> Int {
        guard !imageIds.isEmpty else { return 0 }
        
        let originalCount = userImages.count
        userImages.removeAll { imageIds.contains($0.id) }
        cachedFavoriteImages.removeAll { imageIds.contains($0.id) }
        
        if !modelImagesCache.isEmpty {
            for (modelName, cached) in modelImagesCache {
                let filtered = cached.images.filter { !imageIds.contains($0.id) }
                if filtered.count != cached.images.count {
                    modelImagesCache[modelName] = (filtered, cached.fetchedAt)
                }
            }
        }
        
        // Re-sort after deletion to maintain chronological order
        // Note: This function is called from MainActor context (removeImagesLocally is called from MainActor)
        sortUserImagesByDate()
        
        return originalCount - userImages.count
    }

    /// Handles INSERT events from Realtime
    private func handleMediaInsert(_ action: InsertAction) async {
        do {
            let insertedMedia = try action.decodeRecord(as: UserImage.self, decoder: JSONDecoder())

            guard insertedMedia.isSuccess else {
                print("⚠️ [ProfileViewModel] Ignoring failed media insert: \(insertedMedia.id)")
                return
            }

            let hasValidImageUrl = !insertedMedia.image_url.isEmpty && URL(string: insertedMedia.image_url) != nil
            let hasValidThumbnailUrl = insertedMedia.thumbnail_url.map { !$0.isEmpty && URL(string: $0) != nil } ?? false

            guard hasValidImageUrl || hasValidThumbnailUrl else {
                print("⚠️ [ProfileViewModel] Ignoring insert with invalid URLs (id: \(insertedMedia.id))")
                return
            }

            // Check if already exists or is being added (prevent duplicates)
            // This prevents race conditions if the handler is called multiple times quickly
            let alreadyExistsOrInFlight = await MainActor.run {
                return inFlightImageIds.contains(insertedMedia.id) || userImages.contains { $0.id == insertedMedia.id }
            }
            guard !alreadyExistsOrInFlight else {
                print("✅ [ProfileViewModel] Insert already present or being added, skipping: \(insertedMedia.id)")
                return
            }

            await addImage(insertedMedia)
            print("✅ [ProfileViewModel] Realtime insert added: \(insertedMedia.id)")
        } catch {
            print("❌ [ProfileViewModel] Error decoding inserted media: \(error)")
        }
    }

    /// Convenience overload for removing images with an array
    @discardableResult
    private func removeImagesLocally(imageIds: [String]) -> Int {
        return removeImagesLocally(imageIds: Set(imageIds))
    }
    
    private func loadCachedStats(for userId: String) {
        // Decode cached stats if available
        if cachedUserStatsMap.isEmpty {
            if let data = try? JSONDecoder().decode([String: UserStats].self, from: cachedUserStatsData),
               !data.isEmpty {
                cachedUserStatsMap = data
            }
        }
        
        // Load stats for this user if available
        if let stats = cachedUserStatsMap[userId] {
            favoriteCount = stats.favorite_count
            imageCount = stats.image_count
            videoCount = stats.video_count
            modelCounts = stats.model_counts
            videoModelCounts = stats.video_model_counts
            hasLoadedStats = true
            print("✅ Loaded cached stats: \(stats.favorite_count) favorites, \(stats.image_count) images, \(stats.video_count) videos")
        }
    }
    
    private func saveCachedStats(for userId: String, stats: UserStats) {
        cachedUserStatsMap[userId] = stats
        lastUserId = userId // Remember the last user for pre-loading in init()
        if let encoded = try? JSONEncoder().encode(cachedUserStatsMap) {
            cachedUserStatsData = encoded
        }
    }

    private func loadCachedImages(for userId: String) {
        print("🟡 DEBUG loadCachedImages: Loading cache for userId: \(userId)")
        
        // Ensure cache is decoded
        if cachedUserImagesMap.isEmpty {
            decodeCacheStore()
        }

        if let entry = cachedUserImagesMap[userId] {
            // Filter out items with invalid/empty URLs to prevent display issues
            let validImages = entry.images.filter { image in
                let hasValidImageUrl = !image.image_url.isEmpty && URL(string: image.image_url) != nil
                let hasValidThumbnailUrl = image.thumbnail_url.map { !$0.isEmpty && URL(string: $0) != nil } ?? false
                return hasValidImageUrl || hasValidThumbnailUrl
            }
            
            // Deduplicate: Remove duplicate entries by ID (keep first occurrence)
            var seenIds = Set<String>()
            var duplicateCount = 0
            let deduplicatedImages = validImages.filter { image in
                if seenIds.contains(image.id) {
                    duplicateCount += 1
                    return false
                }
                seenIds.insert(image.id)
                return true
            }
            
            // If we filtered out invalid items or duplicates, update the cache
            if deduplicatedImages.count != entry.images.count {
                let removedCount = entry.images.count - deduplicatedImages.count
                print("🧹 Removed \(removedCount) invalid/duplicate cached item(s) (duplicates: \(duplicateCount))")
                userImages = deduplicatedImages
                saveCachedImages(for: userId)  // Save the cleaned cache
            } else {
                userImages = deduplicatedImages
            }
            
            // Sort by created_at descending (newest first) to ensure correct order
            // Note: loadCachedImages is called from init/onAppear which is on MainActor
            sortUserImagesByDate()
            
            lastFetchedAt = entry.lastFetchedAt
            // Set the page based on cached count so pagination continues correctly
            currentPage = Int(ceil(Double(userImages.count) / Double(pageSize)))
            hasMorePages = userImages.count >= pageSize

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
    
    /// Clears the local cache for the current user, forcing a full refresh from the database
    /// Call this when there are issues with cached data
    func clearCache() async {
        guard let userId = userId else { return }
        
        // Clear in-memory cache
        userImages = []
        cachedUserImagesMap.removeValue(forKey: userId)
        lastFetchedAt = nil
        hasFetchedFromDatabase = false
        currentPage = 0
        hasMorePages = true
        
        // Clear model-specific caches
        modelImagesCache.removeAll()
        
        // Clear Images-only and Videos-only tab caches
        tabImagesOnly = []
        tabVideosOnly = []
        imagesOnlyCurrentPage = 0
        videosOnlyCurrentPage = 0
        hasMoreImagesOnlyPages = false
        hasMoreVideosOnlyPages = false
        
        // Clear stats cache
        cachedUserStatsMap.removeValue(forKey: userId)
        favoriteCount = 0
        imageCount = 0
        videoCount = 0
        modelCounts = [:]
        videoModelCounts = [:]
        hasLoadedStats = false
        
        // Persist the cleared caches
        if let encoded = try? JSONEncoder().encode(cachedUserImagesMap) {
            cachedUserImagesData = encoded
        }
        if let encoded = try? JSONEncoder().encode(cachedUserStatsMap) {
            cachedUserStatsData = encoded
        }
        
        print("🧹 Cache cleared for user: \(userId) (including stats cache)")
        
        // Recompute stats from user_media table (the authoritative source of truth)
        // NOTE: With database triggers, this uses the database function for efficiency
        await recomputeUserStatsViaDatabase()
        
        // Also refresh images to ensure UI is up to date
        await fetchUserImages(forceRefresh: true)
    }

    private func saveCachedImages(for userId: String) {
        let now = Date()
        lastFetchedAt = lastFetchedAt ?? now
        
        // Deduplicate before saving to cache (keep first occurrence of each ID)
        var seenIds = Set<String>()
        var duplicateCount = 0
        let deduplicatedImages = userImages.filter { image in
            if seenIds.contains(image.id) {
                duplicateCount += 1
                return false
            }
            seenIds.insert(image.id)
            return true
        }
        
        if duplicateCount > 0 {
            print("🧹 Removed \(duplicateCount) duplicate(s) before saving cache")
        }
        
        cachedUserImagesMap[userId] = CachedUserMediaEntry(
            images: deduplicatedImages,
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
                .or("status.is.null,status.eq.success") // Only successful items
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                .execute()

            let newImages = response.value ?? []

            // If we got fewer images than pageSize, we've reached the end
            hasMorePages = newImages.count == pageSize

            // Append new images (or replace if it's the first page)
            await MainActor.run {
                if currentPage == 0 {
                    userImages = newImages
                } else {
                    userImages.append(contentsOf: newImages)
                }
                
                // Ensure array is sorted by created_at descending (newest first)
                sortUserImagesByDate()
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
    
    /// OPTIMIZED: Checks for new items using lightweight query (id + created_at only)
    /// Only fetches full records if new items are found, saving ~96% egress on refresh
    /// Strategy:
    /// 1. Fetch only id + created_at (2 fields vs 14 fields = ~96% reduction)
    /// 2. Compare with cached IDs to find new items
    /// 3. Only fetch full records for new items (typically 0-5 items vs 50)
    /// This reduces refresh query from ~2.5MB to ~100KB when no new items exist

    private func refreshLatest(for userId: String) async {
        guard !isLoading else { 
            print("⚠️ refreshLatest: Already loading, skipping")
            return 
        }

        let latestTimestamp = userImages.compactMap { $0.created_at }.max()
        print("🔄 refreshLatest: Checking for new images (latest cached timestamp: \(latestTimestamp ?? "none"), cached count: \(userImages.count))")

        do {
            // OPTIMIZATION: First, only fetch id and created_at to check for new items (much cheaper!)
            let checkResponse: PostgrestResponse<[MediaCheck]> = try await client.database
                .from("user_media")
                .select("id,created_at")
                .eq("user_id", value: userId)
                .or("status.is.null,status.eq.success") // Only successful items
                .order("created_at", ascending: false)
                .limit(pageSize) // Check first page only
                .execute()

            let checks = checkResponse.value ?? []
            print("🔄 refreshLatest: Checked \(checks.count) items (lightweight query)")

            // DELETION SYNC: Detect items that were deleted on other devices
            // If an item is in our cache but NOT in the database response, it was deleted
            // This only checks the first page, which is sufficient for most deletion scenarios
            let databaseIds = Set(checks.map { $0.id })
            let firstPageCachedIds = Set(userImages.prefix(pageSize).map { $0.id })
            let deletedIds = firstPageCachedIds.subtracting(databaseIds)

            if !deletedIds.isEmpty {
                print("🗑️ refreshLatest: Detected \(deletedIds.count) deleted item(s) - removing from cache")
                await MainActor.run {
                    userImages.removeAll { deletedIds.contains($0.id) }
                    // Re-sort after deletion to maintain chronological order
                    sortUserImagesByDate()
                }
                saveCachedImages(for: userId)
                // Refresh stats since items were deleted
                await fetchUserStats()
            }

            guard !checks.isEmpty else {
                print("⚠️ refreshLatest: No images found in database")
                lastFetchedAt = Date()
                saveCachedImages(for: userId)
                hasFetchedFromDatabase = true
                return
            }

            // Find new items by comparing IDs (use updated existingIds after deletion sync)
            let currentExistingIds = Set(userImages.map { $0.id })
            let newItemIds = checks.filter { check in
                !currentExistingIds.contains(check.id)
            }.map { $0.id }

            print("🔄 refreshLatest: Found \(newItemIds.count) new items (after ID check)")

            guard !newItemIds.isEmpty else {
                print("✅ refreshLatest: No new images found - saved ~\(checks.count * 48) KB by checking first!")
                lastFetchedAt = Date()
                saveCachedImages(for: userId)
                hasFetchedFromDatabase = true
                return
            }

            // Only now fetch full records for the new items (much smaller query!)
            // Fetch items by building OR condition for IDs
            var freshItems: [UserImage] = []
            
            if newItemIds.count == 1 {
                // Single ID - simple query
                let response: PostgrestResponse<[UserImage]> = try await client.database
                    .from("user_media")
                    .select()
                    .eq("user_id", value: userId)
                    .eq("id", value: newItemIds[0])
                    .or("status.is.null,status.eq.success") // Only successful items
                    .execute()
                freshItems = response.value ?? []
            } else {
                // Multiple IDs - use OR condition
                let orCondition = newItemIds.map { "id.eq.\($0)" }.joined(separator: ",")
                let response: PostgrestResponse<[UserImage]> = try await client.database
                    .from("user_media")
                    .select()
                    .eq("user_id", value: userId)
                    .or(orCondition)
                    .or("status.is.null,status.eq.success") // Only successful items
                    .execute()
                freshItems = response.value ?? []
            }
            print("🔄 refreshLatest: Fetched full details for \(freshItems.count) new images")

            // Filter out any failed items or items with invalid URLs before adding
            // This is a safety net in case the database query didn't filter them
            let validItems = freshItems.filter { item in
                let isSuccessful = item.isSuccess
                return isSuccessful && hasValidMediaUrl(item)
            }
            let filteredCount = freshItems.count - validItems.count
            if filteredCount > 0 {
                print("⚠️ Filtered out \(filteredCount) failed/invalid item(s) from refresh")
            }

            // Add new items to the list
            if !validItems.isEmpty {
                print("✅ refreshLatest: Adding \(validItems.count) new image(s) to list")
                // Add items to the array (they will be inserted at correct positions by addImage or we'll sort after)
                // Instead of inserting at 0, add them and then sort the entire array to ensure correct order
                await MainActor.run {
                    userImages.append(contentsOf: validItems)
                    // Re-sort entire array to maintain chronological order (handles any edge cases)
                    sortUserImagesByDate()
                }
                
                // IMPORTANT: Do NOT increment counts here!
                // These items may already be counted in the database stats (if they were filtered out
                // from cache due to invalid URLs or duplicates). Instead, refetch stats from the
                // database to get accurate counts. The database stats are the source of truth.
                print("📊 refreshLatest: Refetching stats from database to get accurate counts")
                await fetchUserStats()
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
                .or("status.is.null,status.eq.success") // Only successful items
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                .execute()
            
            let newImages = response.value ?? []
            
            // If we got fewer images than pageSize, we've reached the end
            hasMorePages = newImages.count == pageSize
            
            // Append new images
            await MainActor.run {
                userImages.append(contentsOf: newImages)
                // Ensure array is sorted by created_at descending (newest first)
                sortUserImagesByDate()
            }
            lastFetchedAt = Date()
            saveCachedImages(for: userId)
            currentPage += 1
//            print("✅ Loaded more images, page \(currentPage), total: \(userImages.count), hasMore: \(hasMorePages)")
            
        } catch {
            print("❌ Failed to load more images: \(error)")
        }
        
        isLoadingMore = false
    }

    // MARK: - Fetch Images by Model (with Pagination)

    /// Fetches the first page of user images filtered by a specific model name
    /// Uses pagination (50 images per page) to reduce database egress
    /// - Parameters:
    ///   - modelName: The model name to filter by (from item.display.modelName)
    ///   - forceRefresh: Whether to force a refresh from database
    /// - Returns: Array of UserImage filtered by model (first page only)
    func fetchModelImages(modelName: String, forceRefresh: Bool = false) async -> [UserImage] {
        guard let userId = userId else { return [] }
        
        // Reset pagination state if forcing refresh
        if forceRefresh {
            modelCurrentPages[modelName] = 0
            modelHasMorePages[modelName] = true
            modelImagesCache.removeValue(forKey: modelName)
        }

        // Check model-specific cache first (if not forcing refresh)
        if !forceRefresh {
            if let cached = modelImagesCache[modelName] {
                let cacheAge = Date().timeIntervalSince(cached.fetchedAt)
                if cacheAge < modelCacheStaleInterval {
                    print("✅ Using cached model images for \(modelName): \(cached.images.count) images")
                    // Restore pagination state from cache
                    let cachedCount = cached.images.count
                    modelCurrentPages[modelName] = cachedCount >= pageSize ? 1 : 0
                    modelHasMorePages[modelName] = cachedCount >= pageSize
                    return cached.images
                } else {
                    print("⏰ Model cache stale for \(modelName), refreshing...")
                }
            }
        }

        // ⚠️ REMOVED: Previous logic tried to use main userImages cache but it was buggy.
        // The main cache only contains the first 50 images across ALL models, not model-specific.
        // This caused incorrect `hasMoreModelPages` determination when a model had fewer images
        // in the first 50 overall but more in the database (e.g., 17 in cache but 77 in DB).
        // Now we always query the database for model-specific images to get accurate pagination.

        // ✅ REQUEST DEDUPLICATION: Check if there's already an in-flight request for this model
        if let existingTask = inFlightModelRequests[modelName] {
            print("🔄 Reusing in-flight request for \(modelName)")
            return await existingTask.value
        }
        
        // Create a new task for this request
        let requestTask = Task<[UserImage], Never> {
            defer {
                inFlightModelRequests.removeValue(forKey: modelName)
            }
            
            // Query database - fetch first page only (50 images)
            print("📡 Querying database for model images (first page): \(modelName)")
            do {
                let response: PostgrestResponse<[UserImage]> = try await client.database
                    .from("user_media")
                    .select()
                    .eq("user_id", value: userId)
                    .eq("model", value: modelName)
                    .order("created_at", ascending: false)
                    .limit(pageSize)
                    .range(from: 0, to: pageSize - 1)
                    .execute()

                let images = response.value ?? []
                
                // Update pagination state
                modelCurrentPages[modelName] = 1
                modelHasMorePages[modelName] = images.count == pageSize
                
                // Cache the results
                modelImagesCache[modelName] = (images, Date())
                print("✅ Fetched and cached \(images.count) images for model \(modelName) (hasMore: \(modelHasMorePages[modelName] ?? false))")
                
                return images
            } catch {
                print("❌ Failed to fetch model images for \(modelName): \(error)")
                modelHasMorePages[modelName] = false
                return []
            }
        }
        
        // Store the task for deduplication
        inFlightModelRequests[modelName] = requestTask
        
        // Wait for and return the result
        return await requestTask.value
    }
    
    /// Loads the next page of images for a specific model
    func loadMoreModelImages(modelName: String) async -> [UserImage] {
        guard let userId = userId else { return [] }
        guard modelHasMorePages[modelName] == true else { return [] }
        
        let currentPage = modelCurrentPages[modelName] ?? 0
        
        print("📡 Loading more model images for \(modelName), page \(currentPage + 1)")
        
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("model", value: modelName)
                .or("status.is.null,status.eq.success") // Only successful items
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                .execute()
            
            let newImages = response.value ?? []
            
            // Update pagination state
            modelHasMorePages[modelName] = newImages.count == pageSize
            modelCurrentPages[modelName] = currentPage + 1
            
            // Update cache with new images appended
            if let cached = modelImagesCache[modelName] {
                var updatedImages = cached.images
                updatedImages.append(contentsOf: newImages)
                modelImagesCache[modelName] = (updatedImages, cached.fetchedAt)
            }
            
            print("✅ Loaded \(newImages.count) more images for \(modelName) (hasMore: \(modelHasMorePages[modelName] ?? false))")
            
            return newImages
        } catch {
            print("❌ Failed to load more model images for \(modelName): \(error)")
            modelHasMorePages[modelName] = false
            return []
        }
    }
    
    /// Checks if there are more pages available for a model
    func hasMoreModelPages(modelName: String) -> Bool {
        return modelHasMorePages[modelName] ?? false
    }
    
    // MARK: - Fetch Images-Only / Videos-Only (for Images and Videos pills)
    
    /// Fetches the first page of user media filtered by media_type = "image".
    /// Used when the user taps the Images pill so the gallery shows all images (not just those in the first 50 mixed rows).
    func fetchImagesOnly(forceRefresh: Bool = false) async {
        guard let userId = userId else { return }
        await MainActor.run { isLoadingImagesOnly = true }
        if forceRefresh {
            imagesOnlyCurrentPage = 0
            hasMoreImagesOnlyPages = true
        }
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("media_type", value: "image")
                .or("status.is.null,status.eq.success")
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: 0, to: pageSize - 1)
                .execute()
            let items = response.value ?? []
            await MainActor.run {
                tabImagesOnly = items
                imagesOnlyCurrentPage = 1
                hasMoreImagesOnlyPages = items.count == pageSize
                isLoadingImagesOnly = false
            }
        } catch {
            print("❌ Failed to fetch images-only: \(error)")
            await MainActor.run {
                tabImagesOnly = []
                hasMoreImagesOnlyPages = false
                isLoadingImagesOnly = false
            }
        }
    }
    
    /// Fetches the first page of user media filtered by media_type = "video".
    /// Used when the user taps the Videos pill so the gallery shows all videos (not just those in the first 50 mixed rows).
    func fetchVideosOnly(forceRefresh: Bool = false) async {
        guard let userId = userId else { return }
        await MainActor.run { isLoadingVideosOnly = true }
        if forceRefresh {
            videosOnlyCurrentPage = 0
            hasMoreVideosOnlyPages = true
        }
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("media_type", value: "video")
                .or("status.is.null,status.eq.success")
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: 0, to: pageSize - 1)
                .execute()
            let items = response.value ?? []
            await MainActor.run {
                tabVideosOnly = items
                videosOnlyCurrentPage = 1
                hasMoreVideosOnlyPages = items.count == pageSize
                isLoadingVideosOnly = false
            }
        } catch {
            print("❌ Failed to fetch videos-only: \(error)")
            await MainActor.run {
                tabVideosOnly = []
                hasMoreVideosOnlyPages = false
                isLoadingVideosOnly = false
            }
        }
    }
    
    /// Loads the next page of images-only (Images pill).
    func loadMoreImagesOnly() async {
        guard hasMoreImagesOnlyPages, !isLoadingMoreImagesOnly else { return }
        guard let userId = userId else { return }
        isLoadingMoreImagesOnly = true
        defer { isLoadingMoreImagesOnly = false }
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("media_type", value: "image")
                .or("status.is.null,status.eq.success")
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: imagesOnlyCurrentPage * pageSize, to: (imagesOnlyCurrentPage + 1) * pageSize - 1)
                .execute()
            let newItems = response.value ?? []
            await MainActor.run {
                tabImagesOnly.append(contentsOf: newItems)
                imagesOnlyCurrentPage += 1
                hasMoreImagesOnlyPages = newItems.count == pageSize
            }
        } catch {
            print("❌ Failed to load more images-only: \(error)")
            await MainActor.run { hasMoreImagesOnlyPages = false }
        }
    }
    
    /// Loads the next page of videos-only (Videos pill).
    func loadMoreVideosOnly() async {
        guard hasMoreVideosOnlyPages, !isLoadingMoreVideosOnly else { return }
        guard let userId = userId else { return }
        isLoadingMoreVideosOnly = true
        defer { isLoadingMoreVideosOnly = false }
        do {
            let response: PostgrestResponse<[UserImage]> = try await client.database
                .from("user_media")
                .select()
                .eq("user_id", value: userId)
                .eq("media_type", value: "video")
                .or("status.is.null,status.eq.success")
                .order("created_at", ascending: false)
                .limit(pageSize)
                .range(from: videosOnlyCurrentPage * pageSize, to: (videosOnlyCurrentPage + 1) * pageSize - 1)
                .execute()
            let newItems = response.value ?? []
            await MainActor.run {
                tabVideosOnly.append(contentsOf: newItems)
                videosOnlyCurrentPage += 1
                hasMoreVideosOnlyPages = newItems.count == pageSize
            }
        } catch {
            print("❌ Failed to load more videos-only: \(error)")
            await MainActor.run { hasMoreVideosOnlyPages = false }
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
                // Check if image_count/video_count are 0 (likely from migration - need to recompute)
                // Always resync if both image_count AND video_count are 0 (simplified condition)
                if stats.image_count == 0 && stats.video_count == 0 {
                    print("⚠️ Stats found but image_count=0 and video_count=0 - triggering resync...")
                    print("📊 DB values: favorites=\(stats.favorite_count), models=\(stats.model_counts.count)")
                    await initializeUserStats()
                    return
                }
                
                // Check if stats are significantly out of sync with loaded images
                // NOTE: With database triggers, this should rarely happen, but we keep it as a safety net
                // This can happen if triggers weren't set up yet, or after migrations before triggers run
                let actualImageCount = userImages.filter { $0.isImage && $0.isSuccess }.count
                let actualVideoCount = userImages.filter { $0.isVideo && $0.isSuccess }.count
                
                // If we have loaded images and the discrepancy is large (>50% difference or >10 items), resync
                let imageDiscrepancy = abs(actualImageCount - stats.image_count)
                let videoDiscrepancy = abs(actualVideoCount - stats.video_count)
                let hasLargeDiscrepancy = (imageDiscrepancy > 10 && actualImageCount > stats.image_count * 2) ||
                                         (videoDiscrepancy > 10 && actualVideoCount > stats.video_count * 2)
                
                if hasLargeDiscrepancy && (actualImageCount > 0 || actualVideoCount > 0) {
                    print("⚠️ Stats out of sync detected! (This should be rare with database triggers)")
                    print("📊 DB stats: images=\(stats.image_count), videos=\(stats.video_count)")
                    print("📊 Actual loaded: images=\(actualImageCount), videos=\(actualVideoCount)")
                    print("📊 Discrepancy: images=\(imageDiscrepancy), videos=\(videoDiscrepancy)")
                    print("🔄 Triggering stats resync via database function...")
                    // Use database function to recompute stats (more efficient than Swift-side computation)
                    await recomputeUserStatsViaDatabase()
                    return
                }
                
                // Update published properties from stats
                print("📊 Current counts before update: favorites=\(favoriteCount), images=\(imageCount), videos=\(videoCount)")
                print("📊 Fetched stats from DB: favorites=\(stats.favorite_count), images=\(stats.image_count), videos=\(stats.video_count)")
                
                // Update counts from database (source of truth)
                favoriteCount = stats.favorite_count
                imageCount = stats.image_count
                videoCount = stats.video_count
                modelCounts = stats.model_counts
                videoModelCounts = stats.video_model_counts
                hasLoadedStats = true
                
                // Cache stats for immediate availability on next load
                saveCachedStats(for: userId, stats: stats)
                
                print("✅ Fetched user stats: \(stats.favorite_count) favorites, \(stats.image_count) images, \(stats.video_count) videos, \(stats.model_counts.count) image models, \(stats.video_model_counts.count) video models")
                print("✅ Model counts: \(stats.model_counts)")
                print("📊 Counts after update: favorites=\(favoriteCount), images=\(imageCount), videos=\(videoCount)")
            } else {
                // Stats don't exist yet, initialize them
                print("⚠️ User stats not found, initializing...")
                // Use database function for more efficient initialization
                await recomputeUserStatsViaDatabase()
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
    /// NOTE: With database triggers, this should rarely be needed, but useful for manual resyncs
    func resyncUserStats() async {
        print("🔄 Re-syncing user stats from database...")
        await recomputeUserStatsViaDatabase()
    }
    
    /// Diagnostic function to compare actual video model counts vs stored counts
    /// This helps identify model name mismatches or counting errors
    func diagnoseVideoModelCounts() async {
        guard let userId = userId else {
            print("❌ Cannot diagnose: userId is nil")
            return
        }
        
        print("🔍 DIAGNOSING VIDEO MODEL COUNTS...")
        print(String(repeating: "=", count: 60))
        
        do {
            // Fetch all videos from database
            let response: PostgrestResponse<[MediaStats]> = try await client.database
                .from("user_media")
                .select("model,media_type,status")
                .eq("user_id", value: userId)
                .eq("media_type", value: "video")
                .limit(10000)
                .execute()
            
            let allVideos = response.value ?? []
            print("📊 Total videos in database: \(allVideos.count)")
            
            // Count by actual model names in database (EXCLUDE failed videos)
            var actualCounts: [String: Int] = [:]
            var failedVideoCount = 0
            
            for video in allVideos {
                // Only count successful videos
                guard video.isSuccess else {
                    failedVideoCount += 1
                    continue
                }
                
                let modelName = video.model ?? "(null)"
                actualCounts[modelName, default: 0] += 1
            }
            
            if failedVideoCount > 0 {
                print("⚠️ Excluded \(failedVideoCount) failed video(s) from counts")
            }
            
            print("\n📊 ACTUAL COUNTS FROM DATABASE (user_media, successful only):")
            print(String(repeating: "-", count: 60))
            for (model, count) in actualCounts.sorted(by: { $0.key < $1.key }) {
                print("  \(model): \(count)")
            }
            
            print("\n📊 STORED COUNTS IN user_stats:")
            print(String(repeating: "-", count: 60))
            for (model, count) in videoModelCounts.sorted(by: { $0.key < $1.key }) {
                print("  \(model): \(count)")
            }
            
            print("\n🔍 COMPARISON:")
            print(String(repeating: "-", count: 60))
            
            // Find mismatches
            var totalActual = 0
            var totalStored = 0
            
            let allModelNames = Set(actualCounts.keys).union(Set(videoModelCounts.keys))
            
            for modelName in allModelNames.sorted() {
                let actual = actualCounts[modelName] ?? 0
                let stored = videoModelCounts[modelName] ?? 0
                totalActual += actual
                totalStored += stored
                
                if actual != stored {
                    print("  ⚠️ MISMATCH: \(modelName)")
                    print("     Actual: \(actual), Stored: \(stored), Difference: \(actual - stored)")
                } else {
                    print("  ✅ Match: \(modelName) = \(actual)")
                }
            }
            
            print("\n📊 TOTALS:")
            print(String(repeating: "-", count: 60))
            print("  Actual successful videos (from user_media, excluding failed): \(totalActual)")
            print("  Failed videos excluded: \(failedVideoCount)")
            print("  Stored video_count: \(videoCount)")
            print("  Sum of stored model counts: \(totalStored)")
            
            // Check for videos with null model
            let nullModelCount = actualCounts["(null)"] ?? 0
            if nullModelCount > 0 {
                print("\n⚠️ WARNING: Found \(nullModelCount) video(s) with null model name")
                print("   These videos are counted in the total but not assigned to any model")
            }
            
            // Compare with loaded videos in userImages array
            print("\n📊 LOADED VIDEOS IN APP (userImages array):")
            print(String(repeating: "-", count: 60))
            // If we have cached videos, use them (they contain paginated videos)
            // Otherwise, fall back to filtering from userImages (limited to first 50)
            let loadedVideos = userImages.filter { $0.isVideo }
            print("  Total loaded videos: \(loadedVideos.count)")
            
            var loadedCounts: [String: Int] = [:]
            for video in loadedVideos {
                let modelName = video.model ?? "(null)"
                loadedCounts[modelName, default: 0] += 1
            }
            
            print("  Loaded videos by model:")
            for (model, count) in loadedCounts.sorted(by: { $0.key < $1.key }) {
                let dbCount = actualCounts[model] ?? 0
                if count != dbCount {
                    print("    ⚠️ \(model): Loaded=\(count), DB=\(dbCount)")
                } else {
                    print("    ✅ \(model): \(count)")
                }
            }
            
            // Check for model name mismatches
            print("\n🔍 MODEL NAME ANALYSIS:")
            print(String(repeating: "-", count: 60))
            print("  Checking for potential model name mismatches...")
            
            // Get all unique model names from both sources
            let dbModelNames = Set(actualCounts.keys.filter { $0 != "(null)" })
            let loadedModelNames = Set(loadedCounts.keys.filter { $0 != "(null)" })
            
            let onlyInDB = dbModelNames.subtracting(loadedModelNames)
            let onlyInLoaded = loadedModelNames.subtracting(dbModelNames)
            
            if !onlyInDB.isEmpty {
                print("  ⚠️ Model names only in database (not in loaded videos):")
                for model in onlyInDB.sorted() {
                    print("     - \(model) (count: \(actualCounts[model] ?? 0))")
                }
            }
            
            if !onlyInLoaded.isEmpty {
                print("  ⚠️ Model names only in loaded videos (not in database):")
                for model in onlyInLoaded.sorted() {
                    print("     - \(model) (count: \(loadedCounts[model] ?? 0))")
                }
            }
            
            if onlyInDB.isEmpty && onlyInLoaded.isEmpty {
                print("  ✅ All model names match between database and loaded videos")
            }
            
            print(String(repeating: "=", count: 60))
            
        } catch {
            print("❌ Failed to diagnose video model counts: \(error)")
        }
    }
    
    /// Fallback method to compute stats directly from user_media when user_stats table doesn't exist
    private func computeStatsFromDatabase() async {
        guard let userId = userId else { return }
        
        do {
            // Fetch only the fields we need for stats computation (lightweight query)
            let response: PostgrestResponse<[MediaStats]> = try await client.database
                .from("user_media")
                .select("model,media_type,is_favorite,status")
                .eq("user_id", value: userId)
                .limit(10000) // High limit to get all
                .execute()
            
            let allMedia = response.value ?? []
            
            // Compute counts (EXCLUDE failed items - only count successful ones)
            var computedFavoriteCount = 0
            var computedImageCount = 0
            var computedVideoCount = 0
            var computedModelCounts: [String: Int] = [:]
            var computedVideoModelCounts: [String: Int] = [:]
            var failedCount = 0 // Track failed items for logging
            
            print("📊 Computing stats from \(allMedia.count) media items...")
            for media in allMedia {
                // Skip failed items - only count successful ones
                guard media.isSuccess else {
                    failedCount += 1
                    continue
                }
                
                // Count favorites (handle both true and nil as false)
                if media.is_favorite == true {
                    computedFavoriteCount += 1
                }
                
                // Count images and videos
                if media.isImage {
                    computedImageCount += 1
                } else if media.isVideo {
                    computedVideoCount += 1
                }
                
                // Count by model (exclude null/empty model names from model-specific counts)
                // These are still counted in total counts, but not assigned to a model
                if let model = media.model, !model.isEmpty, model != "(null)" {
                    if media.isImage {
                        computedModelCounts[model, default: 0] += 1
                    } else if media.isVideo {
                        computedVideoModelCounts[model, default: 0] += 1
                    }
                }
            }
            
            if failedCount > 0 {
                print("⚠️ Excluded \(failedCount) failed item(s) from counts")
            }
            
            // Update published properties on main thread
            print("📊 Before update - favorites=\(self.favoriteCount), images=\(self.imageCount), videos=\(self.videoCount)")
            print("📊 Computed - favorites=\(computedFavoriteCount), images=\(computedImageCount), videos=\(computedVideoCount)")
            await MainActor.run {
                self.favoriteCount = computedFavoriteCount
                self.imageCount = computedImageCount
                self.videoCount = computedVideoCount
                self.modelCounts = computedModelCounts
                self.videoModelCounts = computedVideoModelCounts
                self.hasLoadedStats = true
                
                print("📊 After update - favorites=\(self.favoriteCount), images=\(self.imageCount), videos=\(self.videoCount)")
                print("✅ Computed stats from database: \(computedFavoriteCount) favorites, \(computedImageCount) images, \(computedVideoCount) videos, \(computedModelCounts.count) image models, \(computedVideoModelCounts.count) video models")
                print("✅ Model counts dictionary: \(computedModelCounts)")
                print("✅ Video model counts dictionary: \(computedVideoModelCounts)")
            }
        } catch {
            print("❌ Failed to compute stats from database: \(error)")
        }
    }
    
    /// Initializes user stats by computing counts from user_media table
    /// This is the authoritative source of truth - use this to resync stats
    func initializeUserStats() async {
        guard let userId = userId else { return }
        
        print("📊 Initializing user stats by computing counts from user_media...")
        
        // Compute counts from user_media (one-time expensive operation)
        do {
            // Fetch only the fields we need for stats computation (lightweight query)
            let response: PostgrestResponse<[MediaStats]> = try await client.database
                .from("user_media")
                .select("model,media_type,is_favorite,status")
                .eq("user_id", value: userId)
                .limit(10000) // High limit to get all
                .execute()
            
            let allMedia = response.value ?? []
            
            print("📊 Computing stats from \(allMedia.count) media items...")
            
            // Compute counts (EXCLUDE failed items - only count successful ones)
            var favoriteCount = 0
            var imageCount = 0
            var videoCount = 0
            var modelCounts: [String: Int] = [:]
            var videoModelCounts: [String: Int] = [:]
            var failedCount = 0 // Track failed items for logging
            
            for media in allMedia {
                // Skip failed items - only count successful ones
                guard media.isSuccess else {
                    failedCount += 1
                    continue
                }
                
                // Count favorites (handle both true and nil as false)
                if media.is_favorite == true {
                    favoriteCount += 1
                }
                
                // Count images and videos
                if media.isImage {
                    imageCount += 1
                } else if media.isVideo {
                    videoCount += 1
                }
                
                // Count by model (exclude null/empty model names from model-specific counts)
                // These are still counted in total image_count/video_count, but not assigned to a model
                if let model = media.model, !model.isEmpty, model != "(null)" {
                    if media.isImage {
                        modelCounts[model, default: 0] += 1
                    } else if media.isVideo {
                        videoModelCounts[model, default: 0] += 1
                    }
                }
            }
            
            if failedCount > 0 {
                print("⚠️ Excluded \(failedCount) failed item(s) from counts")
            }
            
            // Create stats record (IMPORTANT: include image_count and video_count!)
            let stats = UserStats(
                id: nil,
                user_id: userId,
                favorite_count: favoriteCount,
                image_count: imageCount,
                video_count: videoCount,
                model_counts: modelCounts,
                video_model_counts: videoModelCounts,
                created_at: nil,
                updated_at: nil
            )
            
            print("📊 Stats to save: favorites=\(favoriteCount), images=\(imageCount), videos=\(videoCount)")
            
            // Check if stats already exist (for re-sync)
            let existingResponse: PostgrestResponse<[UserStats]> = try await client.database
                .from("user_stats")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            
            if existingResponse.value.first != nil {
                // Update existing stats using raw SQL via RPC to ensure it works
                print("📊 Updating existing user stats with: favorites=\(favoriteCount), images=\(imageCount), videos=\(videoCount)")
                
                // First try using the Codable object
                do {
                    let response = try await client.database
                        .from("user_stats")
                        .update(stats)
                        .eq("user_id", value: userId)
                        .select()
                        .execute()
                    
                    // Check what was returned
                    if let updatedStats = try? JSONDecoder().decode([UserStats].self, from: response.data),
                       let first = updatedStats.first {
                        print("✅ Database update returned: favorites=\(first.favorite_count), images=\(first.image_count), videos=\(first.video_count)")
                    } else {
                        print("⚠️ Database update returned unexpected data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
                    }
                } catch {
                    print("❌ Database update failed: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                }
            } else {
                // Insert new stats
                print("📊 Inserting new user stats...")
                do {
                    try await client.database
                        .from("user_stats")
                        .insert(stats)
                        .execute()
                    print("✅ Database insert completed successfully")
                } catch {
                    print("❌ Database insert failed: \(error)")
                }
            }
            
            // Update published properties
            print("📊 Before update - favorites=\(self.favoriteCount), images=\(self.imageCount), videos=\(self.videoCount)")
            print("📊 Computed - favorites=\(favoriteCount), images=\(imageCount), videos=\(videoCount)")
            self.favoriteCount = favoriteCount
            self.imageCount = imageCount
            self.videoCount = videoCount
            self.modelCounts = modelCounts
            self.videoModelCounts = videoModelCounts
            self.hasLoadedStats = true
            
            // Cache stats for immediate availability on next load
            let statsToCache = UserStats(
                id: nil,
                user_id: userId,
                favorite_count: favoriteCount,
                image_count: imageCount,
                video_count: videoCount,
                model_counts: modelCounts,
                video_model_counts: videoModelCounts,
                created_at: nil,
                updated_at: nil
            )
            self.saveCachedStats(for: userId, stats: statsToCache)
            
            print("📊 After update - favorites=\(self.favoriteCount), images=\(self.imageCount), videos=\(self.videoCount)")
            
            print("✅ Initialized user stats: \(favoriteCount) favorites, \(imageCount) images, \(videoCount) videos, \(modelCounts.count) image models, \(videoModelCounts.count) video models")
        } catch {
            print("❌ Failed to initialize user stats: \(error)")
        }
    }
    
    // MARK: - Update User Stats
    
    /// Refreshes user stats from the database
    /// NOTE: With database triggers, stats are automatically updated when user_media changes.
    /// This function just reads the current stats from the database.
    private func refreshUserStats() async {
        // Small delay to ensure triggers have completed
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        await fetchUserStats()
    }
    
    /// Calls the database function to recompute user stats
    /// This is more efficient than Swift-side computation and uses the same logic as triggers
    private func recomputeUserStatsViaDatabase() async {
        guard let userId = userId else { return }
        
        do {
            // Call the database function recompute_user_stats
            // This uses RPC (Remote Procedure Call) to execute the function
            // The function returns void, so we just execute without expecting a return value
            try await client.database
                .rpc("recompute_user_stats", params: ["target_user_id": userId])
                .execute()
            
            print("✅ Called recompute_user_stats database function")
            
            // Refresh stats after recomputation (small delay to ensure trigger completed)
            await refreshUserStats()
        } catch {
            print("❌ Failed to call recompute_user_stats: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            // Fallback to Swift-side computation if RPC fails
            print("⚠️ Falling back to Swift-side stats computation...")
            await initializeUserStats()
        }
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
                .or("status.is.null,status.eq.success") // Only successful items
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
    // MARK: - Fetch Videos with Pagination
    
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
        // NOTE: Database triggers will automatically update user_stats
        do {
            try await client.database
                .from("user_media")
                .update(["is_favorite": newFavorite])
                .eq("id", value: imageId)
                .eq("user_id", value: userId)
                .execute()
            
            // Refresh stats from database (triggers handle the count updates)
            await refreshUserStats()
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
    
    /// Computes the actual favorite count from userImages (includes both images and videos)
    /// This ensures the count is always accurate, even if database stats are out of sync
    var actualFavoriteCount: Int {
        return userImages.filter { $0.is_favorite == true }.count
    }
    
    /// Computes the actual image count from userImages
    /// This ensures the count is always accurate, even if database stats are out of sync
    var actualImageCount: Int {
        return userImages.filter { $0.isImage }.count
    }
    
    /// Computes the actual video count from userImages
    /// This ensures the count is always accurate, even if database stats are out of sync
    var actualVideoCount: Int {
        return userImages.filter { $0.isVideo }.count
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
        
        // Remove from local caches
        _ = removeImagesLocally(imageIds: [imageId])
        
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
                    
                    // NOTE: Database triggers will automatically update user_stats when media is deleted
                    // No manual count updates needed
                    
                    // Success - remove from local array
                    await MainActor.run {
                        _ = removeImagesLocally(imageIds: [imageId])
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
                
                // Check if the image was already deleted by another device
                // If it doesn't exist in the database, remove it locally anyway
                do {
                    let checkResponse: PostgrestResponse<[UserImage]> = try await client.database
                        .from("user_media")
                        .select("id")
                        .eq("id", value: imageId)
                        .limit(1)
                        .execute()
                    
                    let stillExists = (checkResponse.value ?? []).count > 0
                    if !stillExists {
                        print("✅ Image \(imageId) was already deleted by another device, removing locally")
                        await MainActor.run {
                            _ = removeImagesLocally(imageIds: [imageId])
                        }
                    }
                } catch {
                    print("⚠️ Could not verify if image \(imageId) still exists: \(error)")
                    // If we can't verify, we'll rely on Realtime DELETE event to sync
                }
            }
        }
        
        // Update cache after all deletions
        await MainActor.run {
            saveCachedImages(for: userId)
        }
        
        // Force a fresh fetch of stats from database to ensure accuracy
        // This ensures counts are correct even if there were any cache inconsistencies
        await fetchUserStats()
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

    /// True when an image has at least one valid URL we can render in the grid.
    private func hasValidMediaUrl(_ image: UserImage) -> Bool {
        let hasValidImageUrl = !image.image_url.isEmpty && URL(string: image.image_url) != nil
        let hasValidThumbnailUrl = image.thumbnail_url.map { !$0.isEmpty && URL(string: $0) != nil } ?? false
        return hasValidImageUrl || hasValidThumbnailUrl
    }
    
    // MARK: - Add Image
    
    /// Adds a new image to the local array and cache
    /// - Parameter image: The UserImage to add
    func addImage(_ image: UserImage) async {
        guard let userId = userId else { return }

        // Atomically check if we're already adding this image (race condition prevention)
        // This prevents duplicates when notification handler and Realtime INSERT fire together
        guard !inFlightImageIds.contains(image.id) else {
            print("⏳ [addImage] Image \(image.id) is already being added, skipping duplicate")
            return
        }
        inFlightImageIds.insert(image.id)
        defer { inFlightImageIds.remove(image.id) }

        // Validate the image before adding (or updating existing)
        guard hasValidMediaUrl(image) else {
            print("🚨 WARNING: Attempting to add image with INVALID URL(s) - id: \(image.id), url: '\(image.image_url)'")
            return
        }

        // Add the image and then sort to ensure correct chronological order
        // Create a new array and assign it to trigger SwiftUI's @Published change detection
        // CRITICAL: Wrap BOTH read and write in MainActor.run to ensure SwiftUI detects the change
        await MainActor.run {
            var updatedImages = userImages
            if let existingIndex = updatedImages.firstIndex(where: { $0.id == image.id }) {
                updatedImages[existingIndex] = image
            } else {
                updatedImages.append(image)
            }
            updatedImages.sort { (a, b) -> Bool in
                let aDate = a.created_at ?? ""
                let bDate = b.created_at ?? ""
                return aDate > bDate // Descending order (newest first)
            }
            // Single assignment triggers @Published which calls objectWillChange automatically
            userImages = updatedImages
            print("✅ [addImage] Image added to userImages. New count: \(userImages.count), id: \(image.id)")
        }
        
        // Clear model-specific cache for this image's model (if it has one)
        // This ensures the "Your Creations" section shows the new image
        if let modelName = image.model, !modelName.isEmpty {
            clearModelCache(for: modelName)
        }
        
        // Update cache
        await MainActor.run {
            saveCachedImages(for: userId)
        }
        
        // NOTE: If the image was already in the database, triggers will handle stats updates.
        // If this is a new image being added locally (before DB insert), we'll refresh stats
        // after the database operation completes. For now, just refresh to get current counts.
        await refreshUserStats()
    }
    
    /// Fetches a single image by ID and adds it to the list
    /// - Parameter imageId: The ID of the image to fetch
    func fetchAndAddImageById(imageId: String) async {
        guard let userId = userId else {
            print("⚠️ fetchAndAddImageById: userId is nil")
            return
        }
        
        // Check if image already exists or is being added to avoid duplicates
        let existingImage = await MainActor.run {
            return userImages.first(where: { $0.id == imageId })
        }
        if let existingImage, hasValidMediaUrl(existingImage) {
            print("✅ fetchAndAddImageById: Image \(imageId) already exists with valid URLs, skipping")
            return
        }
        if await MainActor.run { inFlightImageIds.contains(imageId) } {
            print("⏳ fetchAndAddImageById: Image \(imageId) is already being added, skipping")
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
                    if !hasValidMediaUrl(newImage) {
                        print("⚠️ fetchAndAddImageById: Image found but URLs not ready yet, retrying...")
                    } else {
                        // Check if already exists or is being added before adding (double-check after DB fetch)
                        let alreadyExistsOrInFlight = await MainActor.run {
                            return inFlightImageIds.contains(newImage.id) || userImages.contains(where: { $0.id == newImage.id })
                        }
                        
                        if !alreadyExistsOrInFlight {
                            await addImage(newImage)
                            await MainActor.run {
                                print("✅ fetchAndAddImageById: Image added successfully. Total images: \(userImages.count)")
                            }
                        } else if let existingImage = await MainActor.run { userImages.first(where: { $0.id == newImage.id }) },
                                  !hasValidMediaUrl(existingImage),
                                  hasValidMediaUrl(newImage) {
                            await addImage(newImage)
                            await MainActor.run {
                                print("✅ fetchAndAddImageById: Updated existing image with valid URLs. Total images: \(userImages.count)")
                            }
                        } else {
                            print("⚠️ fetchAndAddImageById: Image already exists or is being added, skipping")
                        }
                        return // Success, exit retry loop
                    }
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
        let existingImage = await MainActor.run {
            return userImages.first(where: { $0.image_url == imageUrl })
        }
        
        if let existingImage, hasValidMediaUrl(existingImage) {
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
                    if !hasValidMediaUrl(newImage) {
                        print("⚠️ fetchAndAddImage: Image found but URLs not ready yet, retrying...")
                    } else {
                        // Check if already exists or is being added before adding (double-check after DB fetch)
                        let alreadyExistsOrInFlight = await MainActor.run {
                            return inFlightImageIds.contains(newImage.id) || userImages.contains(where: { $0.id == newImage.id })
                        }
                        
                        if !alreadyExistsOrInFlight {
                            await addImage(newImage)
                            await MainActor.run {
                                print("✅ fetchAndAddImage: Image added successfully. Total images: \(userImages.count)")
                            }
                        } else if let existingImage = await MainActor.run { userImages.first(where: { $0.id == newImage.id }) },
                                  !hasValidMediaUrl(existingImage),
                                  hasValidMediaUrl(newImage) {
                            await addImage(newImage)
                            await MainActor.run {
                                print("✅ fetchAndAddImage: Updated existing image with valid URLs. Total images: \(userImages.count)")
                            }
                        } else {
                            print("⚠️ fetchAndAddImage: Image already exists in list, skipping")
                        }
                        return // Success, exit retry loop
                    }
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
                .or("status.is.null,status.eq.success") // Only successful items
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
