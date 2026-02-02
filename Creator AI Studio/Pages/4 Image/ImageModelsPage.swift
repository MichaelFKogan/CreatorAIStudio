import Combine
import PhotosUI
import SwiftUI

// MARK: MAIN CONTENT

struct ImageModelsPage: View {
    @StateObject private var viewModel = ImageModelsViewModel()
    @AppStorage("imageModelsIsGridView") private var isGridView = true
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                ImageMainContent(viewModel: viewModel, isGridView: $isGridView)
                    .padding(.bottom)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Image Models")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    CreditsToolbarView(diamondColor: .blue, borderColor: .blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OfflineToolbarIcon()
                }
            }
        }
    }
}

// Content-only version for use in container
struct ImageModelsPageContent: View {
    @StateObject private var viewModel = ImageModelsViewModel()
    @AppStorage("imageModelsIsGridView") private var isGridView = true
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                ImageMainContent(viewModel: viewModel, isGridView: $isGridView)
                    .padding(.bottom, 100) // Space for tab switcher
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Image Models")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    CreditsToolbarView(diamondColor: .blue, borderColor: .blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OfflineToolbarIcon()
                }
            }
        }
    }
}

// MARK: VIEW MODEL

final class ImageModelsViewModel: ObservableObject {
    @Published var imageFilterIndex: Int = 0 { didSet { updateModelsIfNeeded() } }
    @Published var sortOrder: Int = 0 { didSet { updateModelsIfNeeded() } }
    @Published private(set) var filteredAndSortedImageModels: [InfoPacket] = []

    private var allModels: [InfoPacket] = []
    private var lastComputedInputs: (filter: Int, sort: Int)?
    private var cancellables = Set<AnyCancellable>()

    // ✅ New init: load JSON
    init() {
        allModels = ImageModelsViewModel.loadImageModels()
        updateModels()
    }

    // MARK: - JSON LOADER

    static func loadImageModels() -> [InfoPacket] {
        guard let url = Bundle.main.url(forResource: "ImageModelData", withExtension: "json") else {
            print("JSON file not found")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            var decoded = try decoder.decode([InfoPacket].self, from: data)
            // Automatically set type for all items loaded from ImageModelData.json
            decoded = decoded.map { var item = $0; item.type = "Image Model"; return item }
            return decoded
        } catch {
            print("Failed to decode JSON:", error)
            return []
        }
    }

    var hasActiveFilters: Bool { imageFilterIndex != 0 }

    func clearFilters() {
        imageFilterIndex = 0
        sortOrder = 0
    }

    private func updateModelsIfNeeded() {
        let inputs = (filter: imageFilterIndex, sort: sortOrder)
        if lastComputedInputs == nil || lastComputedInputs! != inputs {
            updateModels()
        }
    }

    private func updateModels() {
        var models = allModels

        switch imageFilterIndex {
        case 1:
            // Text to Image Only - models that have Text to Image but NOT Image to Image
            models = models.filter {
                let caps = $0.resolvedCapabilities ?? []
                return caps.contains("Text to Image") && !caps.contains("Image to Image")
            }
        case 2:
            models = models.filter { $0.resolvedCapabilities?.contains("Image to Image") == true }
        default: break
        }

        switch sortOrder {
        case 1: models.sort { ($0.resolvedCost ?? 0) < ($1.resolvedCost ?? 0) }
        case 2: models.sort { ($0.resolvedCost ?? 0) > ($1.resolvedCost ?? 0) }
        default:
            break
        }

        filteredAndSortedImageModels = models
        lastComputedInputs = (imageFilterIndex, sortOrder)
    }
}

// final class ImageModelsViewModel: ObservableObject {
//     // Input controls (changing these triggers updateModels)
//     @Published var imageFilterIndex: Int = 0 { didSet { updateModelsIfNeeded() } }
//     @Published var sortOrder: Int = 0 { didSet { updateModelsIfNeeded() } } // 0 = default, 1 = low->high, 2 = high->low

//     // Output: cached filtered & sorted models
//     @Published private(set) var filteredAndSortedImageModels: [InfoPacket] = []

//     // Internal
//     private var allModels: [InfoPacket]
//     private var lastComputedInputs: (filter: Int, sort: Int)?
//     private var cancellables = Set<AnyCancellable>()

//     init(models: [InfoPacket]) {
//         allModels = models
//         // compute initial list
//         updateModels()
//     }

//     // Public helpers
//     var hasActiveFilters: Bool { imageFilterIndex != 0 }

//     func clearFilters() {
//         imageFilterIndex = 0
//         sortOrder = 0
//     }

//     // MARK: - Private: compute & cache

//     private func updateModelsIfNeeded() {
//         let inputs = (filter: imageFilterIndex, sort: sortOrder)
//         if lastComputedInputs == nil || lastComputedInputs! != inputs {
//             updateModels()
//         }
//     }

//     private func updateModels() {
//         var models = allModels

//         // Apply filter
//         switch imageFilterIndex {
//         case 1:
//             models = models.filter { $0.capabilities.contains("Text to Image") }
//         case 2:
//             models = models.filter { $0.capabilities.contains("Image to Image") }
//         default:
//             break
//         }

//         // Apply sort
//         switch sortOrder {
//         case 1: models.sort { $0.cost < $1.cost }
//         case 2: models.sort { $0.cost > $1.cost }
//         default: break
//         }

//         // Publish once
//         filteredAndSortedImageModels = models
//         lastComputedInputs = (imageFilterIndex, sortOrder)

//     }
// }

// MARK: - MainContent (small body)

private struct ImageMainContent: View {
    @ObservedObject var viewModel: ImageModelsViewModel
    @Binding var isGridView: Bool

