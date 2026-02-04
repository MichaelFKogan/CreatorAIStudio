//
//  YetiFilterDetailPage.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/25/25.
//

import Kingfisher
import PhotosUI
import SwiftUI
import AVKit
import UIKit

//struct LazyView<Content: View>: View {
//    let build: () -> Content
//    init(_ build: @autoclosure @escaping () -> Content) { self.build = build }
//    var body: some View { build() }
//}

struct YetiFilterDetailPage: View {
    @State var item: InfoPacket
    
    @State private var prompt: String = ""
    @FocusState private var isPromptFocused: Bool
    @State private var isExamplePromptsPresented: Bool = false
    
    @State private var isGenerating: Bool = false
    @State private var showEmptyPromptAlert: Bool = false
    @State private var showSignInSheet: Bool = false
    @State private var showPurchaseCreditsView: Bool = false
    @State private var showInsufficientCreditsAlert: Bool = false
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var selectedAspectIndex: Int = 0
    @State private var selectedDurationIndex: Int = 0
    @State private var selectedResolutionIndex: Int = 0
    @State private var generateAudio: Bool = true  // Default to ON for audio generation
    @State private var videoPlayer: AVPlayer? = nil
    @State private var isVideoMuted: Bool = true
    @State private var keyboardHeight: CGFloat = 0
    
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
    
    private let defaultResolutionOptions: [ResolutionOption] = [
        ResolutionOption(
            id: "480p", label: "480p", description: "Standard quality"),
        ResolutionOption(
            id: "720p", label: "720p", description: "High quality"),
        ResolutionOption(id: "1080p", label: "1080p", description: "Full HD"),
    ]
    
    // MARK: Computed Properties - Model-specific options
    
    // Force use of Google Veo 3.1 Fast model configuration
    private var videoDurationOptions: [DurationOption] {
        // Get options for Google Veo 3.1 Fast
        var veoItem = item
        veoItem.display.modelName = "Google Veo 3.1 Fast"
        return ModelConfigurationManager.shared.allowedDurations(for: veoItem)
            ?? defaultDurationOptions
    }
    
    private var videoAspectOptions: [AspectRatioOption] {
        // Get options for Google Veo 3.1 Fast
        var veoItem = item
        veoItem.display.modelName = "Google Veo 3.1 Fast"
        return ModelConfigurationManager.shared.allowedAspectRatios(for: veoItem)
            ?? defaultAspectOptions
    }
    
    private var videoResolutionOptions: [ResolutionOption] {
        // Get options for Google Veo 3.1 Fast
        var veoItem = item
        veoItem.display.modelName = "Google Veo 3.1 Fast"
        return ModelConfigurationManager.shared.allowedResolutions(for: veoItem)
            ?? defaultResolutionOptions
    }
    
    /// Checks if the current model supports variable resolution selection
    private var hasVariableResolution: Bool {
        return PricingManager.shared.hasVariablePricing(for: "Google Veo 3.1 Fast")
    }
    
    /// Checks if the current model supports audio generation
    private var supportsAudio: Bool {
        // Google Veo 3.1 Fast supports audio
        var veoItem = item
        veoItem.display.modelName = "Google Veo 3.1 Fast"
        guard let capabilities = ModelConfigurationManager.shared.capabilities(
            for: veoItem)
        else { return false }
        return capabilities.contains("Audio")
    }
    
