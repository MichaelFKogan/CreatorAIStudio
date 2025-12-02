import SwiftUI

// MARK: - Filter Scroll Row

struct FilterScrollRow: View {
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters) { filter in
                    FilterThumbnailCompact(
                        title: filter.display.title,
                        imageName: filter.display.imageName,
                        isSelected: selectedFilter?.id == filter.id
                    )
                    .onTapGesture {
                        onSelect(filter)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 100)
    }
}

// MARK: - Compact Filter Thumbnail for Horizontal Scroll

struct FilterThumbnailCompact: View {
    let title: String
    let imageName: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipped()
                    .cornerRadius(12)
                    .padding(0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.pink : Color.black.opacity(0), lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 0)
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.purple, .pink],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 22, height: 22)
                                    )
                                    .padding(4)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        },
                        alignment: .topTrailing
                    )
            }
            .padding(2)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.white)
                .frame(width: 70)
        }
    }
}

// MARK: - StyleSelectionButton Component

struct StyleSelectionButtonTwo: View {
    let title: String
    let icon: String
    let description: String
    let backgroundImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack {
            Button(action: action) {
                ZStack(alignment: .topTrailing) {
                    // Background image - no extra container
                    Image(backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipped()

                    // Clean content layout
                    VStack(alignment: .leading, spacing: 6) {
                        // Checkmark in top left
                        if isSelected {
                            HStack {
                                ZStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentColor)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isSelected
                                ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .shadow(
                    color: isSelected
                        ? .accentColor.opacity(0.3) : .black.opacity(0.1),
                    radius: isSelected ? 8 : 4, x: 0, y: 2
                )
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .padding(.vertical, 2)
            .buttonStyle(PlainButtonStyle())

            // Clean content layout
            VStack(alignment: .leading) {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.95))
                    .lineLimit(2)
            }
        }
    }
}
