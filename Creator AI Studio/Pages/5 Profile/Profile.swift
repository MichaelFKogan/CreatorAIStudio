import AVKit
import AuthenticationServices // Add this for Apple Sign-In
import CommonCrypto // For SHA256 hashing
import GoogleSignIn
import Kingfisher
import Photos
import SwiftUI
import UIKit

// MARK: PROFILE

struct Profile: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Always show gallery content (with placeholders if not signed in)
                if authViewModel.isCheckingSession {
                    // Show loading while checking session
                    ProgressView("Loading…")
                        .padding()
                } else {
                    ProfileViewContent(viewModel: viewModel, isSignedIn: authViewModel.user != nil)
                        .environmentObject(authViewModel)
                        .onAppear {
                            if let user = authViewModel.user {
                                let userIdChanged = viewModel.userId != user.id.uuidString
                                if userIdChanged {
                                    viewModel.userId = user.id.uuidString
                                }
                                Task {
                                    // Fetch stats FIRST so UI shows correct counts immediately
                                    // This is very cheap - just one row from user_stats table
                                    if !viewModel.hasLoadedStats || userIdChanged {
                                        await viewModel.fetchUserStats()
                                    }
                                    // Then fetch images
                                    await viewModel.fetchUserImages(
                                        forceRefresh: false)
                                }
                            }
                        }
                        .onChange(of: authViewModel.user) { oldUser, newUser in
                            // When user signs in or changes, fetch images
                            if let user = newUser {
                                let userIdChanged = viewModel.userId != user.id.uuidString
                                // Only fetch if this is a new sign-in or user changed
                                if oldUser == nil || userIdChanged {
                                    if userIdChanged {
                                        viewModel.userId = user.id.uuidString
                                    }
                                    Task {
                                        // Fetch stats FIRST so UI shows correct counts immediately
                                        if !viewModel.hasLoadedStats || userIdChanged {
                                            await viewModel.fetchUserStats()
                                        }
                                        // Then fetch images
                                        await viewModel.fetchUserImages(forceRefresh: false)
                                    }
                                }
                            }
                        }
                }
                
                // Show sign-in overlay when not signed in
                if !authViewModel.isCheckingSession && authViewModel.user == nil {
                    SignInOverlay()
                        .environmentObject(authViewModel)
                }
            }

            // MARK: NAVIGATION BAR

            .navigationTitle("")
            .toolbar {
                // Always show "Gallery" title
                if !authViewModel.isCheckingSession {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("Gallery")
                            .font(
                                .system(size: 28, weight: .bold, design: .rounded)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.gray, .white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
        }
    }
}

// MARK: STRUCT PROFILEVIEWCONTENT