    /// Computed property to get the current price based on selected aspect ratio, duration, and audio
    private var currentPrice: Decimal? {
        let modelName = "Google Veo 3.1 Fast"
        
        // Check if model has variable pricing
        guard PricingManager.shared.hasVariablePricing(for: modelName) else {
            return item.resolvedCost
        }
        
        // Ensure indices are valid
        guard selectedAspectIndex < videoAspectOptions.count,
            selectedDurationIndex < videoDurationOptions.count
        else {
            return item.resolvedCost
        }
        
        // Get selected options
        let selectedAspectOption = videoAspectOptions[selectedAspectIndex]
        let selectedDurationOption = videoDurationOptions[selectedDurationIndex]
        
        // Get selected resolution
        guard selectedResolutionIndex < videoResolutionOptions.count else {
            return item.resolvedCost
        }
        let selectedResolutionOption = videoResolutionOptions[selectedResolutionIndex]
        let resolution = selectedResolutionOption.id
        
        // Get variable price for this combination
        if var variablePrice = PricingManager.shared.variablePrice(
            for: modelName,
            aspectRatio: selectedAspectOption.id,
            resolution: resolution,
            duration: selectedDurationOption.duration
        ) {
            // Adjust audio pricing if applicable
            if supportsAudio && !generateAudio {
                if let audioAddon = PricingManager.shared.audioPriceAddon(
                    for: modelName, duration: selectedDurationOption.duration)
                {
                    variablePrice -= audioAddon
                }
            }
            return variablePrice
        }
        
        // Fallback to base price if variable pricing not found for this combination
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
    
    private let examplePrompts: [String] = [
        "A majestic yeti walking through a snowy mountain landscape",
        "A friendly yeti playing in a winter wonderland",
        "A yeti discovering a hidden ice cave",
        "A yeti family having a snowball fight",
        "A yeti building an ice castle",
        "A yeti skiing down a mountain slope",
        "A yeti fishing in a frozen lake",
        "A yeti dancing in the snow",
        "A yeti exploring an ancient glacier",
        "A yeti meeting other arctic animals",
    ]
    
    // MARK: BODY
    
    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Page Title - Animated
                        AnimatedTitle(text: "Yeti Vlog")
                            .padding(.top, 16)
                        
                        LazyView(
                            BannerSectionYeti(
                                item: item, price: currentPrice, videoPlayer: $videoPlayer, isVideoMuted: $isVideoMuted))
                        
                        Divider().padding(.horizontal)
                        
                        LazyView(
                            PromptSectionYeti(
                                prompt: $prompt,
                                isFocused: $isPromptFocused,
                                isExamplePromptsPresented: $isExamplePromptsPresented,
                                examplePrompts: examplePrompts
                            ))

                        LazyView(
                            GenerateButtonYeti(
                                prompt: prompt,
                                isGenerating: $isGenerating,
                                keyboardHeight: $keyboardHeight,
                                price: currentPrice,
                                selectedSize: videoAspectOptions[selectedAspectIndex].id,
                                selectedResolution: hasVariableResolution
                                    ? videoResolutionOptions[selectedResolutionIndex].id : nil,
                                selectedDuration: "\(Int(videoDurationOptions[selectedDurationIndex].duration))s",
                                isLoggedIn: authViewModel.user != nil,
                                hasCredits: hasEnoughCredits,
                                isConnected: networkMonitor.isConnected,
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
                        
                        Divider().padding(.horizontal)
                        
                        // // Audio toggle - only show for models that support audio generation
                        // if supportsAudio {
                        //     AudioToggleSectionYeti(
                        //         generateAudio: $generateAudio
                        //     )
                        // }
                        
                        LazyView(
                            AspectRatioSectionYeti(
                                options: videoAspectOptions,
                                selectedIndex: $selectedAspectIndex
                            ))
                        
                        // Only show resolution selector for models with variable pricing
                        if hasVariableResolution {
                            LazyView(
                                ResolutionSectionYeti(
                                    options: videoResolutionOptions,
                                    selectedIndex: $selectedResolutionIndex
                                ))
                        }
                        
                        LazyView(
                            DurationSectionYeti(
                                options: videoDurationOptions,
                                selectedIndex: $selectedDurationIndex
                            ))
                        
                        Divider().padding(.horizontal)
                        
                        // Pricing Table - Only show for models with variable pricing
                        if PricingManager.shared.hasVariablePricing(for: "Google Veo 3.1 Fast") {
                            LazyView(
                                PricingTableSectionYeti(modelName: "Google Veo 3.1 Fast")
                            )
                            
                            Divider().padding(.horizontal)
                        }
                        
                        Color.clear.frame(height: 130)  // bottom padding for floating button
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isPromptFocused = false }
        .sheet(isPresented: $isExamplePromptsPresented) {
            ExamplePromptsSheet(
                examplePrompts: examplePrompts,
                examplePromptsTransform: [],
                selectedPrompt: $prompt,
                isPresented: $isExamplePromptsPresented,
                title: "Example Prompts"
            )
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isPromptFocused = false }
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification)
        ) { notification in
            if let keyboardFrame = notification.userInfo?[
                UIResponder.keyboardFrameEndUserInfoKey
            ] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            keyboardHeight = 0
        }
        .alert("Prompt Required", isPresented: $showEmptyPromptAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enter a prompt to generate a video.")
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .alert("Insufficient Credits", isPresented: $showInsufficientCreditsAlert) {
            Button("Purchase Credits") {
                showPurchaseCreditsView = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need \(String(format: "$%.2f", requiredCredits)) to generate this. Your current balance is \(creditsViewModel.formattedBalance()).")
        }
        .onAppear {
            // Setup video player if video is available
            setupVideoPlayer()
            
            // Note: Credit balance fetching is now handled by AuthAwareCostCard
            
            // Validate and reset indices if they're out of bounds for model-specific options
            if selectedAspectIndex >= videoAspectOptions.count {
                selectedAspectIndex = 0
            }
            if selectedDurationIndex >= videoDurationOptions.count {
                selectedDurationIndex = 0
            }
            if selectedResolutionIndex >= videoResolutionOptions.count {
                selectedResolutionIndex = 0
            }
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
        .onDisappear {
            // Clean up video player
            cleanupVideoPlayer()
        }
    }
    
    // MARK: FUNCTION GENERATE
    
    private func generate() {
        guard !prompt.isEmpty else {
            showEmptyPromptAlert = true
            return
        }
        guard !isGenerating else { return }
        
        // Check credits before generating
        if !hasEnoughCredits {
            showInsufficientCreditsAlert = true
            return
        }
        
        isGenerating = true
        let selectedAspectOption = videoAspectOptions[selectedAspectIndex]
        let selectedDurationOption = videoDurationOptions[selectedDurationIndex]
        let selectedResolutionOption = videoResolutionOptions[selectedResolutionIndex]
        
        // Create modified item with Google Veo 3.1 Fast model
        var modifiedItem = item
        modifiedItem.prompt = prompt
        modifiedItem.display.modelName = "Google Veo 3.1 Fast"
        
        // Use resolvedAPIConfig as base, then modify aspectRatio
        var config = modifiedItem.resolvedAPIConfig
        config.aspectRatio = selectedAspectOption.id
        modifiedItem.apiConfig = config
        
        guard let userId = authViewModel.user?.id.uuidString.lowercased(),
            !userId.isEmpty
        else {
            isGenerating = false
            return
        }
        
        Task { @MainActor in
            await PushNotificationManager.shared.checkAuthorizationStatus()
            if PushNotificationManager.shared.authorizationStatus == .notDetermined {
                _ = await PushNotificationManager.shared.requestPermissions()
            }
            _ = VideoGenerationCoordinator.shared.startVideoGeneration(
                item: modifiedItem,
                image: nil,  // No image for yeti filter
                userId: userId,
                duration: selectedDurationOption.duration,
                aspectRatio: selectedAspectOption.id,
                resolution: hasVariableResolution
                    ? selectedResolutionOption.id : nil,
                generateAudio: supportsAudio ? generateAudio : nil,
                firstFrameImage: nil,
                lastFrameImage: nil,
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

private struct BannerSectionYeti: View {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Video centered
            HStack {
                Spacer()
                if let player = videoPlayer {
                    VideoPlayerWithMuteButton(
                        player: player,
                        isMuted: $isVideoMuted,
                        width: 230,
                        height: 254,
                        cornerRadius: 12
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if getVideoURL(for: item) != nil {
                    // Video URL exists but player not ready yet - show placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 230, height: 254)
                        .overlay(
                            ProgressView()
                        )
                } else {
                    // Fallback to image
                    Image(item.resolvedModelImageName ?? item.display.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 230, height: 254)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            // Horizontal row with model image, title, pill, pricing, model info
            HStack(alignment: .top, spacing: 16) {
                Image("veo31fast")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Google Veo 3.1 Fast")
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
                    
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill").font(.caption)
                        Text("Video Generation Model").font(.caption)
                    }
                    .foregroundColor(.purple)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
            
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

// MARK: PROMPT SECTION

private struct PromptSectionYeti: View {
    @Binding var prompt: String
    @FocusState.Binding var isFocused: Bool
    @Binding var isExamplePromptsPresented: Bool
    let examplePrompts: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft").foregroundColor(.purple)
                Text("Prompt").font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            TextEditor(text: $prompt)
                .font(.system(size: 15))
                .opacity(0.9)
                .frame(minHeight: 140)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isFocused
                                ? Color.purple.opacity(0.5)
                                : Color.gray.opacity(0.3),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("Describe the yeti video you want to generate...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .focused($isFocused)
        }
        .padding(.horizontal)
    }
}

// MARK: ASPECT RATIO

private struct AspectRatioSectionYeti: View {
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

// MARK: RESOLUTION

private struct ResolutionSectionYeti: View {
    let options: [ResolutionOption]
    @Binding var selectedIndex: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resolution")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, -6)
            ResolutionSelector(
                options: options, selectedIndex: $selectedIndex, color: .purple
            )
        }
        .padding(.horizontal)
    }
}

// MARK: DURATION

private struct DurationSectionYeti: View {
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

// MARK: PRICING TABLE

private struct PricingTableSectionYeti: View {
    let modelName: String
    @State private var isExpanded: Bool = false
    
    private var pricingConfig: VideoPricingConfiguration? {
        PricingManager.shared.pricingConfiguration(for: modelName)
    }
    
    /// Check if this model has audio pricing (different prices for audio on/off)
    private var hasAudioPricing: Bool {
        PricingManager.shared.hasAudioPricing(for: modelName)
    }
    
    /// Check if this model requires audio (audio-only, like Sora 2)
    private var isAudioRequired: Bool {
        let audioRequiredModels = ["Sora 2"]
        return audioRequiredModels.contains(modelName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "tablecells")
                            .foregroundColor(.purple)
                            .font(.system(size: 14))
                        Text("Pricing Table")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Hide" : "View All")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Image(
                            systemName: isExpanded
                                ? "chevron.up" : "chevron.down"
                        )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.purple)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded, let config = pricingConfig {
                if hasAudioPricing {
                    // Show separate tables for audio/no-audio pricing
                    PricingTableContentWithAudioYeti(
                        config: config,
                        modelName: modelName
                    )
                } else {
                    // Standard pricing table (with audio label for audio-required models)
                    PricingTableContentYeti(
                        config: config,
                        showAudioLabel: isAudioRequired
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: PRICING TABLE CONTENT WITH AUDIO

private struct PricingTableContentWithAudioYeti: View {
    let config: VideoPricingConfiguration
    let modelName: String
    
    // Get sorted unique values
    private var aspectRatios: [String] {
        Array(config.pricing.keys).sorted { lhs, rhs in
            let order = ["9:16", "3:4", "1:1", "4:3", "16:9"]
            let lhsIdx = order.firstIndex(of: lhs) ?? 99
            let rhsIdx = order.firstIndex(of: rhs) ?? 99
            return lhsIdx < rhsIdx
        }
    }
    
    private var resolutions: [String] {
        var resSet = Set<String>()
        for (_, resDict) in config.pricing {
            for res in resDict.keys {
                resSet.insert(res)
            }
        }
        return resSet.sorted { lhs, rhs in
            let order = ["480p", "720p", "1080p"]
            let lhsIdx = order.firstIndex(of: lhs) ?? 99
            let rhsIdx = order.firstIndex(of: rhs) ?? 99
            return lhsIdx < rhsIdx
        }
    }
    
    private var durations: [Double] {
        var durSet = Set<Double>()
        for (_, resDict) in config.pricing {
            for (_, durDict) in resDict {
                for dur in durDict.keys {
                    durSet.insert(dur)
                }
            }
        }
        return durSet.sorted()
    }
    
    /// Get audio addon for a specific duration
    private func audioAddon(for duration: Double) -> Decimal {
        PricingManager.shared.audioPriceAddon(
            for: modelName, duration: duration) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // With Audio table (first)
            AudioPricingCardYeti(
                title: "With Audio",
                icon: "speaker.wave.2.fill",
                aspectRatios: aspectRatios,
                resolutions: resolutions,
                durations: durations,
                config: config,
                audioAddonProvider: { _ in 0 }  // Base price includes audio
            )
            
            // Without Audio table
            AudioPricingCardYeti(
                title: "Without Audio",
                icon: "speaker.slash",
                aspectRatios: aspectRatios,
                resolutions: resolutions,
                durations: durations,
                config: config,
                audioAddonProvider: { duration in -audioAddon(for: duration) }  // Subtract audio addon per duration
            )
        }
    }
}

// MARK: AUDIO PRICING CARD

private struct AudioPricingCardYeti: View {
    let title: String
    let icon: String
    let aspectRatios: [String]
    let resolutions: [String]
    let durations: [Double]
    let config: VideoPricingConfiguration
    /// Closure that returns the price adjustment for a given duration
    let audioAddonProvider: (Double) -> Decimal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Audio type header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.purple)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.purple.opacity(0.12))
            )
            
            // For each resolution, show a sub-section
            ForEach(resolutions, id: \.self) { resolution in
                VStack(alignment: .leading, spacing: 4) {
                    // Resolution label
                    Text(resolution)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    // Table header
                    HStack(spacing: 0) {
                        Text("Size")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        ForEach(durations, id: \.self) { duration in
                            Text("\(Int(duration))s")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    
                    // Table rows
                    VStack(spacing: 0) {
                        ForEach(Array(aspectRatios.enumerated()), id: \.element)
                        { index, aspectRatio in
                            HStack(spacing: 0) {
                                Text(aspectRatio)
                                    .font(
                                        .system(
                                            size: 12, weight: .medium,
                                            design: .monospaced)
                                    )
                                    .foregroundColor(.primary)
                                    .frame(width: 50, alignment: .leading)
                                
                                ForEach(durations, id: \.self) { duration in
                                    if let basePrice = config.price(
                                        aspectRatio: aspectRatio,
                                        resolution: resolution,
                                        duration: duration)
                                    {
                                        let adjustedPrice =
                                            basePrice
                                            + audioAddonProvider(duration)
                                        PriceDisplayView(
                                            price: adjustedPrice,
                                            font: .system(
                                                size: 12, weight: .medium,
                                                design: .rounded),
                                            foregroundColor: .white
                                        )
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        Text("-")
                                            .font(.system(size: 12))
                                            .foregroundColor(
                                                .secondary.opacity(0.5)
                                            )
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                index % 2 == 0
                                    ? Color.clear
                                    : Color.purple.opacity(0.03)
                            )
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.04))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.purple.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: PRICING TABLE CONTENT

private struct PricingTableContentYeti: View {
    let config: VideoPricingConfiguration
    var showAudioLabel: Bool = false
    
    // Get sorted unique values
    private var aspectRatios: [String] {
        Array(config.pricing.keys).sorted { lhs, rhs in
            let order = ["9:16", "3:4", "1:1", "4:3", "16:9"]
            let lhsIdx = order.firstIndex(of: lhs) ?? 99
            let rhsIdx = order.firstIndex(of: rhs) ?? 99
            return lhsIdx < rhsIdx
        }
    }
    
    private var resolutions: [String] {
        var resSet = Set<String>()
        for (_, resDict) in config.pricing {
            for res in resDict.keys {
                resSet.insert(res)
            }
        }
        return resSet.sorted { lhs, rhs in
            let order = ["480p", "720p", "1080p"]
            let lhsIdx = order.firstIndex(of: lhs) ?? 99
            let rhsIdx = order.firstIndex(of: rhs) ?? 99
            return lhsIdx < rhsIdx
        }
    }
    
    private var durations: [Double] {
        var durSet = Set<Double>()
        for (_, resDict) in config.pricing {
            for (_, durDict) in resDict {
                for dur in durDict.keys {
                    durSet.insert(dur)
                }
            }
        }
        return durSet.sorted()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Show "With Audio" header for audio-required models
            if showAudioLabel {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("With Audio")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.purple.opacity(0.12))
                )
            }
            
            ForEach(resolutions, id: \.self) { resolution in
                ResolutionPricingCardYeti(
                    resolution: resolution,
                    aspectRatios: aspectRatios,
                    durations: durations,
                    config: config
                )
            }
        }
    }
}

// MARK: RESOLUTION PRICING CARD

private struct ResolutionPricingCardYeti: View {
    let resolution: String
    let aspectRatios: [String]
    let durations: [Double]
    let config: VideoPricingConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Resolution header
            HStack(spacing: 6) {
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 12))
                    .foregroundColor(.purple)
                Text(resolution)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.purple.opacity(0.12))
            )
            
            // Table header
            HStack(spacing: 0) {
                Text("Size")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                
                ForEach(durations, id: \.self) { duration in
                    Text("\(Int(duration))s")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            // Table rows
            VStack(spacing: 0) {
                ForEach(Array(aspectRatios.enumerated()), id: \.element) {
                    index, aspectRatio in
                    HStack(spacing: 0) {
                        Text(aspectRatio)
                            .font(
                                .system(
                                    size: 12, weight: .medium,
                                    design: .monospaced)
                            )
                            .foregroundColor(.primary)
                            .frame(width: 50, alignment: .leading)
                        
                        ForEach(durations, id: \.self) { duration in
                            if let price = config.price(
                                aspectRatio: aspectRatio,
                                resolution: resolution, duration: duration)
                            {
                                PriceDisplayView(
                                    price: price,
                                    font: .system(
                                        size: 12, weight: .medium,
                                        design: .rounded),
                                    foregroundColor: .white
                                )
                                .frame(maxWidth: .infinity)
                            } else {
                                Text("-")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        index % 2 == 0
                            ? Color.clear
                            : Color.purple.opacity(0.03)
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.purple.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: GENERATE BUTTON

private struct GenerateButtonYeti: View {
    let prompt: String
    @Binding var isGenerating: Bool
    @Binding var keyboardHeight: CGFloat
    let price: Decimal?
    let selectedSize: String
    let selectedResolution: String?
    let selectedDuration: String
    let isLoggedIn: Bool
    let hasCredits: Bool
    let isConnected: Bool
    let onSignInTap: () -> Void
    let action: () -> Void
    
    private var canGenerate: Bool {
        isLoggedIn && hasCredits && isConnected
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                if !isLoggedIn {
                    onSignInTap()
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
            
            // Compact summary of selected options
            HStack(spacing: 0) {
                // Size column
                HStack(spacing: 4) {
                    Image(systemName: "aspectratio")
                        .font(.system(size: 11))
                    Text(selectedSize)
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                
                // Resolution column (if available)
                if let resolution = selectedResolution {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 11))
                        Text(resolution)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Duration column
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 11))
                    Text(selectedDuration)
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal)
        }
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
}

// MARK: AUDIO TOGGLE

private struct AudioToggleSectionYeti: View {
    @Binding var generateAudio: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .foregroundColor(.purple)
                            .font(.system(size: 14))
                        Text("Audio Generation")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    Text(
                        "Generate synchronized audio, dialogue, and sound effects"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $generateAudio)
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        generateAudio
                            ? Color.purple.opacity(0.3)
                            : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
}
