//
//  TechnoVikingFilterDetailPage.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/25/25.
//

import Kingfisher
import PhotosUI
import SwiftUI
import AVKit

struct TechnoVikingFilterDetailPage: View {
    @State var item: InfoPacket
    
    @State private var referenceImage: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    @State private var isGenerating: Bool = false
    @State private var showEmptyImageAlert: Bool = false
    @State private var showCameraSheet: Bool = false
    @State private var showActionSheet: Bool = false
    @State private var showSignInSheet: Bool = false
    @State private var showSubscriptionView: Bool = false
    @State private var showPurchaseCreditsView: Bool = false
    @AppStorage("testSubscriptionStatus") private var isSubscribed: Bool = false
    @State private var hasCredits: Bool = true
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var selectedAspectIndex: Int = 0
    @State private var selectedDurationIndex: Int = 0
    @State private var videoPlayer: AVPlayer? = nil
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // MARK: Constants - Default options for filter
    
    private let defaultDurationOptions: [DurationOption] = [
        DurationOption(
            id: "5",
            label: "5 seconds",
            duration: 5.0,
            description: "Standard duration"
        ),
        DurationOption(
            id: "10",
            label: "10 seconds",
            duration: 10.0,
            description: "Extended duration"
        ),
        DurationOption(
            id: "8",
            label: "8 seconds",
            duration: 8.0,
            description: "Medium duration"
        ),
    ]
    
    private let defaultAspectOptions: [AspectRatioOption] = [
        AspectRatioOption(
            id: "9:16", label: "9:16", width: 9, height: 16,
            platforms: ["TikTok", "Reels"]
        ),
        AspectRatioOption(
            id: "1:1", label: "1:1", width: 1, height: 1,
            platforms: ["Instagram"]
        ),
        AspectRatioOption(
            id: "16:9", label: "16:9", width: 16, height: 9,
            platforms: ["YouTube"]
        ),
    ]
    
    private var videoDurationOptions: [DurationOption] {
        ModelConfigurationManager.shared.allowedDurations(for: item)
            ?? defaultDurationOptions
    }
    
    private var videoAspectOptions: [AspectRatioOption] {
        ModelConfigurationManager.shared.allowedAspectRatios(for: item)
            ?? defaultAspectOptions
    }
    
    private var currentPrice: Decimal? {
        return item.resolvedCost
    }
    
