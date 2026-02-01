//
//  DanceFilterDetailPage.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/25/25.
//

import Kingfisher
import PhotosUI
import SwiftUI
import AVKit
import AVFoundation

struct DanceFilterDetailPage: View {
    @State var item: InfoPacket
    
    @State private var referenceImage: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    @State private var isGenerating: Bool = false
    @State private var showEmptyImageAlert: Bool = false
    @State private var showCameraSheet: Bool = false
    @State private var showActionSheet: Bool = false
    @State private var showSignInSheet: Bool = false
    @State private var showPurchaseCreditsView: Bool = false
    @State private var showInsufficientCreditsAlert: Bool = false
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var selectedAspectIndex: Int = 0
    @State private var selectedDurationIndex: Int = 0
    @State private var videoPlayer: AVPlayer? = nil
    @State private var playerItemObserver: NSKeyValueObservation? = nil
    @State private var isVideoMuted: Bool = true // Start muted for autoplay compliance
    
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
    
    // Calculate required credits as Double
    private var requiredCredits: Double {
        let price = currentPrice ?? item.resolvedCost ?? 0
        return NSDecimalNumber(decimal: price).doubleValue
    }
    
    // Check if user has enough credits
    private var hasEnoughCredits: Bool {
        guard let userId = authViewModel.user?.id else { return false }
        return creditsViewModel.hasEnoughCredits(requiredAmount: requiredCredits)
    }
    
    // MARK: BODY
    
    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Page Title - Animated
                        AnimatedTitle(text: item.display.title)
                            .padding(.top, 16)
                        
                        LazyView(
                            BannerSectionFilter(
                                item: item, price: currentPrice, videoPlayer: $videoPlayer, isVideoMuted: $isVideoMuted))
                        
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
                        
