import PhotosUI
import SwiftUI

struct VideoModelsPage: View {
    // MARK: STATE

    @State private var sortOrder = 0 // 0 = Default, 1 = Low->High, 2 = High->Low
    @State private var videoFilterIndex: Int = 0 // 0 = All, 1 = Text to Image, 2 = Image to Video
    @AppStorage("videoModelsIsGridView") private var isGridView = true // true = grid, false = list

    private var filteredAndSortedVideoModels: [InfoPacket] {
        var models = videoModelData

        // Apply category filter
        switch videoFilterIndex {
        case 1:
            models = models.filter {
                videoCapabilities(for: $0).contains("Text to Video")
            }
        case 2:
            models = models.filter {
                videoCapabilities(for: $0).contains("Video to Video")
            }
        case 3:
            models = models.filter {
                videoCapabilities(for: $0).contains("Audio")
            }
        default: break
        }

        // Apply sort
        switch sortOrder {
        case 1: return models.sorted { $0.cost < $1.cost }
        case 2: return models.sorted { $0.cost > $1.cost }
        default: return models
        }
    }

    // Capability detection functions - now using real data
    private func videoCapabilities(for model: InfoPacket) -> [String] {
        return model.capabilities
    }

    // Check if any filters are active
    private var hasActiveFilters: Bool {
        return videoFilterIndex != 0
    }

    // Clear all filters
    private func clearAllFilters() {
        withAnimation {
            videoFilterIndex = 0
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // MARK: FILTER PILLS

                    VStack(spacing: 12) {
                        // Image Filters
                        HStack(spacing: 8) {
                            Text("Filter:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    FilterPill(
                                        title: "All",
                                        isSelected: videoFilterIndex == 0,
                                        color: .purple
                                    ) {
                                        withAnimation { videoFilterIndex = 0 }
                                    }
                                    FilterPill(
                                        title: "Text to Video",
                                        isSelected: videoFilterIndex == 1,
                                        color: .purple
                                    ) {
                                        withAnimation { videoFilterIndex = 1 }
                                    }
                                    FilterPill(
                                        title: "Image to Video",
                                        isSelected: videoFilterIndex == 2,
                                        color: .purple
                                    ) {
                                        withAnimation { videoFilterIndex = 2 }
                                    }
                                    FilterPill(
                                        title: "Audio",
                                        isSelected: videoFilterIndex == 3,
                                        color: .purple
                                    ) {
                                        withAnimation { videoFilterIndex = 3 }
                                    }
                                }
                                .padding(.vertical, 2)
                            }

                            // Clear Filters Button
                            if hasActiveFilters {
                                Button(action: clearAllFilters) {
                                    Text("Clear")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.purple)
                                }
                            }
                        }

                        // MARK: LIST VIEW AND PRICE

                        HStack {
                            Spacer()
                            // View Toggle Button
                            Button {
                                withAnimation {
                                    isGridView.toggle()
                                }
                            } label: {
                                Image(systemName: isGridView ? "square.grid.2x2" : "line.3.horizontal")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                Text(isGridView ? "Grid View" : "List View")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }

                            Text(" | ")
                                .font(.caption)
                                .foregroundColor(.purple)

                            // Sort Button with Arrow Icons
                            Button {
                                withAnimation {
                                    sortOrder = (sortOrder + 1) % 3
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Price")
                                        .font(.caption)

                                    if sortOrder == 1 {
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 10))
                                    } else if sortOrder == 2 {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 10))
                                    } else {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.system(size: 10))
                                    }
                                }
                                .foregroundColor(.purple)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // MARK: PHOTO GRID

                    VStack(alignment: .leading, spacing: 16) {
                        if filteredAndSortedVideoModels.isEmpty {
                            EmptyStateView(
                                icon: "photo.slash",
                                message: "No video models found"
                            )
                        } else {
                            // MARK: GRID VIEW

                            if isGridView {
                                // Grid View
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                    ], spacing: 16
                                ) {
                                    ForEach(filteredAndSortedVideoModels) { item in
                                        NavigationLink(
                                            destination: VideoModelDetailPage(
                                                item: item)
                                        ) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                // Image with overlays
                                                ZStack(alignment: .bottom) {
                                                    Image(item.display.imageName)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(maxWidth: .infinity)
                                                        .frame(height: 180)
                                                        .clipped()
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))

                                                    // Gradient overlay for better text readability
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

                                                // Title and Cost section
                                                HStack(alignment: .top) {
                                                    Text(item.display.title)
                                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(2)
                                                    Spacer()
                                                    Text("$\(item.cost, specifier: "%.2f")")
                                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                        .foregroundColor(.purple)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                // MARK: LIST VIEW

                                // List View
                                VStack(spacing: 12) {
                                    ForEach(filteredAndSortedVideoModels) { item in
                                        NavigationLink(
                                            destination: VideoModelDetailPage(
                                                item: item)
                                        ) {
                                            HStack(spacing: 12) {
                                                // Model Image
                                                Image(item.display.imageName)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 70, height: 70)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                                // Model Info
                                                Text(item.display.title)
                                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)

                                                // // Capabilities
                                                // if !capabilities.isEmpty {
                                                //     Text(capabilities.joined(separator: " • "))
                                                //         .font(.custom("Nunito-Regular", size: 12))
                                                //         .foregroundColor(.secondary)
                                                //         .lineLimit(1)
                                                // }

                                                Spacer()
                                                VStack(alignment: .trailing) {
                                                    // Cost
                                                    Text("$\(item.cost, specifier: "%.2f")")
                                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                        .foregroundColor(.purple)
                                                    Text("per 8s video")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }

                                                // Chevron
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
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom)
            }

            // MARK: NAVIGATION BAR

            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Video Models")
                        .font(
                            .system(size: 28, weight: .bold, design: .rounded)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
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
                                    colors: [.purple, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .font(.system(size: 8))
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
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.purple, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
            }
        }
    }
}
