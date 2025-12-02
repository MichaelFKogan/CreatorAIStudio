import SwiftUI

// MARK: - Compact Filters Grid (for sheet)

struct CompactFiltersGrid: View {
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void

    var body: some View {
        let spacing: CGFloat = 8
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 4)

        LazyVGrid(
            columns: columns,
            spacing: spacing
        ) {
            ForEach(filters) { filter in
                FilterThumbnail(
                    title: filter.display.title,
                    imageName: filter.display.imageName,
                    isSelected: selectedFilter?.id == filter.id,
                    size: 80
                )
                .onTapGesture { onSelect(filter) }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Filter Category Sheet

struct FilterCategorySheet: View {
    @Binding var isPresented: Bool
    let categorizedFilters: [FilterCategory: [InfoPacket]]
    let allFilters: [InfoPacket]
    @Binding var selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void

    @State private var expandedCategories: Set<FilterCategory> = []

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // All Filters section (always visible)
                        CategorySection(
                            title: "Popular",
                            icon: "square.grid.2x2.fill",
                            filters: allFilters,
                            selectedFilter: selectedFilter,
                            onSelect: { filter in
                                onSelect(filter)
                                isPresented = false
                            },
                            isExpanded: true,
                            isAlwaysExpanded: true
                        )
                        .padding(.top, 8)

                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 8)

                        // Category sections
                        ForEach(FilterCategory.allCases) { category in
                            if let filters = categorizedFilters[category], !filters.isEmpty {
                                CategorySection(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    filters: filters,
                                    selectedFilter: selectedFilter,
                                    onSelect: { filter in
                                        onSelect(filter)
                                        isPresented = false
                                    },
                                    isExpanded: expandedCategories.contains(category),
                                    isAlwaysExpanded: false,
                                    onToggle: {
                                        if expandedCategories.contains(category) {
                                            expandedCategories.remove(category)
                                        } else {
                                            expandedCategories.insert(category)
                                        }
                                    }
                                )

                                if category != FilterCategory.allCases.last {
                                    Divider()
                                        .background(Color.white.opacity(0.2))
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Category Section

struct CategorySection: View {
    let title: String
    let icon: String
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void
    let isExpanded: Bool
    let isAlwaysExpanded: Bool
    var onToggle: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            Button {
                if !isAlwaysExpanded {
                    onToggle?()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 24)

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    if !isAlwaysExpanded {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())

            // Filters grid (shown if expanded or always expanded)
            if isExpanded || isAlwaysExpanded {
                CompactFiltersGrid(
                    filters: filters,
                    selectedFilter: selectedFilter,
                    onSelect: onSelect
                )
                .padding(.bottom, 8)
            }
        }
    }
}
