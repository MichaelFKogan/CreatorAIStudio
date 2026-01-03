import SwiftUI

struct Home: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var filtersViewModel = PhotoFiltersViewModel.shared
    @State private var showSubscriptionSheet: Bool = false
    @State private var showSignInSheet: Bool = false
    let resetTrigger: UUID
    
    private let categoryManager = CategoryConfigurationManager.shared
    
    // Load image and video models
    private var imageModels: [InfoPacket] {
        ImageModelsViewModel.loadImageModels()
    }
    
    private var videoModels: [InfoPacket] {
        VideoModelsViewModel.loadVideoModels()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner Carousel
                    BannerCarousel()
                        .padding(.top, 8)
                    
                    // Rest of content can go here
                    VStack(spacing: 20) {
                        // Image Models Row
                        if !imageModels.isEmpty {
                            ModelRow(
                                title: "Image Models",
                                iconName: "photo.on.rectangle",
                                items: imageModels,
                                seeAllDestination: AnyView(ImageModelsPage())
                            )
                            .padding(.top, 16)
                        }
                        
                        // Video Models Row
                        if !videoModels.isEmpty {
                            ModelRow(
                                title: "Video Models",
                                iconName: "video.fill",
                                items: videoModels,
                                seeAllDestination: AnyView(VideoModelsPage())
                            )
                        }
                        
                        // Display all categories in order
                        ForEach(Array(sortedCategoryNames.enumerated()), id: \.element) { index, categoryName in
                            let items = filtersViewModel.filters(for: categoryName)
                            if !items.isEmpty {
                                let emoji = categoryManager.emoji(for: categoryName)
                                CategoryRow(title: "\(emoji) \(categoryName)", items: items, rowIndex: index)
                            }
                        }
                        Color.clear.frame(height: 160)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {

                    // MARK: Leading Title
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: 8) {
                            Image("logo-image")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)  // adjust size as needed

                            Text("RunSpeed AI")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                // .foregroundStyle(
                                //     LinearGradient(
                                //         colors: titleGradient,
                                //         startPoint: .leading,
                                //         endPoint: .trailing
                                //     )
                                // )
                        }
                    }

                    // MARK: Sign In / Crown Icon for Subscription
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Group {
                            if authViewModel.user == nil {
                                // Show "Sign in" button when logged out
                                Button(action: {
                                    showSignInSheet = true
                                }) {
                                    Text("Sign in")
                                        .font(
                                            .system(
                                                size: 16, weight: .semibold,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.primary)
                                }
                            } else {
                                // Show crown icon when logged in
                                Button(action: {
                                    showSubscriptionSheet = true
                                }) {
                                    Image(systemName: "crown.fill")
                                        .font(
                                            .system(
                                                size: 14, weight: .semibold,
                                                design: .rounded)
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.yellow, .orange],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                        }
                    }
                }
            .sheet(isPresented: $showSignInSheet) {
                SignInView()
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionView()
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var sortedCategoryNames: [String] {
        filtersViewModel.sortedCategoryNames
    }

    private var titleGradient: [Color] {
        colorScheme == .dark
            ? [.pink, .purple]
            : [.pink, .purple]
    }
}