    // MARK: BODY
    
    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {
                        LazyView(
                            BannerSectionFilter(
                                item: item, price: currentPrice, videoPlayer: $videoPlayer))
                        
                        Divider().padding(.horizontal)
                        
                        // Image Upload Section
                        LazyView(
                            ImageUploadSectionFilter(
                                referenceImage: $referenceImage,
                                selectedPhotoItem: $selectedPhotoItem,
                                showCameraSheet: $showCameraSheet,
                                showActionSheet: $showActionSheet,
                                color: .purple
                            ))
                        
                        // Network connectivity disclaimer
                        if !networkMonitor.isConnected {
                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Spacer()
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                    Text("No internet connection. Please connect to the internet.")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Login disclaimer
                        if authViewModel.user == nil {
                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Spacer()
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                    Text("You must be logged in to generate a video")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        showSignInSheet = true
                                    }) {
                                        Text("Sign In / Sign Up")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        } else if !isSubscribed {
                            VStack(spacing: 8) {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        showSubscriptionView = true
                                    }) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.yellow, .orange],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        Text("Subscribe")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                }
                                
                                HStack(spacing: 6) {
                                    Spacer()
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.orange)
                                    Text("Please Subscribe to create a video")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        } else if !hasCredits {
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Spacer()
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.orange)
                                    Text("Insufficient credits to generate")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                                
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        showPurchaseCreditsView = true
                                    }) {
                                        Text("Buy Credits")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        LazyView(
                            GenerateButtonFilter(
                                isGenerating: $isGenerating,
                                price: currentPrice,
                                isLoggedIn: authViewModel.user != nil,
                                isSubscribed: isSubscribed,
                                hasCredits: hasCredits,
                                isConnected: networkMonitor.isConnected,
                                hasImage: referenceImage != nil,
                                onSignInTap: {
                                    showSignInSheet = true
                                },
                                action: generate
                            ))
                        
                        // Informative text about aspect ratio matching
                        LazyView(
                            AspectRatioInfoSection()
                        )
                        
                        Divider().padding(.horizontal)
                        
                        Color.clear.frame(height: 130)  // bottom padding for floating button
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Video Filters")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                CreditsBadge(
                    diamondColor: .purple,
                    borderColor: .pink,
                    creditsAmount: "$10.00"
                )
            }
        }
        .alert("Image Required", isPresented: $showEmptyImageAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please upload an image to transform into a dancing video.")
        }
        .sheet(isPresented: $showCameraSheet) {
            SimpleCameraPicker(isPresented: $showCameraSheet) { capturedImage in
                referenceImage = capturedImage
            }
        }
        .sheet(isPresented: $showActionSheet) {
            SingleImageSourceSelectionSheet(
                showCameraSheet: $showCameraSheet,
                selectedPhotoItem: $selectedPhotoItem,
                showActionSheet: $showActionSheet,
                image: $referenceImage,
                color: .purple
            )
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPurchaseCreditsView) {
            PurchaseCreditsView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Setup video player if video is available
            setupVideoPlayer()
        }
        .onDisappear {
            // Clean up video player
            cleanupVideoPlayer()
        }
    }
    
    // MARK: FUNCTION GENERATE
    
    private func generate() {
        guard let image = referenceImage else {
            showEmptyImageAlert = true
            return
        }
        guard !isGenerating else { return }
        
        isGenerating = true
        // Use default aspect ratio (9:16) and duration (5 seconds)
        let defaultAspectRatio = "9:16"
        let defaultDuration = 5.0
        var modifiedItem = item
        
        // Set the model to Kling VIDEO 2.6 Pro for motion control
        modifiedItem.display.modelName = "Kling VIDEO 2.6 Pro"
        
        // Set the prompt for Techno Viking transformation
        // The prompt should instruct the model to transform the image into a dancing video
        modifiedItem.prompt = item.prompt ?? "Character performs the same movements from the reference video"
        
        // Use resolvedAPIConfig as base, then modify aspectRatio and model
        var config = modifiedItem.resolvedAPIConfig
        config.aspectRatio = defaultAspectRatio
        // Set the Runware model to Kling VIDEO 2.6 Pro
        config.runwareModel = "klingai:kling-video@2.6-pro"
        modifiedItem.apiConfig = config
        
        // Get the reference video URL from the bundle (separate from UI preview video)
        let referenceVideoURL = getReferenceVideoURL()
        
        guard let userId = authViewModel.user?.id.uuidString.lowercased(),
            !userId.isEmpty
        else {
            isGenerating = false
            return
        }
        
        // Ensure we have a reference video URL
        guard let refVideoURL = referenceVideoURL else {
            isGenerating = false
            print("Error: Reference video not found for Techno Viking filter")
            return
        }
        
        Task { @MainActor in
            _ = VideoGenerationCoordinator.shared.startVideoGeneration(
                item: modifiedItem,
                image: image,
                userId: userId,
                duration: defaultDuration,
                aspectRatio: defaultAspectRatio,
                resolution: nil,
                generateAudio: true, // Enable audio for motion control
                firstFrameImage: nil,
                lastFrameImage: nil,
                referenceVideoURL: refVideoURL, // Pass the reference video for motion control
                onVideoGenerated: { _ in
                    isGenerating = false
                },
                onError: { error in
                    isGenerating = false
                    print("Video generation failed: \(error.localizedDescription)")
                }
            )
        }
    }
    
    // MARK: REFERENCE VIDEO HELPER
    
    /// Gets the reference video URL for motion control (separate from UI preview video)
    private func getReferenceVideoURL() -> URL? {
        let referenceVideoName = "technoVikingReference"
        
        // Check if it's a URL string
        if referenceVideoName.hasPrefix("http://") || referenceVideoName.hasPrefix("https://") {
            return URL(string: referenceVideoName)
        }
        
        // Check if it's a video file in the bundle
        // Try common video extensions
        let videoExtensions = ["mp4", "mov", "m4v", "webm"]
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: referenceVideoName, withExtension: ext) {
                return url
            }
        }
        
        // Check in Video Filters subdirectory
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: referenceVideoName, withExtension: ext, subdirectory: "Video Filters") {
                return url
            }
        }
        
        return nil
    }
    
    // MARK: VIDEO PLAYER HELPERS
    
    private func getVideoURL(for item: InfoPacket) -> URL? {
        let imageName = item.display.imageName
        
        // Check if it's a URL string
        if imageName.hasPrefix("http://") || imageName.hasPrefix("https://") {
            return URL(string: imageName)
        }
        
        // Check if it's a video file in the bundle
        // Try common video extensions
        let videoExtensions = ["mp4", "mov", "m4v", "webm"]
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext) {
                return url
            }
        }
        
        // Check in Video Filters subdirectory
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext, subdirectory: "Video Filters") {
                return url
            }
        }
        
        return nil
    }
    
    private func setupVideoPlayer() {
        guard let videoURL = getVideoURL(for: item) else { return }
        
        let player = AVPlayer(url: videoURL)
        player.isMuted = true // Mute by default for autoplay
        player.actionAtItemEnd = .none // Don't pause at end
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        videoPlayer = player
        player.play()
    }
    
    private func cleanupVideoPlayer() {
        if let player = videoPlayer {
            player.pause()
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }
        videoPlayer = nil
    }
}

