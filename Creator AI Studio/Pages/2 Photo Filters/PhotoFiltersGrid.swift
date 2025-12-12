import SwiftUI

struct PhotoFiltersGrid: View {
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void
    
    private let columns = 4
    private let spacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 16
    
    private var itemSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let totalSpacing = spacing * CGFloat(columns - 1)
        let availableWidth = max(0, screenWidth - totalSpacing - (horizontalPadding * 2))
        return max(44, availableWidth / CGFloat(columns))
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(filters) { filter in
                FilterThumbnail(
                    title: filter.display.title,
                    imageName: filter.display.imageName,
                    isSelected: selectedFilter?.id == filter.id,
                    size: itemSize,
                    cost: filter.resolvedCost,
                    imageUrl: filter.display.imageName.hasPrefix("http") ? filter.display.imageName : nil
                )
                .onTapGesture { onSelect(filter) }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 16)
    }
}
