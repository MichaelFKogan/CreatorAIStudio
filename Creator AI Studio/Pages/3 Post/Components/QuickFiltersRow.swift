import SwiftUI

// MARK: - Quick Filters Row

struct QuickFiltersRow: View {
    let quickFilters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void
    let onShowAll: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
//                Text("Filters")
//                    .font(.caption)
//                    .foregroundColor(.white)

                // "See All" button
                Button {
                    onShowAll()
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 70, height: 70)

                            Image(systemName: "chevron.up")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )

                        Text("See All")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .frame(width: 70)
                    }
                }

                // Quick filter thumbnails
                ForEach(quickFilters) { filter in
                    FilterThumbnailCompact(
                        title: filter.display.title,
                        imageName: filter.display.imageName,
                        isSelected: selectedFilter?.id == filter.id,
                        cost: filter.cost
                    )
                    .onTapGesture {
                        onSelect(filter)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}
