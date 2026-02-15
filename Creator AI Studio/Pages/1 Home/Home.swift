import SwiftUI

struct Home: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var filtersViewModel = PhotoFiltersViewModel.shared
    @StateObject private var videoFiltersViewModel = VideoFiltersViewModel.shared
    @State private var showSignInSheet = false
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
    
    // Spooky Video Filters (Kling O1 reference-to-video)
    private var spookyVideoFilters: [InfoPacket] {
        videoFiltersViewModel.spookyVideoFilters
    }
    
    // Mermaid Video Filters (WaveSpeed video-effects)
    private var mermaidVideoFilters: [InfoPacket] {
        videoFiltersViewModel.mermaidVideoFilters
    }

    // Anime Video Filters (Kling 2.6 image-to-video)
    private var animeVideoFilters: [InfoPacket] {
        videoFiltersViewModel.animeVideoFilters
    }

    // Yeti Video Filters
    private var yetiVideoFilters: [InfoPacket] {
        videoFiltersViewModel.yetiVideoFilters
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // // Banner Carousel
                    // BannerCarousel()
                    //     .padding(.top, 8)
                    
                    // Rest of content can go here
                    VStack(spacing: 20) {

                        // Video Filters Row
                        if !videoFilters.isEmpty {
                            VideoRowGrid(
                                title: "🕺 Viral Dance",
                                items: videoFilters,
                                seeAllDestination: nil // TODO: Add VideoFiltersPage when ready
                            )
                        }

                        if !animeVideoFilters.isEmpty {
                            VideoRowGrid(
                                title: "🌀 Anime",
                                items: animeVideoFilters,
                                seeAllDestination: nil
                            )
                        }

                        if !yetiVideoFilters.isEmpty {
                            VideoRowGrid(
                                title: "🦣 Yeti Vlog",
                                items: yetiVideoFilters,
                                seeAllDestination: nil
                            )
                        }
                        
                        // // Mermaid Video Filters Row (WaveSpeed video-effects)
                        // if !mermaidVideoFilters.isEmpty {
                        //     VideoRowGrid(
                        //         title: "🧜 Mermaid Video Filters",
                        //         items: mermaidVideoFilters,
                        //         seeAllDestination: nil
                        //     )
                        // }
                        
                        // WaveSpeed video-effect rows by category (Magical, Fashion, Video Games)
                        if !videoFiltersViewModel.wavespeedFilters(forCategory: "Enchanted").isEmpty {
                            VideoRowGrid(
                                title: "✨ Enchanted",
                                items: videoFiltersViewModel.wavespeedFilters(forCategory: "Enchanted"),
                                seeAllDestination: nil
                            )
                        }
                        if !videoFiltersViewModel.wavespeedFilters(forCategory: "Video Games").isEmpty {
                            VideoRowGrid(
                                title: "🎮 Video Games",
                                items: videoFiltersViewModel.wavespeedFilters(forCategory: "Video Games"),
                                seeAllDestination: nil
                            )
                        }
                        if !videoFiltersViewModel.wavespeedFilters(forCategory: "Creative").isEmpty {
                            VideoRowGrid(
                                title: "🎨 Creative",
                                items: videoFiltersViewModel.wavespeedFilters(forCategory: "Creative"),
                                seeAllDestination: nil
                            )
                        }
                        if !videoFiltersViewModel.wavespeedFilters(forCategory: "Superpower").isEmpty {
                            VideoRowGrid(
                                title: "🦸 Superpower",
                                items: videoFiltersViewModel.wavespeedFilters(forCategory: "Superpower"),
                                seeAllDestination: nil
                            )
                        }
                        if !videoFiltersViewModel.wavespeedFilters(forCategory: "Art").isEmpty {
                            VideoRowGrid(
                                title: "🖼️ Art",
                                items: videoFiltersViewModel.wavespeedFilters(forCategory: "Art"),
                                seeAllDestination: nil
                            )
                        }
                        if !videoFiltersViewModel.wavespeedFilters(forCategory: "Red Carpet").isEmpty {
                            VideoRowGrid(
                                title: "🌟 Red Carpet",
                                items: videoFiltersViewModel.wavespeedFilters(forCategory: "Red Carpet"),
                                seeAllDestination: nil
                            )
                        }

                        // Category Rows - manually listed
                        if hasCategoryItems("Anime") {
                            CategoryRowGrid(categoryName: "Anime", animationType: .scanHorizontal)
                                .padding(.top, 16)
                        }
                        
                        if hasCategoryItems("Art") {
                            CategoryRowGrid(categoryName: "Art", animationType: .scanHorizontal)
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
                            CategoryRowGrid(categoryName: "Character", animationType: .flipCard)
                        }
                        
                        if hasCategoryItems("Video Games") {
                            CategoryRowGrid(categoryName: "Video Games", animationType: .scanHorizontal)
                        }
                        if hasCategoryItems("Photography") {
                            CategoryRowGrid(categoryName: "Photography", animationType: .cameraAperture)
                        }
                        if hasCategoryItems("Instagram") {
                            CategoryRowGrid(categoryName: "Instagram", animationType: nil)
                        }
                        // if hasCategoryItems("Photobooth") {
                        //     CategoryRowGrid(categoryName: "Photobooth", animationType: nil)
                        // }
                        if hasCategoryItems("Fashion") {
                            CategoryRowGrid(categoryName: "Fashion", animationType: nil)
                        }
                        if hasCategoryItems("Spooky") {
                            CategoryRowGrid(categoryName: "Spooky", animationType: nil)
                        }
                        if !spookyVideoFilters.isEmpty {
                            VideoRowGrid(
                                title: "👻 Spooky Video Filters",
                                items: spookyVideoFilters,
                                seeAllDestination: nil
                            )
                        }
                        if hasCategoryItems("Luxury") {
                            CategoryRowGrid(categoryName: "Luxury", animationType: nil)
                        }
                        if hasCategoryItems("Professional") {
                            CategoryRowGrid(categoryName: "Professional", animationType: nil)
                        }
                        if hasCategoryItems("Chibi") {
                            CategoryRowGrid(categoryName: "Chibi", animationType: nil)
                        }
                        if hasCategoryItems("Just For Fun") {
                            CategoryRowGrid(categoryName: "Just For Fun", animationType: nil)
                        }
                        if hasCategoryItems("Back In Time") {
                            CategoryRowGrid(categoryName: "Back In Time", animationType: nil)
                        }
                        if hasCategoryItems("Men's") {
                            CategoryRowGrid(categoryName: "Men's", animationType: nil)
                        }
                        
                        Color.clear.frame(height: 160)
                    }
                }
                .padding(.top, 16)
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

                    // MARK: Sign in (Home only) + Credits + Settings
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 6) {
                            if authViewModel.user == nil {
                                Button("Sign in") {
                                    showSignInSheet = true
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            }
                            else {
                            CreditsToolbarView(
                                diamondColor: .purple,
                                borderColor: .purple,
                                showSignInSheet: $showSignInSheet
                            )
                            }

                            // NavigationLink(
                            //     destination: Settings(profileViewModel: nil)
                            //         .environmentObject(authViewModel)
                            // ) {
                            //     Image(systemName: "gearshape")
                            //         .font(.body)
                            //         .foregroundColor(.gray)
                            // }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        OfflineToolbarIcon()
                    }
                }
            .sheet(isPresented: $showSignInSheet) {
                SignInView()
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
