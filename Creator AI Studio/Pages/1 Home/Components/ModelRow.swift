import SwiftUI
import UIKit

struct ModelRow: View {
    let title: String
    let iconName: String?
    let items: [InfoPacket]
    let seeAllDestination: AnyView?
    
    @State private var lastOffset: CGFloat = 0
    @State private var feedback: UISelectionFeedbackGenerator?
    
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
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(destination: destinationView(for: item)) {
                            VStack(spacing: 8) {
                                // Model image
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
                                    .font(.custom("Nunito-ExtraBold", size: 11))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                                    .frame(width: 140)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .background(ScrollOffsetReader { newOffset in
                    handleScrollFeedback(newOffset: newOffset)
                })
            }
            .frame(height: 220)
        }
        .onAppear {
            if feedback == nil {
                feedback = UISelectionFeedbackGenerator()
                feedback?.prepare()
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

// MARK: - Model Row Title Component
struct ModelRowTitle: View {
    let title: String
    let iconName: String?
    let items: [InfoPacket]
    let seeAllDestination: AnyView?
    
    init(title: String, iconName: String? = nil, items: [InfoPacket], seeAllDestination: AnyView? = nil) {
        self.title = title
        self.iconName = iconName
        self.items = items
        self.seeAllDestination = seeAllDestination
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            if let destination = seeAllDestination {
                NavigationLink(destination: destination) {
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
        }
        .padding(.horizontal)
    }
}

// MARK: - Helper View to detect horizontal scroll offset (reused from CategoryRow)
private struct ScrollOffsetReader: View {
    var onChange: (CGFloat) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let minX = geo.frame(in: .global).minX
            // Only send valid frame values
            Color.clear
                .preference(key: ScrollOffsetKey.self, value: minX.isFinite && !minX.isNaN ? minX : 0)
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

