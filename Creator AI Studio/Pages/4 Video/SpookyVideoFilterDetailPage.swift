//
//  SpookyVideoFilterDetailPage.swift
//  Creator AI Studio
//
//  Spooky Video Filters: Kling O1 reference-to-video (user image + style reference image).
//

import AVFoundation
import AVKit
import PhotosUI
import SwiftUI

struct SpookyVideoFilterDetailPage: View {
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
    @AppStorage("videoFilterPreviewMuted") private var isVideoMuted: Bool = true // Default muted for autoplay; preference persisted
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var mainTabState: MainTabState
    
    private let defaultDurationOptions: [DurationOption] = [
        DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
        DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration"),
    ]
    private let defaultAspectOptions: [AspectRatioOption] = [
        AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
        AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
        AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
    ]
    
    private var videoDurationOptions: [DurationOption] {
        ModelConfigurationManager.shared.allowedDurations(for: item) ?? defaultDurationOptions
    }
    private var videoAspectOptions: [AspectRatioOption] {
        ModelConfigurationManager.shared.allowedAspectRatios(for: item) ?? defaultAspectOptions
    }
    
    /// Fixed 40 credits per video (Kling VIDEO O1 Standard).
    private var currentPrice: Decimal? {
        PricingManager.shared.price(for: item) ?? item.resolvedCost
    }
    
    private var requiredCredits: Double {
        let price = currentPrice ?? item.resolvedCost ?? 0
        return NSDecimalNumber(decimal: price).doubleValue
    }
    
    private var hasEnoughCredits: Bool {
        guard let userId = authViewModel.user?.id else { return false }
        return creditsViewModel.hasEnoughCredits(requiredAmount: requiredCredits)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AnimatedTitle(text: item.display.title)
                    .padding(.top, 16)
                
                LazyView(
                    SpookyBannerSection(
                        item: item,
                        price: currentPrice,
                        videoPlayer: $videoPlayer,
                        isVideoMuted: $isVideoMuted
                    )
                )
                
                Divider().padding(.horizontal)
                
                // Image upload
                ImageUploadSectionFilter(
                    referenceImage: $referenceImage,
                    selectedPhotoItem: $selectedPhotoItem,
                    showCameraSheet: $showCameraSheet,
                    showActionSheet: $showActionSheet,
                    color: .orange
                )
                
                Text("Upload a photo to use as the start frame. The video will match the style of the filter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Duration
                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DurationSelector(
                        options: videoDurationOptions,
                        selectedIndex: $selectedDurationIndex,
                        color: .orange
                    )
                }
                .padding(.horizontal)
                
                // Aspect ratio
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aspect ratio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    AspectRatioSelector(
                        options: videoAspectOptions,
                        selectedIndex: $selectedAspectIndex,
                        color: .orange
                    )
                }
                .padding(.horizontal)
                
                // Generate button
                GenerateButtonFilter(
                    isGenerating: $isGenerating,
                    price: currentPrice,
                    isLoggedIn: authViewModel.user != nil,
                    hasCredits: hasEnoughCredits,
                    isConnected: networkMonitor.isConnected,
                    hasImage: referenceImage != nil,
                    onSignInTap: { showSignInSheet = true },
                    action: generate
                )
                
                AuthAwareCostCard(
                    price: currentPrice ?? item.resolvedCost ?? 0,
                    requiredCredits: requiredCredits,
                    primaryColor: .orange,
                    secondaryColor: .red,
                    loginMessage: "Log in to generate a video",
                    isConnected: networkMonitor.isConnected,
                    onSignIn: { showSignInSheet = true },
                    onBuyCredits: { showPurchaseCreditsView = true }
                )
                .padding(.horizontal)
                
