import Kingfisher
import SwiftUI

// MARK: - Filter Thumbnail (Square)

struct FilterThumbnail: View {
    let title: String
    let imageName: String
    let isSelected: Bool
    let size: CGFloat
    let cost: Decimal?
    let imageUrl: String?  // Optional URL for user-generated images (presets)
    let isMultiSelectMode: Bool
    let isMultiSelected: Bool

    init(
        title: String, imageName: String, isSelected: Bool, size: CGFloat,
        cost: Decimal?, imageUrl: String? = nil, isMultiSelectMode: Bool = false,
        isMultiSelected: Bool = false
    ) {
        self.title = title
        self.imageName = imageName
        self.isSelected = isSelected
        self.size = size
        self.cost = cost
        self.imageUrl = imageUrl
        self.isMultiSelectMode = isMultiSelectMode
        self.isMultiSelected = isMultiSelected
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
                    if let urlString = effectiveImageUrl,
                        let url = URL(string: urlString)
                    {
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
                                // Selection overlay (darkens when selected in multi-select mode)
                                Group {
                                    if isMultiSelectMode {
                                        Rectangle()
                                            .fill(Color.black.opacity(isMultiSelected ? 0.3 : 0))
                                    }
                                }
                            )
                            .overlay(
                                VStack(alignment: .trailing, spacing: 4) {
                                    // Multi-select circle (top right)
                                    if isMultiSelectMode {
                                        ZStack {
                                            Circle()
                                                .fill(isMultiSelected ? Color.blue : Color.gray.opacity(0.7))
                                                .frame(width: 16, height: 16)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(Color.white, lineWidth: 1.5)
                                                )
                                            if isMultiSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(1)
                                    }

                                    Spacer()

                                    // Price badge (always visible if cost exists)
                                    if let cost = cost {
                                        PriceDisplayView(
                                            price: cost,
                                            font: .system(size: 10, weight: .medium),
                                            foregroundColor: .white
                                        )
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    Color.black.opacity(0.7)
                                                )
                                        )
                                        .shadow(
                                            color: .black.opacity(0.3),
                                            radius: 2, x: 0,
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
                                // Selection overlay (darkens when selected in multi-select mode)
                                Group {
                                    if isMultiSelectMode {
                                        Rectangle()
                                            .fill(Color.black.opacity(isMultiSelected ? 0.3 : 0))
                                    }
                                }
                            )
                            .overlay(
                                VStack(alignment: .trailing, spacing: 4) {
                                    // Multi-select circle (top right)
                                    if isMultiSelectMode {
                                        ZStack {
                                            Circle()
                                                .fill(isMultiSelected ? Color.blue : Color.gray.opacity(0.7))
                                                .frame(width: 16, height: 16)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(Color.white, lineWidth: 1.5)
                                                )
                                            if isMultiSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(1)
                                    }

                                    Spacer()

                                    // Price badge (always visible if cost exists)
                                    if let cost = cost {
                                        PriceDisplayView(
                                            price: cost,
                                            font: .system(size: 10, weight: .medium),
                                            foregroundColor: .white
                                        )
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    Color.black.opacity(0.7)
                                                )
                                        )
                                        .shadow(
                                            color: .black.opacity(0.3),
                                            radius: 2, x: 0,
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