                        // Full body image disclaimer
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Spacer()
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                                Text("Please upload a full body image")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Spacer()
                            }
                            
                            HStack(alignment: .top, spacing: 6) {
                                Spacer()
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text("Uploading a square photo will result in a square video. Please upload the photo size that you want the video result to be (see instructions below)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)

                        LazyView(
                            GenerateButtonFilter(
                                isGenerating: $isGenerating,
                                price: currentPrice,
                                isLoggedIn: authViewModel.user != nil,
                                hasCredits: hasEnoughCredits,
                                isConnected: networkMonitor.isConnected,
                                hasImage: referenceImage != nil,
                                onSignInTap: {
                                    showSignInSheet = true
                                },
                                action: generate
                            ))

                        VStack(spacing: 12) {
                            // Use the reusable AuthAwareCostCard component
                            AuthAwareCostCard(
                                price: currentPrice ?? item.resolvedCost ?? 0,
                                requiredCredits: requiredCredits,
                                primaryColor: .purple,
                                secondaryColor: .pink,
                                loginMessage: "Log in to generate a video",
                                isConnected: networkMonitor.isConnected,
                                onSignIn: {
                                    showSignInSheet = true
                                },
                                onBuyCredits: {
                                    showPurchaseCreditsView = true
                                }
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, -8)  // Bring closer to the button above
                        
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
                CreditsToolbarView(
                    diamondColor: .purple,
                    borderColor: .pink,
                    showSignInSheet: $showSignInSheet,
                    showPurchaseCreditsView: $showPurchaseCreditsView
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
        .onAppear {
            // Configure audio session immediately when view appears
            // This helps iOS recognize the view transition as user interaction
            do {
                try AVAudioSession.sharedInstance().setCategory(
                    .playback,
                    mode: .default,
                    options: [.mixWithOthers, .duckOthers]
                )
                try AVAudioSession.sharedInstance().setActive(true, options: [])
            } catch {
                print("Failed to configure audio session on appear: \(error)")
            }
            
            // Setup video player if video is available
            // Small delay helps iOS recognize view transition as user interaction for audio autoplay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                setupVideoPlayer()
            }
            // Note: Credit balance fetching is now handled by AuthAwareCostCard
        }
        .onChange(of: showSignInSheet) { isPresented in
            // When sign-in sheet is dismissed, refresh credits if user signed in
            if !isPresented, let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { notification in
            // Refresh credits when balance is updated (e.g., after purchase)
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
        .alert("Insufficient Credits", isPresented: $showInsufficientCreditsAlert) {
            Button("Purchase Credits") {
                showPurchaseCreditsView = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need \(String(format: "$%.2f", requiredCredits)) to generate this. Your current balance is \(creditsViewModel.formattedBalance()).")
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
        
        // Check credits before generating
        if !hasEnoughCredits {
            showInsufficientCreditsAlert = true
            return
        }
        
        isGenerating = true
        
        // Calculate aspect ratio from the uploaded image
        let imageAspectRatio = calculateAspectRatio(from: image)
        
        // Duration is unknown until video is generated, so we'll pass a default for the API call
        // but store nil in the database to indicate it's not user-selected
        let apiDuration = 5.0 // Default for API call
        
        var modifiedItem = item
        
        // Set the model to Kling VIDEO 2.6 Pro for motion control
        modifiedItem.display.modelName = "Kling VIDEO 2.6 Pro"
        
        // Set the prompt for transformation
        // The prompt should instruct the model to transform the image into a dancing video
        modifiedItem.prompt = item.prompt ?? "The subject performs the same movements from the reference video while preserving their original appearance, anatomy, and physical characteristics. Only apply the motion pattern, not the body structure."
        
        // Use resolvedAPIConfig as base, then modify aspectRatio and model
        var config = modifiedItem.resolvedAPIConfig
        config.aspectRatio = imageAspectRatio
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
            print("Error: Reference video not found for \(item.display.title) filter")
            return
        }
        
        Task { @MainActor in
            await PushNotificationManager.shared.checkAuthorizationStatus()
            if PushNotificationManager.shared.authorizationStatus == .notDetermined {
                _ = await PushNotificationManager.shared.requestPermissions()
            }
            _ = VideoGenerationCoordinator.shared.startVideoGeneration(
                item: modifiedItem,
                image: image,
                userId: userId,
                duration: apiDuration,
                aspectRatio: imageAspectRatio,
                resolution: nil,
                storedDuration: nil, // Store nil in database since actual duration is unknown
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
    
    // MARK: - Helper to calculate aspect ratio from image
    
    private func calculateAspectRatio(from image: UIImage) -> String {
        let width = image.size.width
        let height = image.size.height
        
        // Calculate GCD to simplify the ratio
        let gcd = greatestCommonDivisor(Int(width), Int(height))
        let simplifiedWidth = Int(width) / gcd
        let simplifiedHeight = Int(height) / gcd
        
        // Return common aspect ratios or the simplified ratio
        let ratio = Double(width) / Double(height)
        
        // Check for common aspect ratios with tolerance
        if abs(ratio - (16.0/9.0)) < 0.1 {
            return "16:9"
        } else if abs(ratio - (9.0/16.0)) < 0.1 {
            return "9:16"
        } else if abs(ratio - 1.0) < 0.1 {
            return "1:1"
        } else if abs(ratio - (4.0/3.0)) < 0.1 {
            return "4:3"
        } else if abs(ratio - (3.0/4.0)) < 0.1 {
            return "3:4"
        } else {
            // Return simplified ratio
            return "\(simplifiedWidth):\(simplifiedHeight)"
        }
    }
    
    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var a = a
        var b = b
        while b != 0 {
            let temp = b
            b = a % b
            a = temp
        }
        return a
    }
    
    // MARK: REFERENCE VIDEO HELPER
    
    /// Gets the reference video URL for motion control (separate from UI preview video)
    /// Uses a pre-hosted Supabase URL to avoid uploading the same video with every request
    private func getReferenceVideoURL() -> URL? {
        // Get reference video name from item
        guard let referenceVideoName = getReferenceVideoName() else {
            print("Warning: No reference video name found for \(item.display.title)")
            return nil
        }
        
        // Construct Supabase URL
        let supabaseVideoURL = "https://inaffymocuppuddsewyq.supabase.co/storage/v1/object/public/reference-videos/\(referenceVideoName).mp4"
        
        // Use the hosted URL if available (preferred for efficiency)
        if let url = URL(string: supabaseVideoURL) {
            return url
        }
        
        // Fallback to local bundle (for development/testing)
        let videoExtensions = ["mp4", "mov", "m4v", "webm"]
        
        // Check bundle root
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: referenceVideoName, withExtension: ext) {
                return url
            }
        }
        
        // Check in Videos subdirectory
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: referenceVideoName, withExtension: ext, subdirectory: "Videos") {
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
    
    /// Helper to get reference video name from item
    private func getReferenceVideoName() -> String? {
        // First try to get from item's referenceVideoName field
        if let refVideoName = item.referenceVideoName, !refVideoName.isEmpty {
            return refVideoName
        }
        
        // Fallback: use a simple mapping based on title
        let titleLower = item.display.title.lowercased()
        if titleLower.contains("techno viking") {
            return "technoVikingReference"
        } else if titleLower.contains("gangnam style") {
            return "gangnamStyleReference"
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
        
        // Configure audio session aggressively to allow playback
        // Use .playback category with .mixWithOthers option to allow audio even in silent mode
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        let playerItem = AVPlayerItem(url: videoURL)
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = isVideoMuted // Sync with state
        player.volume = 1.0 // Ensure volume is at maximum
        player.actionAtItemEnd = .none // Don't pause at end
        
        // Wait for player item to be ready before playing
        // This ensures audio tracks are loaded
        playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak player] item, _ in
            guard let player = player else { return }
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    // Ensure audio session is still active
                    do {
                        try AVAudioSession.sharedInstance().setActive(true, options: [])
                    } catch {
                        print("Failed to reactivate audio session: \(error)")
                    }
                    // Sync mute state with player
                    player.isMuted = isVideoMuted
                    player.play()
                }
            }
        }
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        videoPlayer = player
        
        // Try to play immediately (may work if player item loads quickly)
        // The observer above will handle it if not ready yet
        if playerItem.status == .readyToPlay {
            player.play()
        }
    }
    
    private func cleanupVideoPlayer() {
        // Remove observer
        playerItemObserver?.invalidate()
        playerItemObserver = nil
        
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

// MARK: VIDEO CONTENT VIEW (Helper for sizing)

private struct VideoContentView: View {
    let item: InfoPacket
    let videoPlayer: AVPlayer?
    @Binding var isVideoMuted: Bool
    let getVideoURL: (InfoPacket) -> URL?
    let getVideoAspectRatio: (AVPlayer?) -> CGFloat?
    
    private var aspectRatio: CGFloat {
        if let player = videoPlayer {
            return getVideoAspectRatio(player) ?? (9.0 / 16.0)
        }
        return 9.0 / 16.0 // Default aspect ratio
    }
    
    var body: some View {
        let contentWidth: CGFloat = 350
        let contentHeight = contentWidth / aspectRatio
        
        Group {
            if let player = videoPlayer {
                VideoPlayerWithMuteButton(
                    player: player,
                    isMuted: $isVideoMuted,
                    width: contentWidth,
                    height: contentHeight,
                    cornerRadius: 12
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(width: contentWidth, height: contentHeight)
            } else if getVideoURL(item) != nil {
                // Video URL exists but player not ready yet - show placeholder
                let placeholderHeight = contentWidth / (9.0 / 16.0)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: contentWidth, height: placeholderHeight)
                    .overlay(
                        ProgressView()
                    )
            } else {
                // Fallback to image
                let imageHeight = contentWidth / (9.0 / 16.0)
                
                Image(item.resolvedModelImageName ?? item.display.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: contentWidth, height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(width: contentWidth, height: contentHeight)
    }
}

// MARK: - Diagonal Overlapping Video Images
struct DiagonalOverlappingVideoImages: View {
    let leftImageName: String
    let videoPlayer: AVPlayer?
    @Binding var isVideoMuted: Bool

    @State private var arrowWiggle: Bool = false

    var body: some View {
        // Calculate height based on available width (screen width minus horizontal padding)
        // This ensures consistent sizing across devices
        let availableWidth = UIScreen.main.bounds.width - 40  // Account for horizontal padding (20 on each side)
        let leftImageWidth = availableWidth * 0.20625  // 10% bigger (0.1875 * 1.10)
        let rightVideoWidth = availableWidth * 0.825  // 10% bigger (0.75 * 1.10)
        let leftImageHeight = leftImageWidth * 1.38
        let rightVideoHeight = rightVideoWidth * 1.38
        let contentHeight = max(leftImageHeight, rightVideoHeight) + 40  // Extra space for shadows and arrow
        let calculatedHeight = max(280, min(400, contentHeight))  // Clamp between 280 and 400

        GeometryReader { geometry in
            let leftImageWidth = geometry.size.width * 0.20625  // 10% bigger (0.1875 * 1.10)
            let rightVideoWidth = geometry.size.width * 0.825  // 10% bigger (0.75 * 1.10)
            let leftImageHeight = leftImageWidth * 1.38
            let rightVideoHeight = rightVideoWidth * 1.38
            
            // Calculate positions
            // Right video is centered (no offset)
            let rightVideoX: CGFloat = 0
            let rightVideoY: CGFloat = 0
            
            // Left image positioned so its bottom-right corner barely overlaps top-left corner of video
            // Top-left corner of video: (-rightVideoWidth/2, -rightVideoHeight/2)
            // Bottom-right corner of left image: (leftImageX + leftImageWidth/2, leftImageY + leftImageHeight/2)
            // Position for slight overlap
            let overlapOffset: CGFloat = 15  // Small overlap amount
            let leftImageX = -rightVideoWidth * 0.5 - leftImageWidth * 0.5 + overlapOffset  // Positioned so bottom-right corner overlaps top-left of video
            let leftImageY = -rightVideoHeight * 0.5 - leftImageHeight * 0.5 + overlapOffset + 30 + 50  // Moved down 50 pixels (was 30, now 80 total)
            
            // Arrow position: at the right bottom corner of the left photo
            // Position arrow at the bottom-right area of the left image
            let arrowX = leftImageX + leftImageWidth * 0.35  // Positioned at right side of left image
            let arrowY = leftImageY + leftImageHeight * 0.35  // Positioned at bottom area of left image
            
            // Calculate arrow rotation angle (pointing from left image to right video)
            let deltaX = rightVideoX - arrowX
            let deltaY = rightVideoY - arrowY
            let arrowAngle = atan2(deltaY, deltaX) * 180 / .pi  // Convert to degrees

            ZStack(alignment: .center) {
                // Right video player (centered, larger)
                if let player = videoPlayer {
                    VideoPlayerWithMuteButton(
                        player: player,
                        isMuted: $isVideoMuted,
                        width: rightVideoWidth,
                        height: rightVideoHeight,
                        cornerRadius: 16
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white, .gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.25), radius: 12, x: 4, y: 4
                    )
                    .offset(x: rightVideoX, y: rightVideoY)
                } else {
                    // Fallback to image if video player is not available
                    Image(leftImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: rightVideoWidth, height: rightVideoHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white, .gray],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: Color.black.opacity(0.25), radius: 12, x: 4, y: 4
                        )
                        .offset(x: rightVideoX, y: rightVideoY)
                }
                
                // Left image (smaller, overlapping top-left corner)
                Image(leftImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: leftImageWidth, height: leftImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white, .gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.25), radius: 12, x: -4,
                        y: 4
                    )
                    .rotationEffect(.degrees(-6))
                    .offset(x: leftImageX, y: leftImageY)

                // Arrow pointing from left image center to right video center
                Image("arrow")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)  // 25% smaller (40 * 0.75 = 30)
                    .rotationEffect(.degrees(arrowAngle + (arrowWiggle ? 6 : -6)))
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(
                            autoreverses: true), value: arrowWiggle
                    )
                    .offset(x: arrowX, y: arrowY)
            }
            .onAppear {
                arrowWiggle = true
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: calculatedHeight)  // Use calculated height for consistency
        .padding(.horizontal, 20)
    }
}

// MARK: BANNER SECTION

private struct BannerSectionFilter: View {
    let item: InfoPacket
    let price: Decimal?
    @Binding var videoPlayer: AVPlayer?
    @Binding var isVideoMuted: Bool
    
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
    
    private func getVideoAspectRatio(from player: AVPlayer?) -> CGFloat? {
        guard let player = player,
              let playerItem = player.currentItem,
              let track = playerItem.asset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        let size = track.naturalSize
        let transform = track.preferredTransform
        let width = abs(transform.a) * size.width + abs(transform.b) * size.height
        let height = abs(transform.c) * size.width + abs(transform.d) * size.height
        
        if height > 0 {
            return width / height
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Diagonal Overlapping Images with video on the right
            DiagonalOverlappingVideoImages(
                leftImageName: item.display.imageNameOriginal ?? "yourphoto",
                videoPlayer: videoPlayer,
                isVideoMuted: $isVideoMuted
            )
            .padding(.bottom, 8)
            
            // Horizontal row with model image, title, pill, pricing, model info
            HStack(alignment: .top, spacing: 16) {
                Image("klingvideo26pro")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kling VIDEO 2.6 Pro")
                        .font(.title2).fontWeight(.bold).foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("With Motion Control")
                        .font(.headline).fontWeight(.semibold).foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)                        
                    
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
                    
                    // HStack(spacing: 6) {
                    //     Image(systemName: "video.fill").font(.caption)
                    //     Text("Video Generation Model").font(.caption)
                    // }
                    // .foregroundColor(.purple)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .frame(height: 128)
            
            // Filter Description
            if let description = item.resolvedModelDescription ?? item.display.description,
                !description.isEmpty
            {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal)
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
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 140, maxHeight: 196)
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
    let hasCredits: Bool
    let isConnected: Bool
    let hasImage: Bool
    let onSignInTap: () -> Void
    let action: () -> Void
    
    private var canGenerate: Bool {
        isLoggedIn && hasCredits && isConnected && hasImage
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
                        // Image(systemName: "video.fill")
                    }
                    if isGenerating {
                        Text("Generating...")
                            .fontWeight(.semibold)
                    } else {
                        Text("Generate")
                            .fontWeight(.semibold)
                        Image(systemName: "sparkle")
                            .font(.system(size: 14))
                        Text(PricingManager.formatPrice(price ?? 0))
                            .fontWeight(.semibold)
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

