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

    // Quick filters - returns first N filters from all filters, or all filters if limit is nil
    func quickFilters(limit: Int? = nil) -> [InfoPacket] {
        if let limit = limit {
            return Array(filters.prefix(limit))
        } else {
            return filters
        }
    }

    // Categorized filters - dynamically extracted from JSON category field
    var categorizedFilters: [String: [InfoPacket]] {
        var result: [String: [InfoPacket]] = [:]
        
        // Group filters by their category field
        for filter in filters {
            if let category = filter.category, !category.isEmpty {
                if result[category] == nil {
                    result[category] = []
                }
                result[category]?.append(filter)
            }
        }
        
        return result
    }
    
    // Get sorted category names for display
    var sortedCategoryNames: [String] {
        categorizedFilters.keys.sorted()
    }

    init() {
        loadFiltersJSON()
    }

    private func loadFiltersJSON() {
        guard let url = Bundle.main.url(forResource: "AllPhotoFilters", withExtension: "json") else {
            print("AllPhotoFilters.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([InfoPacket].self, from: data)
            filters = decoded
        } catch {
            print("Failed to decode AllPhotoFilters.json: \(error)")
        }
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
                        
                        // All Filters section
                        VStack(alignment: .leading, spacing: 12) {
                            // HStack {
                            //     Image(systemName: "square.grid.2x2.fill")
                            //         .font(.system(size: 16))
                            //         .foregroundColor(.green)
                            //     Text("Photo Filters")
                            //         .font(.system(size: 18, weight: .semibold))
                            //         .foregroundColor(.primary)
                            //     Spacer()
                            // }
                            // .padding(.horizontal, 16)

//                            .padding(.top, presetInfoPackets.isEmpty ? 16 : 8)
                            
                            PhotoFiltersGrid(
                                filters: viewModel.filters,
                                selectedFilter: selectedFilter,
                                onSelect: { filter in
                                    selectedFilter = filter
                                    navigationPath.append(filter)
                                }
                            )
                        }
                    }
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
}
