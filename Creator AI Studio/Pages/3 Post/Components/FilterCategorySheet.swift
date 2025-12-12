import SwiftUI

// MARK: - Compact Filters Grid (for sheet)

struct CompactFiltersGrid: View {
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void

    var body: some View {
        let spacing: CGFloat = 8
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: spacing), count: 4)

        LazyVGrid(
            columns: columns,
            spacing: spacing
        ) {
            ForEach(filters) { filter in
                FilterThumbnailTwo(
                    title: filter.display.title,
                    imageName: filter.display.imageName,
                    isSelected: selectedFilter?.id == filter.id,
                    size: 80,
                    cost: filter.resolvedCost,
                    imageUrl: filter.display.imageName.hasPrefix("http")
                        ? filter.display.imageName : nil
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
    let categorizedFilters: [String: [InfoPacket]]
    let allFilters: [InfoPacket]
    let imageModels: [InfoPacket]
    @Binding var selectedFilter: InfoPacket?
    @Binding var selectedImageModel: InfoPacket?
    let onSelect: (InfoPacket) -> Void
    let onSelectModel: (InfoPacket) -> Void

    @State private var expandedCategories: Set<String> = []
//    @StateObject private var presetViewModel = PresetViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

//    // Convert presets to InfoPacket format
//    private var presetInfoPackets: [InfoPacket] {
//        let allModels = ImageModelsViewModel.loadImageModels()
//        return presetViewModel.presets.compactMap { preset in
//            preset.toInfoPacket(allModels: allModels)
//        }
//    }

    // Filter image models to only show those with Image to Image capability
    private var imageToImageModels: [InfoPacket] {
        imageModels.filter { model in
            model.capabilities?.contains("Image to Image") ?? false
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                //                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Description text
                        Text("Choose either an AI Model or Photo Filter")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            // .padding(.top, 16)
                            .padding(.bottom, 12)

                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 8)

                        // // Presets section (if any exist, shown first)
                        // if !presetInfoPackets.isEmpty {
                        //     CategorySection(
                        //         title: "My Presets",
                        //         icon: "bookmark.fill",
                        //         filters: presetInfoPackets,
                        //         selectedFilter: selectedFilter ?? selectedImageModel,
                        //         onSelect: { filter in
                        //             onSelect(filter)
                        //         },
                        //         isExpanded: true,
                        //         isAlwaysExpanded: true
                        //     )
                        //     .padding(.top, 8)

                        //     Divider()
                        //         .background(Color.white.opacity(0.2))
                        //         .padding(.vertical, 8)
                        // }

                        // AI Models section (first row, always visible)
                        if !imageToImageModels.isEmpty {
                            CategorySection(
                                title: "AI Models",
                                icon: "cpu",
                                filters: imageToImageModels,
                                selectedFilter: selectedImageModel,
                                onSelect: { model in
                                    onSelectModel(model)
                                },
                                isExpanded: true,
                                isAlwaysExpanded: true
                            )
                            .padding(.top, 8)

                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.vertical, 8)
                        }

                        // // All Filters section (always visible)
                        // CategorySection(
                        //     title: "Popular Filters",
                        //     icon: "square.grid.2x2.fill",
                        //     filters: allFilters,
                        //     selectedFilter: selectedFilter,
                        //     onSelect: { filter in
                        //         onSelect(filter)
                        //     },
                        //     isExpanded: true,
                        //     isAlwaysExpanded: true
                        // )
                        // .padding(.top, imageToImageModels.isEmpty ? 8 : 0)

                        // Divider()
                        //     .background(Color.white.opacity(0.2))
                        //     .padding(.vertical, 8)

                        // Category sections - dynamically generated from JSON
                        ForEach(Array(categorizedFilters.keys.sorted()), id: \.self) { categoryName in
                            if let filters = categorizedFilters[categoryName],
                                !filters.isEmpty
                            {
                                CategorySection(
                                    title: categoryName,
                                    icon: iconForCategory(categoryName),
                                    filters: filters,
                                    selectedFilter: selectedFilter,
                                    onSelect: { filter in
                                        onSelect(filter)
                                    },
                                    isExpanded: expandedCategories.contains(categoryName),
                                    isAlwaysExpanded: false,
                                    onToggle: {
                                        if expandedCategories.contains(categoryName) {
                                            expandedCategories.remove(categoryName)
                                        } else {
                                            expandedCategories.insert(categoryName)
                                        }
                                    }
                                )

                                if categoryName != categorizedFilters.keys.sorted().last {
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
            .navigationTitle("Filters & Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            //            .preferredColorScheme(.dark)
        }
        .presentationDetents([.medium, .large])
//        .onAppear {
//            // Load presets if user is signed in
//            if let userId = authViewModel.user?.id.uuidString {
//                presetViewModel.userId = userId
//                Task {
//                    await presetViewModel.fetchPresets()
//                }
//            }
//        }
    }
    
    // Helper function to get icon for category name
    private func iconForCategory(_ categoryName: String) -> String {
        // Try to match with FilterCategory enum first for known categories
        if let category = FilterCategory(rawValue: categoryName) {
            return category.icon
        }
        
        // Default icons for common category names
        let lowercased = categoryName.lowercased()
        if lowercased.contains("anime") {
            return "sparkles.rectangle.stack.fill"
        } else if lowercased.contains("character") || lowercased.contains("figure") {
            return "figure.stand"
        } else if lowercased.contains("art") || lowercased.contains("artistic") {
            return "paintbrush.fill"
        } else if lowercased.contains("game") || lowercased.contains("gaming") {
            return "gamecontroller.fill"
        } else if lowercased.contains("photo") || lowercased.contains("camera") {
            return "camera.fill"
        } else if lowercased.contains("creative") || lowercased.contains("design") {
            return "sparkles"
        } else {
            return "square.grid.2x2.fill" // Default icon
        }
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

                    if title.contains("AI Models") {
                        Text("Image to Image Models")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 2)
                    }

                    Spacer()

                    if !isAlwaysExpanded {
                        Image(
                            systemName: isExpanded
                                ? "chevron.up" : "chevron.down"
                        )
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
