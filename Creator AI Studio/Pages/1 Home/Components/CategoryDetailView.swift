import SwiftUI
import Kingfisher

struct CategoryDetailView: View {
    let categoryName: String
    let items: [InfoPacket]
    
    // Computed property for title with emoji
    private var titleWithEmoji: String {
        let categoryManager = CategoryConfigurationManager.shared
        let emoji = categoryManager.emoji(for: categoryName)
        return "\(emoji) \(categoryName)"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Animated Title at the top (with emoji if available)
                AnimatedTitle(text: titleWithEmoji)
                
                // 2x2 Grid of all items in the category
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.blue)
                        Text("All \(categoryName) Styles")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    
                    Text("Browse all available styles in this category")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Grid of all items (2x2 layout)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6)
                    ],
                    spacing: 6
                ) {
                    ForEach(items) { item in
                        NavigationLink(
                            destination: PhotoFilterDetailView(item: item)
                        ) {
                            GeometryReader { geo in
                                Group {
                                    if let urlString = item.display.imageName.hasPrefix("http")
                                        ? item.display.imageName : nil,
                                        let url = URL(string: urlString)
                                    {
                                        KFImage(url)
                                            .placeholder {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .overlay(ProgressView())
                                            }
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width, height: 260)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    } else {
                                        Image(item.display.imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width, height: 260)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    }
                                }
                            }
                            .frame(height: 260)
                        }
                    }
                }
                
                // More Styles Section
                let moreStyles = getMoreStylesForCategory(categoryName)
                if !moreStyles.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundColor(.blue)
                            Text("More Styles")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        
                        HStack {
                            Text("See what's possible with this image style")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    MoreStylesImageSection(items: moreStyles)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 150)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Helper function to get more styles for a category
    private func getMoreStylesForCategory(_ categoryName: String) -> [InfoPacket] {
        let categoryManager = CategoryConfigurationManager.shared
        guard let moreStyles = categoryManager.moreStyles(for: categoryName),
              !moreStyles.isEmpty else {
            return []
        }
        
        let viewModel = PhotoFiltersViewModel.shared
        var result: [InfoPacket] = []
        
        // Iterate through each style group
        for styleGroup in moreStyles {
            for categoryName in styleGroup {
                let categoryFilters = viewModel.filters(for: categoryName)
                
                for filter in categoryFilters {
                    // Avoid duplicates and exclude items already in the main grid
                    if !items.contains(where: { $0.id == filter.id })
                        && !result.contains(where: { $0.id == filter.id })
                    {
                        result.append(filter)
                    }
                }
            }
        }
        
        return result
    }
}