// MARK: BANNER SECTION

private struct BannerSectionFilter: View {
    let item: InfoPacket
    let price: Decimal?
    @Binding var videoPlayer: AVPlayer?
    
    private func getVideoURL(for item: InfoPacket) -> URL? {
        let imageName = item.display.imageName
        
        // Check if it's a URL string
        if imageName.hasPrefix("http://") || imageName.hasPrefix("https://") {
            return URL(string: imageName)
        }
        
        // Check if it's a video file in the bundle
        // Try common video extensions
        let videoExtensions = ["mp4", "mov", "m4v", "webm"]
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext) {
                return url
            }
        }
        
        // Check in Video Filters subdirectory
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext, subdirectory: "Video Filters") {
                return url
            }
        }
        
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                // Try to display video first, fallback to image
                if let player = videoPlayer {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 190, height: 254)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if getVideoURL(for: item) != nil {
                    // Video URL exists but player not ready yet - show placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 190, height: 254)
                        .overlay(
                            ProgressView()
                        )
                } else {
                    // Fallback to image
                    Image(item.resolvedModelImageName ?? item.display.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 190, height: 254)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Text(item.display.title)
                    Text("Techno Viking Dance")
                        .font(.title2).fontWeight(.bold).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars").font(.caption)
                        Text("Video Filter").font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.purple.opacity(0.8)))
                    
                    HStack(spacing: 4) {
                        PriceDisplayView(
                            price: price ?? item.resolvedCost ?? 0,
                            showUnit: true,
                            font: .title3,
                            fontWeight: .bold,
                            foregroundColor: .white
                        )
                        Text("per video").font(.caption).foregroundColor(.secondary)
                    }
                    
                    if let description = item.display.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.purple)
                            .lineLimit(3)
                    }
                    
                    // Kling VIDEO 2.6 Pro Model Info
                    VStack(alignment: .leading, spacing: 8) {
                        // Model Image - full width, square
                        Image("klingvideo26pro")
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        // Model Title and Info - in rows below image
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Kling VIDEO 2.6 Pro")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple)
                                Text("Video Generation Model")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 254)
            
            // // Filter Description
            // if let description = item.resolvedModelDescription ?? item.display.description,
            //     !description.isEmpty
            // {
            //     Text(description)
            //         .font(.system(size: 14))
            //         .foregroundColor(.secondary)
            //         .lineSpacing(4)
            //         .fixedSize(horizontal: false, vertical: true)
            //         .padding(.top, 4)
            // }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
}

// MARK: IMAGE UPLOAD SECTION