                Color.clear.frame(height: 100)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Spooky Video")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                CreditsToolbarView(
                    diamondColor: .orange,
                    borderColor: .orange,
                    showSignInSheet: $showSignInSheet,
                    showPurchaseCreditsView: $showPurchaseCreditsView
                )
            }
        }
        .alert("Image Required", isPresented: $showEmptyImageAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please upload an image to use as the start frame for your video.")
        }
        .alert("Insufficient Credits", isPresented: $showInsufficientCreditsAlert) {
            Button("Purchase Credits") { showPurchaseCreditsView = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need \(String(format: "$%.2f", requiredCredits)) to generate this video. Your current balance is \(creditsViewModel.formattedBalance()).")
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
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
                color: .orange
            )
        }
        .onAppear {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                setupVideoPlayer()
            }
        }
        .onDisappear {
            cleanupVideoPlayer()
        }
        .onChange(of: mainTabState.selectedTabIndex) { _, newTab in
            if newTab != 0 {
                cleanupVideoPlayer()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run { referenceImage = uiImage }
                }
            }
        }
        .onChange(of: showSignInSheet) { _, isPresented in
            if !isPresented, let userId = authViewModel.user?.id {
                Task { await creditsViewModel.fetchBalance(userId: userId) }
            }
        }
    }
    
    private func generate() {
        guard let image = referenceImage else {
            showEmptyImageAlert = true
            return
        }
        guard !isGenerating else { return }
        if !hasEnoughCredits {
            showInsufficientCreditsAlert = true
            return
        }
        
        isGenerating = true
        
        guard let refStyleURL = getReferenceStyleImageURL() else {
            isGenerating = false
            return
        }
        guard let userId = authViewModel.user?.id.uuidString.lowercased(), !userId.isEmpty else {
            isGenerating = false
            return
        }
        
        let durationOption = videoDurationOptions[selectedDurationIndex]
        let aspectOption = videoAspectOptions[selectedAspectIndex]
        
        var modifiedItem = item
        modifiedItem.display.modelName = "Kling VIDEO O1 Standard"
        modifiedItem.prompt = item.prompt
        modifiedItem.cost = 0.40
        
        Task { @MainActor in
            await PushNotificationManager.shared.checkAuthorizationStatus()
            if PushNotificationManager.shared.authorizationStatus == .notDetermined {
                _ = await PushNotificationManager.shared.requestPermissions()
            }
            _ = VideoGenerationCoordinator.shared.startVideoGeneration(
                item: modifiedItem,
                image: image,
                userId: userId,
                duration: durationOption.duration,
                aspectRatio: aspectOption.id,
                resolution: nil,
                storedDuration: durationOption.duration,
                generateAudio: nil,
                firstFrameImage: nil,
                lastFrameImage: nil,
                referenceVideoURL: nil,
                referenceStyleImageURL: refStyleURL,
                motionControlTier: nil,
                onVideoGenerated: { _ in isGenerating = false },
                onError: { _ in isGenerating = false }
            )
        }
    }
    
    private func getVideoURL(for item: InfoPacket) -> URL? {
        // Detail page banner: prefer full video with sound from Supabase (detailVideoURL)
        if let urlString = item.display.detailVideoURL, !urlString.isEmpty, let url = URL(string: urlString) {
            return url
        }
        let imageName = item.display.imageName
        if imageName.hasPrefix("http://") || imageName.hasPrefix("https://") {
            return URL(string: imageName)
        }
        let videoExtensions = ["mp4", "mov", "m4v", "webm"]
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext) {
                return url
            }
        }
        for ext in videoExtensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext, subdirectory: "Video Filters") {
                return url
            }
        }
        return nil
    }
    
    private func setupVideoPlayer() {
        guard let videoURL = getVideoURL(for: item) else { return }
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
        player.isMuted = isVideoMuted
        player.volume = 1.0
        player.actionAtItemEnd = .none
        playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak player] item, _ in
            guard let player = player else { return }
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    try? AVAudioSession.sharedInstance().setActive(true, options: [])
                    player.isMuted = isVideoMuted
                    player.play()
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        videoPlayer = player
        if playerItem.status == .readyToPlay {
            player.play()
        }
    }
    
    private func cleanupVideoPlayer() {
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
    
    /// Resolves the style reference image URL from item.referenceImageName (Supabase or bundle).
    private func getReferenceStyleImageURL() -> URL? {
        guard let name = item.referenceImageName, !name.isEmpty else { return nil }
        let base = "https://inaffymocuppuddsewyq.supabase.co/storage/v1/object/public/reference-images"
        // Prefer jpeg/jpg first (Supabase reference-images use .jpeg); then png, webp
        for ext in ["jpeg", "jpg", "png", "webp"] {
            if let url = URL(string: "\(base)/\(name).\(ext)") {
                return url
            }
        }
        for ext in ["jpeg", "jpg", "png"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}

// MARK: - Spooky banner (vertical video + Your Photo + arrow + model card)

private struct SpookyDiagonalOverlappingVideoImages: View {
    let leftImageName: String
    let rightImageName: String
    let videoPlayer: AVPlayer?
    @Binding var isVideoMuted: Bool
    
    @State private var arrowWiggle: Bool = false
    
    var body: some View {
        let availableWidth = UIScreen.main.bounds.width - 40
        let leftImageWidth = availableWidth * 0.20625
        let rightVideoWidth = availableWidth * 0.825
        let leftImageHeight = leftImageWidth * 1.38
        let rightVideoHeight = rightVideoWidth * 1.38
        let contentHeight = max(leftImageHeight, rightVideoHeight) + 40
        let calculatedHeight = max(280, min(400, contentHeight))
        
        GeometryReader { geometry in
            let leftImageWidth = geometry.size.width * 0.20625
            let rightVideoWidth = geometry.size.width * 0.825
            let leftImageHeight = leftImageWidth * 1.38
            let rightVideoHeight = rightVideoWidth * 1.38
            let rightVideoX: CGFloat = 0
            let rightVideoY: CGFloat = 0
            let overlapOffset: CGFloat = 15
            let leftImageX = -rightVideoWidth * 0.5 - leftImageWidth * 0.5 + overlapOffset
            let leftImageY = -rightVideoHeight * 0.5 - leftImageHeight * 0.5 + overlapOffset + 30 + 50
            let arrowX = leftImageX + leftImageWidth * 0.35
            let arrowY = leftImageY + leftImageHeight * 0.35
            let deltaX = rightVideoX - arrowX
            let deltaY = rightVideoY - arrowY
            let arrowAngle = atan2(deltaY, deltaX) * 180 / .pi
            
            ZStack(alignment: .center) {
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
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 4, y: 4)
                    .offset(x: rightVideoX, y: rightVideoY)
                } else {
                    Image(rightImageName)
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
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 4, y: 4)
                        .offset(x: rightVideoX, y: rightVideoY)
                }
                
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
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: -4, y: 4)
                    .rotationEffect(.degrees(-6))
                    .offset(x: leftImageX, y: leftImageY)
                
                Image("arrow")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(arrowAngle + (arrowWiggle ? 6 : -6)))
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: arrowWiggle
                    )
                    .offset(x: arrowX, y: arrowY)
            }
            .onAppear { arrowWiggle = true }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: calculatedHeight)
        .padding(.horizontal, 20)
    }
}

