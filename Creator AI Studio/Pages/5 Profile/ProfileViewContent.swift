import Photos
import SwiftUI
import UIKit

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
                        count: viewModel.imageCount + viewModel.videoCount,
                        isSignedIn: isSignedIn
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
                        // Use actualFavoriteCount to ensure it includes both images and videos
                        // This counts from actual data, ensuring videos are included
                        // Falls back to favoriteCount from stats if userImages is empty
                        count: viewModel.userImages.isEmpty ? viewModel.favoriteCount : viewModel.actualFavoriteCount,
                        isSignedIn: isSignedIn
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

            // Show count when not selected or when showing all models, and user is signed in
            if isSignedIn && !isSelected && modelCount > 0 {
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

            // Show count when not selected or when showing all models, and user is signed in
            if isSignedIn && !isSelected && modelCount > 0 {
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