    var body: some View {
        VStack(spacing: 12) {
            FilterSection(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.top, 8)

            SortAndViewToggle(viewModel: viewModel, isGridView: $isGridView)
                .padding(.horizontal)
                .padding(.top, 4)

            ContentList(viewModel: viewModel, isGridView: isGridView)

            Color.clear.frame(height: 160)
        }
    }
}


// MARK: FILTERS SECTION

private struct FilterSection: View {
    @ObservedObject var viewModel: ImageModelsViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text("Filter:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterPill(title: "All", isSelected: viewModel.imageFilterIndex == 0) {
                        viewModel.imageFilterIndex = 0
                    }
                    FilterPill(title: "Text to Image", isSelected: viewModel.imageFilterIndex == 1) {
                        viewModel.imageFilterIndex = 1
                    }
                    FilterPill(title: "Image to Image", isSelected: viewModel.imageFilterIndex == 2) {
                        viewModel.imageFilterIndex = 2
                    }
                }
                .padding(.vertical, 2)
            }

            if viewModel.hasActiveFilters {
                Button(action: viewModel.clearFilters) {
                    Text("Clear")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: PRICE & VIEW TOGGLE

private struct SortAndViewToggle: View {
    @ObservedObject var viewModel: ImageModelsViewModel
    @Binding var isGridView: Bool

    var body: some View {
        HStack {
            Spacer()

            // View Toggle
            Button {
                isGridView.toggle()
            } label: {
                HStack {
                    Image(systemName: isGridView ? "line.3.horizontal" : "square.grid.2x2")
                        .font(.caption)
                    Text(isGridView ? "List View" : "Grid View")
                        .font(.system(size: 14))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white).opacity(0.9)
            }

            Text(" | ")
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.white).opacity(0.9)

            // Sort button (cycles 0,1,2)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.sortOrder = (viewModel.sortOrder + 1) % 3
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Price")
                        .font(.system(size: 14))
                        .fontWeight(.semibold)
                    if viewModel.sortOrder == 1 {
                        Image(systemName: "arrow.down").font(.system(size: 10))
                    } else if viewModel.sortOrder == 2 {
                        Image(systemName: "arrow.up").font(.system(size: 10))
                    } else {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 10))
                    }
                }
                .foregroundColor(.white).opacity(0.9)
            }
        }
    }
}

// MARK: CONTENT LIST

private struct ContentList: View {
    @ObservedObject var viewModel: ImageModelsViewModel
    let isGridView: Bool

    // grid columns - using flexible with reduced spacing to prevent overlap on smaller devices
    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.filteredAndSortedImageModels.isEmpty {
                EmptyStateView(icon: "photo.slash", message: "No image models found")
            } else {
                if isGridView {
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(viewModel.filteredAndSortedImageModels) { item in
                            // Lightweight navigation (replace EmptyView with your detail view if needed)
                            NavigationLink(destination: ImageModelDetailPage(item: item)) {
                                ImageModelGridItem(item: item, viewModel: viewModel)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.filteredAndSortedImageModels) { item in
                            NavigationLink(destination: ImageModelDetailPage(item: item)) {
                                ImageModelListItem(item: item, viewModel: viewModel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: GRID VIEW

private struct ImageModelGridItem: View {
    let item: InfoPacket
    @ObservedObject var viewModel: ImageModelsViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                Image(item.display.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let capabilities = item.resolvedCapabilities, !capabilities.isEmpty {
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [Color.black.opacity(0.9), Color.black.opacity(0)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: 30)
                    }

                    HStack {
                        Text(capabilities.joined(separator: " • "))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                        Spacer()
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            HStack(alignment: .top) {
                Text(item.display.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                PriceDisplayView(
                    price: item.resolvedCost,
                    showUnit: true,
                    font: .system(size: 12, weight: .semibold, design: .rounded),
                    foregroundColor: .secondary
                )
            }
        }
    }
}

// MARK: LIST VIEW

private struct ImageModelListItem: View {
    let item: InfoPacket
    @ObservedObject var viewModel: ImageModelsViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(item.display.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 65, height: 65)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.display.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if viewModel.hasActiveFilters, let capabilities = item.resolvedCapabilities, !capabilities.isEmpty {
                    Text(capabilities.joined(separator: " • "))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                PriceDisplayView(
                    price: item.resolvedCost,
                    font: .caption,
                    foregroundColor: .white
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.4))
                .clipShape(Capsule())
                Text("per image")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: TOOLBAR

// MARK: FILTER PILL

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(isSelected ? .blue : .blue.opacity(0.12))
                .foregroundColor(isSelected ? .white : .blue)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : .blue.opacity(0.6), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: EMPTY STATE VIEW

private struct EmptyStateView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

// // MARK: - Credit Conversion Helper
// extension Decimal {
//     /// Converts dollar amount to credits (1 credit = $0.01)
//     var credits: Int {
//         let dollars = NSDecimalNumber(decimal: self).doubleValue
//         return Int((dollars * 100).rounded())
//     }
// }

// extension Optional where Wrapped == Decimal {
//     /// Converts dollar amount to credits, returns 0 if nil
//     var credits: Int {
//         guard let value = self else { return 0 }
//         return value.credits
//     }
// }


// MARK: - Tab Button Style Extension

extension View {
    func tabButtonStyle(isSelected: Bool) -> some View {
        font(.caption)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.gray.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    
    func modelTabButtonStyle(isSelected: Bool, selectedColor: Color, unselectedColor: Color) -> some View {
        font(.caption)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : selectedColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? selectedColor : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : unselectedColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
