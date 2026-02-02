import PhotosUI
import SwiftUI
import Combine
import Kingfisher

// MARK: - FILTER CATEGORY

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
    
    // Shared instance for accessing filters from anywhere
    static let shared = PhotoFiltersViewModel()

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
    
    // Get filters by category name
    func filters(for category: String) -> [InfoPacket] {
        return categorizedFiltersDict[category] ?? []
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
                // Automatically set category and type for all items in this file
                decoded = decoded.map { var item = $0; 
                    item.category = categoryName; 
                    item.type = "Photo Filter"; 
                    return item 
                }
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

// MARK: - PHOTO FILTERS VIEW

struct PhotoFilters: View {
    @StateObject private var viewModel = PhotoFiltersViewModel()
//    @StateObject private var presetViewModel = PresetViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @State private var selectedFilter: InfoPacket? = nil
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var navigateToConfirmation: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var prompt: String = ""
    @State private var navigationPath = NavigationPath()
    @State private var selectedCategoryTab: String? = nil
    @State private var isMultiSelectMode: Bool = false
    @State private var selectedFilterIds: Set<UUID> = []
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
                // Horizontal scrollable category tab bar
                CategoryTabBar(
                    categories: viewModel.sortedCategoryNames,
                    selectedCategory: $selectedCategoryTab,
                    emojiForCategory: emojiForCategory,
                    onCategorySelected: { categoryName in
                        selectedCategoryTab = categoryName
                    }
                )
                .background(Color(.systemGroupedBackground))
                
                // Multi-Select toggle section
                HStack {
                    Spacer()
                    
                    Button(action: {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            selectedFilterIds.removeAll()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Multi-Select")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Toggle("", isOn: $isMultiSelectMode)
                                .scaleEffect(0.60)
                                .labelsHidden()
                                .onChange(of: isMultiSelectMode) { newValue in
                                    if !newValue {
                                        selectedFilterIds.removeAll()
                                    }
                                }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 2)
                .background(Color(.systemGroupedBackground))
                
                // Main content with ScrollViewReader
                ScrollViewReader { proxy in
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
                                        emoji: emojiForCategory(categoryName),
                                        filters: filters,
                                        selectedFilter: selectedFilter,
                                        isMultiSelectMode: isMultiSelectMode,
                                        selectedFilterIds: $selectedFilterIds,
                                        onSelect: { filter in
                                            if isMultiSelectMode {
                                                if selectedFilterIds.contains(filter.id) {
                                                    selectedFilterIds.remove(filter.id)
                                                } else {
                                                    // Limit to maximum 5 selections
                                                    if selectedFilterIds.count < 5 {
                                                        selectedFilterIds.insert(filter.id)
                                                    }
                                                }
                                            } else {
                                                selectedFilter = filter
                                                navigationPath.append(filter)
                                            }
                                        }
                                    )
                                    .id("category_\(categoryName)")
                                    
                                    if categoryName != viewModel.sortedCategoryNames.last {
                                        Divider()
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 16)
                                    }
                                }
                            }

                        // Bottom spacing
                        Color.clear.frame(height: 160)
                        }
                        // .padding(.top, 16)
                    }
                    .onChange(of: selectedCategoryTab) { newCategory in
                        if let category = newCategory {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("category_\(category)", anchor: .top)
                            }
                        }
                    }
                }

            //   PhotoFiltersBottomBar(
            //       showPhotoPicker: $showPhotoPicker,
            //       selectedPhotoItem: $selectedPhotoItem,
            //       cost: (selectedFilter?.cost as NSDecimalNumber?)?.doubleValue ?? 0.04
            //   )
            }
            .overlay(alignment: .bottom) {
                // Integrated single bar with preview thumbnails and confirm button
                if isMultiSelectMode && !selectedFilterIds.isEmpty {
                    VStack(spacing: 0) {
                        // Count and disclaimer text above thumbnails
                        HStack {
                            Text("\(selectedFilterIds.count) selected")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("Maximum 5")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        
                        // Preview thumbnails and confirm button row
                        HStack(spacing: 12) {
                            // Preview thumbnails (scrollable on the left)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(selectedFilters) { filter in
                                        ZStack(alignment: .topTrailing) {
                                            // Filter thumbnail
                                            Group {
                                                if let urlString = filter.display.imageName.hasPrefix("http") ? filter.display.imageName : nil,
                                                   let url = URL(string: urlString) {
                                                    KFImage(url)
                                                        .placeholder {
                                                            Rectangle()
                                                                .fill(Color.gray.opacity(0.2))
                                                                .overlay(ProgressView())
                                                        }
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 50, height: 50)
                                                        .clipped()
                                                        .cornerRadius(8)
                                                } else {
                                                    Image(filter.display.imageName)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 50, height: 50)
                                                        .clipped()
                                                        .cornerRadius(8)
                                                }
                                            }
                                            
                                            // Remove button
                                            Button(action: {
                                                selectedFilterIds.remove(filter.id)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .background(
                                                        Circle()
                                                            .fill(Color.black.opacity(0.6))
                                                    )
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                                .padding(.leading, 16)
                                .padding(.vertical, 8)
                            }
                            
                            // Confirm button (on the right)
                            NavigationLink(destination: destinationView) {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Next")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [.green, .teal],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            }
                            .padding(.trailing, 16)
                        }
                    }
                    .background(
                        Color(.systemGroupedBackground)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, y: -2)
                    )
                    .padding(.bottom, 60) // Account for bottom navbar (50-60px) + some extra padding
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedFilterIds.isEmpty)
                }
            }

