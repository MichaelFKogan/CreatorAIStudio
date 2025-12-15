import SwiftUI

struct PhotoFiltersGrid: View {
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let isMultiSelectMode: Bool
    @Binding var selectedFilterIds: Set<UUID>
    let onSelect: (InfoPacket) -> Void
    
    init(
        filters: [InfoPacket],
        selectedFilter: InfoPacket?,
        isMultiSelectMode: Bool = false,
        selectedFilterIds: Binding<Set<UUID>> = .constant([]),
        onSelect: @escaping (InfoPacket) -> Void
    ) {
        self.filters = filters
        self.selectedFilter = selectedFilter
        self.isMultiSelectMode = isMultiSelectMode
        self._selectedFilterIds = selectedFilterIds
        self.onSelect = onSelect
    }
    
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
                    imageUrl: filter.display.imageName.hasPrefix("http") ? filter.display.imageName : nil,
                    isMultiSelectMode: isMultiSelectMode,
                    isMultiSelected: selectedFilterIds.contains(filter.id)
                )
                .onTapGesture { onSelect(filter) }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 16)
    }
}
