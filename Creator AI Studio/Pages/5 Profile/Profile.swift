import AVKit
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
            VStack {
                if let user = authViewModel.user {
                    ProfileViewContent(viewModel: viewModel)
                        .environmentObject(authViewModel)
                        .onAppear {
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
                                //                            print("📸 Fetched \(viewModel.images.count) images")
                            }
                        }
                } else {
                    Text("Loading user…")
                }
            }

            // MARK: NAVIGATION BAR

            .navigationTitle("")
            .toolbar {
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

// MARK: STRUCT PROFILEVIEWCONTENT

struct ProfileViewContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    //    @StateObject private var presetViewModel = PresetViewModel()
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

    // Compute models with metadata - returns immediately without caching
    private func computeModelsWithMetadata() -> [(
        model: String, count: Int, imageName: String
    )] {
        // Use modelCounts if available (from database query), otherwise fall back to uniqueModels
        let modelNames: [String]
        if !viewModel.modelCounts.isEmpty {
            modelNames = Array(viewModel.modelCounts.keys).sorted()
            print("🔍 DEBUG: Computing models from modelCounts: \(modelNames.count) models")
        } else {
            modelNames = viewModel.uniqueModels
            print("🔍 DEBUG: Computing models from uniqueModels: \(modelNames.count) models")
        }

        var result: [(String, Int, String)] = []

        for modelName in modelNames {
            // Use count from modelCounts if available, otherwise filter from userImages
            let count: Int
            if let dbCount = viewModel.modelCounts[modelName], dbCount > 0 {
                count = dbCount
            } else {
                count = viewModel.filteredImages(by: modelName, favoritesOnly: false).count
            }
            
            print("🔍 DEBUG: Model '\(modelName)' has \(count) images")
            guard count > 0 else { continue }

            // Find the model image from ImageModelData using display.imageName
            var imageName = "photo.on.rectangle.angled"  // fallback
            if let modelInfo = allImageModels.first(where: {
                $0.display.modelName == modelName
            }) {
                imageName = modelInfo.display.imageName
                print(
                    "🔍 DEBUG: Found model info by modelName: \(modelName) -> \(imageName)"
                )
            } else if let modelInfo = allImageModels.first(where: {
                $0.display.title == modelName
            }) {
                imageName = modelInfo.display.imageName
                print(
                    "🔍 DEBUG: Found model info by title: \(modelName) -> \(imageName)"
                )
            } else {
                print(
                    "⚠️ DEBUG: No model info found for: \(modelName), using fallback"
                )
            }

            result.append((modelName, count, imageName))
        }

        // Sort by count descending
        let sorted = result.sorted { $0.1 > $1.1 }
        print("🔍 DEBUG: Computed \(sorted.count) models")
        return sorted
    }

    // Compute video models with metadata - returns immediately without caching
    private func computeVideoModelsWithMetadata() -> [(
        model: String, count: Int, imageName: String
    )] {
        // Use videoModelCounts if available (from database query), otherwise fall back to uniqueVideoModels
        let modelNames: [String]
        if !viewModel.videoModelCounts.isEmpty {
            modelNames = Array(viewModel.videoModelCounts.keys).sorted()
            print("🎬 DEBUG: Computing video models from videoModelCounts: \(modelNames.count) models")
        } else {
            modelNames = viewModel.uniqueVideoModels
            print("🎬 DEBUG: Computing video models from uniqueVideoModels: \(modelNames.count) models")
        }

        var result: [(String, Int, String)] = []

        for modelName in modelNames {
            // Use count from videoModelCounts if available, otherwise filter from userVideos
            let count: Int
            if let dbCount = viewModel.videoModelCounts[modelName], dbCount > 0 {
                count = dbCount
            } else {
                count = viewModel.filteredVideos(by: modelName, favoritesOnly: false).count
            }
            
            print("🎬 DEBUG: Video Model '\(modelName)' has \(count) videos")
            guard count > 0 else { continue }

            // Find the model image from VideoModelData using display.imageName
            var imageName = "video.fill"  // fallback
            if let modelInfo = allVideoModels.first(where: {
                $0.display.modelName == modelName
            }) {
                imageName = modelInfo.display.imageName
                print(
                    "🎬 DEBUG: Found video model info by modelName: \(modelName) -> \(imageName)"
                )
            } else if let modelInfo = allVideoModels.first(where: {
                $0.display.title == modelName
            }) {
                imageName = modelInfo.display.imageName
                print(
                    "🎬 DEBUG: Found video model info by title: \(modelName) -> \(imageName)"
                )
            } else {
                print(
                    "⚠️ DEBUG: No video model info found for: \(modelName), using fallback"
                )
            }

            result.append((modelName, count, imageName))
        }

        // Sort by count descending
        let sorted = result.sorted { $0.1 > $1.1 }
        print("🎬 DEBUG: Computed \(sorted.count) video models")
        return sorted
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            filterSection

                            contentSection
                        }
                        .padding(.top, 10)
                        .id("scrollTop")
                    }

                    // Scroll to top button overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo("scrollTop", anchor: .top)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.9))
                                        .frame(width: 50, height: 50)
                                        // .overlay(
                                        //     Circle()
                                        //         .stroke(Color.black, lineWidth: 2)
                                        // )
                                        .shadow(
                                            color: .black.opacity(0.5),
                                            radius: 4, x: 0, y: 2)

                                    Image(systemName: "arrow.up")
                                        .font(
                                            .system(size: 20, weight: .semibold)
                                        )
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 75)
                        }
                    }
                }
                //                .navigationTitle("Profile")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isSelectionMode {
                            HStack(spacing: 12) {
                                // Save button
                                Button(action: {
                                    if selectedImageIds.isEmpty {
                                        noSelectionAlertMessage =
                                            "Please select at least one image to save."
                                        showNoSelectionAlert = true
                                    } else {
                                        Task {
                                            await saveSelectedImages()
                                        }
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.blue)
                                            .opacity(0.8)
                                        Text("Save")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isSaving || isDeleting)

                                // Share button
                                Button(action: {
                                    if selectedImageIds.isEmpty {
                                        noSelectionAlertMessage =
                                            "Please select at least one image to share."
                                        showNoSelectionAlert = true
                                    } else {
                                        Task {
                                            await shareSelectedImages()
                                        }
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.blue)
                                            .opacity(0.8)
                                        Text("Share")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .disabled(isSharing || isDeleting)

                                // Delete button
                                Button(action: {
                                    if selectedImageIds.isEmpty {
                                        noSelectionAlertMessage =
                                            "Please select at least one image to delete."
                                        showNoSelectionAlert = true
                                    } else {
                                        showDeleteConfirmation = true
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.red)
                                            .opacity(0.8)
                                        Text("Delete")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.top, 2)
                                }
                                .buttonStyle(.plain)
                                .disabled(isDeleting)

                                Button(action: {
                                    isSelectionMode = false
                                    selectedImageIds.removeAll()
                                }) {
                                    Text("Cancel")
                                        .font(.body)
                                        .foregroundColor(.blue)
                                }
                            }
                        } else {
                            HStack(spacing: 16) {
                                Button(action: {
                                    isSelectionMode = true
                                }) {
                                    Text("Select")
                                        .font(.body)
                                        .foregroundColor(.gray)
                                }

                                NavigationLink(
                                    destination: Settings().environmentObject(
                                        authViewModel)
                                ) {
                                    Image(systemName: "gearshape")
                                        .font(.body)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            //            .onAppear {
            //                if let userId = authViewModel.user?.id.uuidString {
            //                    Task {
            //                        presetViewModel.userId = userId
            //                        await presetViewModel.fetchPresets()
            //                    }
            //                }
            //            }
            .onChange(of: notificationManager.notifications.count) {
                oldCount, newCount in
                // When notification count decreases (notification dismissed), refresh images
                if newCount < oldCount {
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
            }
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

                    // // Presets pill
                    // GalleryTabPill(
                    //     title: "Presets",
                    //     icon: "slider.horizontal.3",
                    //     isSelected: false,
                    //     count: presetViewModel.presets.count
                    // ) {
                    //     showPresetsSheet = true
                    // }

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
            print("🔍 DEBUG: Image Models button tapped")
            showImageModelsPopover = true
        } label: {
            imageModelsButtonLabel
        }
        .sheet(isPresented: $showImageModelsPopover) {
            let models = computeModelsWithMetadata()
            print(
                "🔍 DEBUG: Sheet builder - Passing \(models.count) models to sheet"
            )
            return ImageModelsSheet(
                models: models,
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
            print("🎬 DEBUG: Video Models button tapped")
            showVideoModelsPopover = true
        } label: {
            videoModelsButtonLabel
        }
        .sheet(isPresented: $showVideoModelsPopover) {
            let models = computeVideoModelsWithMetadata()
            print(
                "🎬 DEBUG: Sheet builder - Passing \(models.count) video models to sheet"
            )
            return VideoModelsSheet(
                models: models,
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

        if filteredImages.isEmpty
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

    var body: some View {
        GeometryReader { proxy in
            let totalSpacing = spacing * 2
            let contentWidth = max(0, proxy.size.width - totalSpacing - 8)
            let itemWidth = max(44, contentWidth / 3)  // minimum thumbnail size
            let itemHeight = itemWidth * 1.4

            LazyVGrid(columns: gridColumns, spacing: spacing) {
                // Show placeholders first (in-progress generations)
                ForEach(placeholders) { placeholder in
                    PlaceholderImageCard(
                        placeholder: placeholder,
                        itemWidth: itemWidth,
                        itemHeight: itemHeight
                    )
                }

                // Then show completed images
                ForEach(userImages) { userImage in
                    if let displayUrl = userImage.isVideo
                        ? userImage.thumbnail_url : userImage.image_url,
                        let url = URL(string: displayUrl)
                    {
                        ZStack {
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
                                        .frame(
                                            width: itemWidth, height: itemHeight
                                        )
                                        .clipped()
                                        .overlay(
                                            // Selection overlay
                                            Group {
                                                if isSelectionMode {
                                                    Rectangle()
                                                        .fill(
                                                            Color.black.opacity(
                                                                selectedImageIds
                                                                    .contains(
                                                                        userImage
                                                                            .id)
                                                                    ? 0.3 : 0))
                                                }
                                            }
                                        )
                                        .overlay(
                                            // Checkmark overlay
                                            Group {
                                                if isSelectionMode {
                                                    VStack {
                                                        HStack {
                                                            Spacer()
                                                            ZStack {
                                                                Circle()
                                                                    .fill(
                                                                        selectedImageIds
                                                                            .contains(
                                                                                userImage
                                                                                    .id
                                                                            )
                                                                            ? Color
                                                                                .blue
                                                                            : Color
                                                                                .white
                                                                                .opacity(
                                                                                    0.3
                                                                                )
                                                                    )
                                                                    .frame(
                                                                        width:
                                                                            24,
                                                                        height:
                                                                            24)
                                                                if selectedImageIds
                                                                    .contains(
                                                                        userImage
                                                                            .id)
                                                                {
                                                                    Image(
                                                                        systemName:
                                                                            "checkmark"
                                                                    )
                                                                    .font(
                                                                        .system(
                                                                            size:
                                                                                14,
                                                                            weight:
                                                                                .bold
                                                                        )
                                                                    )
                                                                    .foregroundColor(
                                                                        .white)
                                                                }
                                                            }
                                                            .padding(6)
                                                        }
                                                        Spacer()
                                                    }
                                                }
                                            }
                                        )

                                    // Video play icon overlay
                                    if userImage.isVideo {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.6))
                                                .frame(width: 40, height: 40)

                                            Image(systemName: "play.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            // Heart icon and bookmark icon overlay (only show when not in selection mode)
                            if !isSelectionMode {
                                VStack {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Color.clear
                                                    .frame(
                                                        width: 32, height: 32
                                                    )
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        if let viewModel =
                                                            viewModel
                                                        {
                                                            Task {
                                                                await viewModel
                                                                    .toggleFavorite(
                                                                        imageId:
                                                                            userImage
                                                                            .id)
                                                            }
                                                        } else {
                                                            // Fallback to local state if no viewModel
                                                            let imageId =
                                                                userImage.id
                                                            if favoritedImageIds
                                                                .contains(
                                                                    imageId)
                                                            {
                                                                favoritedImageIds
                                                                    .remove(
                                                                        imageId)
                                                            } else {
                                                                favoritedImageIds
                                                                    .insert(
                                                                        imageId)
                                                            }
                                                        }
                                                    }

                                                // Heart icon
                                                Image(
                                                    systemName: (userImage
                                                        .is_favorite ?? false)
                                                        ? "heart.fill" : "heart"
                                                )
                                                .font(
                                                    .system(
                                                        size: 16,
                                                        weight: .semibold)
                                                )
                                                .foregroundColor(
                                                    (userImage.is_favorite
                                                        ?? false)
                                                        ? .red : .white
                                                )
                                                .shadow(
                                                    color: .black.opacity(0.5),
                                                    radius: 2, x: 0, y: 1
                                                )
                                                .allowsHitTesting(false)
                                            }

                                            // // Bookmark icon (blue) if preset is enabled
                                            // if hasMatchingPreset(for: userImage) {
                                            //     ZStack {
                                            //         Circle()
                                            //             .fill(Color.black)
                                            //             .frame(width: 28, height: 28)

                                            //         Image(systemName: "bookmark.fill")
                                            //             .font(.system(size: 12, weight: .semibold))
                                            //             .foregroundColor(.blue)
                                            //     }
                                            //     .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                            // }
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .onAppear {
                            // Trigger loading more when we're 10 items from the end
                            if let viewModel = viewModel,
                                let index = userImages.firstIndex(where: {
                                    $0.id == userImage.id
                                }),
                                index >= userImages.count - 10
                            {
                                Task {
                                    if isFavoritesTab {
                                        await viewModel.loadMoreFavorites()
                                    } else {
                                        await viewModel.loadMoreImages()
                                    }
                                }
                            }
                        }

                    } else if let url = URL(string: userImage.image_url) {
                        // Fallback for videos without thumbnails
                        ZStack {
                            Button {
                                onSelect(userImage)
                            } label: {
                                ZStack {
                                    KFImage(url)
                                        .placeholder {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .overlay(
                                                    Image(
                                                        systemName: "video.fill"
                                                    )
                                                    .font(.largeTitle)
                                                    .foregroundColor(.gray)
                                                )
                                        }
                                        .resizable()
                                        .scaledToFill()
                                        .frame(
                                            width: itemWidth, height: itemHeight
                                        )
                                        .clipped()
                                        .overlay(
                                            // Selection overlay
                                            Group {
                                                if isSelectionMode {
                                                    Rectangle()
                                                        .fill(
                                                            Color.black.opacity(
                                                                selectedImageIds
                                                                    .contains(
                                                                        userImage
                                                                            .id)
                                                                    ? 0.3 : 0))
                                                }
                                            }
                                        )
                                        .overlay(
                                            // Checkmark overlay
                                            Group {
                                                if isSelectionMode {
                                                    VStack {
                                                        HStack {
                                                            Spacer()
                                                            ZStack {
                                                                Circle()
                                                                    .fill(
                                                                        selectedImageIds
                                                                            .contains(
                                                                                userImage
                                                                                    .id
                                                                            )
                                                                            ? Color
                                                                                .blue
                                                                            : Color
                                                                                .white
                                                                                .opacity(
                                                                                    0.3
                                                                                )
                                                                    )
                                                                    .frame(
                                                                        width:
                                                                            24,
                                                                        height:
                                                                            24)
                                                                if selectedImageIds
                                                                    .contains(
                                                                        userImage
                                                                            .id)
                                                                {
                                                                    Image(
                                                                        systemName:
                                                                            "checkmark"
                                                                    )
                                                                    .font(
                                                                        .system(
                                                                            size:
                                                                                14,
                                                                            weight:
                                                                                .bold
                                                                        )
                                                                    )
                                                                    .foregroundColor(
                                                                        .white)
                                                                }
                                                            }
                                                            .padding(6)
                                                        }
                                                        Spacer()
                                                    }
                                                }
                                            }
                                        )

                                    if userImage.isVideo {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.6))
                                                .frame(width: 40, height: 40)

                                            Image(systemName: "play.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            // Heart icon and bookmark icon overlay (only show when not in selection mode)
                            if !isSelectionMode {
                                VStack {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Color.clear
                                                    .frame(
                                                        width: 32, height: 32
                                                    )
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        if let viewModel =
                                                            viewModel
                                                        {
                                                            Task {
                                                                await viewModel
                                                                    .toggleFavorite(
                                                                        imageId:
                                                                            userImage
                                                                            .id)
                                                            }
                                                        } else {
                                                            // Fallback to local state if no viewModel
                                                            let imageId =
                                                                userImage.id
                                                            if favoritedImageIds
                                                                .contains(
                                                                    imageId)
                                                            {
                                                                favoritedImageIds
                                                                    .remove(
                                                                        imageId)
                                                            } else {
                                                                favoritedImageIds
                                                                    .insert(
                                                                        imageId)
                                                            }
                                                        }
                                                    }

                                                // Heart icon
                                                Image(
                                                    systemName: (userImage
                                                        .is_favorite ?? false)
                                                        ? "heart.fill" : "heart"
                                                )
                                                .font(
                                                    .system(
                                                        size: 16,
                                                        weight: .semibold)
                                                )
                                                .foregroundColor(
                                                    (userImage.is_favorite
                                                        ?? false)
                                                        ? .red : .white
                                                )
                                                .shadow(
                                                    color: .black.opacity(0.5),
                                                    radius: 2, x: 0, y: 1
                                                )
                                                .allowsHitTesting(false)
                                            }

                                            // // Bookmark icon (blue) if preset is enabled
                                            // if hasMatchingPreset(for: userImage) {
                                            //     ZStack {
                                            //         Circle()
                                            //             .fill(Color.gray.opacity(0.7))
                                            //             .frame(width: 24, height: 24)

                                            //         Image(systemName: "bookmark.fill")
                                            //             .font(.system(size: 12, weight: .semibold))
                                            //             .foregroundColor(.blue)
                                            //     }
                                            //     .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                            // }
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .onAppear {
                            // Trigger loading more when we're 10 items from the end
                            if let viewModel = viewModel,
                                let index = userImages.firstIndex(where: {
                                    $0.id == userImage.id
                                }),
                                index >= userImages.count - 10
                            {
                                Task {
                                    if isFavoritesTab {
                                        await viewModel.loadMoreFavorites()
                                    } else {
                                        await viewModel.loadMoreImages()
                                    }
                                }
                            }
                        }
                    }
                }

                // Loading indicator for pagination
                if let viewModel = viewModel, viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(
            height: calculateHeight(for: placeholders.count + userImages.count))
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

    var body: some View {
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
        .padding(.vertical, 60)
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
                    // Text("🔍 Models in sheet: \(models.count)")
                    //     .font(.caption)
                    //     .foregroundColor(.red)
                    //     .padding()

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
            .onAppear {
                print("🔍 DEBUG: Sheet appeared with \(models.count) models")
                for model in models {
                    print(
                        "🔍 DEBUG: Sheet model: \(model.model) - \(model.count) images - image: \(model.imageName)"
                    )
                }
            }
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
            .onAppear {
                print(
                    "🎬 DEBUG: Video Models Sheet appeared with \(models.count) models"
                )
                for model in models {
                    print(
                        "🎬 DEBUG: Sheet model: \(model.model) - \(model.count) videos - image: \(model.imageName)"
                    )
                }
            }
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
//
//// MARK: - PRESETS LIST SHEET
//
//struct PresetsListSheet: View {
//    @ObservedObject var presetViewModel: PresetViewModel
//    @Binding var isPresented: Bool
////    @State private var presetToDelete: Preset? = nil
//    @State private var showDeleteConfirmation = false
//    @State private var isEditMode = false
////    @State private var selectedPreset: Preset? = nil
//
//    var body: some View {
//        NavigationStack {
//            Group {
//                if presetViewModel.isLoading && presetViewModel.presets.isEmpty {
//                    ProgressView("Loading presets…")
//                        .padding()
//                } else if presetViewModel.presets.isEmpty {
//                    ScrollView {
//                        EmptyPresetsView()
//                            .padding(.vertical, 60)
//                    }
//                } else {
//                    if isEditMode {
//                        // Edit mode with drag and drop using List
//                        List {
//                            ForEach(presetViewModel.presets) { preset in
//                                PresetRow(
//                                    preset: preset,
//                                    isEditMode: true,
//                                    onDelete: {
//                                        presetToDelete = preset
//                                        showDeleteConfirmation = true
//                                    }
//                                )
//                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
//                                .listRowBackground(Color.clear)
//                            }
//                            .onMove { source, destination in
//                                presetViewModel.reorderPresets(from: source, to: destination)
//                            }
//                        }
//                        .listStyle(.plain)
//                        .environment(\.editMode, .constant(.active))
//                    } else {
//                        // Normal mode with tap navigation
//                        ScrollView {
//                            LazyVStack(spacing: 0) {
//                                ForEach(presetViewModel.presets) { preset in
//                                    Button {
//                                        selectedPreset = preset
//                                    } label: {
//                                        PresetRow(preset: preset, isEditMode: false, onDelete: nil)
//                                            .padding(.horizontal)
//                                            .padding(.vertical, 8)
//                                    }
//                                    .buttonStyle(.plain)
//                                }
//                            }
//                            .padding(.vertical)
//                        }
//                    }
//                }
//            }
//            .navigationTitle("Presets")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    if !presetViewModel.presets.isEmpty {
//                        Button(isEditMode ? "Done" : "Edit") {
//                            isEditMode.toggle()
//                        }
//                    }
//                }
//                // ToolbarItem(placement: .navigationBarTrailing) {
//                //     Button("Done") {
//                //         isPresented = false
//                //     }
//                // }
//            }
//            .alert("Delete Preset", isPresented: $showDeleteConfirmation) {
//                Button("Cancel", role: .cancel) {
//                    presetToDelete = nil
//                }
//                Button("Delete", role: .destructive) {
//                    if let preset = presetToDelete {
//                        Task {
//                            do {
//                                try await presetViewModel.deletePreset(presetId: preset.id)
//                            } catch {
//                                print("❌ Failed to delete preset: \(error)")
//                            }
//                        }
//                    }
//                    presetToDelete = nil
//                }
//            } message: {
//                if let preset = presetToDelete {
//                    Text("Are you sure you want to delete \"\(preset.title)\"?")
//                }
//            }
//            .sheet(item: $selectedPreset) { preset in
//                PresetDetailView(
//                    preset: preset,
//                    presetViewModel: presetViewModel,
//                    isPresented: Binding(
//                        get: { selectedPreset != nil },
//                        set: { if !$0 { selectedPreset = nil } }
//                    )
//                )
//                .presentationDetents([.large])
//                .presentationDragIndicator(.visible)
//            }
//            .onAppear {
//                Task {
//                    await presetViewModel.fetchPresets(forceRefresh: true)
//                }
//            }
//        }
//    }
//}

//// MARK: - Preset Row
//
//private struct PresetRow: View {
////    let preset: Preset
//    let isEditMode: Bool
//    let onDelete: (() -> Void)?
//
//    var body: some View {
//        HStack(spacing: 12) {
//            // // Drag handle in edit mode
//            // if isEditMode {
//            //     Image(systemName: "line.3.horizontal")
//            //         .font(.system(size: 16, weight: .medium))
//            //         .foregroundColor(.secondary)
//            //         .padding(.trailing, 4)
//            // }
//
//            // Icon or image
//            ZStack {
//                RoundedRectangle(cornerRadius: 8)
//                    .fill(Color.blue.opacity(0.1))
//                    .frame(width: 60, height: 60)
//
//                if let imageUrl = preset.imageUrl, let url = URL(string: imageUrl) {
//                    KFImage(url)
//                        .placeholder {
//                            Image(systemName: "slider.horizontal.3")
//                                .font(.system(size: 24))
//                                .foregroundColor(.blue)
//                        }
//                        .resizable()
//                        .aspectRatio(contentMode: .fill)
//                        .frame(width: 60, height: 60)
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                } else {
//                    Image(systemName: "slider.horizontal.3")
//                        .font(.system(size: 24))
//                        .foregroundColor(.blue)
//                }
//            }
//            .frame(width: 60, height: 60)
//
//            // Preset details
//            VStack(alignment: .leading, spacing: 6) {
//                Text(preset.title)
//                    .font(.system(size: 16, weight: .semibold, design: .rounded))
//                    .foregroundColor(.primary)
//                    .lineLimit(1)
//
//                if let modelName = preset.modelName, !modelName.isEmpty {
//                    HStack(spacing: 4) {
//                        Image(systemName: "cpu")
//                            .font(.system(size: 11))
//                            .foregroundColor(.secondary)
//                        Text(modelName)
//                            .font(.system(size: 13, weight: .medium, design: .rounded))
//                            .foregroundColor(.secondary)
//                            .lineLimit(1)
//                    }
//                }
//
//                if let prompt = preset.prompt, !prompt.isEmpty {
//                    Text(prompt)
//                        .font(.system(size: 12, design: .rounded))
//                        .foregroundColor(.secondary)
//                        .lineLimit(2)
//                }
//            }
//
//            Spacer()
//
//            // Delete button in edit mode, chevron in normal mode
//            if isEditMode {
//                Button(action: {
//                    onDelete?()
//                }) {
//                    Image(systemName: "minus.circle.fill")
//                        .font(.system(size: 24))
//                        .foregroundColor(.red)
//                }
//                .buttonStyle(.plain)
//            } else {
//                Image(systemName: "chevron.right")
//                    .font(.system(size: 12, weight: .medium))
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding(12)
//        .background(Color.gray.opacity(0.06))
//        .clipShape(RoundedRectangle(cornerRadius: 12))
//        .overlay(
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//        )
//    }
//}
//
//// MARK: - Preset Detail View
//
//struct PresetDetailView: View {
//    let preset: Preset
//    @ObservedObject var presetViewModel: PresetViewModel
//    @Binding var isPresented: Bool
//
//    @State private var title: String
//    @State private var modelName: String
//    @State private var prompt: String
//    @State private var isSaving = false
//    @State private var showDeleteConfirmation = false
//    @State private var showError = false
//    @State private var errorMessage = ""
//    @FocusState private var focusedField: Field?
//
//    enum Field {
//        case title, modelName, prompt
//    }
//
//    init(preset: Preset, presetViewModel: PresetViewModel, isPresented: Binding<Bool>) {
//        self.preset = preset
//        self.presetViewModel = presetViewModel
//        self._isPresented = isPresented
//        _title = State(initialValue: preset.title)
//        _modelName = State(initialValue: preset.modelName ?? "")
//        _prompt = State(initialValue: preset.prompt ?? "")
//    }
//
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 24) {
//                    // Image preview
//                    if let imageUrl = preset.imageUrl, let url = URL(string: imageUrl) {
//                        KFImage(url)
//                            .placeholder {
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(Color.gray.opacity(0.2))
//                                    .overlay(
//                                        Image(systemName: "photo")
//                                            .font(.system(size: 40))
//                                            .foregroundColor(.gray)
//                                    )
//                            }
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(maxHeight: 300)
//                            .clipShape(RoundedRectangle(cornerRadius: 12))
//                            .padding(.horizontal)
//                    }
//
//                    // Edit fields
//                    VStack(alignment: .leading, spacing: 20) {
//                        // Title field
//                        VStack(alignment: .leading, spacing: 8) {
//                            Text("Title")
//                                .font(.headline)
//                                .foregroundColor(.primary)
//
//                            TextField("Preset title", text: $title)
//                                .textFieldStyle(.roundedBorder)
//                                .focused($focusedField, equals: .title)
//                        }
//
//                        // Model name field
//                        VStack(alignment: .leading, spacing: 8) {
//                            Text("Model Name")
//                                .font(.headline)
//                                .foregroundColor(.primary)
//
//                            TextField("Image model", text: $modelName)
//                                .textFieldStyle(.roundedBorder)
//                                .focused($focusedField, equals: .modelName)
//                        }
//
//                        // Prompt field
//                        VStack(alignment: .leading, spacing: 8) {
//                            Text("Prompt")
//                                .font(.headline)
//                                .foregroundColor(.primary)
//
//                            ZStack(alignment: .topLeading) {
//                                // Hidden text to measure content height
//                                Text(prompt.isEmpty ? " " : prompt)
//                                    .font(.system(size: 17))
//                                    .padding(8)
//                                    .opacity(0)
//                                    .fixedSize(horizontal: false, vertical: true)
//                                    .frame(maxWidth: .infinity, alignment: .leading)
//
//                                // Actual TextEditor
//                                TextEditor(text: $prompt)
//                                    .scrollDisabled(true)
//                                    .padding(8)
//                                    .background(Color.gray.opacity(0.1))
//                                    .focused($focusedField, equals: .prompt)
//                            }
//                            .frame(minHeight: 120)
//                            .fixedSize(horizontal: false, vertical: true)
//                            .clipShape(RoundedRectangle(cornerRadius: 8))
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 8)
//                                    .stroke(focusedField == .prompt ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
//                            )
//                        }
//                    }
//                    .padding(.horizontal)
//
//                    // Save button
//                    Button(action: {
//                        Task {
//                            await savePreset()
//                        }
//                    }) {
//                        HStack {
//                            if isSaving {
//                                ProgressView()
//                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                            }
//                            Text(isSaving ? "Saving..." : "Save Changes")
//                                .font(.headline)
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(title.isEmpty ? Color.gray : Color.blue)
//                        .foregroundColor(.white)
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
//                    }
//                    .disabled(title.isEmpty || isSaving)
//                    .padding(.horizontal)
//
//                    // Delete button
//                    Button(action: {
//                        showDeleteConfirmation = true
//                    }) {
//                        HStack {
//                            Image(systemName: "trash")
//                            Text("Delete Preset")
//                                .font(.headline)
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.red.opacity(0.1))
//                        .foregroundColor(.red)
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
//                    }
//                    .padding(.horizontal)
//                    .padding(.bottom)
//                }
//                .padding(.vertical)
//            }
//            .navigationTitle("Edit Preset")
//            .navigationBarTitleDisplayMode(.inline)
//            .presentationDetents([.large])
//            .presentationDragIndicator(.visible)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") {
//                        isPresented = false
//                    }
//                }
//            }
//            .alert("Delete Preset", isPresented: $showDeleteConfirmation) {
//                Button("Cancel", role: .cancel) {}
//                Button("Delete", role: .destructive) {
//                    Task {
//                        await deletePreset()
//                    }
//                }
//            } message: {
//                Text("Are you sure you want to delete \"\(preset.title)\"? This action cannot be undone.")
//            }
//            .alert("Error", isPresented: $showError) {
//                Button("OK", role: .cancel) {}
//            } message: {
//                Text(errorMessage)
//            }
//        }
//    }
//
//    private func savePreset() async {
//        isSaving = true
//
//        do {
//            try await presetViewModel.updatePreset(
//                presetId: preset.id,
//                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
//                modelName: modelName.isEmpty ? nil : modelName.trimmingCharacters(in: .whitespacesAndNewlines),
//                prompt: prompt.isEmpty ? nil : prompt.trimmingCharacters(in: .whitespacesAndNewlines),
//                imageUrl: preset.imageUrl
//            )
//
//            await MainActor.run {
//                isSaving = false
//                isPresented = false
//            }
//        } catch {
//            await MainActor.run {
//                isSaving = false
//                errorMessage = "Failed to update preset: \(error.localizedDescription)"
//                showError = true
//            }
//        }
//    }
//
//    private func deletePreset() async {
//        do {
//            try await presetViewModel.deletePreset(presetId: preset.id)
//
//            await MainActor.run {
//                isPresented = false
//            }
//        } catch {
//            await MainActor.run {
//                errorMessage = "Failed to delete preset: \(error.localizedDescription)"
//                showError = true
//            }
//        }
//    }
//}
//
//// MARK: - Empty Presets View
//
//private struct EmptyPresetsView: View {
//    var body: some View {
//        VStack(spacing: 16) {
//            Image(systemName: "slider.horizontal.3")
//                .font(.system(size: 48))
//                .foregroundColor(.gray.opacity(0.5))
//
//            VStack(spacing: 8) {
//                Text("No Presets Yet")
//                    .font(.headline)
//                    .foregroundColor(.primary)
//
//                Text("Save presets from your images to quickly reuse your favorite settings")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 32)
//            }
//        }
//    }
//}

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