private struct SpookyBannerSection: View {
    let item: InfoPacket
    let price: Decimal?
    @Binding var videoPlayer: AVPlayer?
    @Binding var isVideoMuted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SpookyDiagonalOverlappingVideoImages(
                leftImageName: item.display.imageNameOriginal ?? "yourphoto",
                rightImageName: item.display.imageName,
                videoPlayer: videoPlayer,
                isVideoMuted: $isVideoMuted
            )
            .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    Image(item.display.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kling VIDEO O1")
                            .font(.title2).fontWeight(.bold).foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("Standard")
                            .font(.headline).fontWeight(.semibold).foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars").font(.caption)
                            Text("Spooky Video Filter").font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.orange.opacity(0.8)))
                        HStack(spacing: 4) {
                            PriceDisplayView(
                                price: price ?? item.resolvedCost ?? 0.40,
                                showUnit: true,
                                font: .title3,
                                fontWeight: .bold,
                                foregroundColor: .white
                            )
                            Text("per video").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 128)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                if let description = item.resolvedModelDescription ?? item.display.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                } else {
                    Color.clear.frame(height: 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal)
    }
}

// MARK: - Private filter components (mirror of DanceFilterDetailPage, orange theme)

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
            Text("Upload an image to use as the start frame")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.bottom, 4)
            if let image = referenceImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 140, maxHeight: 196)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.6), lineWidth: 2))
                    Button(action: { referenceImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red))
                    }
                    .padding(8)
                }
            } else {
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
                            .strokeBorder(style: StrokeStyle(lineWidth: 3.5, dash: [6, 4]))
                            .foregroundColor(.gray.opacity(0.4))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
}

private struct GenerateButtonFilter: View {
    @Binding var isGenerating: Bool
    let price: Decimal?
    let isLoggedIn: Bool
    let hasCredits: Bool
    let isConnected: Bool
    let hasImage: Bool
    let onSignInTap: () -> Void
    let action: () -> Void
    private var canGenerate: Bool { isLoggedIn && hasCredits && isConnected && hasImage }
    
    var body: some View {
        Button(action: {
            if !isLoggedIn { onSignInTap() }
            else { action() }
        }) {
            HStack {
                if isGenerating {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                }
                if isGenerating {
                    Text("Generating...").fontWeight(.semibold)
                } else {
                    Text("Generate").fontWeight(.semibold)
                    Image(systemName: "sparkle").font(.system(size: 14))
                    Text(PricingManager.formatPrice(price ?? 0)).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isGenerating || !canGenerate
                    ? LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.orange.opacity(0.8), Color.red], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isGenerating || !canGenerate)
        .opacity(canGenerate ? 1.0 : 0.6)
        .padding(.horizontal)
    }
}

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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showCameraSheet = true }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.fill").font(.system(size: 24)).foregroundColor(color).frame(width: 40)
                        Text("Camera").font(.headline).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 1, matching: .images) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 24)).foregroundColor(color).frame(width: 40)
                        Text("Gallery").font(.headline).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .onChange(of: selectedPhotoItems) { _, newItems in
                    if let item = newItems.first {
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
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
                    Button("Cancel") { showActionSheet = false }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}
