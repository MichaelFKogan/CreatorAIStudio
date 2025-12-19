import SwiftUI
import Kingfisher

// MARK: - Filter Model Selection Sheet

struct FilterModelSelectionView: View {
    @Binding var isPresented: Bool
    let capturedImage: UIImage
    let categorizedFilters: [String: [InfoPacket]]
    let allFilters: [InfoPacket]
    let imageModels: [InfoPacket]
    @Binding var selectedFilter: InfoPacket?
    @Binding var selectedImageModel: InfoPacket?
    let onSelectFilter: (InfoPacket) -> Void
    let onSelectModel: (InfoPacket) -> Void
    
    @State private var expandedCategories: Set<String> = []
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Use centralized category configuration manager
    private let categoryManager = CategoryConfigurationManager.shared
    
    // Get category names in the specified display order
    private var sortedCategoryNames: [String] {
        return categoryManager.sortedCategoryNames(from: Set(categorizedFilters.keys))
    }
    
    // Get category names that actually have filters (for divider logic)
    private var sortedCategoryNamesWithFilters: [String] {
        sortedCategoryNames.filter { 
            guard let filters = categorizedFilters[$0] else { return false }
            return !filters.isEmpty
        }
    }

    // Filter image models to only show those with Image to Image capability
    private var imageToImageModels: [InfoPacket] {
        imageModels.filter { model in
            model.resolvedCapabilities?.contains("Image to Image") == true
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Description text
                    Text("Choose either an AI Model or Photo Filter")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 8)

                    // AI Models section (dropdown like other categories)
                    if !imageToImageModels.isEmpty {
                        CategorySection(
                            title: "AI Models",
                            emoji: "🦾",
                            filters: imageToImageModels,
                            selectedFilter: selectedImageModel,
                            onSelect: { model in
                                // Update parent bindings and dismiss sheet
                                onSelectModel(model)
                                isPresented = false
                            },
                            isExpanded: expandedCategories.contains("AI Models"),
                            isAlwaysExpanded: false,
                            onToggle: {
                                if expandedCategories.contains("AI Models") {
                                    expandedCategories.remove("AI Models")
                                } else {
                                    expandedCategories.insert("AI Models")
                                }
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 8)
                    }

                    // Category sections - dynamically generated from JSON in specified order
                    ForEach(sortedCategoryNames, id: \.self) { categoryName in
                        if let filters = categorizedFilters[categoryName],
                            !filters.isEmpty
                        {
                            CategorySection(
                                title: categoryName,
                                emoji: emojiForCategory(categoryName),
                                filters: filters,
                                selectedFilter: selectedFilter,
                                onSelect: { filter in
                                    // Update parent bindings and dismiss sheet
                                    onSelectFilter(filter)
                                    isPresented = false
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

                            if categoryName != sortedCategoryNamesWithFilters.last {
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
        .navigationTitle("Select Filter or Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    isPresented = false
                }
                .foregroundColor(.white)
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // Helper function to get emoji for category name
    private func emojiForCategory(_ categoryName: String) -> String {
        return categoryManager.emoji(for: categoryName)
    }
}
