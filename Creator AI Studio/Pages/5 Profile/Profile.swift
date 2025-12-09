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
                            if viewModel.userId != user.id.uuidString {
                                viewModel.userId = user.id.uuidString
                            }
                            Task {
                                //                            print("🔄 Profile appeared, fetching images for user: \(user.id.uuidString)")
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
    @StateObject private var presetViewModel = PresetViewModel()
    @State private var selectedUserImage: UserImage? = nil
    @State private var selectedTab: GalleryTab = .all
    @State private var selectedModel: String? = nil
    @State private var showImageModelsPopover: Bool = false
    @State private var showPresetsSheet: Bool = false

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

    enum GalleryTab: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case imageModels = "Image Models"
    }

    // Compute models with metadata - returns immediately without caching
    private func computeModelsWithMetadata() -> [(model: String, count: Int, imageName: String)] {
        let currentUniqueModels = viewModel.uniqueModels
        print("🔍 DEBUG: Computing models - uniqueModels = \(currentUniqueModels)")
        print("🔍 DEBUG: Computing models - Total userImages = \(viewModel.userImages.count)")
        
        // Debug: Print first few images and their model values
        for (index, image) in viewModel.userImages.prefix(5).enumerated() {
            print("🔍 DEBUG: Image \(index): model = '\(image.model ?? "nil")'")
        }
        
        var result: [(String, Int, String)] = []

        for modelName in currentUniqueModels {
            let count = viewModel.filteredImages(by: modelName, favoritesOnly: false).count
            print("🔍 DEBUG: Model '\(modelName)' has \(count) images")
            guard count > 0 else { continue }

            // Find the model image from ImageModelData using display.imageName
            var imageName = "photo.on.rectangle.angled" // fallback
            if let modelInfo = allImageModels.first(where: { $0.display.modelName == modelName }) {
                imageName = modelInfo.display.imageName
                print("🔍 DEBUG: Found model info by modelName: \(modelName) -> \(imageName)")
            } else if let modelInfo = allImageModels.first(where: { $0.display.title == modelName }) {
                imageName = modelInfo.display.imageName
                print("🔍 DEBUG: Found model info by title: \(modelName) -> \(imageName)")
            } else {
                print("⚠️ DEBUG: No model info found for: \(modelName), using fallback")
            }

            result.append((modelName, count, imageName))
        }

        // Sort by count descending
        let sorted = result.sorted { $0.1 > $1.1 }
        print("🔍 DEBUG: Computed \(sorted.count) models")
        return sorted
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    filterSection

                    contentSection
                }
                .padding(.top, 10)
                //                .navigationTitle("Profile")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: Settings().environmentObject(authViewModel)) {
                            Image(systemName: "gearshape")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .onAppear {
                if let userId = authViewModel.user?.id.uuidString {
                    Task {
                        presetViewModel.userId = userId
                        await presetViewModel.fetchPresets()
                    }
                }
            }
            .onChange(of: notificationManager.notifications.count) {
                oldCount, newCount in
                // When notification count decreases (notification dismissed), refresh images
                if newCount < oldCount {
                    Task {
                        await viewModel.fetchUserImages(forceRefresh: true)
                    }
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
                        isSelected: selectedTab == .all && selectedModel == nil,
                        count: viewModel.userImages.count
                    ) {
                        selectedTab = .all
                        selectedModel = nil
                    }

                    // Favorites pill
                    GalleryTabPill(
                        title: "Favorites",
                        icon: "heart.fill",
                        isSelected: selectedTab == .favorites && selectedModel == nil,
                        count: viewModel.favoriteImages.count
                    ) {
                        selectedTab = .favorites
                        selectedModel = nil
                    }

                    // Presets pill
                    GalleryTabPill(
                        title: "Presets",
                        icon: "slider.horizontal.3",
                        isSelected: false,
                        count: presetViewModel.presets.count
                    ) {
                        showPresetsSheet = true
                    }

                    imageModelsButton
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
                print("🔍 DEBUG: Sheet builder - Passing \(models.count) models to sheet")
                return ImageModelsSheet(
                    models: models,
                    selectedModel: $selectedModel,
                    selectedTab: $selectedTab,
                    isPresented: $showImageModelsPopover
                )
            }
            .sheet(isPresented: $showPresetsSheet) {
                PresetsListSheet(
                    presetViewModel: presetViewModel,
                    isPresented: $showPresetsSheet
                )
            }
    }

    private var imageModelsButtonLabel: some View {
        let isSelected = selectedTab == .imageModels && selectedModel != nil
        let title = isSelected && selectedModel != nil ? selectedModel! : "Image Models"
        let modelCount = viewModel.uniqueModels.count

        return HStack(spacing: 6) {
            Image(systemName: "cpu")
                .font(.system(size: 12, weight: .medium))
            
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
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

        if filteredImages.isEmpty && notificationManager.activePlaceholders.isEmpty {
            EmptyGalleryView(
                tab: selectedTab,
                model: selectedModel,
                isImageModelsTab: selectedTab == .imageModels
            )
        } else {
            ImageGridView(
                userImages: filteredImages,
                placeholders: notificationManager.activePlaceholders,
                onSelect: { userImage in
                    selectedUserImage = userImage
                },
                viewModel: viewModel,
                presetViewModel: presetViewModel
            )
        }
    }

    private func getFilteredImages() -> [UserImage] {
        switch selectedTab {
        case .all:
            return selectedModel == nil
                ? viewModel.userImages
                : viewModel.filteredImages(by: selectedModel, favoritesOnly: false)
        case .favorites:
            return selectedModel == nil
                ? viewModel.favoriteImages
                : viewModel.filteredImages(by: selectedModel, favoritesOnly: true)
        case .imageModels:
            return selectedModel != nil
                ? viewModel.filteredImages(by: selectedModel, favoritesOnly: false)
                : viewModel.userImages
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
    var presetViewModel: PresetViewModel?

    @State private var favoritedImageIds: Set<String> = []

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
    }

    var body: some View {
        GeometryReader { proxy in
            let totalSpacing = spacing * 2
            let contentWidth = max(0, proxy.size.width - totalSpacing - 8)
            let itemWidth = max(44, contentWidth / 3) // minimum thumbnail size
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
                                        .frame(width: itemWidth, height: itemHeight)
                                        .clipped()

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

                            // Heart icon and bookmark icon overlay
                            VStack {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Color.clear
                                                .frame(width: 32, height: 32)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    if let viewModel = viewModel {
                                                        Task {
                                                            await viewModel.toggleFavorite(imageId: userImage.id)
                                                        }
                                                    } else {
                                                        // Fallback to local state if no viewModel
                                                        let imageId = userImage.id
                                                        if favoritedImageIds.contains(imageId) {
                                                            favoritedImageIds.remove(imageId)
                                                        } else {
                                                            favoritedImageIds.insert(imageId)
                                                        }
                                                    }
                                                }

                                            // Heart icon
                                            Image(systemName: (userImage.is_favorite ?? false) ? "heart.fill" : "heart")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor((userImage.is_favorite ?? false) ? .red : .white)
                                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                                .allowsHitTesting(false)
                                        }
                                        
                                        // Bookmark icon (blue) if preset is enabled
                                        if hasMatchingPreset(for: userImage) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.black)
                                                    .frame(width: 28, height: 28)
                                                
                                                Image(systemName: "bookmark.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.blue)
                                            }
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                        .onAppear {
                            // Trigger loading more when we're 10 items from the end
                            if let viewModel = viewModel, 
                               let index = userImages.firstIndex(where: { $0.id == userImage.id }),
                               index >= userImages.count - 10 {
                                Task {
                                    await viewModel.loadMoreImages()
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
                                                    Image(systemName: "video.fill")
                                                        .font(.largeTitle)
                                                        .foregroundColor(.gray)
                                                )
                                        }
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: itemWidth, height: itemHeight)
                                        .clipped()

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

                            // Heart icon and bookmark icon overlay
                            VStack {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Color.clear
                                                .frame(width: 32, height: 32)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    if let viewModel = viewModel {
                                                        Task {
                                                            await viewModel.toggleFavorite(imageId: userImage.id)
                                                        }
                                                    } else {
                                                        // Fallback to local state if no viewModel
                                                        let imageId = userImage.id
                                                        if favoritedImageIds.contains(imageId) {
                                                            favoritedImageIds.remove(imageId)
                                                        } else {
                                                            favoritedImageIds.insert(imageId)
                                                        }
                                                    }
                                                }

                                            // Heart icon
                                            Image(systemName: (userImage.is_favorite ?? false) ? "heart.fill" : "heart")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor((userImage.is_favorite ?? false) ? .red : .white)
                                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                                .allowsHitTesting(false)
                                        }
                                        
                                        // Bookmark icon (blue) if preset is enabled
                                        if hasMatchingPreset(for: userImage) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.gray.opacity(0.7))
                                                    .frame(width: 24, height: 24)
                                                
                                                Image(systemName: "bookmark.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.blue)
                                            }
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                        .onAppear {
                            // Trigger loading more when we're 10 items from the end
                            if let viewModel = viewModel,
                               let index = userImages.firstIndex(where: { $0.id == userImage.id }),
                               index >= userImages.count - 10 {
                                Task {
                                    await viewModel.loadMoreImages()
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
        .frame(height: calculateHeight(for: placeholders.count + userImages.count))
    }

    private func calculateHeight(for count: Int) -> CGFloat {
        let rows = ceil(Double(count) / 3.0)
        let itemWidth = (UIScreen.main.bounds.width - 16) / 3
        return CGFloat(rows) * (itemWidth * 1.4 + spacing)
    }
    
    // Check if an image has a matching preset
    private func hasMatchingPreset(for userImage: UserImage) -> Bool {
        guard let presetViewModel = presetViewModel else { return false }
        
        let currentModelName = userImage.title
        let currentPrompt = userImage.prompt
        
        return presetViewModel.presets.contains { preset in
            // Compare model names (both can be nil or empty)
            let modelMatch: Bool
            if let currentModel = currentModelName, !currentModel.isEmpty {
                modelMatch = preset.modelName == currentModel
            } else {
                // Both are nil/empty - consider it a match
                modelMatch = preset.modelName == nil || preset.modelName?.isEmpty == true
            }
            
            // Compare prompts (both can be nil or empty)
            let promptMatch: Bool
            if let current = currentPrompt, !current.isEmpty {
                promptMatch = preset.prompt == current
            } else {
                // Both are nil/empty - consider it a match
                promptMatch = preset.prompt == nil || preset.prompt?.isEmpty == true
            }
            
            return modelMatch && promptMatch
        }
    }
}

// MARK: PLACEHOLDER Image Card (for in-progress generations)

struct PlaceholderImageCard: View {
    let placeholder: PlaceholderImage
    let itemWidth: CGFloat
    let itemHeight: CGFloat

    @State private var shimmer = false
    @State private var pulseAnimation = false
    @StateObject private var notificationManager = NotificationManager.shared

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
                if let thumbnail = placeholder.thumbnailImage {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .blue.opacity(0.3),
                                        .purple.opacity(0.3),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
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
                    if let errorMsg = placeholder.errorMessage {
                        Text(errorMsg)
                            .font(.custom("Nunito-Regular", size: 8))
                            .foregroundColor(.red.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
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
                                notificationManager.cancelTask(notificationId: placeholder.id)
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
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)

                if count > 0 {
                    Text("(\(count))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
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
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)

                if count > 0 {
                    Text("(\(count))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
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
        } else if isImageModelsTab && model != nil {
            return "photo.on.rectangle"
        } else {
            return "photo.on.rectangle"
        }
    }

    private var emptyTitle: String {
        if tab == .favorites {
            return "No Favorites Yet"
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
        } else if isImageModelsTab && model != nil {
            return "You haven't created any images with this model yet"
        } else if isImageModelsTab {
            return "Select an image model from the dropdown to view your creations"
        } else {
            return "Start creating amazing images to see them here!"
        }
    }
}

// MARK: - IMAGE MODELS SHEET

struct ImageModelsSheet: View {
    let models: [(model: String, count: Int, imageName: String)]
    @Binding var selectedModel: String?
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
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .frame(width: 65, height: 65)

                                // Model name and count
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(modelData.model)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)

                                    Text("\(modelData.count) image\(modelData.count == 1 ? "" : "s")")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.blue)
                                }

                                Spacer()

                                // Checkmark if selected
                                if selectedTab == .imageModels && selectedModel == modelData.model {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(12)
                            .background(
                                selectedTab == .imageModels && selectedModel == modelData.model
                                    ? Color.blue.opacity(0.08)
                                    : Color.gray.opacity(0.06)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedTab == .imageModels && selectedModel == modelData.model
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
                    print("🔍 DEBUG: Sheet model: \(model.model) - \(model.count) images - image: \(model.imageName)")
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

// MARK: - PRESETS LIST SHEET

struct PresetsListSheet: View {
    @ObservedObject var presetViewModel: PresetViewModel
    @Binding var isPresented: Bool
    @State private var presetToDelete: Preset? = nil
    @State private var showDeleteConfirmation = false
    @State private var isEditMode = false
    @State private var selectedPreset: Preset? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if presetViewModel.isLoading && presetViewModel.presets.isEmpty {
                    ProgressView("Loading presets…")
                        .padding()
                } else if presetViewModel.presets.isEmpty {
                    ScrollView {
                        EmptyPresetsView()
                            .padding(.vertical, 60)
                    }
                } else {
                    if isEditMode {
                        // Edit mode with drag and drop using List
                        List {
                            ForEach(presetViewModel.presets) { preset in
                                PresetRow(
                                    preset: preset,
                                    isEditMode: true,
                                    onDelete: {
                                        presetToDelete = preset
                                        showDeleteConfirmation = true
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                            }
                            .onMove { source, destination in
                                presetViewModel.reorderPresets(from: source, to: destination)
                            }
                        }
                        .listStyle(.plain)
                        .environment(\.editMode, .constant(.active))
                    } else {
                        // Normal mode with tap navigation
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(presetViewModel.presets) { preset in
                                    Button {
                                        selectedPreset = preset
                                    } label: {
                                        PresetRow(preset: preset, isEditMode: false, onDelete: nil)
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !presetViewModel.presets.isEmpty {
                        Button(isEditMode ? "Done" : "Edit") {
                            isEditMode.toggle()
                        }
                    }
                }
                // ToolbarItem(placement: .navigationBarTrailing) {
                //     Button("Done") {
                //         isPresented = false
                //     }
                // }
            }
            .alert("Delete Preset", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    presetToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let preset = presetToDelete {
                        Task {
                            do {
                                try await presetViewModel.deletePreset(presetId: preset.id)
                            } catch {
                                print("❌ Failed to delete preset: \(error)")
                            }
                        }
                    }
                    presetToDelete = nil
                }
            } message: {
                if let preset = presetToDelete {
                    Text("Are you sure you want to delete \"\(preset.title)\"?")
                }
            }
            .sheet(item: $selectedPreset) { preset in
                PresetDetailView(
                    preset: preset,
                    presetViewModel: presetViewModel,
                    isPresented: Binding(
                        get: { selectedPreset != nil },
                        set: { if !$0 { selectedPreset = nil } }
                    )
                )
            }
            .onAppear {
                Task {
                    await presetViewModel.fetchPresets(forceRefresh: true)
                }
            }
        }
    }
}

// MARK: - Preset Row

private struct PresetRow: View {
    let preset: Preset
    let isEditMode: Bool
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // // Drag handle in edit mode
            // if isEditMode {
            //     Image(systemName: "line.3.horizontal")
            //         .font(.system(size: 16, weight: .medium))
            //         .foregroundColor(.secondary)
            //         .padding(.trailing, 4)
            // }
            
            // Icon or image
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                if let imageUrl = preset.imageUrl, let url = URL(string: imageUrl) {
                    KFImage(url)
                        .placeholder {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 60, height: 60)
            
            // Preset details
            VStack(alignment: .leading, spacing: 6) {
                Text(preset.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let modelName = preset.modelName, !modelName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(modelName)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if let prompt = preset.prompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Delete button in edit mode, chevron in normal mode
            if isEditMode {
                Button(action: {
                    onDelete?()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .presentationDetents([.large])
    }
}

// MARK: - Preset Detail View

struct PresetDetailView: View {
    let preset: Preset
    @ObservedObject var presetViewModel: PresetViewModel
    @Binding var isPresented: Bool
    
    @State private var title: String
    @State private var modelName: String
    @State private var prompt: String
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, modelName, prompt
    }
    
    init(preset: Preset, presetViewModel: PresetViewModel, isPresented: Binding<Bool>) {
        self.preset = preset
        self.presetViewModel = presetViewModel
        self._isPresented = isPresented
        _title = State(initialValue: preset.title)
        _modelName = State(initialValue: preset.modelName ?? "")
        _prompt = State(initialValue: preset.prompt ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Image preview
                    if let imageUrl = preset.imageUrl, let url = URL(string: imageUrl) {
                        KFImage(url)
                            .placeholder {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }
                    
                    // Edit fields
                    VStack(alignment: .leading, spacing: 20) {
                        // Title field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Preset title", text: $title)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .title)
                        }
                        
                        // Model name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model Name")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Image model", text: $modelName)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .modelName)
                        }
                        
                        // Prompt field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prompt")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ZStack(alignment: .topLeading) {
                                // Hidden text to measure content height
                                Text(prompt.isEmpty ? " " : prompt)
                                    .font(.system(size: 17))
                                    .padding(8)
                                    .opacity(0)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Actual TextEditor
                                TextEditor(text: $prompt)
                                    .scrollDisabled(true)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .focused($focusedField, equals: .prompt)
                            }
                            .frame(minHeight: 120)
                            .fixedSize(horizontal: false, vertical: true)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(focusedField == .prompt ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Save button
                    Button(action: {
                        Task {
                            await savePreset()
                        }
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isSaving ? "Saving..." : "Save Changes")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(title.isEmpty || isSaving)
                    .padding(.horizontal)
                    
                    // Delete button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Preset")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.vertical)
            }
            .navigationTitle("Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .alert("Delete Preset", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deletePreset()
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(preset.title)\"? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func savePreset() async {
        isSaving = true
        
        do {
            try await presetViewModel.updatePreset(
                presetId: preset.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                modelName: modelName.isEmpty ? nil : modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                prompt: prompt.isEmpty ? nil : prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                imageUrl: preset.imageUrl
            )
            
            await MainActor.run {
                isSaving = false
                isPresented = false
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = "Failed to update preset: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func deletePreset() async {
        do {
            try await presetViewModel.deletePreset(presetId: preset.id)
            
            await MainActor.run {
                isPresented = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete preset: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Empty Presets View

private struct EmptyPresetsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Presets Yet")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Save presets from your images to quickly reuse your favorite settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

// MARK: - URL Identifiable

extension URL: Identifiable {
    public var id: String { absoluteString }
}
