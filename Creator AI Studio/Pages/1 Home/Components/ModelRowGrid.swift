import SwiftUI
import UIKit

struct ModelRowGrid: View {
    let title: String
    let iconName: String?
    let items: [InfoPacket]
    let seeAllDestination: AnyView?

    @State private var lastOffset: CGFloat = 0
    @State private var feedback: UISelectionFeedbackGenerator?

    // Layout constants (25% larger than ModelRow)
    private let largeImageWidth: CGFloat = 175
    private let largeImageHeight: CGFloat = 245
    private let smallImageWidth: CGFloat = 84
    private let smallImageHeight: CGFloat = 119
    private let gridSpacing: CGFloat = 7
    private let itemSpacing: CGFloat = 12

    init(title: String, iconName: String? = nil, items: [InfoPacket], seeAllDestination: AnyView? = nil) {
        self.title = title
        self.iconName = iconName
        self.items = items
        self.seeAllDestination = seeAllDestination
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ModelRowTitle(title: title, iconName: iconName, items: items, seeAllDestination: seeAllDestination)

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
                .background(ScrollOffsetReaderGrid { newOffset in
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
        NavigationLink(destination: destinationView(for: item)) {
            VStack(spacing: 8) {
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
                        // Empty placeholder
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

            // No title under grid - just spacing to match height
            Color.clear.frame(height: 16)
        }
    }

    @ViewBuilder
    private func smallItemView(item: InfoPacket) -> some View {
        NavigationLink(destination: destinationView(for: item)) {
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

    @ViewBuilder
    private func destinationView(for item: InfoPacket) -> some View {
        if item.type == "Image Model" {
            ImageModelDetailPage(item: item)
        } else if item.type == "Video Model" {
            VideoModelDetailPage(item: item)
        } else {
            // Fallback - should not happen but handle gracefully
            ImageModelDetailPage(item: item)
        }
    }

    private func handleScrollFeedback(newOffset: CGFloat) {
        // Guard against invalid values
        guard newOffset.isFinite && !newOffset.isNaN else { return }

        // Use async dispatch to avoid modifying state during view update
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
private struct ScrollOffsetReaderGrid: View {
    var onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            let minX = geo.frame(in: .global).minX
            // Only send valid frame values
            Color.clear
                .preference(key: ScrollOffsetKeyGrid.self, value: minX.isFinite && !minX.isNaN ? minX : 0)
        }
        .onPreferenceChange(ScrollOffsetKeyGrid.self, perform: onChange)
    }
}

private struct ScrollOffsetKeyGrid: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
