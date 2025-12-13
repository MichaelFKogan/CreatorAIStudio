import PhotosUI
import SwiftUI
import Combine

// MARK: - Filter Category

enum FilterCategory: String, CaseIterable, Identifiable {
    case art = "Art"
    case anime = "Anime"
    case character = "Character"
    case gaming = "Gaming"
    case creative = "Creative"
    case photography = "Photography"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .art: return "paintbrush.fill"
        case .anime: return "sparkles"
        case .character: return "figure.stand"
        case .gaming: return "gamecontroller.fill"
        case .creative: return "paintbrush.fill"
        case .photography: return "camera.fill"
//        case luxury: return ""
//        case fashion: return ""
        }
    }
}

@MainActor
class PhotoFiltersViewModel: ObservableObject {
    @Published var filters: [InfoPacket] = []
    @Published private var categorizedFiltersDict: [String: [InfoPacket]] = [:]
    
    // Use centralized category configuration manager
    private let categoryManager = CategoryConfigurationManager.shared

    // Quick filters - returns first N filters from all filters, or all filters if limit is nil
    func quickFilters(limit: Int? = nil) -> [InfoPacket] {
        if let limit = limit {
            return Array(filters.prefix(limit))
        } else {
            return filters
        }
    }

    // Categorized filters - loaded from separate JSON files by category
    var categorizedFilters: [String: [InfoPacket]] {
        return categorizedFiltersDict
    }
    
    // Get category names in the specified display order
    // Categories not in the order list will appear at the end, sorted alphabetically
    var sortedCategoryNames: [String] {
        return categoryManager.sortedCategoryNames(from: Set(categorizedFilters.keys))
    }

    init() {
        loadFiltersJSON()
    }

    private func loadFiltersJSON() {
        // Get ordered array of (categoryName, fileName) tuples from centralized manager
        let categoryFileOrder = categoryManager.categoryFileOrder()
        
        var allFilters: [InfoPacket] = []
        var categorized: [String: [InfoPacket]] = [:]
        
        // Load each category file in the specified order
        for (categoryName, fileName) in categoryFileOrder {
            // Try loading from Data subdirectory first, then from bundle root
            var url: URL?
            if let dataUrl = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Data") {
                url = dataUrl
            } else if let rootUrl = Bundle.main.url(forResource: fileName, withExtension: "json") {
                url = rootUrl
            }
            
            guard let fileUrl = url else {
                print("\(fileName).json not found in bundle")
                continue
            }
            
            do {
                let data = try Data(contentsOf: fileUrl)
                var decoded = try JSONDecoder().decode([InfoPacket].self, from: data)
                // Automatically set category for all items in this file
                decoded = decoded.map { var item = $0; item.category = categoryName; return item }
                categorized[categoryName] = decoded
                allFilters.append(contentsOf: decoded)
            } catch {
                print("Failed to decode \(fileName).json: \(error)")
            }
        }
        
        // Update published properties
        categorizedFiltersDict = categorized
        filters = allFilters
    }
}

struct PhotoFilters: View {
    @StateObject private var viewModel = PhotoFiltersViewModel()
//    @StateObject private var presetViewModel = PresetViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedFilter: InfoPacket? = nil
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var navigateToConfirmation: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var prompt: String = ""
    @State private var navigationPath = NavigationPath()
    
    // // Convert presets to InfoPacket format
    // private var presetInfoPackets: [InfoPacket] {
    //     let allModels = ImageModelsViewModel.loadImageModels()
    //     let converted = presetViewModel.presets.compactMap { preset -> InfoPacket? in
    //         let result = preset.toInfoPacket(allModels: allModels)
    //         if result == nil {
    //             print("⚠️ [PhotoFilters] Preset '\(preset.title)' could not be converted to InfoPacket")
    //             print("   - Has modelName: \(preset.modelName != nil && !preset.modelName!.isEmpty)")
    //             if let modelName = preset.modelName {
    //                 print("   - ModelName: '\(modelName)'")
    //                 let matchingModel = allModels.first(where: { $0.display.title == modelName })
    //                 print("   - Found matching model: \(matchingModel != nil)")
    //             }
    //         }
    //         return result
    //     }
    //     // print("📊 [PhotoFilters] Total presets: \(presetViewModel.presets.count), Converted: \(converted.count)") 
    //     return converted
    // }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        
                        // // Presets section (if any exist)
                        // if !presetInfoPackets.isEmpty {
                        //     VStack(alignment: .leading, spacing: 0) {
                        //         HStack {
                        //             Image(systemName: "bookmark.fill")
                        //                 .font(.system(size: 16))
                        //                 .foregroundColor(.blue)
                        //             Text("My Presets")
                        //                 .font(.system(size: 18, weight: .semibold))
                        //                 .foregroundColor(.primary)
                        //             Spacer()
                        //         }
                        //         .padding(.horizontal, 16)
                        //         .padding(.top, 16)
                                