struct ProfileViewContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    let isSignedIn: Bool
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedUserImage: UserImage? = nil
    @State private var selectedTab: GalleryTab = .all
    @State private var selectedModel: String? = nil
    @State private var selectedVideoModel: String? = nil
    @State private var showImageModelsPopover: Bool = false
    @State private var showVideoModelsPopover: Bool = false
    @State private var showPresetsSheet: Bool = false
    @State private var isSelectionMode: Bool = false
    @State private var selectedImageIds: Set<String> = []
    @State private var isDeleting: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var isSaving: Bool = false
    @State private var isSharing: Bool = false
    @State private var shareItems: [URL] = []
    @State private var showShareSheet: Bool = false
    @State private var showNoSelectionAlert: Bool = false
    @State private var noSelectionAlertMessage: String = ""

    // Load model data to get images - cache at static level to avoid repeated loading
    private static var cachedImageModels: [InfoPacket]?
    private var allImageModels: [InfoPacket] {
        if let cached = Self.cachedImageModels {
            return cached
        }
        let models = ImageModelsViewModel.loadImageModels()
        Self.cachedImageModels = models
        return models
    }

    // Load video model data - cache at static level to avoid repeated loading
    private static var cachedVideoModels: [InfoPacket]?
    private var allVideoModels: [InfoPacket] {
        if let cached = Self.cachedVideoModels {
            return cached
        }
        let models = VideoModelsViewModel.loadVideoModels()
        Self.cachedVideoModels = models
        return models
    }

    enum GalleryTab: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case imageModels = "Image Models"
        case videoModels = "Video Models"
    }

    // MARK: - Cached Computations
    
    @State private var cachedImageModelsMetadata: [(model: String, count: Int, imageName: String)]? = nil
    @State private var cachedVideoModelsMetadata: [(model: String, count: Int, imageName: String)]? = nil
    
    // Compute models with metadata - cached to avoid repeated computation
    private func computeModelsWithMetadata() -> [(model: String, count: Int, imageName: String)] {
        // Use cached result if available and modelCounts haven't changed
        if let cached = cachedImageModelsMetadata, !viewModel.modelCounts.isEmpty {
            return cached
        }
        
        let modelNames: [String]
        if !viewModel.modelCounts.isEmpty {
            modelNames = Array(viewModel.modelCounts.keys).sorted()
        } else {
            modelNames = viewModel.uniqueModels
        }

        var result: [(String, Int, String)] = []

        for modelName in modelNames {
            let count: Int
            if let dbCount = viewModel.modelCounts[modelName], dbCount > 0 {
                count = dbCount
            } else {
                count = viewModel.filteredImages(by: modelName, favoritesOnly: false).count
            }
            
            guard count > 0 else { continue }

            let imageName = findImageModelImageName(for: modelName)
            result.append((modelName, count, imageName))
        }

        let sorted = result.sorted { $0.1 > $1.1 }
        cachedImageModelsMetadata = sorted
        return sorted
    }

    // Compute video models with metadata - cached to avoid repeated computation
    private func computeVideoModelsWithMetadata() -> [(model: String, count: Int, imageName: String)] {
        // Use cached result if available
        if let cached = cachedVideoModelsMetadata {
            return cached
        }
        
        let modelNames: [String]
        if !viewModel.videoModelCounts.isEmpty {
            modelNames = Array(viewModel.videoModelCounts.keys).sorted()
        } else {
            modelNames = viewModel.uniqueVideoModels
        }

        var result: [(String, Int, String)] = []

        for modelName in modelNames {
            let count = viewModel.filteredVideos(by: modelName, favoritesOnly: false).count
            guard count > 0 else { continue }

            let imageName = findVideoModelImageName(for: modelName)
            result.append((modelName, count, imageName))
        }

        let sorted = result.sorted { $0.1 > $1.1 }
        cachedVideoModelsMetadata = sorted
        return sorted
    }
    
    private func findImageModelImageName(for modelName: String) -> String {
        if let modelInfo = allImageModels.first(where: { $0.display.modelName == modelName }) {
            return modelInfo.display.imageName
        } else if let modelInfo = allImageModels.first(where: { $0.display.title == modelName }) {
            return modelInfo.display.imageName
        }
        return "photo.on.rectangle.angled"
    }
    
    private func findVideoModelImageName(for modelName: String) -> String {
        if let modelInfo = allVideoModels.first(where: { $0.display.modelName == modelName }) {
            return modelInfo.display.imageName
        } else if let modelInfo = allVideoModels.first(where: { $0.display.title == modelName }) {
            return modelInfo.display.imageName
        }
        return "video.fill"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    mainScrollView
                    scrollToTopButton(proxy: proxy)
                }
                .toolbar { toolbarContent }
            }
            .onChange(of: notificationManager.notifications.count) {
                oldCount, newCount in
                // When notification count decreases (notification dismissed), refresh images
                if newCount < oldCount {
                    invalidateCaches()
                    Task {
                        await viewModel.fetchUserImages(forceRefresh: true)
                    }
                }
            }
            .onChange(of: notificationManager.notifications) {
                oldNotifications, newNotifications in
                handleNotificationChange(
                    oldNotifications: oldNotifications,
                    newNotifications: newNotifications
                )
            }
            .onChange(of: viewModel.userImages.count) {
                _ in
                invalidateCaches()
            }
            .onChange(of: viewModel.modelCounts) {
                _ in
                cachedImageModelsMetadata = nil
            }
            .onChange(of: viewModel.videoModelCounts) {
                _ in
                cachedVideoModelsMetadata = nil
            }
            // Listen for webhook-based image completions
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("ImageSavedToDatabase"))
            ) { _ in
                print(
                    "📸 [Profile] Received ImageSavedToDatabase notification - refreshing gallery"
                )
                Task {
                    await viewModel.fetchUserImages(forceRefresh: true)
                }
            }
            // Listen for webhook-based video completions
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("VideoSavedToDatabase"))
            ) { _ in
                print(
                    "🎬 [Profile] Received VideoSavedToDatabase notification - refreshing gallery"
                )
                Task {
                    await viewModel.fetchUserImages(forceRefresh: true)
                }
            }
            .sheet(item: $selectedUserImage) { userImage in
                FullScreenImageView(
                    userImage: userImage,
                    isPresented: Binding(
                        get: { selectedUserImage != nil },
                        set: { if !$0 { selectedUserImage = nil } }
                    ),
                    viewModel: viewModel
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea()
            }
            .alert(
                "Delete Selected Images?", isPresented: $showDeleteConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteSelectedImages()
                    }
                }
            } message: {
                Text(
                    "This will permanently delete \(selectedImageIds.count) image\(selectedImageIds.count == 1 ? "" : "s"). This action cannot be undone."
                )
            }
            .alert("No Images Selected", isPresented: $showNoSelectionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(noSelectionAlertMessage)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems)
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - View Components
    
    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                filterSection
                contentSection
            }
            .padding(.top, 10)
            .id("scrollTop")
        }
    }
    
    private func scrollToTopButton(proxy: ScrollViewProxy) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("scrollTop", anchor: .top)
                    }
                }) {
                    scrollToTopButtonContent
                }
                .padding(.trailing, 16)
                .padding(.bottom, 75)
            }
        }
    }
    
    private var scrollToTopButtonContent: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.9))
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            
            Image(systemName: "arrow.up")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if isSelectionMode {
                selectionModeToolbar
            } else {
                normalModeToolbar
            }
        }
    }
    
    private var selectionModeToolbar: some View {
        HStack(spacing: 24) {
            saveButton
            shareButton
            deleteButton
            cancelButton
        }
    }
    
    private var normalModeToolbar: some View {
        HStack(spacing: 16) {
            Button(action: { isSelectionMode = true }) {
                Text("Select")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            NavigationLink(
                destination: Settings(profileViewModel: viewModel)
                    .environmentObject(authViewModel)
            ) {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: handleSaveAction) {
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .opacity(0.8)
                    .frame(height: 14)
                Text("Save")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .disabled(isSaving || isDeleting)
    }
    
    private var shareButton: some View {
        Button(action: handleShareAction) {
            VStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .opacity(0.8)
                    .frame(height: 14)
                Text("Share")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .disabled(isSharing || isDeleting)
    }
    
    private var deleteButton: some View {
        Button(action: handleDeleteAction) {
            VStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .opacity(0.8)
                    .frame(height: 14)
                Text("Delete")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
    }
    
    private var cancelButton: some View {
        Button(action: {
            isSelectionMode = false
            selectedImageIds.removeAll()
        }) {
            Text("Cancel")
                .font(.body)
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - Cache Management
    
    private func invalidateCaches() {
        cachedImageModelsMetadata = nil
        cachedVideoModelsMetadata = nil
    }
    
    // MARK: - Actions
    
    private func handleSaveAction() {
        if selectedImageIds.isEmpty {
            noSelectionAlertMessage = "Please select at least one image to save."
            showNoSelectionAlert = true
        } else {
            Task {
                await saveSelectedImages()
            }
        }
    }
    
    private func handleShareAction() {
        if selectedImageIds.isEmpty {
            noSelectionAlertMessage = "Please select at least one image to share."
            showNoSelectionAlert = true
        } else {
            Task {
                await shareSelectedImages()
            }
        }
    }
    
    private func handleDeleteAction() {
        if selectedImageIds.isEmpty {
            noSelectionAlertMessage = "Please select at least one image to delete."
            showNoSelectionAlert = true
        } else {
            showDeleteConfirmation = true
        }
    }

    private func handleNotificationChange(
        oldNotifications: [NotificationData],
        newNotifications: [NotificationData]
    ) {
        // When a notification is marked as completed, fetch and add the new image
        let newlyCompleted = newNotifications.filter { notification in
            notification.state == .completed
                && !oldNotifications.contains(where: { existing in
                    existing.id == notification.id
                        && existing.state == .completed
                })
        }

        guard !newlyCompleted.isEmpty else { return }

        Task {
            await viewModel.fetchLatestImage()
        }
    }

    // MARK: PROFILE HEADER

    private var profileHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 4) {
                    Text("Your Name")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("@username")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 32) {
                    statView(value: "24", label: "Creations")
                    statView(value: "156", label: "Likes")
                    statView(value: "89", label: "Followers")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top)
        .padding(.horizontal)
    }

    private func statView(value: String, label: String) -> some View {
        VStack {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All pill
                    GalleryTabPill(
                        title: "All",
                        icon: "photo.on.rectangle.angled",
                        isSelected: selectedTab == .all && selectedModel == nil
                            && selectedVideoModel == nil,
                        // Stats are pre-loaded from cache in init(), so this should show correct count immediately
                        count: viewModel.imageCount + viewModel.videoCount
                    ) {
                        selectedTab = .all
                        selectedModel = nil
                        selectedVideoModel = nil
                    }

                    // Favorites pill
                    GalleryTabPill(
                        title: "Favorites",
                        icon: "heart.fill",
                        isSelected: selectedTab == .favorites
                            && selectedModel == nil
                            && selectedVideoModel == nil,
                        // Stats are pre-loaded from cache in init(), so this should show correct count immediately
                        count: viewModel.favoriteCount
                    ) {
                        selectedTab = .favorites
                        selectedModel = nil
                        selectedVideoModel = nil
                        // Fetch favorites when tab is clicked (with pagination)
                        Task {
                            await viewModel.fetchFavorites()
                        }
                    }

                    imageModelsButton

                    videoModelsButton
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)
        }
    }

    private var imageModelsButton: some View {
        Button {
            showImageModelsPopover = true
        } label: {
            imageModelsButtonLabel
        }
        .sheet(isPresented: $showImageModelsPopover) {
            ImageModelsSheet(
                models: computeModelsWithMetadata(),
                selectedModel: $selectedModel,
                selectedVideoModel: $selectedVideoModel,
                selectedTab: $selectedTab,
                isPresented: $showImageModelsPopover
            )
        }
        //            .sheet(isPresented: $showPresetsSheet) {
        //                PresetsListSheet(
        //                    presetViewModel: presetViewModel,
        //                    isPresented: $showPresetsSheet
        //                )
        //                .presentationDetents([.large])
        //                .presentationDragIndicator(.visible)
        //            }
    }

    private var imageModelsButtonLabel: some View {
        let isSelected = selectedTab == .imageModels && selectedModel != nil
        let title =
            isSelected && selectedModel != nil ? selectedModel! : "Image Models"
        let modelCount = viewModel.hasLoadedStats ? viewModel.modelCounts.count : viewModel.uniqueModels.count

        return HStack(spacing: 6) {
            Image(systemName: "cpu")
                .font(.system(size: 12, weight: .medium))

            Text(title)
                .font(
                    .system(size: 14, weight: isSelected ? .semibold : .regular)
                )
                .lineLimit(1)

            // Show count when not selected or when showing all models
            if !isSelected && modelCount > 0 {
                Text("(\(modelCount))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(isSelected ? .white : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue : Color.gray.opacity(0.15))
        .clipShape(Capsule())
    }

    private var videoModelsButton: some View {
        Button {
            showVideoModelsPopover = true
        } label: {
            videoModelsButtonLabel
        }
        .sheet(isPresented: $showVideoModelsPopover) {
            VideoModelsSheet(
                models: computeVideoModelsWithMetadata(),
                selectedModel: $selectedModel,
                selectedVideoModel: $selectedVideoModel,
                selectedTab: $selectedTab,
                isPresented: $showVideoModelsPopover
            )
        }
    }

    private var videoModelsButtonLabel: some View {
        let isSelected =
            selectedTab == .videoModels && selectedVideoModel != nil
        let title =
            isSelected && selectedVideoModel != nil
            ? selectedVideoModel! : "Video Models"
        let modelCount = viewModel.hasLoadedStats ? viewModel.videoModelCounts.count : viewModel.uniqueVideoModels.count

        return HStack(spacing: 6) {
            Image(systemName: "video")
                .font(.system(size: 12, weight: .medium))

            Text(title)
                .font(
                    .system(size: 14, weight: isSelected ? .semibold : .regular)
                )
                .lineLimit(1)

            // Show count when not selected or when showing all models
            if !isSelected && modelCount > 0 {
                Text("(\(modelCount))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(isSelected ? .white : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.purple : Color.gray.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoading {
                ProgressView("Loading images…")
                    .padding()
            } else {
                filteredContent
            }
        }
    }

    @ViewBuilder
    private var filteredContent: some View {
        let filteredImages = getFilteredImages()
        
        // If not signed in, show placeholder grid
        if !isSignedIn {
            PlaceholderGrid()
        } else if filteredImages.isEmpty
            && notificationManager.activePlaceholders.isEmpty
        {
            EmptyGalleryView(
                tab: selectedTab,
                model: selectedModel,
                isImageModelsTab: selectedTab == .imageModels,
                isVideoModelsTab: selectedTab == .videoModels,
                videoModel: selectedVideoModel
            )
        } else {
            ImageGridView(
                userImages: filteredImages,
                placeholders: notificationManager.activePlaceholders,
                onSelect: { userImage in
                    if isSelectionMode {
                        if selectedImageIds.contains(userImage.id) {
                            selectedImageIds.remove(userImage.id)
                        } else {
                            selectedImageIds.insert(userImage.id)
                        }
                    } else {
                        selectedUserImage = userImage
                    }
                },
                viewModel: viewModel,
                //                presetViewModel: presetViewModel,
                isSelectionMode: isSelectionMode,
                selectedImageIds: $selectedImageIds,
                isFavoritesTab: selectedTab == .favorites
            )
        }
    }

    private func getFilteredImages() -> [UserImage] {
        switch selectedTab {
        case .all:
            return selectedModel == nil
                ? viewModel.userImages
                : viewModel.filteredImages(
                    by: selectedModel, favoritesOnly: false)
        case .favorites:
            return selectedModel == nil
                ? viewModel.favoriteImages
                : viewModel.filteredImages(
                    by: selectedModel, favoritesOnly: true)
        case .imageModels:
            return selectedModel != nil
                ? viewModel.filteredImages(
                    by: selectedModel, favoritesOnly: false)
                : viewModel.userImages
        case .videoModels:
            return selectedVideoModel != nil
                ? viewModel.filteredVideos(
                    by: selectedVideoModel, favoritesOnly: false)
                : viewModel.userVideos
        }
    }

    private func deleteSelectedImages() async {
        guard !selectedImageIds.isEmpty else { return }

        isDeleting = true
        let idsToDelete = Array(selectedImageIds)

        await viewModel.deleteImages(imageIds: idsToDelete)

        await MainActor.run {
            selectedImageIds.removeAll()
            isSelectionMode = false
            isDeleting = false
        }
    }

    private func saveSelectedImages() async {
        guard !selectedImageIds.isEmpty else { return }

        await MainActor.run {
            isSaving = true
        }

        // Get selected images
        let selectedImages = viewModel.userImages.filter {
            selectedImageIds.contains($0.id)
        }

        // Request photo library permission
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            await MainActor.run {
                isSaving = false
            }
            return
        }

        var savedCount = 0
        var failedCount = 0

        // Save each image
        for userImage in selectedImages {
            do {
                guard let url = URL(string: userImage.image_url) else {
                    failedCount += 1
                    continue
                }

                // Download the media data
                let (data, _) = try await URLSession.shared.data(from: url)

                if userImage.isVideo {
                    // Save video to photo library
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(
                            userImage.file_extension ?? "mp4")

                    try data.write(to: tempURL)

                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetCreationRequest.creationRequestForAssetFromVideo(
                            atFileURL: tempURL)
                    }

                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                } else {
                    // Save image to photo library
                    guard let image = UIImage(data: data) else {
                        failedCount += 1
                        continue
                    }

                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetCreationRequest.creationRequestForAsset(
                            from: image)
                    }
                }

                savedCount += 1
            } catch {
                print("❌ Failed to save image \(userImage.id): \(error)")
                failedCount += 1
            }
        }

        await MainActor.run {
            isSaving = false
            if savedCount > 0 {
                // Optionally show success message
                print("✅ Saved \(savedCount) image(s) to photo library")
            }
            if failedCount > 0 {
                print("⚠️ Failed to save \(failedCount) image(s)")
            }
        }
    }

    private func shareSelectedImages() async {
        guard !selectedImageIds.isEmpty else { return }

        await MainActor.run {
            isSharing = true
            shareItems.removeAll()
        }

        // Get selected images
        let selectedImages = viewModel.userImages.filter {
            selectedImageIds.contains($0.id)
        }

        var tempURLs: [URL] = []

        // Download and create temporary files for each image
        for userImage in selectedImages {
            do {
                guard let url = URL(string: userImage.image_url) else {
                    continue
                }

                // Download the media data
                let (data, _) = try await URLSession.shared.data(from: url)

                // Create a temporary file
                let fileExtension =
                    userImage.isVideo
                    ? (userImage.file_extension ?? "mp4")
                    : (userImage.file_extension ?? "jpg")
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(fileExtension)

                // Write data to temporary file
                try data.write(to: tempURL)
                tempURLs.append(tempURL)
            } catch {
                print(
                    "❌ Failed to prepare image \(userImage.id) for sharing: \(error)"
                )
            }
        }

        await MainActor.run {
            isSharing = false
            shareItems = tempURLs
            if !shareItems.isEmpty {
                showShareSheet = true
            }
        }

        // Clean up temporary files after a delay (to allow sharing to complete)
        Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000)  // 60 seconds
            for tempURL in tempURLs {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }
}

// MARK: IMAGE GRID (3×3 PORTRAIT)

struct ImageGridView: View {
    let userImages: [UserImage]
    let placeholders: [PlaceholderImage]
    let spacing: CGFloat = 2
    var onSelect: (UserImage) -> Void
    var viewModel: ProfileViewModel?
    //    var presetViewModel: PresetViewModel?
    var isSelectionMode: Bool = false
    @Binding var selectedImageIds: Set<String>
    var isFavoritesTab: Bool = false

    @State private var favoritedImageIds: Set<String> = []

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
    }
    
    /// Filter out items with invalid/empty URLs and duplicates to prevent empty rectangles in the grid
    /// Optimized with efficient filtering and deduplication
    private var validUserImages: [UserImage] {
        // Use Set for O(1) lookup during deduplication
        var seenIds = Set<String>()
        
        // Single pass: filter by URL validity and deduplicate simultaneously
        return userImages.compactMap { userImage in
            // Skip if already seen
            guard !seenIds.contains(userImage.id) else { return nil }
            
            // Check URL validity
            let hasValidImageUrl = !userImage.image_url.isEmpty && URL(string: userImage.image_url) != nil
            let hasValidThumbnailUrl = userImage.thumbnail_url.map { !$0.isEmpty && URL(string: $0) != nil } ?? false
            
            guard hasValidImageUrl || hasValidThumbnailUrl else { return nil }
            
            seenIds.insert(userImage.id)
            return userImage
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = calculateItemWidth(proxy: proxy)
            let itemHeight = itemWidth * 1.4

            LazyVGrid(columns: gridColumns, spacing: spacing) {
                placeholderItems(itemWidth: itemWidth, itemHeight: itemHeight)
                imageItems(itemWidth: itemWidth, itemHeight: itemHeight)
                loadingIndicator
            }
            .padding(.horizontal, 4)
        }
        .frame(height: calculateHeight(for: placeholders.count + validUserImages.count))
    }
    
    // MARK: - Grid Components
    
    private func calculateItemWidth(proxy: GeometryProxy) -> CGFloat {
        let totalSpacing = spacing * 2
        let contentWidth = max(0, proxy.size.width - totalSpacing - 8)
        return max(44, contentWidth / 3)
    }
    
    @ViewBuilder
    private func placeholderItems(itemWidth: CGFloat, itemHeight: CGFloat) -> some View {
        ForEach(placeholders) { placeholder in
            PlaceholderImageCard(
                placeholder: placeholder,
                itemWidth: itemWidth,
                itemHeight: itemHeight
            )
        }
    }
    
    @ViewBuilder
    private func imageItems(itemWidth: CGFloat, itemHeight: CGFloat) -> some View {
        ForEach(validUserImages) { userImage in
            imageGridItem(
                userImage: userImage,
                itemWidth: itemWidth,
                itemHeight: itemHeight
            )
        }
    }
    
    @ViewBuilder
    private func imageGridItem(userImage: UserImage, itemWidth: CGFloat, itemHeight: CGFloat) -> some View {
        if let displayUrl = getDisplayUrl(for: userImage),
           let url = URL(string: displayUrl) {
            imageItemWithUrl(
                userImage: userImage,
                url: url,
                itemWidth: itemWidth,
                itemHeight: itemHeight
            )
        } else if let url = URL(string: userImage.image_url) {
            fallbackImageItem(
                userImage: userImage,
                url: url,
                itemWidth: itemWidth,
                itemHeight: itemHeight
            )
        }
    }
    
    private func getDisplayUrl(for userImage: UserImage) -> String? {
        let isValidUrl: (String?) -> Bool = { urlString in
            guard let urlString = urlString, !urlString.isEmpty else { return false }
            return URL(string: urlString) != nil
        }
        
        if userImage.isVideo {
            if isValidUrl(userImage.thumbnail_url) {
                return userImage.thumbnail_url
            } else if isValidUrl(userImage.image_url) {
                return userImage.image_url
            }
        } else {
            if isValidUrl(userImage.image_url) {
                return userImage.image_url
            }
        }
        return nil
    }
    
    private func imageItemWithUrl(userImage: UserImage, url: URL, itemWidth: CGFloat, itemHeight: CGFloat) -> some View {
        ZStack {
            imageButton(userImage: userImage, url: url, itemWidth: itemWidth, itemHeight: itemHeight)
            if !isSelectionMode {
                favoriteOverlay(userImage: userImage)
            }
        }
        .onAppear {
            handleItemAppear(userImage: userImage)
        }
    }
    
    private func fallbackImageItem(userImage: UserImage, url: URL, itemWidth: CGFloat, itemHeight: CGFloat) -> some View {
        ZStack {
            fallbackImageButton(userImage: userImage, url: url, itemWidth: itemWidth, itemHeight: itemHeight)
            if !isSelectionMode {
                favoriteOverlay(userImage: userImage)
            }
        }
        .onAppear {
            handleItemAppear(userImage: userImage)
        }
    }
    
    private func imageButton(userImage: UserImage, url: URL, itemWidth: CGFloat, itemHeight: CGFloat) -> some View {
        Button {
            onSelect(userImage)
        } label: {
            ZStack {
                KFImage(url)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView())
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: itemWidth, height: itemHeight)
                    .clipped()
                    .overlay(selectionOverlay(userImage: userImage))
                    .overlay(checkmarkOverlay(userImage: userImage))
                
                if userImage.isVideo {
                    videoPlayIcon
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func fallbackImageButton(userImage: UserImage, url: URL, itemWidth: CGFloat, itemHeight: CGFloat) -> some View {
        Button {
            onSelect(userImage)
        } label: {
            ZStack {
                KFImage(url)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "video.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: itemWidth, height: itemHeight)
                    .clipped()
                    .overlay(selectionOverlay(userImage: userImage))
                    .overlay(checkmarkOverlay(userImage: userImage))
                
                if userImage.isVideo {
                    videoPlayIcon
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func selectionOverlay(userImage: UserImage) -> some View {
        if isSelectionMode {
            Rectangle()
                .fill(Color.black.opacity(selectedImageIds.contains(userImage.id) ? 0.3 : 0))
        }
    }
    
    @ViewBuilder
    private func checkmarkOverlay(userImage: UserImage) -> some View {
        if isSelectionMode {
            VStack {
                HStack {
                    Spacer()
                    checkmarkCircle(userImage: userImage)
                        .padding(6)
                }
                Spacer()
            }
        }
    }
    
    private func checkmarkCircle(userImage: UserImage) -> some View {
        ZStack {
            Circle()
                .fill(selectedImageIds.contains(userImage.id) ? Color.blue : Color.white.opacity(0.3))
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
            
            if selectedImageIds.contains(userImage.id) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var videoPlayIcon: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 40, height: 40)
            
            Image(systemName: "play.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
        }
    }
    
    private func favoriteOverlay(userImage: UserImage) -> some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    ZStack {
                        Color.clear
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleFavoriteTap(userImage: userImage)
                            }
                        
                        Image(systemName: (userImage.is_favorite ?? false) ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor((userImage.is_favorite ?? false) ? .red : .white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .allowsHitTesting(false)
                    }
                }
            }
            Spacer()
        }
    }
    
    private func handleFavoriteTap(userImage: UserImage) {
        if let viewModel = viewModel {
            Task {
                await viewModel.toggleFavorite(imageId: userImage.id)
            }
        } else {
            let imageId = userImage.id
            if favoritedImageIds.contains(imageId) {
                favoritedImageIds.remove(imageId)
            } else {
                favoritedImageIds.insert(imageId)
            }
        }
    }
    
    private func handleItemAppear(userImage: UserImage) {
        guard let viewModel = viewModel,
              let index = validUserImages.firstIndex(where: { $0.id == userImage.id }),
              index >= validUserImages.count - 10 else { return }
        
        Task {
            if isFavoritesTab {
                await viewModel.loadMoreFavorites()
            } else {
                await viewModel.loadMoreImages()
            }
        }
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        if let viewModel = viewModel, viewModel.isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                    .padding()
                Spacer()
            }
        }
    }

    private func calculateHeight(for count: Int) -> CGFloat {
        let rows = ceil(Double(count) / 3.0)
        let itemWidth = (UIScreen.main.bounds.width - 16) / 3
        return CGFloat(rows) * (itemWidth * 1.4 + spacing)
    }

    //    // Check if an image has a matching preset
    //    private func hasMatchingPreset(for userImage: UserImage) -> Bool {
    //        guard let presetViewModel = presetViewModel else { return false }
    //
    //        let currentModelName = userImage.title
    //        let currentPrompt = userImage.prompt
    //
    //        return presetViewModel.presets.contains { preset in
    //            // Compare model names (both can be nil or empty)
    //            let modelMatch: Bool
    //            if let currentModel = currentModelName, !currentModel.isEmpty {
    //                modelMatch = preset.modelName == currentModel
    //            } else {
    //                // Both are nil/empty - consider it a match
    //                modelMatch = preset.modelName == nil || preset.modelName?.isEmpty == true
    //            }
    //
    //            // Compare prompts (both can be nil or empty)
    //            let promptMatch: Bool
    //            if let current = currentPrompt, !current.isEmpty {
    //                promptMatch = preset.prompt == current
    //            } else {
    //                // Both are nil/empty - consider it a match
    //                promptMatch = preset.prompt == nil || preset.prompt?.isEmpty == true
    //            }
    //
    //            return modelMatch && promptMatch
    //        }
    //    }
}

// MARK: PLACEHOLDER Image Card (for in-progress generations)

struct PlaceholderImageCard: View {
    let placeholder: PlaceholderImage
    let itemWidth: CGFloat
    let itemHeight: CGFloat

    @State private var shimmer = false
    @State private var pulseAnimation = false
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var isRetrying = false
    @State private var showCopiedConfirmation = false

    // Helper to check if image is a placeholder (very small, like 1x1)
    private var isValidImage: Bool {
        guard let image = placeholder.thumbnailImage else { return false }
        let size = image.size
        // Consider images smaller than 10x10 as placeholders
        return size.width >= 10 && size.height >= 10
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: 2)
                )

            VStack(spacing: 8) {
                // Thumbnail or Icon
                if let thumbnail = placeholder.thumbnailImage, isValidImage {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                } else {
                    // Show an AI/magic icon for text-to-image generation (matches NotificationBar)
                    ZStack {
                        // Animated gradient background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.6, blue: 1.0),
                                        Color(red: 0.6, green: 0.4, blue: 1.0),
                                        Color(red: 0.8, green: 0.5, blue: 1.0),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .opacity(0.8)

                        // Sparkles/magic wand icon to represent AI text-to-image
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(
                                color: .black.opacity(0.2), radius: 2, x: 0,
                                y: 1)
                    }
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: Color.purple.opacity(0.4), radius: 6, x: 0, y: 2
                    )
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                }

                // Title and Message
                VStack(spacing: 4) {
                    Text(placeholder.title)
                        .font(.custom("Nunito-Bold", size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)

                    Text(placeholder.message)
                        .font(.custom("Nunito-Regular", size: 9))
                        .foregroundColor(
                            placeholder.state == .failed ? .red : .secondary
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                // Progress Bar or Error Message
                if placeholder.state == .failed {
                    VStack(spacing: 6) {
                        if let errorMsg = placeholder.errorMessage {
                            Text(errorMsg)
                                .font(.custom("Nunito-Regular", size: 8))
                                .foregroundColor(.red.opacity(0.8))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }

                        // Retry button
                        Button(action: {
                            retryGeneration()
                        }) {
                            HStack(spacing: 4) {
                                if isRetrying {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(
                                                tint: .white)
                                        )
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(
                                            .system(size: 10, weight: .semibold)
                                        )
                                }
                                Text("Retry")
                                    .font(.custom("Nunito-Bold", size: 10))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray)
                            // .background(
                            //     LinearGradient(
                            //         colors: [.blue, .purple],
                            //         startPoint: .leading,
                            //         endPoint: .trailing
                            //     )
                            // )
                            .clipShape(Capsule())
                        }
                        .disabled(isRetrying)
                        .padding(.top, 4)

                        // Copy Prompt button (only show if prompt exists)
                        if let prompt = placeholder.prompt, !prompt.isEmpty {
                            Button(action: {
                                copyPrompt(prompt)
                            }) {
                                HStack(spacing: 3) {
                                    Image(
                                        systemName: showCopiedConfirmation
                                            ? "checkmark" : "doc.on.doc"
                                    )
                                    .font(.system(size: 9, weight: .semibold))
                                    Text(
                                        showCopiedConfirmation
                                            ? "Copied!" : "Copy Prompt"
                                    )
                                    .font(.custom("Nunito-Bold", size: 9))
                                }
                                .foregroundColor(
                                    showCopiedConfirmation ? .green : .blue
                                )
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            showCopiedConfirmation
                                                ? Color.green : Color.blue,
                                            lineWidth: 1.5)
                                )
                            }
                            .padding(.top, 2)
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geometry.size.width
                                            * placeholder.progress, height: 4
                                    )
                                    .overlay(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0),
                                                Color.white.opacity(0.6),
                                                Color.white.opacity(0),
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .rotationEffect(.degrees(20))
                                        .offset(x: shimmer ? 100 : -100)
                                        .mask(RoundedRectangle(cornerRadius: 2))
                                    )
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 8)

                        Text("\(Int(placeholder.progress * 100))%")
                            .font(.custom("Nunito-Regular", size: 9))
                            .foregroundColor(.secondary)

                        // Cancel button for in-progress tasks
                        if placeholder.state == .inProgress {
                            Button(action: {
                                notificationManager.cancelTask(
                                    notificationId: placeholder.id)
                            }) {
                                Text("Cancel")
                                    .font(.custom("Nunito-Bold", size: 10))
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .frame(width: itemWidth, height: itemHeight)
        .overlay(alignment: .topTrailing) {
            // Close button for failed image generations
            if placeholder.state == .failed {
                Button(action: {
                    notificationManager.dismissNotification(id: placeholder.id)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 24, height: 24)

                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .padding(6)
            }
        }
        .onAppear {
            pulseAnimation = true
            withAnimation(
                .linear(duration: 1.5).repeatForever(autoreverses: false)
            ) {
                shimmer = true
            }
        }
        .animation(
            .easeInOut(duration: 1).repeatForever(autoreverses: true),
            value: pulseAnimation
        )
    }

    private var backgroundGradient: LinearGradient {
        switch placeholder.state {
        case .failed:
            return LinearGradient(
                colors: [Color.red.opacity(0.1), Color.red.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .completed:
            return LinearGradient(
                colors: [Color.green.opacity(0.1), Color.green.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        switch placeholder.state {
        case .failed: return Color.red.opacity(0.4)
        case .completed: return Color.green.opacity(0.4)
        default: return Color.gray.opacity(0.3)
        }
    }

    private func retryGeneration() {
        guard !isRetrying else { return }
        isRetrying = true

        Task {
            let success = ImageGenerationCoordinator.shared
                .retryImageGeneration(
                    notificationId: placeholder.id,
                    onImageGenerated: { _ in
                        isRetrying = false
                    },
                    onError: { _ in
                        isRetrying = false
                    }
                )

            if !success {
                isRetrying = false
            }
        }
    }

    private func copyPrompt(_ prompt: String) {
        UIPasteboard.general.string = prompt
        showCopiedConfirmation = true

        // Reset confirmation after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showCopiedConfirmation = false
        }
    }
}

// MARK: - GALLERY TAB PILL

struct GalleryTabPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))

                Text(title)
                    .font(
                        .system(
                            size: 14, weight: isSelected ? .semibold : .regular)
                    )
                    .foregroundColor(isSelected ? .white : .primary)

                if count > 0 {
                    Text("(\(count))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(
                            isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 0)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MODEL FILTER CHIP (kept for backward compatibility if needed)

struct ModelFilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(
                        .system(
                            size: 14, weight: isSelected ? .semibold : .regular)
                    )
                    .foregroundColor(isSelected ? .white : .primary)

                if count > 0 {
                    Text("(\(count))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(
                            isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 0)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EMPTY GALLERY VIEW

struct EmptyGalleryView: View {
    let tab: ProfileViewContent.GalleryTab
    let model: String?
    let isImageModelsTab: Bool
    var isVideoModelsTab: Bool = false
    var videoModel: String? = nil
    
    private let spacing: CGFloat = 2
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
    }
    
    private var shouldShowPlaceholderGrid: Bool {
        // Show placeholder grid only for the default "No Images Yet" case
        return tab == .all && !isImageModelsTab && !isVideoModelsTab
    }

    var body: some View {
        if shouldShowPlaceholderGrid {
            // For "No Images Yet" case: show placeholder grid with center cell containing message
            placeholderGrid
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // For other cases: keep original layout
            VStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.5))

                VStack(spacing: 8) {
                    Text(emptyTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
    
    private var placeholderGrid: some View {
        GeometryReader { proxy in
            let totalSpacing = spacing * 2
            let contentWidth = max(0, proxy.size.width - totalSpacing - 8)
            let itemWidth = max(44, contentWidth / 3)
            let itemHeight = itemWidth * 1.4
            
            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(0..<9, id: \.self) { index in
                    if index == 4 {
                        // Center cell: show icon and title
                        VStack(spacing: 12) {
                            Image(systemName: iconName)
                                .font(.system(size: 32))
                                .foregroundColor(.gray.opacity(0.4))
                            
                            Text(emptyTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: itemWidth, height: itemHeight)
                        .background(Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    } else {
                        // Other cells: show placeholder with gray icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                .frame(width: itemWidth, height: itemHeight)
                                .background(Color.gray.opacity(0.05))
                            
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.gray.opacity(0.25))
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minHeight: calculateGridHeight())
    }
    
    private func calculateGridHeight() -> CGFloat {
        // Calculate height for 3 rows of items
        // We need to estimate based on screen width
        let screenWidth = UIScreen.main.bounds.width
        let totalSpacing = spacing * 2
        let contentWidth = max(0, screenWidth - totalSpacing - 8)
        let itemWidth = max(44, contentWidth / 3)
        let itemHeight = itemWidth * 1.4
        // 3 rows with 2 spacing gaps between them
        return itemHeight * 3 + spacing * 2
    }

    private var iconName: String {
        if tab == .favorites {
            return "heart.slash"
        } else if isVideoModelsTab {
            return "video.slash"
        } else if isImageModelsTab && model != nil {
            return "photo.on.rectangle"
        } else {
            return "photo.on.rectangle"
        }
    }

    private var emptyTitle: String {
        if tab == .favorites {
            return "No Favorites Yet"
        } else if isVideoModelsTab && videoModel != nil {
            return "No Videos for \(videoModel!)"
        } else if isVideoModelsTab {
            return "No Video Models Selected"
        } else if isImageModelsTab && model != nil {
            return "No Images for \(model!)"
        } else if isImageModelsTab {
            return "No Image Models Selected"
        } else {
            return "No Images Yet"
        }
    }

    private var emptyMessage: String {
        if tab == .favorites {
            return "Tap the heart icon on any image to add it to your favorites"
        } else if isVideoModelsTab && videoModel != nil {
            return "You haven't created any videos with this model yet"
        } else if isVideoModelsTab {
            return
                "Select a video model from the dropdown to view your creations"
        } else if isImageModelsTab && model != nil {
            return "You haven't created any images with this model yet"
        } else if isImageModelsTab {
            return
                "Select an image model from the dropdown to view your creations"
        } else {
            return "Start creating amazing images to see them here!"
        }
    }
}

// MARK: - IMAGE MODELS SHEET

struct ImageModelsSheet: View {
    let models: [(model: String, count: Int, imageName: String)]
    @Binding var selectedModel: String?
    @Binding var selectedVideoModel: String?
    @Binding var selectedTab: ProfileViewContent.GalleryTab
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(models, id: \.model) { modelData in
                        Button {
                            selectedTab = .imageModels
                            selectedModel = modelData.model
                            selectedVideoModel = nil  // Clear video model selection
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                // Model image with fallback
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 65, height: 65)

                                    Image(modelData.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 65, height: 65)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 8))
                                }
                                .frame(width: 65, height: 65)

                                // Model name and count
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(modelData.model)
                                        .font(
                                            .system(
                                                size: 15, weight: .bold,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)

                                    Text(
                                        "\(modelData.count) image\(modelData.count == 1 ? "" : "s")"
                                    )
                                    .font(
                                        .system(
                                            size: 12, weight: .medium,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.blue)
                                }

                                Spacer()

                                // Checkmark if selected
                                if selectedTab == .imageModels
                                    && selectedModel == modelData.model
                                {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(12)
                            .background(
                                selectedTab == .imageModels
                                    && selectedModel == modelData.model
                                    ? Color.blue.opacity(0.08)
                                    : Color.gray.opacity(0.06)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedTab == .imageModels
                                            && selectedModel == modelData.model
                                            ? Color.blue.opacity(0.3)
                                            : Color.gray.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Image Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - VIDEO MODELS SHEET

struct VideoModelsSheet: View {
    let models: [(model: String, count: Int, imageName: String)]
    @Binding var selectedModel: String?
    @Binding var selectedVideoModel: String?
    @Binding var selectedTab: ProfileViewContent.GalleryTab
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(models, id: \.model) { modelData in
                        Button {
                            selectedTab = .videoModels
                            selectedVideoModel = modelData.model
                            selectedModel = nil  // Clear image model selection
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                // Model image with fallback
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 65, height: 65)

                                    Image(modelData.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 65, height: 65)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 8))
                                }
                                .frame(width: 65, height: 65)

                                // Model name and count
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(modelData.model)
                                        .font(
                                            .system(
                                                size: 15, weight: .bold,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)

                                    Text(
                                        "\(modelData.count) video\(modelData.count == 1 ? "" : "s")"
                                    )
                                    .font(
                                        .system(
                                            size: 12, weight: .medium,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.purple)
                                }

                                Spacer()

                                // Checkmark if selected
                                if selectedTab == .videoModels
                                    && selectedVideoModel == modelData.model
                                {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.purple)
                                }
                            }
                            .padding(12)
                            .background(
                                selectedTab == .videoModels
                                    && selectedVideoModel == modelData.model
                                    ? Color.purple.opacity(0.08)
                                    : Color.gray.opacity(0.06)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedTab == .videoModels
                                            && selectedVideoModel
                                                == modelData.model
                                            ? Color.purple.opacity(0.3)
                                            : Color.gray.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Video Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - PLACEHOLDER GRID (for unsigned-in users)

struct PlaceholderGrid: View {
    let spacing: CGFloat = 2
    private let placeholderCount = 9 // 3x3 grid
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
    }
    
    var body: some View {
        GeometryReader { proxy in
            let totalSpacing = spacing * 2
            let contentWidth = max(0, proxy.size.width - totalSpacing - 8)
            let itemWidth = max(44, contentWidth / 3)
            let itemHeight = itemWidth * 1.4
            
            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(0..<placeholderCount, id: \.self) { _ in
                    UnsignedInPlaceholderCard(
                        itemWidth: itemWidth,
                        itemHeight: itemHeight
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: calculateHeight(for: placeholderCount))
    }
    
    private func calculateHeight(for count: Int) -> CGFloat {
        let rows = ceil(Double(count) / 3.0)
        let itemWidth = (UIScreen.main.bounds.width - 16) / 3
        return CGFloat(rows) * (itemWidth * 1.4 + spacing)
    }
}

// MARK: - UNSIGNED IN PLACEHOLDER CARD

struct UnsignedInPlaceholderCard: View {
    let itemWidth: CGFloat
    let itemHeight: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .frame(width: itemWidth, height: itemHeight)
    }
}

// MARK: - SIGN IN OVERLAY

struct SignInOverlay: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEmailSignIn = false
    @State private var showSignUpOverlay = false
    @State private var isGoogleSigningIn = false
    @State private var googleSignInError: String?
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow dismissing by tapping outside (optional)
                }
            
            // Sign-in card
            VStack(spacing: 24) {
                // // Close button
                // HStack {
                //     Spacer()
                //     Button(action: {
                //         // Optional: dismiss overlay
                //         // For now, we'll keep it visible until sign-in
                //     }) {
                //         Image(systemName: "xmark.circle.fill")
                //             .font(.system(size: 28))
                //             .foregroundColor(.white.opacity(0.8))
                //     }
                // }
                // .padding(.top, 8)
                // .padding(.trailing, 8)
                
                // Welcome section
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Log In")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Sign in to view and manage your creations")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Sign in buttons
                VStack(spacing: 14) {
                    // Apple Sign In
                    Button(action: {
                        handleAppleSignIn()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "applelogo")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Google Sign In
                    Button(action: {
                        Task {
                            await handleGoogleSignIn()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Email Sign In
                    Button(action: {
                        showEmailSignIn = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Email")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 32)
                
                // Terms and Privacy
                VStack(spacing: 4) {
                    Text("By continuing you agree to our")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                            .font(.footnote)
                            .underline()
                            .foregroundColor(.white.opacity(0.9))
                        Text("and")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                        Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                            .font(.footnote)
                            .underline()
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.top, 8)
                
                // Sign Up link
                Button(action: {
                    showSignUpOverlay = true
                }) {
                    Text("Don't have an account? Sign Up")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .underline()
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmbeddedEmailSignInView(isSignUp: .constant(false), isPresented: $showEmailSignIn)
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSignUpOverlay) {
            SignUpOverlay()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .alert("Sign In Error", isPresented: Binding(
            get: { googleSignInError != nil },
            set: { if !$0 { googleSignInError = nil } }
        )) {
            Button("OK", role: .cancel) {
                googleSignInError = nil
            }
            if googleSignInError == "USER_NOT_FOUND" {
                Button("Create Account") {
                    googleSignInError = nil
                    showSignUpOverlay = true
                }
            }
        } message: {
            if googleSignInError == "NONCE_ERROR" {
                Text("There was an authentication configuration error. Please try again or contact support if the issue persists.")
            } else if googleSignInError == "USER_NOT_FOUND" {
                Text("No account found with this Google email. Please create an account first.")
            } else if let error = googleSignInError {
                Text(error)
            }
        }
    }
    
    // MARK: - Apple Sign In
    func handleAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator(authViewModel: authViewModel)
        controller.performRequests()
    }
    
    // MARK: - Google Sign In
    func handleGoogleSignIn() async {
        isGoogleSigningIn = true
        googleSignInError = nil
        
        // Get the Google Client ID from Info.plist or environment
        guard let clientID = getGoogleClientID() else {
            await MainActor.run {
                googleSignInError = "Google Client ID not configured. Please add GOOGLE_CLIENT_ID to your Info.plist."
                isGoogleSigningIn = false
            }
            print("❌ Google Client ID not found")
            return
        }
        
        // Generate a random nonce for security
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        
        print("🔑 [SignInOverlay] Generated nonce - raw: \(rawNonce.prefix(10))..., hashed: \(hashedNonce.prefix(10))...")
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the presenting view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            await MainActor.run {
                googleSignInError = "Unable to find root view controller"
                isGoogleSigningIn = false
            }
            print("❌ Unable to find root view controller")
            return
        }
        
        do {
            // Perform the sign-in with the hashed nonce
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce
            )
            
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                await MainActor.run {
                    googleSignInError = "Failed to get Google ID token"
                    isGoogleSigningIn = false
                }
                print("❌ Failed to get Google ID token")
                return
            }
            
            // Get access token
            let accessToken = user.accessToken.tokenString
            
            // Sign in with Supabase - pass the RAW nonce
            await authViewModel.signInWithGoogle(idToken: idToken, accessToken: accessToken, rawNonce: rawNonce)
            
            await MainActor.run {
                isGoogleSigningIn = false
                // Check if sign-in failed and show appropriate message
                if !authViewModel.isSignedIn {
                    if let error = authViewModel.lastError {
                        if error == "USER_NOT_FOUND" {
                            googleSignInError = "USER_NOT_FOUND"
                        } else {
                            googleSignInError = error
                        }
                    } else {
                        googleSignInError = "Failed to sign in with Google. Please try again."
                    }
                }
            }
        } catch {
            await MainActor.run {
                googleSignInError = error.localizedDescription
                isGoogleSigningIn = false
            }
            print("❌ Google sign-in error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Nonce Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        inputData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(inputData.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func getGoogleClientID() -> String? {
        // Try to get from Info.plist first
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String {
            return clientID
        }
        
        // Try to get from environment variable (for development)
        if let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] {
            return clientID
        }
        
        return nil
    }
}

// MARK: - SIGN UP OVERLAY

struct SignUpOverlay: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEmailSignIn = false
    @State private var isGoogleSigningIn = false
    @State private var googleSignInError: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Sign-up card
            VStack(spacing: 24) {
                // Welcome section
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Create Your Account")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Sign up to start creating amazing images")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Sign up buttons
                VStack(spacing: 14) {
                    // Apple Sign Up
                    Button(action: {
                        handleAppleSignUp()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "applelogo")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Google Sign Up
                    Button(action: {
                        Task {
                            await handleGoogleSignIn()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            if isGoogleSigningIn {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(isGoogleSigningIn)
                    
                    // Email Sign Up
                    Button(action: {
                        showEmailSignIn = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Email")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 32)
                
                // Terms and Privacy
                VStack(spacing: 4) {
                    Text("By signing up you agree to our")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                            .font(.footnote)
                            .underline()
                            .foregroundColor(.white.opacity(0.9))
                        Text("and")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                        Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                            .font(.footnote)
                            .underline()
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.top, 8)
                
                // Sign In link
                Button(action: {
                    dismiss()
                }) {
                    Text("Already have an account? Sign In")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .underline()
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmbeddedEmailSignInView(isSignUp: .constant(true), isPresented: $showEmailSignIn)
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .alert("Sign Up Error", isPresented: Binding(
            get: { googleSignInError != nil },
            set: { if !$0 { googleSignInError = nil } }
        )) {
            Button("OK", role: .cancel) {
                googleSignInError = nil
            }
        } message: {
            if googleSignInError == "NONCE_ERROR" {
                Text("There was an authentication configuration error. Please try again or contact support if the issue persists.")
            } else if googleSignInError == "USER_NOT_FOUND" {
                // This shouldn't happen on sign-up page, but handle it just in case
                Text("Unable to create account. Please try again or contact support.")
            } else if let error = googleSignInError {
                Text(error)
            }
        }
    }
    
    // MARK: - Apple Sign Up
    func handleAppleSignUp() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator(authViewModel: authViewModel)
        controller.performRequests()
    }
    
    // MARK: - Google Sign In
    func handleGoogleSignIn() async {
        isGoogleSigningIn = true
        googleSignInError = nil
        
        // Get the Google Client ID from Info.plist or environment
        guard let clientID = getGoogleClientID() else {
            await MainActor.run {
                googleSignInError = "Google Client ID not configured. Please add GOOGLE_CLIENT_ID to your Info.plist."
                isGoogleSigningIn = false
            }
            print("❌ Google Client ID not found")
            return
        }
        
        // Generate a random nonce for security
        // This raw nonce will be passed to Supabase
        // The SHA256 hash will be passed to Google
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        
        print("🔑 [SignUpOverlay] Generated nonce - raw: \(rawNonce.prefix(10))..., hashed: \(hashedNonce.prefix(10))...")
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the presenting view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            await MainActor.run {
                googleSignInError = "Unable to find root view controller"
                isGoogleSigningIn = false
            }
            print("❌ Unable to find root view controller")
            return
        }
        
        do {
            // Perform the sign-in with the hashed nonce
            // Google will include this hash in the ID token
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce
            )
            
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                await MainActor.run {
                    googleSignInError = "Failed to get Google ID token"
                    isGoogleSigningIn = false
                }
                print("❌ Failed to get Google ID token")
                return
            }
            
            // Get access token
            let accessToken = user.accessToken.tokenString
            
            print("🔑 [SignUpOverlay] Calling signInWithGoogle with raw nonce...")
            // Sign in with Supabase - pass the RAW nonce (not hashed)
            // Supabase will hash it and compare to the hash in the ID token
            await authViewModel.signInWithGoogle(idToken: idToken, accessToken: accessToken, rawNonce: rawNonce)
            
            await MainActor.run {
                isGoogleSigningIn = false
                if authViewModel.isSignedIn {
                    print("✅ [SignUpOverlay] Sign-in successful, dismissing...")
                    dismiss()
                } else {
                    // Show the actual error message
                    if let error = authViewModel.lastError {
                        print("❌ [SignUpOverlay] Error from AuthViewModel: \(error)")
                        googleSignInError = error
                    } else {
                        print("❌ [SignUpOverlay] Unknown error - isSignedIn is false but no error set")
                        googleSignInError = "Failed to create account. Please check your Supabase configuration."
                    }
                }
            }
        } catch {
            await MainActor.run {
                googleSignInError = error.localizedDescription
                isGoogleSigningIn = false
            }
            print("❌ Google sign-in error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Nonce Helpers
    
    /// Generates a random string for use as a nonce
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    /// Creates a SHA256 hash of the input string
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        inputData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(inputData.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func getGoogleClientID() -> String? {
        // Try to get from Info.plist first
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String {
            return clientID
        }
        
        // Try to get from environment variable (for development)
        if let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] {
            return clientID
        }
        
        return nil
    }
}

// MARK: - EMBEDDED SIGN IN VIEW

struct EmbeddedSignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEmailSignIn = false
    @State private var isSignUp = false
    @State private var isGoogleSigningIn = false
    @State private var googleSignInError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)
                
                // Welcome section
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Log In")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Sign in to view and manage your creations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)
                
                // Sign in buttons
                VStack(spacing: 16) {
                    // Apple Sign In
                    Button(action: {
                        handleAppleSignIn()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "applelogo")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Google Sign In
                    Button(action: {
                        Task {
                            await handleGoogleSignIn()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Email Sign In
                    Button(action: {
                        showEmailSignIn = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Email")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                // Terms and Privacy
                VStack(spacing: 4) {
                    Text("By continuing you agree to our")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                            .font(.footnote)
                            .underline()
                        Text("and")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                            .font(.footnote)
                            .underline()
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmbeddedEmailSignInView(isSignUp: $isSignUp, isPresented: $showEmailSignIn)
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .alert("Google Sign-In", isPresented: Binding(
            get: { googleSignInError != nil },
            set: { if !$0 { googleSignInError = nil } }
        )) {
            Button("OK", role: .cancel) {
                googleSignInError = nil
            }
            if googleSignInError == "No account found with this Google email. Please create an account first using the 'Create Your Account' page." {
                Button("Create Account") {
                    googleSignInError = nil
                    isSignUp = true
                }
            }
        } message: {
            if let error = googleSignInError {
                Text(error)
            }
        }
    }
    
    // MARK: - Apple Sign In
    func handleAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator(authViewModel: authViewModel)
        controller.performRequests()
    }
    
    // MARK: - Google Sign In
    func handleGoogleSignIn() async {
        isGoogleSigningIn = true
        googleSignInError = nil
        
        // Get the Google Client ID from Info.plist or environment
        guard let clientID = getGoogleClientID() else {
            await MainActor.run {
                googleSignInError = "Google Client ID not configured. Please add GOOGLE_CLIENT_ID to your Info.plist."
                isGoogleSigningIn = false
            }
            print("❌ Google Client ID not found")
            return
        }
        
        // Generate a random nonce for security
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        
        print("🔑 [EmbeddedSignInView] Generated nonce - raw: \(rawNonce.prefix(10))..., hashed: \(hashedNonce.prefix(10))...")
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the presenting view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            await MainActor.run {
                googleSignInError = "Unable to find root view controller"
                isGoogleSigningIn = false
            }
            print("❌ Unable to find root view controller")
            return
        }
        
        do {
            // Perform the sign-in with the hashed nonce
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce
            )
            
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                await MainActor.run {
                    googleSignInError = "Failed to get Google ID token"
                    isGoogleSigningIn = false
                }
                print("❌ Failed to get Google ID token")
                return
            }
            
            // Get access token
            let accessToken = user.accessToken.tokenString
            
            // Sign in with Supabase - pass the RAW nonce
            await authViewModel.signInWithGoogle(idToken: idToken, accessToken: accessToken, rawNonce: rawNonce)
            
            await MainActor.run {
                isGoogleSigningIn = false
                // Check if sign-in failed and show appropriate message
                if !authViewModel.isSignedIn {
                    if let error = authViewModel.lastError {
                        if error == "USER_NOT_FOUND" {
                            googleSignInError = "USER_NOT_FOUND"
                        } else {
                            googleSignInError = error
                        }
                    } else {
                        googleSignInError = "Failed to sign in with Google. Please try again."
                    }
                }
            }
        } catch {
            await MainActor.run {
                googleSignInError = error.localizedDescription
                isGoogleSigningIn = false
            }
            print("❌ Google sign-in error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Nonce Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        inputData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(inputData.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func getGoogleClientID() -> String? {
        // Try to get from Info.plist first
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String {
            return clientID
        }
        
        // Try to get from environment variable (for development)
        if let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] {
            return clientID
        }
        
        return nil
    }
}

// MARK: - EMBEDDED EMAIL SIGN IN VIEW

struct EmbeddedEmailSignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isSignUp: Bool
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var message: String? = nil
    @State private var messageColor: Color = .red
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.primary)
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Message Area
                    if let message = message {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(messageColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Sign In / Sign Up button
                    Button(isSignUp ? "Sign Up" : "Sign In") {
                        Task {
                            guard !email.isEmpty, !password.isEmpty else {
                                showMessage("Please enter both email and password.", color: .red)
                                return
                            }
                            
                            if isSignUp {
                                await authViewModel.signUpWithEmail(email: email, password: password)
                            } else {
                                await authViewModel.signInWithEmail(email: email, password: password)
                            }
                            
                            if authViewModel.isSignedIn {
                                showMessage("Signed in successfully ✅", color: .green)
                                // Close sheet after successful sign in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isPresented = false
                                }
                            } else {
                                // Check for specific error messages
                                if let error = authViewModel.lastError {
                                    if error == "USER_EXISTS" {
                                        showMessage("This email is already registered. Please sign in instead.", color: .orange)
                                    } else {
                                        showMessage(error, color: .red)
                                    }
                                } else {
                                    showMessage("Incorrect email or password.", color: .red)
                                }
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    
                    // Forgot password (only for sign in)
                    if !isSignUp {
                        Button(action: {
                            showForgotPassword = true
                        }) {
                            Text("Forgot password?")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Terms & Privacy (only for sign up)
                    if isSignUp {
                        VStack(spacing: 4) {
                            Text("By signing up you agree to our")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                                    .font(.footnote)
                                    .underline()
                                Text("and")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                                    .font(.footnote)
                                    .underline()
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .padding()
                .padding(.top, 20)
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(isPresented: $showForgotPassword)
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func showMessage(_ text: String, color: Color) {
        withAnimation {
            message = text
            messageColor = color
        }
    }
}

// MARK: - URL Identifiable

extension URL: Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController, context: Context
    ) {}
}
