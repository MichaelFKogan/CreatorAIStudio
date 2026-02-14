//
//  AnimeFilterDetailPage.swift
//  Creator AI Studio
//
//  Kling VIDEO 2.6 image-to-video filters (single image in -> video out).
//

import AVFoundation
import AVKit
import PhotosUI
import SwiftUI

private enum AnimeInputMode: CaseIterable {
    case textToVideo
    case imageToVideo
}

struct AnimeFilterDetailPage: View {
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
    @State private var showEmptyPromptAlert: Bool = false
    @State private var showImageRequiredAlert: Bool = false
    @State private var showPromptCameraSheet: Bool = false
    @State private var showFullPromptSheet: Bool = false
    @State private var showOCRAlert: Bool = false
    @State private var ocrAlertMessage: String = ""
    @State private var isProcessingOCR: Bool = false
    @State private var inputMode: AnimeInputMode = .imageToVideo
    @State private var prompt: String = ""
    @State private var isExamplePromptsPresented: Bool = false
    @FocusState private var isPromptFocused: Bool
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    @State private var selectedAspectIndex: Int = 0
    @State private var selectedDurationIndex: Int = 0
    @State private var selectedResolutionIndex: Int = 0
    @State private var videoPlayer: AVPlayer? = nil
    @State private var isBannerVideoReady: Bool = false
    @State private var playerItemObserver: NSKeyValueObservation? = nil
    @State private var showFullScreenVideo: Bool = false
    @AppStorage("videoFilterPreviewMuted") private var isVideoMuted: Bool = true

    @EnvironmentObject var authViewModel: AuthViewModel

    private let defaultDurationOptions: [DurationOption] = [
        DurationOption(id: "5", label: "5 seconds", duration: 5.0, description: "Standard duration"),
        DurationOption(id: "10", label: "10 seconds", duration: 10.0, description: "Extended duration")
    ]

    private let defaultAspectOptions: [AspectRatioOption] = [
        AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
        AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
        AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"])
    ]

    private let defaultResolutionOptions: [ResolutionOption] = [
        ResolutionOption(id: "720p", label: "720p", description: "HD quality"),
        ResolutionOption(id: "1080p", label: "1080p", description: "Full HD")
    ]

    private var videoDurationOptions: [DurationOption] {
        ModelConfigurationManager.shared.allowedDurations(for: item) ?? defaultDurationOptions
    }

    private var videoAspectOptions: [AspectRatioOption] {
        ModelConfigurationManager.shared.allowedAspectRatios(for: item) ?? defaultAspectOptions
    }

    private var videoResolutionOptions: [ResolutionOption] {
        ModelConfigurationManager.shared.allowedResolutions(for: item) ?? defaultResolutionOptions
    }

    private var examplePrompts: [String] { VideoPromptConstants.examplePrompts }
    private var transformPrompts: [String] { VideoPromptConstants.transformPrompts }

    private var currentPrice: Decimal? {
        guard selectedAspectIndex < videoAspectOptions.count,
              selectedDurationIndex < videoDurationOptions.count,
              selectedResolutionIndex < videoResolutionOptions.count else {
            return item.resolvedCost ?? item.cost
        }
        let modelName = "Kling VIDEO 2.6 Pro"
        let duration = videoDurationOptions[selectedDurationIndex].duration
        let resolution = videoResolutionOptions[selectedResolutionIndex].id
        let aspectRatio = videoAspectOptions[selectedAspectIndex].id
        return PricingManager.shared.variablePrice(for: modelName, aspectRatio: aspectRatio, resolution: resolution, duration: duration)
            ?? item.resolvedCost
            ?? item.cost
    }

    private var requiredCredits: Double {
        let price = currentPrice ?? item.resolvedCost ?? 0
        return NSDecimalNumber(decimal: price).doubleValue
    }

    private var hasEnoughCredits: Bool {
        guard authViewModel.user?.id != nil else { return false }
        return creditsViewModel.hasEnoughCredits(requiredAmount: requiredCredits)
    }

    private var hasRequiredImage: Bool {
        inputMode == .textToVideo || referenceImage != nil
    }

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        AnimatedTitle(text: item.display.title)
                            .padding(.top, 16)

                        LazyView(
                            AnimeBannerSection(
                                item: item,
                                price: currentPrice,
                                videoPlayer: $videoPlayer,
                                isVideoMuted: $isVideoMuted,
                                isBannerVideoReady: isBannerVideoReady,
                                onVideoTap: { showFullScreenVideo = true }
                            )
                        )

                        Divider().padding(.horizontal)

                        AnimePromptSection(
                            prompt: $prompt,
                            isFocused: $isPromptFocused,
                            isExamplePromptsPresented: $isExamplePromptsPresented,
                            onCameraTap: { showPromptCameraSheet = true },
                            onExpandTap: { showFullPromptSheet = true },
                            isProcessingOCR: $isProcessingOCR
                        )

