import SwiftUI

struct Home: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var filtersViewModel = PhotoFiltersViewModel.shared
    @StateObject private var videoFiltersViewModel = VideoFiltersViewModel.shared
    @State private var showSignInSheet: Bool = false
    @State private var showPurchaseCreditsView: Bool = false
    let resetTrigger: UUID
    
    private let categoryManager = CategoryConfigurationManager.shared
    
    // Load image and video models
    private var imageModels: [InfoPacket] {
        ImageModelsViewModel.loadImageModels()
    }
    
    private var videoModels: [InfoPacket] {
        VideoModelsViewModel.loadVideoModels()
    }
    
    // Load video filters
    private var videoFilters: [InfoPacket] {
        videoFiltersViewModel.allVideoFilters
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

                        // Video Filters Row
                        if !videoFilters.isEmpty {
                            VideoRow(
                                title: "🕺 Viral Dance Videos",
                                items: videoFilters,
                                seeAllDestination: nil // TODO: Add VideoFiltersPage when ready
                            )
                        }

                        // Category Rows - manually listed
                        if hasCategoryItems("Anime") {
                            CategoryRow(categoryName: "Anime", animationType: .scanHorizontal)
                                .padding(.top, 16)
                        }
                        
                        if hasCategoryItems("Art") {
                            CategoryRow(categoryName: "Art", animationType: .scanHorizontal)
                        }
                        
                        // Image Models Row (inserted after 2nd category)
                        if !imageModels.isEmpty {
                            ModelRowGrid(
                                title: "Image Models",
                                iconName: "photo.on.rectangle",
                                items: imageModels,
                                seeAllDestination: AnyView(ImageModelsPage())
                            )
                        }

                        // Video Models Row (inserted after 3rd category)
                        if !videoModels.isEmpty {
                            ModelRowGrid(
                                title: "Video Models",
                                iconName: "video.fill",
                                items: videoModels,
                                seeAllDestination: AnyView(VideoModelsPage())
                            )
                        }
                        
                        if hasCategoryItems("Character") {
                            CategoryRow(categoryName: "Character", animationType: .flipCard)
                        }
                        
                        if hasCategoryItems("Video Games") {
                            CategoryRow(categoryName: "Video Games", animationType: .scanHorizontal)
                        }
                        if hasCategoryItems("Photography") {
                            CategoryRowGrid(categoryName: "Photography", animationType: .cameraAperture)
                        }
                        if hasCategoryItems("Instagram") {
                            CategoryRow(categoryName: "Instagram", animationType: nil)
                        }
                        if hasCategoryItems("Photobooth") {
                            CategoryRow(categoryName: "Photobooth", animationType: nil)
                        }
                        if hasCategoryItems("Fashion") {
                            CategoryRowGrid(categoryName: "Fashion", animationType: nil)
                        }
                        if hasCategoryItems("Spooky") {
                            CategoryRow(categoryName: "Spooky", animationType: nil)
                        }
                        if hasCategoryItems("Luxury") {
                            CategoryRowGrid(categoryName: "Luxury", animationType: nil)
                        }
                        if hasCategoryItems("Professional") {
                            CategoryRow(categoryName: "Professional", animationType: nil)
                        }
                        if hasCategoryItems("Chibi") {
                            CategoryRow(categoryName: "Chibi", animationType: nil)
                        }
                        if hasCategoryItems("Just For Fun") {
                            CategoryRowGrid(categoryName: "Just For Fun", animationType: nil)
                        }
                        if hasCategoryItems("Back In Time") {
                            CategoryRow(categoryName: "Back In Time", animationType: nil)
                        }
                        if hasCategoryItems("Men's") {
                            CategoryRow(categoryName: "Men's", animationType: nil)
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
                        HStack(spacing: 16) {
                            Group {
//                                if authViewModel.user == nil {
//                                    // Show "Sign in" button when logged out
//                                    Button(action: {
//                                        showSignInSheet = true
//                                    }) {
//                                        Text("Sign in")
//                                            .font(
//                                                .system(
//                                                    size: 16, weight: .semibold,
//                                                    design: .rounded)
//                                            )
//                                            .foregroundColor(.primary)
//                                    }
//                                } else {
                                    // Show credits badge when logged in
                                    Button(action: {
                                        showPurchaseCreditsView = true
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
//                                }
                            }
                            
                            // Settings button
                            NavigationLink(
                                destination: Settings(profileViewModel: nil)
                                    .environmentObject(authViewModel)
                            ) {
                                Image(systemName: "gearshape")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            .sheet(isPresented: $showSignInSheet) {
                SignInView()
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPurchaseCreditsView) {
                PurchaseCreditsView()
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var sortedCategoryNames: [String] {
        filtersViewModel.sortedCategoryNames
    }
    
    // Helper to check if a category has items
    private func hasCategoryItems(_ categoryName: String) -> Bool {
        !filtersViewModel.filters(for: categoryName).isEmpty
    }

    private var titleGradient: [Color] {
        colorScheme == .dark
            ? [.pink, .purple]
            : [.pink, .purple]
    }
}