                        //         PhotoFiltersGrid(
                        //             filters: presetInfoPackets,
                        //             selectedFilter: selectedFilter,
                        //             onSelect: { filter in
                        //                 selectedFilter = filter
                        //                 navigationPath.append(filter)
                        //             }
                        //         )
                                
                        //         Divider()
                        //             .padding(.horizontal, 16)
                        //             .padding(.top, 8)
                        //     }
                        // }
                        
                        // Category sections - organized by category in specified order
                        ForEach(viewModel.sortedCategoryNames, id: \.self) { categoryName in
                            if let filters = viewModel.categorizedFilters[categoryName],
                                !filters.isEmpty
                            {
                                PhotoFilterCategorySection(
                                    title: categoryName,
                                    icon: iconForCategory(categoryName),
                                    filters: filters,
                                    selectedFilter: selectedFilter,
                                    onSelect: { filter in
                                        selectedFilter = filter
                                        navigationPath.append(filter)
                                    }
                                )
                                
                                if categoryName != viewModel.sortedCategoryNames.last {
                                    Divider()
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 8)
                                }
                            }
                        }

                    // Bottom spacing
                    Color.clear.frame(height: 160)
                    }
                    .padding(.top, 16)
                }

            //   PhotoFiltersBottomBar(
            //       showPhotoPicker: $showPhotoPicker,
            //       selectedPhotoItem: $selectedPhotoItem,
            //       cost: (selectedFilter?.cost as NSDecimalNumber?)?.doubleValue ?? 0.04
            //   )
            }

            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Photo Filters")
                        .font(
                            .system(size: 28, weight: .bold, design: .rounded)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .font(.system(size: 8))
                        Text("250")
                            .font(
                                .system(
                                    size: 14, weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(.white)
                        Text("credits")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.secondary.opacity(0.1))
                            .shadow(
                                color: Color.black.opacity(0.2), radius: 4,
                                x: 0, y: 2
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.mint, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
            }

            NavigationLink(
                destination: destinationView,
                isActive: $navigateToConfirmation,
                label: { EmptyView() }
            )
            .navigationDestination(for: InfoPacket.self) { filter in
                PhotoFilterDetailView(item: filter)
            }
        }
        .onChange(of: selectedPhotoItem, perform: loadPhoto)
        .onAppear {
            setDefaultFilter()
//            // Load presets if user is signed in
//            if let userId = authViewModel.user?.id.uuidString {
//                presetViewModel.userId = userId
//                Task {
//                    await presetViewModel.fetchPresets()
//                }
//            }
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        if let image = selectedImage, let filter = selectedFilter {
            EmptyView() // Replace w/ PhotoConfirmationView
        } else {
            EmptyView()
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        Task {
            guard let data = try? await item?.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { return }

            await MainActor.run { selectedImage = uiImage }
            try? await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run { navigateToConfirmation = true }
        }
    }

    private func setDefaultFilter() {
        if selectedFilter == nil { selectedFilter = viewModel.filters.first }
    }
    
    // Helper function to get icon for category name
    private func iconForCategory(_ categoryName: String) -> String {
        // Try to match with FilterCategory enum first for known categories
        if let category = FilterCategory(rawValue: categoryName) {
            return category.icon
        }
        
        // Use centralized category manager for icon lookup
        return CategoryConfigurationManager.shared.icon(for: categoryName)
    }
}

// MARK: - Photo Filter Category Section

struct PhotoFilterCategorySection: View {
    let title: String
    let icon: String
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let onSelect: (InfoPacket) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            // .padding(.top, 8)
            
            // Filters grid
            PhotoFiltersGrid(
                filters: filters,
                selectedFilter: selectedFilter,
                onSelect: onSelect
            )
        }
    }
}