                        AnimeInputModeSection(inputMode: $inputMode)

                        AnimeImageUploadSection(
                            referenceImage: $referenceImage,
                            selectedPhotoItem: $selectedPhotoItem,
                            showCameraSheet: $showCameraSheet,
                            showActionSheet: $showActionSheet
                        )

                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Spacer()
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                                    .foregroundColor(.pink)
                                Text("Best results: use a clear portrait or full-body photo")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)

                        AnimeAspectRatioSection(
                            options: videoAspectOptions,
                            selectedIndex: $selectedAspectIndex
                        )

                        AnimeResolutionSection(
                            options: videoResolutionOptions,
                            selectedIndex: $selectedResolutionIndex
                        )

                        AnimeDurationSection(
                            options: videoDurationOptions,
                            selectedIndex: $selectedDurationIndex
                        )

                        LazyView(
                            AnimeGenerateButton(
                                isGenerating: $isGenerating,
                                price: currentPrice,
                                isLoggedIn: authViewModel.user != nil,
                                hasCredits: hasEnoughCredits,
                                isConnected: networkMonitor.isConnected,
                                hasRequiredInput: hasRequiredImage,
                                onSignInTap: { showSignInSheet = true },
                                action: generate
                            )
                        )

                        VStack(spacing: 12) {
                            AuthAwareCostCard(
                                price: currentPrice ?? item.resolvedCost ?? 0,
                                requiredCredits: requiredCredits,
                                primaryColor: .purple,
                                secondaryColor: .pink,
                                loginMessage: "Log in to generate a video",
                                isConnected: networkMonitor.isConnected,
                                onSignIn: { showSignInSheet = true },
                                onBuyCredits: { showPurchaseCreditsView = true }
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, -8)

                        Color.clear.frame(height: 130)
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
            Text("Please upload an image to transform into an anime video.")
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
            AnimeImageSourceSheet(
                showCameraSheet: $showCameraSheet,
                selectedPhotoItem: $selectedPhotoItem,
                showActionSheet: $showActionSheet,
                image: $referenceImage
            )
        }
        .sheet(isPresented: $showPromptCameraSheet) {
            SimpleCameraPicker(isPresented: $showPromptCameraSheet) { capturedImage in
                processOCR(from: capturedImage)
            }
        }
        .sheet(isPresented: $showFullPromptSheet) {
            FullPromptSheet(
                prompt: $prompt,
                isPresented: $showFullPromptSheet,
                placeholder: "Describe the anime video you want to generate...",
                accentColor: .purple
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isExamplePromptsPresented) {
            ExamplePromptsSheet(
                examplePrompts: examplePrompts,
                examplePromptsTransform: transformPrompts,
                selectedPrompt: $prompt,
                isPresented: $isExamplePromptsPresented,
                title: "Example Prompts"
            )
        }
        .onAppear {
            prompt = item.prompt ?? ""
            if selectedAspectIndex >= videoAspectOptions.count { selectedAspectIndex = 0 }
            if selectedDurationIndex >= videoDurationOptions.count { selectedDurationIndex = 0 }
            if selectedResolutionIndex >= videoResolutionOptions.count { selectedResolutionIndex = 0 }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                try AVAudioSession.sharedInstance().setActive(true, options: [])
            } catch {
                print("Failed to configure audio session: \(error)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                setupVideoPlayer()
            }
        }
        .onDisappear {
            cleanupVideoPlayer()
        }
        .onChange(of: showSignInSheet) { isPresented in
            if !isPresented, let userId = authViewModel.user?.id {
                Task { await creditsViewModel.fetchBalance(userId: userId) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { _ in
            if let userId = authViewModel.user?.id {
                Task { await creditsViewModel.fetchBalance(userId: userId) }
            }
        }
        .alert("Insufficient Credits", isPresented: $showInsufficientCreditsAlert) {
            Button("Purchase Credits") { showPurchaseCreditsView = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need \(String(format: "$%.2f", requiredCredits)) to generate this. Your current balance is \(creditsViewModel.formattedBalance()).")
        }
        .alert("Prompt Required", isPresented: $showEmptyPromptAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enter a prompt to generate a video.")
        }
        .alert("Image Required", isPresented: $showImageRequiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please add a reference image for Image to Video.")
        }
        .alert("Text Recognition", isPresented: $showOCRAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ocrAlertMessage)
        }
        .sheet(isPresented: $showPurchaseCreditsView) {
            PurchaseCreditsView()
        }
        .sheet(isPresented: $showFullScreenVideo) {
            if let url = getVideoURL(for: item) {
                FullScreenVideoSheet(isPresented: $showFullScreenVideo, videoURL: url)
            }
        }
    }

    private func generate() {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showEmptyPromptAlert = true
            return
        }
        guard !isGenerating else { return }
        if inputMode == .imageToVideo, referenceImage == nil {
            showImageRequiredAlert = true
            return
        }
        if !hasEnoughCredits {
            showInsufficientCreditsAlert = true
            return
        }

        isGenerating = true
        let selectedAspectRatio = videoAspectOptions[selectedAspectIndex].id
        let selectedDuration = videoDurationOptions[selectedDurationIndex].duration
        let selectedResolution = videoResolutionOptions[selectedResolutionIndex].id

        guard let userId = authViewModel.user?.id.uuidString.lowercased(), !userId.isEmpty else {
            isGenerating = false
            return
        }

        var modifiedItem = item
        modifiedItem.display.modelName = "Kling VIDEO 2.6 Pro"
        modifiedItem.prompt = prompt
        var config = modifiedItem.resolvedAPIConfig
        config.runwareModel = "klingai:kling-video@2.6-pro"
        config.aspectRatio = selectedAspectRatio
        config.resolution = selectedResolution
        modifiedItem.apiConfig = config
        modifiedItem.cost = currentPrice

        Task { @MainActor in
            await PushNotificationManager.shared.checkAuthorizationStatus()
            if PushNotificationManager.shared.authorizationStatus == .notDetermined {
                _ = await PushNotificationManager.shared.requestPermissions()
            }
            _ = VideoGenerationCoordinator.shared.startVideoGeneration(
                item: modifiedItem,
                image: inputMode == .imageToVideo ? referenceImage : nil,
                userId: userId,
                duration: selectedDuration,
                aspectRatio: selectedAspectRatio,
                resolution: selectedResolution,
                storedDuration: selectedDuration,
                generateAudio: false,
                firstFrameImage: nil,
                lastFrameImage: nil,
                referenceVideoURL: nil,
                motionControlTier: nil,
                onVideoGenerated: { _ in
                    isGenerating = false
                },
                onError: { error in
                    isGenerating = false
                    print("Anime video generation failed: \(error.localizedDescription)")
                }
            )
        }
    }

    private func processOCR(from image: UIImage) {
        guard !isProcessingOCR else { return }
        isProcessingOCR = true

        Task { @MainActor in
            let recognizedText = await TextRecognitionService.recognizeText(from: image)
            isProcessingOCR = false
            if let text = recognizedText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if prompt.isEmpty {
                    prompt = cleanedText
                } else {
                    prompt += "\n\n" + cleanedText
                }
                ocrAlertMessage = "Text successfully extracted from image and added to prompt."
            } else {
                ocrAlertMessage = "No text could be detected in the image. Please try another image."
            }
            showOCRAlert = true
        }
    }

    private func calculateAspectRatio(from image: UIImage) -> String {
        let width = image.size.width
        let height = image.size.height
        let gcd = greatestCommonDivisor(Int(width), Int(height))
        let simplifiedWidth = Int(width) / gcd
        let simplifiedHeight = Int(height) / gcd
        let ratio = Double(width) / Double(height)
        if abs(ratio - (16.0 / 9.0)) < 0.1 { return "16:9" }
        if abs(ratio - (9.0 / 16.0)) < 0.1 { return "9:16" }
        if abs(ratio - 1.0) < 0.1 { return "1:1" }
        if abs(ratio - (4.0 / 3.0)) < 0.1 { return "4:3" }
        if abs(ratio - (3.0 / 4.0)) < 0.1 { return "3:4" }
        return "\(simplifiedWidth):\(simplifiedHeight)"
    }

    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var a = a, b = b
        while b != 0 { let t = b; b = a % b; a = t }
        return a
    }

    private func getVideoURL(for item: InfoPacket) -> URL? {
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
        isBannerVideoReady = false
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
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
                    isBannerVideoReady = true
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
        isBannerVideoReady = false
        playerItemObserver?.invalidate()
        playerItemObserver = nil
        if let player = videoPlayer {
            player.pause()
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        }
        videoPlayer = nil
    }
}

