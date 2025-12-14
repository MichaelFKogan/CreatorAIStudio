import Combine
import PhotosUI
import SwiftUI

// MARK: MAIN CONTENT

struct VideoModelsPage: View {
    //    @StateObject private var viewModel = VideoModelsViewModel(models: videoModelData)
    @StateObject private var viewModel = VideoModelsViewModel()
    @AppStorage("videoModelsIsGridView") private var isGridView = true

    var body: some View {
        NavigationView {
            ScrollView {
                MainContent(viewModel: viewModel, isGridView: $isGridView)
                    .padding(.bottom)
            }
            .navigationTitle("")
            .toolbar {
                // Leading title
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Video Models")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing)
                        )
                }

                // Trailing credits
                CreditsToolbarVideo()
            }
        }
    }
}

// MARK: VIEW MODEL

final class VideoModelsViewModel: ObservableObject {
    @Published var videoFilterIndex: Int = 0 { didSet { updateModelsIfNeeded() } }
    @Published var sortOrder: Int = 0 { didSet { updateModelsIfNeeded() } }
    @Published private(set) var filteredAndSortedVideoModels: [InfoPacket] = []

    private var allModels: [InfoPacket] = []
    private var lastComputedInputs: (filter: Int, sort: Int)?
    private var cancellables = Set<AnyCancellable>()

    // ✅ New init: load JSON
    init() {
        allModels = VideoModelsViewModel.loadVideoModels()
        updateModels()
    }

        // MARK: - JSON LOADER

    static func loadVideoModels() -> [InfoPacket] {
        guard let url = Bundle.main.url(forResource: "VideoModelData", withExtension: "json") else {
            print("JSON file not found")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([InfoPacket].self, from: data)
        } catch {
            print("Failed to decode JSON:", error)
            return []
        }
    }

    var hasActiveFilters: Bool { videoFilterIndex != 0 }

    func clearFilters() {
        videoFilterIndex = 0
        sortOrder = 0
    }

    private func updateModelsIfNeeded() {
        let inputs = (filter: videoFilterIndex, sort: sortOrder)
        if lastComputedInputs == nil || lastComputedInputs! != inputs {
            updateModels()
        }
    }

    private func updateModels() {
        var models = allModels

        switch videoFilterIndex {
        case 1:
            models = models.filter { $0.capabilities?.contains("Text to Video") == true }
        case 2:
            models = models.filter { $0.capabilities?.contains("Image to Video") == true }
        case 3:
            models = models.filter { $0.capabilities?.contains("Audio") == true }
        default:
            break
        }

        // Sort
        switch sortOrder {
        case 1: models.sort { ($0.cost ?? 0) < ($1.cost ?? 0) }
        case 2: models.sort { ($0.cost ?? 0) > ($1.cost ?? 0) }
        default:
            break
        }
            filteredAndSortedVideoModels = models
            lastComputedInputs = (videoFilterIndex, sortOrder)
    }
}

// final class VideoModelsViewModel: ObservableObject {
//    @Published var filterIndex: Int = 0 { didSet { updateModelsIfNeeded() } }
//    @Published var sortOrder: Int = 0 { didSet { updateModelsIfNeeded() } }

//    @Published private(set) var filteredAndSortedVideoModels: [InfoPacket] = []

//    private var allModels: [InfoPacket]
//    private var lastComputedInputs: (filter: Int, sort: Int)?
//    private var cancellables = Set<AnyCancellable>()

//    init(models: [InfoPacket]) {
//        allModels = models
//        updateModels()
//    }

//    var hasActiveFilters: Bool { filterIndex != 0 }

//    func clearFilters() {
//        withAnimation(.easeInOut(duration: 0.25)) {
//            filterIndex = 0
//            sortOrder = 0
//        }
//    }

//    private func updateModelsIfNeeded() {
//        let inputs = (filter: filterIndex, sort: sortOrder)
//        if lastComputedInputs == nil || lastComputedInputs! != inputs {
//            updateModels()
//        }
//    }

//    private func updateModels() {
//        var models = allModels

//        // Filter
//        switch filterIndex {
//        case 1:
//            models = models.filter { $0.capabilities.contains("Text to Video") }
//        case 2:
//            models = models.filter { $0.capabilities.contains("Image to Video") }
//        case 3:
//            models = models.filter { $0.capabilities.contains("Audio") }
//        default:
//            break
//        }

