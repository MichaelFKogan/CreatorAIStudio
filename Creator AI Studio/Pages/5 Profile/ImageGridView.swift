import Kingfisher
import SwiftUI

// MARK: IMAGE GRID (3×3 PORTRAIT)

struct ImageGridView: View {
    let userImages: [UserImage]
    let placeholders: [PlaceholderImage]
    let spacing: CGFloat = 2
    var onSelect: (UserImage) -> Void
    var viewModel: ProfileViewModel?
    var isSelectionMode: Bool = false
    @Binding var selectedImageIds: Set<String>
    var isFavoritesTab: Bool = false
    var isImagesOnlyTab: Bool = false
    var isVideosOnlyTab: Bool = false
    var isVideoModelsTab: Bool = false
    var selectedVideoModel: String? = nil

    @State private var favoritedImageIds: Set<String> = []
    /// Use Identifiable item so sheet content is built with a valid id (avoids empty sheet on first open).
    @State private var collectionSheetItem: CollectionSheetItem? = nil

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
        .sheet(item: $collectionSheetItem, onDismiss: { collectionSheetItem = nil }) { item in
            if let vm = viewModel {
                AddToPlaylistSheet(
                    viewModel: vm,
                    imageIds: [item.imageId],
                    isPresented: Binding(
                        get: { collectionSheetItem != nil },
                        set: { if !$0 { collectionSheetItem = nil } }
                    )
                )
            }
        }
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
                collectionOverlay(userImage: userImage)
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
            .frame(width: itemWidth, height: itemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: itemWidth, height: itemHeight)
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
            .frame(width: itemWidth, height: itemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: itemWidth, height: itemHeight)
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
    
    private func collectionOverlay(userImage: UserImage) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    Color.clear
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            collectionSheetItem = CollectionSheetItem(imageId: userImage.id)
                        }
                    
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        .allowsHitTesting(false)
                }
            }
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
            } else if isImagesOnlyTab {
                await viewModel.loadMoreImagesOnly()
            } else if isVideosOnlyTab {
                await viewModel.loadMoreVideosOnly()
            } else if isVideoModelsTab, let modelName = selectedVideoModel {
                _ = await viewModel.loadMoreModelVideos(modelName: modelName)
            } else {
                await viewModel.loadMoreImages()
            }
        }
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        let loading: Bool = {
            guard let viewModel = viewModel else { return false }
            if isFavoritesTab { return viewModel.isLoadingMoreFavorites }
            if isImagesOnlyTab { return viewModel.isLoadingMoreImagesOnly }
            if isVideosOnlyTab { return viewModel.isLoadingMoreVideosOnly }
            if isVideoModelsTab { return viewModel.isLoadingModelVideos }
            return viewModel.isLoadingMore
        }()
        if loading {
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
}

// MARK: - Add to Collection sheet item (Identifiable for sheet(item:))
private struct CollectionSheetItem: Identifiable {
    let imageId: String
    var id: String { imageId }
}

