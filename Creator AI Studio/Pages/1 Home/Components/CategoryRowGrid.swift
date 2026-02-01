import SwiftUI
import UIKit

struct CategoryRowGrid: View {
    let categoryName: String
    let animationType: ImageDiffAnimation?

    @State private var lastOffset: CGFloat = 0
    @State private var feedback: UISelectionFeedbackGenerator?

    private let categoryManager = CategoryConfigurationManager.shared
    private let filtersViewModel = PhotoFiltersViewModel.shared

    // Layout constants (25% larger than CategoryRow)
    private let largeImageWidth: CGFloat = 175
    private let largeImageHeight: CGFloat = 245
    private let smallImageWidth: CGFloat = 84
    private let smallImageHeight: CGFloat = 119
    private let gridSpacing: CGFloat = 7
    private let itemSpacing: CGFloat = 12

    // Get items for this category
    private var items: [InfoPacket] {
        filtersViewModel.filters(for: categoryName)
    }

    // Get title with emoji
    private var title: String {
        let emoji = categoryManager.emoji(for: categoryName)
        return "\(emoji) \(categoryName)"
    }

    // Check if this row should use animation
    private var shouldUseAnimation: Bool {
        animationType != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RowTitle(title: title, items: items) {
                print("Tapped See All for \(title)")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: itemSpacing) {
                    ForEach(Array(groupedItems.enumerated()), id: \.offset) { index, group in
                        if group.count == 1 {
                            // Single large image
                            largeItemView(item: group[0])
                        } else {
                            // 2x2 grid of 4 images
                            gridItemView(items: group)
                        }
                    }
                }
                .padding(.horizontal)
                .background(ScrollOffsetReaderCategoryGrid { newOffset in
                    handleScrollFeedback(newOffset: newOffset)
                })
            }
            .frame(height: 275)
        }
        .onAppear {
            if feedback == nil {
                feedback = UISelectionFeedbackGenerator()
                feedback?.prepare()
            }
        }
    }

    // Groups items into alternating pattern: 1 item, then 4 items, then 1, then 4, etc.
    private var groupedItems: [[InfoPacket]] {
        var groups: [[InfoPacket]] = []
        var currentIndex = 0
        var isLargeNext = true

        while currentIndex < items.count {
            if isLargeNext {
                // Take 1 item for large display
                groups.append([items[currentIndex]])
                currentIndex += 1
            } else {
                // Take up to 4 items for grid display
                let endIndex = min(currentIndex + 4, items.count)
                let gridItems = Array(items[currentIndex..<endIndex])
                groups.append(gridItems)
                currentIndex = endIndex
            }
            isLargeNext.toggle()
        }

        return groups
    }

    @ViewBuilder
    private func largeItemView(item: InfoPacket) -> some View {
        NavigationLink(destination: PhotoFilterDetailView(item: item)) {
            VStack(spacing: 8) {
                // Use animated view if animation type is set and original image exists
                if shouldUseAnimation,
                   let originalImageName = item.display.imageNameOriginal,
                   let animation = animationType {
                    ImageAnimations(
                        originalImageName: originalImageName,
                        transformedImageName: item.display.imageName,
                        width: largeImageWidth,
                        height: largeImageHeight,
                        animation: animation
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(alignment: .bottom) {
                        Text("Try This")
                            .font(.custom("Nunito-ExtraBold", size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.8))
                            .clipShape(Capsule())
                            .padding(.bottom, 6)
                    }
                    .overlay(alignment: .topTrailing) {
                        if let cost = item.resolvedCost {
                            Text(PricingManager.formatPrice(cost))
                                .font(.custom("Nunito-Bold", size: 11))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.8))
                                .clipShape(Capsule())
                                .padding(6)
                        }
                    }
                } else {
                    // Regular image
                    Image(item.display.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: largeImageWidth, height: largeImageHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(alignment: .bottom) {
                            Text("Try This")
                                .font(.custom("Nunito-ExtraBold", size: 12))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.8))
                                .clipShape(Capsule())
                                .padding(.bottom, 6)
                        }
                        .overlay(alignment: .topTrailing) {
                            if let cost = item.resolvedCost {
                                Text(PricingManager.formatPrice(cost))
                                    .font(.custom("Nunito-Bold", size: 11))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.8))
                                    .clipShape(Capsule())
                                    .padding(6)
                            }
                        }
                }

                Text(item.display.title)
                    .font(.custom("Nunito-ExtraBold", size: 12))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .frame(width: largeImageWidth)
                    .truncationMode(.tail)
            }
        }
    }

    @ViewBuilder
    private func gridItemView(items: [InfoPacket]) -> some View {
        VStack(spacing: 8) {
            // 2x2 grid
            VStack(spacing: gridSpacing) {
                HStack(spacing: gridSpacing) {
                    if items.count > 0 {
                        smallItemView(item: items[0])
                    }
                    if items.count > 1 {
                        smallItemView(item: items[1])
                    } else {
                        Color.clear.frame(width: smallImageWidth, height: smallImageHeight)
                    }
                }
                HStack(spacing: gridSpacing) {
                    if items.count > 2 {
                        smallItemView(item: items[2])
                    } else {
                        Color.clear.frame(width: smallImageWidth, height: smallImageHeight)
                    }
                    if items.count > 3 {
                        smallItemView(item: items[3])
                    } else {
                        Color.clear.frame(width: smallImageWidth, height: smallImageHeight)
                    }
                }
            }

            // Spacing to match height with large items
            Color.clear.frame(height: 16)
        }
    }

    @ViewBuilder
    private func smallItemView(item: InfoPacket) -> some View {
        NavigationLink(destination: PhotoFilterDetailView(item: item)) {
            Group {
                // Use animated view if animation type is set and original image exists
                if shouldUseAnimation,
                   let originalImageName = item.display.imageNameOriginal,
                   let animation = animationType {
                    ImageAnimations(
                        originalImageName: originalImageName,
                        transformedImageName: item.display.imageName,
                        width: smallImageWidth,
                        height: smallImageHeight,
                        animation: animation
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        if let cost = item.resolvedCost {
                            Text(PricingManager.formatPrice(cost))
                                .font(.custom("Nunito-Bold", size: 8))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.8))
                                .clipShape(Capsule())
                                .padding(3)
                        }
                    }
                } else {
                    // Regular image
                    Image(item.display.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: smallImageWidth, height: smallImageHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(alignment: .topTrailing) {
                            if let cost = item.resolvedCost {
                                Text(PricingManager.formatPrice(cost))
                                    .font(.custom("Nunito-Bold", size: 8))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.8))
                                    .clipShape(Capsule())
                                    .padding(3)
                            }
                        }
                }
            }
        }
    }

    private func handleScrollFeedback(newOffset: CGFloat) {
        guard newOffset.isFinite && !newOffset.isNaN else { return }

        Task { @MainActor in
            let delta = abs(newOffset - lastOffset)
            if delta > 40 {
                feedback?.selectionChanged()
                lastOffset = newOffset
            }
        }
    }
}

// MARK: - Helper View to detect horizontal scroll offset
private struct ScrollOffsetReaderCategoryGrid: View {
    var onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            let minX = geo.frame(in: .global).minX
            Color.clear
                .preference(key: ScrollOffsetKeyCategoryGrid.self, value: minX.isFinite && !minX.isNaN ? minX : 0)
        }
        .onPreferenceChange(ScrollOffsetKeyCategoryGrid.self, perform: onChange)
    }
}

private struct ScrollOffsetKeyCategoryGrid: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
