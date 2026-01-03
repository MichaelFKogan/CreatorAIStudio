import SwiftUI
import UIKit

struct CategoryRow: View {
    let categoryName: String
    let animationType: ImageDiffAnimation?
    
    @State private var lastOffset: CGFloat = 0
    @State private var feedback: UISelectionFeedbackGenerator?
    
    private let categoryManager = CategoryConfigurationManager.shared
    private let filtersViewModel = PhotoFiltersViewModel.shared
    
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

            // ✅ Outer ScrollView must wrap content naturally
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(destination: PhotoFilterDetailView(item: item)) {
                            VStack(spacing: 8) {
                                // Use animated view for rows 1-4 if original image exists
                                if shouldUseAnimation, 
                                   let originalImageName = item.display.imageNameOriginal,
                                   let animation = animationType {
                                    ImageAnimations(
                                        originalImageName: originalImageName,
                                        transformedImageName: item.display.imageName,
                                        width: 140,
                                        height: 196,
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
                                    // Regular image for other categories
                                    Image(item.display.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 140, height: 196)
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
                                    .font(.custom("Nunito-ExtraBold", size: 11))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                // ✅ Add offset tracking *outside* of GeometryReader
                .background(ScrollOffsetReader { newOffset in
                    handleScrollFeedback(newOffset: newOffset)
                })
            }
            .frame(height: 220)
        }
        .onAppear {
            // Prepare haptic feedback generator once
            if feedback == nil {
                feedback = UISelectionFeedbackGenerator()
                feedback?.prepare()
            }
        }
    }

    private func handleScrollFeedback(newOffset: CGFloat) {
        let delta = abs(newOffset - lastOffset)
        if delta > 40 {
            feedback?.selectionChanged()
            lastOffset = newOffset
        }
    }
}

// MARK: - Helper View to detect horizontal scroll offset
private struct ScrollOffsetReader: View {
    var onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .global).minX)
        }
        .onPreferenceChange(ScrollOffsetKey.self, perform: onChange)
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Row Title Component
struct RowTitle: View {
    let title: String
    let items: [InfoPacket]
    let onSeeAll: () -> Void
    
    // Extract category name from title (removes emoji prefix like "✨ Anime" -> "Anime")
    private var categoryName: String {
        // Title format is "\(emoji) \(categoryName)", so we need to remove the first character and space
        let components = title.split(separator: " ", maxSplits: 1)
        return components.count > 1 ? String(components[1]) : title
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            NavigationLink(destination: CategoryDetailView(categoryName: categoryName, items: items)) {
                HStack(spacing: 8) {
                    Text("See All")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
    }
}


