//
//  VideoModelsPageFast.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/25/25.
//

import Combine
import PhotosUI
import SwiftUI

// MARK: - VideoModelsPage (entry)

struct VideoModelsPage: View {
    @StateObject private var viewModel = VideoModelsViewModel(models: videoModelData)
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
                CreditsToolbar()
            }
        }
    }
}

// MARK: - ViewModel

final class VideoModelsViewModel: ObservableObject {
    @Published var filterIndex: Int = 0 { didSet { updateModelsIfNeeded() } }
    @Published var sortOrder: Int = 0 { didSet { updateModelsIfNeeded() } }

    @Published private(set) var filteredAndSortedVideoModels: [InfoPacket] = []

    private var allModels: [InfoPacket]
    private var lastComputedInputs: (filter: Int, sort: Int)?
    private var cancellables = Set<AnyCancellable>()

    init(models: [InfoPacket]) {
        allModels = models
        updateModels()
    }

    var hasActiveFilters: Bool { filterIndex != 0 }

    func clearFilters() {
        withAnimation(.easeInOut(duration: 0.25)) {
            filterIndex = 0
            sortOrder = 0
        }
    }

    private func updateModelsIfNeeded() {
        let inputs = (filter: filterIndex, sort: sortOrder)
        if lastComputedInputs == nil || lastComputedInputs! != inputs {
            updateModels()
        }
    }

    private func updateModels() {
        var models = allModels

        // Filter
        switch filterIndex {
        case 1:
            models = models.filter { $0.capabilities.contains("Text to Video") }
        case 2:
            models = models.filter { $0.capabilities.contains("Video to Video") }
        case 3:
            models = models.filter { $0.capabilities.contains("Audio") }
        default:
            break
        }

        // Sort
        switch sortOrder {
        case 1: models.sort { $0.cost < $1.cost }
        case 2: models.sort { $0.cost > $1.cost }
        default: break
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            filteredAndSortedVideoModels = models
            lastComputedInputs = (filterIndex, sortOrder)
        }
    }
}

// MARK: - MainContent

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

// MARK: - FilterSection

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
                    FilterPill(title: "All", isSelected: viewModel.filterIndex == 0) {
                        withAnimation { viewModel.filterIndex = 0 }
                    }
                    FilterPill(title: "Text to Video", isSelected: viewModel.filterIndex == 1) {
                        withAnimation { viewModel.filterIndex = 1 }
                    }
                    FilterPill(title: "Video to Video", isSelected: viewModel.filterIndex == 2) {
                        withAnimation { viewModel.filterIndex = 2 }
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

// MARK: - Sort & View Toggle

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
                    Image(systemName: isGridView ? "square.grid.2x2" : "line.3.horizontal")
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
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 10))
                    }
                }
                .foregroundColor(.white).opacity(0.9)
            }
        }
    }
}

// MARK: - ContentList

private struct ContentList: View {
    @ObservedObject var viewModel: VideoModelsViewModel
    let isGridView: Bool

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.filteredAndSortedVideoModels.isEmpty {
                EmptyStateView(icon: "video.slash", message: "No video models found")
            } else {
                if isGridView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(viewModel.filteredAndSortedVideoModels) { item in
                            NavigationLink(destination: EmptyView()) {
                                VideoModelGridItem(item: item)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.filteredAndSortedVideoModels) { item in
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

// MARK: - Grid Item

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
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer()

                Text("$\(NSDecimalNumber(decimal: item.cost).stringValue)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white).opacity(0.9)
            }
        }
    }
}

// MARK: - List Item

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
                Text("$\(NSDecimalNumber(decimal: item.cost).stringValue)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white).opacity(0.9)
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

// MARK: - Toolbar

private struct CreditsToolbar: ToolbarContent {
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

                Text("$5.00")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("credits left")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.purple, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Filter Pill

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
                .background(isSelected ? Color.purple.opacity(0.15) : Color.clear)
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.purple.opacity(0.6) : Color.gray.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

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
