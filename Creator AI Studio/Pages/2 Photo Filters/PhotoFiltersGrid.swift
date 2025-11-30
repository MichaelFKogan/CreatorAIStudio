import SwiftUI

struct PhotoFiltersGrid: View {
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let totalSpacing = spacing * 3
            let availableWidth = max(0, proxy.size.width - totalSpacing - 32)
            let itemSize = max(44, availableWidth / 3)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3),
                spacing: spacing
            ) {
                ForEach(filters) { filter in
                    FilterThumbnail(
                        title: filter.display.title,
                        imageName: filter.display.imageName,
                        isSelected: selectedFilter?.id == filter.id,
                        size: itemSize
                    )
                    .onTapGesture { onSelect(filter) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .frame(minHeight: 600)
    }
}
