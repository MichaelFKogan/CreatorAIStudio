import SwiftUI

// MARK:GALLERYTABPILL

struct GalleryTabPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let isSignedIn: Bool
    var selectedColor: Color = .blue
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

                if isSignedIn && count > 0 {
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
                    .fill(isSelected ? selectedColor : Color.gray.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? selectedColor : Color.clear, lineWidth: 0)
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
        return (tab == .all || tab == .images || tab == .videos) && !isImageModelsTab && !isVideoModelsTab
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
        } else if tab == .images {
            return "photo.on.rectangle"
        } else if tab == .videos {
            return "video.slash"
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
        } else if tab == .images {
            return "No Images Yet"
        } else if tab == .videos {
            return "No Videos Yet"
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
        } else if tab == .images {
            return "Start creating amazing images to see them here!"
        } else if tab == .videos {
            return "Start creating amazing videos to see them here!"
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

