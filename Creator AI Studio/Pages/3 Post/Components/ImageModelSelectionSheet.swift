import SwiftUI

// MARK: - Image Model Selection Sheet

struct ImageModelSelectionSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedModel: InfoPacket?
    
    @StateObject private var viewModel = ImageModelsViewModel()
    @AppStorage("imageModelsIsGridView") private var isGridView = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        FilterSection(viewModel: viewModel)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        SortAndViewToggle(viewModel: viewModel, isGridView: $isGridView)
                            .padding(.horizontal)
                        
                        ContentList(
                            viewModel: viewModel,
                            isGridView: isGridView,
                            selectedModel: $selectedModel,
                            isPresented: $isPresented
                        )
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("Select Image Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Filter Section

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

// MARK: - Sort and View Toggle

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
                    Image(systemName: isGridView ? "square.grid.2x2" : "line.3.horizontal")
                        .font(.caption)
                    Text(isGridView ? "Grid View" : "List View")
                        .font(.system(size: 14))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.primary)
            }
            
            Text(" | ")
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
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
                .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Content List

private struct ContentList: View {
    @ObservedObject var viewModel: ImageModelsViewModel
    let isGridView: Bool
    @Binding var selectedModel: InfoPacket?
    @Binding var isPresented: Bool
    
    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.filteredAndSortedImageModels.isEmpty {
                EmptyStateView(icon: "photo.slash", message: "No image models found")
            } else {
                if isGridView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(viewModel.filteredAndSortedImageModels) { item in
                            ImageModelGridItem(item: item, isSelected: selectedModel?.id == item.id)
                                .onTapGesture {
                                    selectedModel = item
                                    isPresented = false
                                }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.filteredAndSortedImageModels) { item in
                            ImageModelListItem(item: item, isSelected: selectedModel?.id == item.id)
                                .onTapGesture {
                                    selectedModel = item
                                    isPresented = false
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Grid Item

private struct ImageModelGridItem: View {
    let item: InfoPacket
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                Image(item.display.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 0)
                
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .bottom,
                    endPoint: .center
                )
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if isSelected {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .background(Circle().fill(Color.white))
                                .padding(8)
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 3 : 1)
            )
            
            HStack(alignment: .top) {
                Text(item.display.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("$\(NSDecimalNumber(decimal: item.cost ?? 0).stringValue)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - List Item

private struct ImageModelListItem: View {
    let item: InfoPacket
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(item.display.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 65, height: 65)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 0)
            
            Text(item.display.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("$\(NSDecimalNumber(decimal: item.cost ?? 0).stringValue)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                Text("per image")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
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

// MARK: - Empty State View

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