//        // Sort
//        switch sortOrder {
//        case 1: models.sort { $0.cost < $1.cost }
//        case 2: models.sort { $0.cost > $1.cost }
//        default: break
//        }

//        withAnimation(.easeInOut(duration: 0.25)) {
//            filteredAndSortedVideoModels = models
//            lastComputedInputs = (filterIndex, sortOrder)
//        }
//    }
// }

// MARK: MAIN CONTENT

private struct MainContent: View {
    @ObservedObject var viewModel: VideoModelsViewModel
    @Binding var isGridView: Bool

    var body: some View {
        VStack(spacing: 12) {
            FilterSection(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.top, 8)

            SortAndViewToggle(viewModel: viewModel, isGridView: $isGridView)
                .padding(.horizontal)

            ContentList(viewModel: viewModel, isGridView: isGridView)
        }
    }
}

// MARK: FILTER SECTION

private struct FilterSection: View {
    @ObservedObject var viewModel: VideoModelsViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text("Filter:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterPill(title: "All", isSelected: viewModel.videoFilterIndex == 0) {
                        viewModel.videoFilterIndex = 0
                    }
                    FilterPill(title: "Text to Video", isSelected: viewModel.videoFilterIndex == 1) {
                        viewModel.videoFilterIndex = 1
                    }
                    FilterPill(title: "Image to Video", isSelected: viewModel.videoFilterIndex == 2) {
                        viewModel.videoFilterIndex = 2
                    }
                    FilterPill(title: "Audio", isSelected: viewModel.videoFilterIndex == 3)
                        {
                        viewModel.videoFilterIndex = 3
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
    @ObservedObject var viewModel: VideoModelsViewModel
    @Binding var isGridView: Bool

    var body: some View {
        HStack {
            Spacer()

            Button {
                isGridView.toggle()
            } label: {
                HStack {
                    Image(
                        systemName: isGridView
                            ? "square.grid.2x2" : "line.3.horizontal"
                    )
                    .font(.system(size: 14))
                    .fontWeight(.semibold)
                    Text(isGridView ? "Grid View" : "List View")
                        .font(.system(size: 14))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white).opacity(0.9)
            }

            Text(" | ")
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.white).opacity(0.9)

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
                        Image(systemName: "arrow.up.arrow.down").font(
                            .system(size: 10))
                    }
                }
                .foregroundColor(.white).opacity(0.9)
            }
        }
    }
}

// MARK: CONTENT LIST

private struct ContentList: View {
    @ObservedObject var viewModel: VideoModelsViewModel
    let isGridView: Bool

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.filteredAndSortedVideoModels.isEmpty {
                EmptyStateView(
                    icon: "video.slash", message: "No video models found")
            } else {
                if isGridView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(viewModel.filteredAndSortedVideoModels) {
                            item in
                            NavigationLink(destination: EmptyView()) {
                                VideoModelGridItem(item: item)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.filteredAndSortedVideoModels) {
                            item in
                            NavigationLink(destination: EmptyView()) {
                                VideoModelListItem(item: item)
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

private struct VideoModelGridItem: View {
    let item: InfoPacket

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                Image(item.display.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .bottom,
                    endPoint: .center
                )
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            HStack(alignment: .top) {
                Text(item.display.title)
                    .font(
                        .system(size: 13, weight: .semibold, design: .rounded)
                    )
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Text("$\(NSDecimalNumber(decimal: item.cost ?? 0).stringValue)")
                    .font(
                        .system(size: 12, weight: .semibold, design: .rounded)
                    )
                    .foregroundColor(.purple)
            }
        }
    }
}

// MARK: LIST VIEW

private struct VideoModelListItem: View {
    let item: InfoPacket

    var body: some View {
        HStack(spacing: 12) {
            Image(item.display.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.display.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing) {
                Text("$\(NSDecimalNumber(decimal: item.cost ?? 0).stringValue)")
                    .font(
                        .system(size: 15, weight: .semibold, design: .rounded)
                    )
                    .foregroundColor(.purple)
                Text("per video")
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

private struct CreditsToolbarVideo: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 6) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("250")
                    .font(
                        .system(size: 14, weight: .semibold, design: .rounded)
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
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.purple, lineWidth: 1.5)
            )
        }
    }
}

// MARK: FILTER PILL

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(isSelected ? .purple : .purple.opacity(0.12))
                .foregroundColor(isSelected ? .white : .purple)
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : .purple.opacity(0.6),
                            lineWidth: 1)
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