// MARK: TOOLBAR
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
                    CreditsToolbarView(diamondColor: .green, borderColor: .mint)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OfflineToolbarIcon()
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
            // Fetch credit balance if user is signed in
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
//            // Load presets if user is signed in
//            if let userId = authViewModel.user?.id.uuidString {
//                presetViewModel.userId = userId
//                Task {
//                    await presetViewModel.fetchPresets()
//                }
//            }
        }
        .onChange(of: authViewModel.user) { newUser in
            // Refresh credits when user signs in or changes
            if let userId = newUser?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            } else {
                // Reset balance when user signs out
                creditsViewModel.balance = 0.00
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { notification in
            // Refresh credits when balance is updated (e.g., after image/video generation)
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
    }

    // @ViewBuilder
    // private var destinationView: some View {
    //     if let image = selectedImage, let filter = selectedFilter {
    //         EmptyView() // Replace w/ PhotoConfirmationView
    //     } else {
    //         EmptyView()
    //     }
    // }

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
    
    // Helper function to get emoji for category name
    private func emojiForCategory(_ categoryName: String) -> String {
        return CategoryConfigurationManager.shared.emoji(for: categoryName)
    }
    
    // Get selected filters based on selectedFilterIds
    private var selectedFilters: [InfoPacket] {
        viewModel.filters.filter { selectedFilterIds.contains($0.id) }
    }
    
    // Destination view for navigation based on number of selected filters
    @ViewBuilder
    private var destinationView: some View {
        if selectedFilters.count == 1, let firstFilter = selectedFilters.first {
            // Single filter - pass normally
            PhotoFilterDetailView(item: firstFilter)
        } else if let firstFilter = selectedFilters.first {
            // Multiple filters - pass first as item, rest as additionalFilters
            let additionalFilters = Array(selectedFilters.dropFirst())
            PhotoFilterDetailView(item: firstFilter, additionalFilters: additionalFilters)
        } else {
            // Fallback (shouldn't happen)
            EmptyView()
        }
    }
}

// MARK: - Category Tab Bar

struct CategoryTabBar: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    let emojiForCategory: (String) -> String
    let onCategorySelected: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { categoryName in
                    CategoryTabButton(
                        categoryName: categoryName,
                        emoji: emojiForCategory(categoryName),
                        isSelected: selectedCategory == categoryName,
                        onTap: {
                            onCategorySelected(categoryName)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 2)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct CategoryTabButton: View {
    let categoryName: String
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 16))
                
                Text(categoryName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.secondarySystemBackground))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isSelected ? Color.clear : Color(.separator).opacity(0.3),
                        lineWidth: isSelected ? 0 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - PHOTO FILTER CATEGORY SECTION

struct PhotoFilterCategorySection: View {
    let title: String
    let emoji: String
    let filters: [InfoPacket]
    let selectedFilter: InfoPacket?
    let isMultiSelectMode: Bool
    @Binding var selectedFilterIds: Set<UUID>
    let onSelect: (InfoPacket) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            HStack {
                Text(emoji)
                    .font(.system(size: 20))
                    .frame(width: 28)
                
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
                isMultiSelectMode: isMultiSelectMode,
                selectedFilterIds: $selectedFilterIds,
                onSelect: onSelect
            )
        }
    }
}