private struct ImageUploadSectionFilter: View {
    @Binding var referenceImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var showCameraSheet: Bool
    @Binding var showActionSheet: Bool
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(color)
                Text("Upload Your Image")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text("Upload an image to transform into a dancing video")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.bottom, 4)
            
            if let image = referenceImage {
                // Show uploaded image with remove button
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(color.opacity(0.6), lineWidth: 2)
                        )
                    
                    Button(action: { referenceImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red))
                    }
                    .padding(8)
                }
            } else {
                // Show add image button
                Button {
                    showActionSheet = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "camera")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        VStack(spacing: 4) {
                            Text("Add Image")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            Text("Camera or Gallery")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.gray.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 3.5, dash: [6, 4])
                            )
                            .foregroundColor(.gray.opacity(0.4))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
}

// MARK: ASPECT RATIO INFO SECTION

private struct AspectRatioInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.purple)
                Text("Video Aspect Ratio")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("The video generated will match the size and aspect ratio of the image you upload.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                        Text("If you upload a square image, your video will be square")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                        Text("If you upload a wide image, your video will be wide")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                        Text("If you upload a portrait photo, your video will be portrait size")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: ASPECT RATIO

private struct AspectRatioSectionFilter: View {
    let options: [AspectRatioOption]
    @Binding var selectedIndex: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Size")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, -6)
            AspectRatioSelector(
                options: options, selectedIndex: $selectedIndex, color: .purple
            )
        }
        .padding(.horizontal)
    }
}

// MARK: DURATION

private struct DurationSectionFilter: View {
    let options: [DurationOption]
    @Binding var selectedIndex: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Duration")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, -6)
            DurationSelector(
                options: options, selectedIndex: $selectedIndex, color: .purple
            )
        }
        .padding(.horizontal)
    }
}

// MARK: GENERATE BUTTON

private struct GenerateButtonFilter: View {
    @Binding var isGenerating: Bool
    let price: Decimal?
    let isLoggedIn: Bool
    let isSubscribed: Bool
    let hasCredits: Bool
    let isConnected: Bool
    let hasImage: Bool
    let onSignInTap: () -> Void
    let action: () -> Void
    
    private var canGenerate: Bool {
        isLoggedIn && isSubscribed && hasCredits && isConnected && hasImage
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                if !isLoggedIn {
                    onSignInTap()
                } else if !hasImage {
                    // Image required alert will be shown by parent
                    action()
                } else {
                    action()
                }
            }) {
                HStack {
                    if isGenerating {
                        ProgressView().progressViewStyle(
                            CircularProgressViewStyle(tint: .white)
                        ).scaleEffect(0.8)
                    } else {
                        Image(systemName: "video.fill")
                    }
                    HStack(spacing: 4) {
                        Text(isGenerating ? "Generating..." : "Generate Video - ")
                            .fontWeight(.semibold)
                        if !isGenerating {
                            PriceDisplayView(
                                price: price ?? 0,
                                showUnit: true,
                                fontWeight: .semibold,
                                foregroundColor: .white
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isGenerating || !canGenerate
                        ? LinearGradient(
                            colors: [Color.gray, Color.gray],
                            startPoint: .leading, endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color.purple.opacity(0.8), Color.pink],
                            startPoint: .leading, endPoint: .trailing
                        )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: (isGenerating || !canGenerate)
                        ? Color.clear : Color.purple.opacity(0.4),
                    radius: 8, x: 0, y: 4
                )
            }
            .scaleEffect(isGenerating ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
            .disabled(isGenerating || !canGenerate)
            .opacity(canGenerate ? 1.0 : 0.6)
            .padding(.horizontal)
            .background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: SINGLE IMAGE SOURCE SELECTION SHEET (reused from VideoModelDetailPage)

private struct SingleImageSourceSelectionSheet: View {
    @Binding var showCameraSheet: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var showActionSheet: Bool
    @Binding var image: UIImage?
    let color: Color
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button {
                    showActionSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCameraSheet = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(color)
                            .frame(width: 40)
                        Text("Camera")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 1,
                    matching: .images
                ) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(color)
                            .frame(width: 40)
                        Text("Gallery")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .onChange(of: selectedPhotoItems) { newItems in
                    if let item = newItems.first {
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                image = img
                            }
                            selectedPhotoItems.removeAll()
                            showActionSheet = false
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showActionSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}

//// MARK: LazyView helper
//
//struct LazyView<Content: View>: View {
//    let build: () -> Content
//    init(_ build: @autoclosure @escaping () -> Content) { self.build = build }
//    var body: some View { build() }
//}

