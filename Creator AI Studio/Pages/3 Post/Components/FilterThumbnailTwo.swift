import SwiftUI
import Kingfisher

// MARK: - Filter Thumbnail (Square)

struct FilterThumbnailTwo: View {
    let title: String
    let imageName: String
    let isSelected: Bool
    let size: CGFloat
    let cost: Decimal?
    let imageUrl: String? // Optional URL for user-generated images (presets)

    init(title: String, imageName: String, isSelected: Bool, size: CGFloat, cost: Decimal?, imageUrl: String? = nil) {
        self.title = title
        self.imageName = imageName
        self.isSelected = isSelected
        self.size = size
        self.cost = cost
        self.imageUrl = imageUrl
    }
    
    // Check if imageName is a URL
    private var isImageUrl: Bool {
        imageName.hasPrefix("http://") || imageName.hasPrefix("https://")
    }
    
    // Use imageUrl if provided, otherwise check if imageName is a URL
    private var effectiveImageUrl: String? {
        imageUrl ?? (isImageUrl ? imageName : nil)
    }
    
    private var effectiveImageName: String {
        isImageUrl ? "" : imageName
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Use KFImage for URLs, Image for local assets
                Group {
                    if let urlString = effectiveImageUrl, let url = URL(string: urlString) {
                        KFImage(url)
                            .placeholder {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(ProgressView())
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isSelected ? Color.pink : Color.clear,
                                        lineWidth: 3)
                            )
                            .overlay(
                                VStack(alignment: .trailing, spacing: 4) {
                                    // Checkmark (shown when selected, below price)
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .background(
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [.pink, .pink],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 20, height: 20)
                                            )
                                            .transition(.scale.combined(with: .opacity))
                                    }

                                    Spacer()

                                    // Price badge (always visible if cost exists)
                                    if let cost = cost {
                                        PriceDisplayView(
                                            price: cost,
                                            font: .system(size: 10, weight: .medium),
                                            foregroundColor: .white
                                        )
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.black.opacity(0.5))
                                        )
                                        .shadow(
                                            color: .black.opacity(0.3), radius: 2, x: 0,
                                            y: 1)
                                    }
                                }
                                .padding(3),
                                alignment: .topTrailing
                            )
                    } else {
                        Image(effectiveImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isSelected ? Color.pink : Color.clear,
                                        lineWidth: 3)
                            )
                            .overlay(
                                VStack(alignment: .trailing, spacing: 4) {
                                    // Checkmark (shown when selected, below price)
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .background(
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [.pink, .pink],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 20, height: 20)
                                            )
                                            .transition(.scale.combined(with: .opacity))
                                    }

                                    Spacer()

                                    // Price badge (always visible if cost exists)
                                    if let cost = cost {
                                        Text(
                                            "$\(NSDecimalNumber(decimal: cost).stringValue)"
                                        )
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.black.opacity(0.5))
                                        )
                                        .shadow(
                                            color: .black.opacity(0.3), radius: 2, x: 0,
                                            y: 1)
                                    }
                                }
                                .padding(3),
                                alignment: .topTrailing
                            )
                    }
                }
            }
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.secondary)
                .frame(width: size)
        }
    }
}