private struct AnimeBannerSection: View {
    let item: InfoPacket
    let price: Decimal?
    @Binding var videoPlayer: AVPlayer?
    @Binding var isVideoMuted: Bool
    let isBannerVideoReady: Bool
    var onVideoTap: (() -> Void)? = nil

    private func getVideoURL(for item: InfoPacket) -> URL? {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DiagonalOverlappingVideoImages(
                leftImageName: item.display.imageNameOriginal ?? "yourphoto",
                videoPlayer: videoPlayer,
                isVideoMuted: $isVideoMuted,
                isVideoLoading: getVideoURL(for: item) != nil && (videoPlayer == nil || !isBannerVideoReady),
                onVideoTap: onVideoTap
            )
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }
}

private struct AnimeImageUploadSection: View {
    @Binding var referenceImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var showCameraSheet: Bool
    @Binding var showActionSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.purple)
                Text("Upload Your Image")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text("Upload an image to transform into an anime video")
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
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.6), lineWidth: 2))
                    Button(action: { referenceImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red))
                    }
                    .padding(8)
                }
            } else {
                Button { showActionSheet = true } label: {
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

private struct AnimeGenerateButton: View {
    @Binding var isGenerating: Bool
    let price: Decimal?
    let isLoggedIn: Bool
    let hasCredits: Bool
    let isConnected: Bool
    let hasRequiredInput: Bool
    let onSignInTap: () -> Void
    let action: () -> Void
    private var canGenerate: Bool { isLoggedIn && hasCredits && isConnected && hasRequiredInput }

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
                    : LinearGradient(colors: [Color.purple.opacity(0.8), Color.pink], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isGenerating || !canGenerate)
        .opacity(canGenerate ? 1.0 : 0.6)
        .padding(.horizontal)
    }
}

private struct AnimeImageSourceSheet: View {
    @Binding var showCameraSheet: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var showActionSheet: Bool
    @Binding var image: UIImage?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button {
                    showActionSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showCameraSheet = true }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.fill").font(.system(size: 24)).foregroundColor(.purple).frame(width: 40)
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
                        Image(systemName: "photo.on.rectangle").font(.system(size: 24)).foregroundColor(.purple).frame(width: 40)
                        Text("Gallery").font(.headline).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .onChange(of: selectedPhotoItems) { newItems in
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

private struct AnimeInputModeSection: View {
    @Binding var inputMode: AnimeInputMode

    var body: some View {
        InputModeCard(color: .purple) {
            ChipOptionPicker(
                options: [
                    ("Text", "doc.text"),
                    ("Image", "photo")
                ],
                selection: Binding(
                    get: { inputMode == .textToVideo ? 0 : 1 },
                    set: { idx in inputMode = idx == 0 ? .textToVideo : .imageToVideo }
                ),
                color: .purple
            )
        } description: {
            VStack(alignment: .leading, spacing: 8) {
                if inputMode == .textToVideo {
                    Label("Text to Video", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Generate an anime-style video directly from your text prompt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label("Image to Video", systemImage: "photo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Upload an image and animate it using your text prompt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct AnimeAspectRatioSection: View {
    let options: [AspectRatioOption]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Size")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, -6)
            AspectRatioSelector(options: options, selectedIndex: $selectedIndex, color: .purple)
        }
        .padding(.horizontal)
    }
}

private struct AnimeResolutionSection: View {
    let options: [ResolutionOption]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resolution")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, -6)
            ResolutionSelector(options: options, selectedIndex: $selectedIndex, color: .purple)
        }
        .padding(.horizontal)
    }
}

private struct AnimeDurationSection: View {
    let options: [DurationOption]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Duration")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, -6)
            DurationSelector(options: options, selectedIndex: $selectedIndex, color: .purple)
        }
        .padding(.horizontal)
    }
}

private struct AnimePromptSection: View {
    @Binding var prompt: String
    @FocusState.Binding var isFocused: Bool
    @Binding var isExamplePromptsPresented: Bool
    let onCameraTap: () -> Void
    let onExpandTap: () -> Void
    @Binding var isProcessingOCR: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft").foregroundColor(.purple)
                Text("Prompt").font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
                Spacer()
                Button(action: onExpandTap) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                }
                .buttonStyle(PlainButtonStyle())
            }

            TextEditor(text: $prompt)
                .font(.system(size: 15))
                .opacity(0.9)
                .frame(height: 140)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.purple.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                )
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("Describe the anime video you want to generate...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .focused($isFocused)

            // HStack {
            //     Spacer(minLength: 0)
            //     HStack(spacing: 6) {
            //         VStack(alignment: .trailing, spacing: 2) {
            //             Text("Take a photo of a prompt")
            //                 .font(.caption2)
            //                 .foregroundColor(.secondary.opacity(0.7))
            //             Text("to add it to the box above")
            //                 .font(.caption2)
            //                 .foregroundColor(.secondary.opacity(0.7))
            //         }
            //         Button(action: onCameraTap) {
            //             Group {
            //                 if isProcessingOCR {
            //                     ProgressView()
            //                         .progressViewStyle(CircularProgressViewStyle(tint: .purple))
            //                         .scaleEffect(0.8)
            //                 } else {
            //                     Image(systemName: "viewfinder")
            //                         .font(.system(size: 18))
            //                         .foregroundColor(.purple)
            //                 }
            //             }
            //         }
            //         .buttonStyle(PlainButtonStyle())
            //     }
            // }

            Button(action: { isExamplePromptsPresented = true }) {
                HStack {
                    Image(systemName: "lightbulb.fill").foregroundColor(.purple).font(.caption)
                    Text("Example Prompts").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
}
