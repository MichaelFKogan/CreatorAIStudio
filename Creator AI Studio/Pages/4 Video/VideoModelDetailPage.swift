//
//  VideoModelDetailPage.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/25/25.
//

import AVFoundation
import Kingfisher
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Used by Motion Control section to load a selected video from PhotosPickerItem.
private struct VideoTransferable: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

//struct LazyView<Content: View>: View {
//    let build: () -> Content
//    init(_ build: @autoclosure @escaping () -> Content) { self.build = build }
//    var body: some View { build() }
//}

/// Input mode for Google Veo 3.1 Fast (Text to Video, Image to Video, or Frame Images).
/// Other video models can define their own mode enums (e.g. Motion Control for Kling VIDEO 2.6 Pro).
private enum GoogleVeoInputMode: String, CaseIterable {
    case textToVideo = "Text"
    case imageToVideo = "Image"
    case frameImages = "Frames"
}

/// Input mode for KlingAI 2.5 Turbo Pro (Text | Image | Frames), same options as Google Veo 3.1 Fast.
private enum KlingAI25TurboProInputMode: String, CaseIterable {
    case textToVideo = "Text"
    case imageToVideo = "Image"
    case frameImages = "Frames"
}

/// Input mode for Kling VIDEO 2.6 Pro: Text | Image | Motion Control.
private enum KlingVideo26ProInputMode: String, CaseIterable {
    case textToVideo = "Text"
    case imageToVideo = "Image"
    case motionControl = "Motion"
}

/// Motion control tier for Kling VIDEO 2.6 Pro: Standard (Fal.ai) or Pro (Runware).
private enum MotionControlTier: String, CaseIterable {
    case standard = "standard"
    case pro = "pro"
    var displayName: String { rawValue == "standard" ? "Standard" : "Pro" }
}

/// Input mode for Sora 2, Seedance 1.0 Pro Fast, Wan2.6: Text to Video or Image to Video.
private enum Sora2InputMode: String, CaseIterable {
    case textToVideo = "Text"
    case imageToVideo = "Image"
}

struct VideoModelDetailPage: View {
    @State var item: InfoPacket

    @State private var prompt: String = ""
    @FocusState private var isPromptFocused: Bool
    @State private var isExamplePromptsPresented: Bool = false

    @State private var referenceImages: [UIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    // Frame images for KlingAI 2.5 Turbo Pro (first and last frame)
    @State private var firstFrameImage: UIImage? = nil
    @State private var lastFrameImage: UIImage? = nil
    @State private var showFirstFrameCameraSheet: Bool = false
    @State private var showLastFrameCameraSheet: Bool = false

    /// Google Veo 3.1 Fast only: Text to Video | Image to Video | Frame Images
    @State private var googleVeoInputMode: GoogleVeoInputMode = .imageToVideo

    /// KlingAI 2.5 Turbo Pro only: Text | Image | Frames
    @State private var klingAI25InputMode: KlingAI25TurboProInputMode = .imageToVideo

    /// Kling VIDEO 2.6 Pro only: Text | Image | Motion Control
    @State private var klingVideo26InputMode: KlingVideo26ProInputMode = .imageToVideo

    /// Kling VIDEO 2.6 Pro Motion Control only: Standard (Fal.ai) or Pro (Runware)
    @State private var motionControlTier: MotionControlTier = .standard

    /// Sora 2, Seedance 1.0 Pro Fast, Wan2.6: Text to Video | Image to Video
    @State private var sora2InputMode: Sora2InputMode = .imageToVideo

    /// Motion Control (Kling VIDEO 2.6 Pro): reference video + character image (UI only for now)
    @State fileprivate var motionControlVideoItem: PhotosPickerItem? = nil
    @State fileprivate var motionControlVideoURL: URL? = nil
    @State fileprivate var motionControlCharacterImage: UIImage? = nil
    @State fileprivate var motionControlCharacterPhotoItem: PhotosPickerItem? = nil
    @State fileprivate var motionControlVideoDuration: Double? = nil
    @State private var showVideoDurationAlert: Bool = false

    @State private var isGenerating: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showEmptyPromptAlert: Bool = false
    @State private var showCameraSheet: Bool = false
    @State private var showPromptCameraSheet: Bool = false
    @State private var showFullPromptSheet: Bool = false
    @State private var isProcessingOCR: Bool = false
    @State private var showOCRAlert: Bool = false
    @State private var ocrAlertMessage: String = ""

    @State private var selectedAspectIndex: Int = 0
    @State private var selectedGenerationMode: Int = 0
    @State private var selectedDurationIndex: Int = 0
    @State private var selectedResolutionIndex: Int = 0
    @State private var generateAudio: Bool = true  // Default to ON for audio generation
    @State private var showSignInSheet: Bool = false
    @State private var showPurchaseCreditsView: Bool = false
    @State private var showInsufficientCreditsAlert: Bool = false
    @State private var showMotionControlMissingAlert: Bool = false
    @State private var motionControlMissingAlertMessage: String = ""
    @State private var showImageRequiredAlert: Bool = false
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: Constants - Default fallback options

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
            id: "3",
            label: "3 seconds",
            duration: 3.0,
            description: "Quick clip"
        ),
        DurationOption(
            id: "8",
            label: "8 seconds",
            duration: 8.0,
            description: "Medium duration"
        ),
        DurationOption(
            id: "12",
            label: "12 seconds",
            duration: 12.0,
            description: "Maximum duration"
        ),
    ]

    private let defaultAspectOptions: [AspectRatioOption] = [
        AspectRatioOption(
            id: "3:4", label: "3:4", width: 3, height: 4,
            platforms: ["Portrait"]
        ),
        AspectRatioOption(
            id: "9:16", label: "9:16", width: 9, height: 16,
            platforms: ["TikTok", "Reels"]
        ),
        AspectRatioOption(
            id: "1:1", label: "1:1", width: 1, height: 1,
            platforms: ["Instagram"]
        ),
        AspectRatioOption(
            id: "4:3", label: "4:3", width: 4, height: 3,
            platforms: ["Landscape"]
        ),
        AspectRatioOption(
            id: "16:9", label: "16:9", width: 16, height: 9,
            platforms: ["YouTube"]
        ),
    ]

    // MARK: Computed Properties - Model-specific options

    private var videoDurationOptions: [DurationOption] {
        ModelConfigurationManager.shared.allowedDurations(for: item)
            ?? defaultDurationOptions
    }

    private var videoAspectOptions: [AspectRatioOption] {
        ModelConfigurationManager.shared.allowedAspectRatios(for: item)
            ?? defaultAspectOptions
    }

    private let defaultResolutionOptions: [ResolutionOption] = [
        ResolutionOption(
            id: "480p", label: "480p", description: "Standard quality"),
        ResolutionOption(
            id: "720p", label: "720p", description: "High quality"),
        ResolutionOption(id: "1080p", label: "1080p", description: "Full HD"),
    ]

    private var videoResolutionOptions: [ResolutionOption] {
        ModelConfigurationManager.shared.allowedResolutions(for: item)
            ?? defaultResolutionOptions
    }

    /// Checks if the current model supports variable resolution selection
    private var hasVariableResolution: Bool {
        guard let modelName = item.display.modelName else { return false }
        return PricingManager.shared.hasVariablePricing(for: modelName)
    }

    /// Checks if the current model supports audio generation
    private var supportsAudio: Bool {
        guard
            let capabilities = ModelConfigurationManager.shared.capabilities(
                for: item)
        else { return false }
        return capabilities.contains("Audio")
    }

    /// Checks if the current model requires audio (cannot be disabled)
    /// Some models like Sora 2 only support video with audio
    private var audioRequired: Bool {
        guard let modelName = item.display.modelName else { return false }
        // Models that require audio (cannot generate without it)
        let audioRequiredModels = ["Sora 2"]
        return audioRequiredModels.contains(modelName)
    }
    
    /// Checks if the current model supports first and last frame images
    /// KlingAI 2.5 Turbo Pro and Google Veo 3.1 Fast support both first and last frame
    private var supportsFrameImages: Bool {
        guard let modelName = item.display.modelName else { return false }
        return modelName == "KlingAI 2.5 Turbo Pro" || modelName == "Google Veo 3.1 Fast"
    }

    /// True when the current model is Google Veo 3.1 Fast (shows Text | Image | Frames mode picker).
    private var isGoogleVeo31Fast: Bool {
        item.display.modelName == "Google Veo 3.1 Fast"
    }

    /// True when the current model is KlingAI 2.5 Turbo Pro (shows Text | Image | Frames mode picker).
    private var isKlingAI25TurboPro: Bool {
        item.display.modelName == "KlingAI 2.5 Turbo Pro"
    }

    /// True when the current model is Kling VIDEO 2.6 Pro (shows Text | Image | Motion Control mode picker).
    private var isKlingVideo26Pro: Bool {
        item.display.modelName == "Kling VIDEO 2.6 Pro"
    }

    /// True when in Motion Control mode for Kling VIDEO 2.6 Pro
    private var isMotionControlMode: Bool {
        isKlingVideo26Pro && klingVideo26InputMode == .motionControl
    }

    /// True when the user has selected Image-to-Video mode (any model that offers Text | Image or Text | Image | Motion).
    private var isInImageToVideoMode: Bool {
        (showsTextImageInputModePicker && sora2InputMode == .imageToVideo)
            || (isGoogleVeo31Fast && googleVeoInputMode == .imageToVideo)
            || (isKlingAI25TurboPro && klingAI25InputMode == .imageToVideo)
            || (isKlingVideo26Pro && klingVideo26InputMode == .imageToVideo)
    }

    /// True when the current model is Sora 2 (used for disclaimer and duration default).
    private var isSora2: Bool {
        item.display.modelName == "Sora 2"
    }

    /// True when the current model shows Text | Image mode picker (Sora 2, Seedance 1.0 Pro Fast, Wan2.6).
    private var showsTextImageInputModePicker: Bool {
        guard let name = item.display.modelName else { return false }
        return name == "Sora 2" || name == "Seedance 1.0 Pro Fast" || name == "Wan2.6"
    }

    // Prompt constants extracted to VideoPromptConstants.swift for build performance
    private var examplePrompts: [String] { VideoPromptConstants.examplePrompts }
    private var transformPrompts: [String] { VideoPromptConstants.transformPrompts }

    private var costString: String {
        NSDecimalNumber(decimal: currentPrice ?? item.resolvedCost ?? 0)
            .stringValue
    }

    private var priceString: String {
        // Motion Control mode: show per-second rate when no video selected (rate is in dollars; convert to credits)
        if isMotionControlMode && motionControlVideoDuration == nil, let modelName = item.display.modelName,
           let rate = PricingManager.shared.motionControlPricePerSecond(for: modelName, tier: motionControlTier.rawValue) {
            return "\(PricingManager.formatCredits(rate)) credits/sec"
        }
        return PricingManager.formatPrice(currentPrice ?? item.resolvedCost ?? 0)
    }

    /// Per-second rate string for banner when Motion Control is selected but no reference video yet (e.g. "8/s Credits").
    private var motionControlBannerPlaceholder: String? {
        guard isMotionControlMode, motionControlVideoDuration == nil,
              let modelName = item.display.modelName,
              let rate = PricingManager.shared.motionControlPricePerSecond(for: modelName, tier: motionControlTier.rawValue) else { return nil }
        return "\(PricingManager.formatCredits(rate))/s Credits"
    }

    private var creditsString: String {
        // Keep for backward compatibility, but use new formatter
        priceString
    }

    /// Computed property to get the current price based on selected aspect ratio, duration, and audio.
    /// Returns variable pricing if available, otherwise falls back to base price.
    /// For Motion Control mode, uses per-second pricing based on reference video duration.
    private var currentPrice: Decimal? {
        guard let modelName = item.display.modelName else {
            return item.resolvedCost
        }

        // Motion Control mode uses per-second pricing based on video duration and tier
        if isMotionControlMode {
            if let videoDuration = motionControlVideoDuration {
                return PricingManager.shared.motionControlPrice(for: modelName, tier: motionControlTier.rawValue, durationSeconds: videoDuration)
            }
            return nil  // No video selected - triggers placeholder display
        }

        guard PricingManager.shared.hasVariablePricing(for: modelName) else {
            return item.resolvedCost
        }
        return calculateVariablePrice(for: modelName) ?? item.resolvedCost
    }

    /// Calculates variable price for the given model based on current selections.
    /// Extracted to reduce type-checker load in currentPrice computed property.
    private func calculateVariablePrice(for modelName: String) -> Decimal? {
        // Validate indices
        guard selectedAspectIndex < videoAspectOptions.count,
              selectedDurationIndex < videoDurationOptions.count,
              selectedResolutionIndex < videoResolutionOptions.count else {
            return nil
        }

        let aspectId = videoAspectOptions[selectedAspectIndex].id
        let duration = videoDurationOptions[selectedDurationIndex].duration
        let resolution = videoResolutionOptions[selectedResolutionIndex].id

        guard var price = PricingManager.shared.variablePrice(
            for: modelName,
            aspectRatio: aspectId,
            resolution: resolution,
            duration: duration
        ) else {
            return nil
        }

        // Subtract audio addon when audio is turned OFF (base price includes audio)
        if supportsAudio && !generateAudio,
           let audioAddon = PricingManager.shared.audioPriceAddon(for: modelName, duration: duration) {
            price -= audioAddon
        }

        return price
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

    private var isMidjourney: Bool {
        item.display.title.lowercased().contains("midjourney")
    }

    // MARK: - Extracted View Builders

    /// Input mode picker for Google Veo 3.1 Fast
    @ViewBuilder
    private var googleVeoInputModePicker: some View {
        if isGoogleVeo31Fast {
            InputModeCard(color: .purple) {
                ChipOptionPicker(
                    options: [
                        ("Text", "doc.text"),
                        ("Image", "photo"),
                        ("Frames", "photo.on.rectangle.angled")
                    ],
                    selection: Binding(
                        get: { GoogleVeoInputMode.allCases.firstIndex(of: googleVeoInputMode) ?? 0 },
                        set: { idx in
                            if idx < GoogleVeoInputMode.allCases.count {
                                googleVeoInputMode = GoogleVeoInputMode.allCases[idx]
                            }
                        }
                    ),
                    color: .purple
                )
            } description: {
                VeoModeDescriptionBlock(mode: googleVeoInputMode, color: .purple)
            }
            .padding(.horizontal)
        }
    }

    /// Input mode picker for KlingAI 2.5 Turbo Pro
    @ViewBuilder
    private var klingAI25InputModePicker: some View {
        if isKlingAI25TurboPro {
            InputModeCard(color: .purple) {
                ChipOptionPicker(
                    options: [
                        ("Text", "doc.text"),
                        ("Image", "photo"),
                        ("Frames", "photo.on.rectangle.angled")
                    ],
                    selection: Binding(
                        get: { KlingAI25TurboProInputMode.allCases.firstIndex(of: klingAI25InputMode) ?? 0 },
                        set: { idx in
                            if idx < KlingAI25TurboProInputMode.allCases.count {
                                klingAI25InputMode = KlingAI25TurboProInputMode.allCases[idx]
                            }
                        }
                    ),
                    color: .purple
                )
            } description: {
                KlingAI25ModeDescriptionBlock(mode: klingAI25InputMode, color: .purple)
            }
            .padding(.horizontal)
        }
    }

    /// Input mode picker for Kling VIDEO 2.6 Pro
    @ViewBuilder
    private var klingVideo26InputModePicker: some View {
        if isKlingVideo26Pro {
            InputModeCard(color: .purple) {
                ChipOptionPicker(
                    options: [
                        ("Text", "doc.text"),
                        ("Image", "photo"),
                        ("Motion Control", "video.badge.waveform")
                    ],
                    selection: Binding(
                        get: { KlingVideo26ProInputMode.allCases.firstIndex(of: klingVideo26InputMode) ?? 0 },
                        set: { idx in
                            if idx < KlingVideo26ProInputMode.allCases.count {
                                klingVideo26InputMode = KlingVideo26ProInputMode.allCases[idx]
                            }
                        }
                    ),
                    color: .purple
                )
            } description: {
                KlingVideo26ModeDescriptionBlock(mode: klingVideo26InputMode, color: .purple)
            }
            .padding(.horizontal)
        }
    }

    /// Input mode picker for Sora 2, Seedance 1.0 Pro Fast, Wan2.6
    @ViewBuilder
    private var textImageInputModePicker: some View {
        if showsTextImageInputModePicker {
            InputModeCard(color: .purple) {
                ChipOptionPicker(
                    options: [
                        ("Text", "doc.text"),
                        ("Image", "photo")
                    ],
                    selection: Binding(
                        get: { Sora2InputMode.allCases.firstIndex(of: sora2InputMode) ?? 0 },
                        set: { idx in
                            if idx < Sora2InputMode.allCases.count {
                                sora2InputMode = Sora2InputMode.allCases[idx]
                            }
                        }
                    ),
                    color: .purple
                )
            } description: {
                TextImageModeDescriptionBlock(mode: sora2InputMode, color: .purple)
            }
            .padding(.horizontal)
        }
    }

    /// Whether to show reference images section based on current model and mode
    private var shouldShowReferenceImages: Bool {
        let isBasicImageToVideo = ModelConfigurationManager.shared.capabilities(for: item)?.contains("Image to Video") == true
            && !supportsFrameImages
            && !showsTextImageInputModePicker
            && !isKlingAI25TurboPro
            && !isKlingVideo26Pro

        let isPickerModeImageToVideo = (showsTextImageInputModePicker && sora2InputMode == .imageToVideo)
            || (isGoogleVeo31Fast && googleVeoInputMode == .imageToVideo)
            || (isKlingAI25TurboPro && klingAI25InputMode == .imageToVideo)
            || (isKlingVideo26Pro && klingVideo26InputMode == .imageToVideo)

        return isBasicImageToVideo || isPickerModeImageToVideo
    }

    /// Whether to show frame images section
    private var shouldShowFrameImages: Bool {
        (isKlingAI25TurboPro && klingAI25InputMode == .frameImages)
            || (isGoogleVeo31Fast && googleVeoInputMode == .frameImages)
    }

    /// Reference images section
    @ViewBuilder
    private var referenceImagesSection: some View {
        if shouldShowReferenceImages {
            LazyView(
                ReferenceImagesSection(
                    referenceImages: $referenceImages,
                    selectedPhotoItems: $selectedPhotoItems,
                    showCameraSheet: $showCameraSheet,
                    color: .purple,
                    disclaimer: item.display.modelName == "Sora 2"
                        ? "Sora 2 does not allow reference images with people - these will be rejected. Images of cartoons, animated figures, or landscapes are allowed."
                        : nil
                ))
        }
    }

    /// Frame images section for KlingAI 2.5 / Google Veo in Frames mode
    @ViewBuilder
    private var frameImagesSection: some View {
        if shouldShowFrameImages {
            LazyView(
                FrameImagesSection(
                    firstFrameImage: $firstFrameImage,
                    lastFrameImage: $lastFrameImage,
                    showFirstFrameCameraSheet: $showFirstFrameCameraSheet,
                    showLastFrameCameraSheet: $showLastFrameCameraSheet,
                    color: .purple,
                    showTitleAndDescription: false
                ))
        }
    }

    /// Motion control section for Kling VIDEO 2.6 Pro
    @ViewBuilder
    private var motionControlSectionView: some View {
        if isKlingVideo26Pro && klingVideo26InputMode == .motionControl {
            VStack(alignment: .leading, spacing: 12) {
                motionControlTierPicker
                motionControlHints
                LazyView(
                    MotionControlSection(
                        videoItem: $motionControlVideoItem,
                        videoURL: $motionControlVideoURL,
                        characterImage: $motionControlCharacterImage,
                        characterPhotoItem: $motionControlCharacterPhotoItem,
                        videoDuration: $motionControlVideoDuration,
                        showDurationAlert: $showVideoDurationAlert,
                        color: .purple,
                        showTitleAndDescription: false
                    ))
            }
        }
    }

    /// Standard vs Pro tier picker when Motion Control has multiple tiers
    @ViewBuilder
    private var motionControlTierPicker: some View {
        let modelName = item.display.modelName ?? ""
        let orderedTiers = PricingManager.shared.motionControlTiers(for: modelName)
        if orderedTiers.count > 1 {
            let options: [(String, String)] = orderedTiers.map { tier in
                (tier == "standard" ? "Standard" : "Pro", tier == "standard" ? "film" : "sparkles")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Motion Control option")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                ChipOptionPicker(
                    options: options,
                    selection: Binding(
                        get: { orderedTiers.firstIndex(of: motionControlTier.rawValue) ?? 0 },
                        set: { idx in
                            if idx >= 0 && idx < orderedTiers.count {
                                motionControlTier = MotionControlTier(rawValue: orderedTiers[idx]) ?? .standard
                            }
                        }
                    ),
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }

    /// Pricing and duration hints for motion control
    @ViewBuilder
    private var motionControlHints: some View {
        let modelName = item.display.modelName ?? ""
        let rate = PricingManager.shared.motionControlPricePerSecond(for: modelName, tier: motionControlTier.rawValue)
        let rateStr = rate.map { "\(PricingManager.formatCredits($0)) credits per second of video" } ?? "Per-second pricing"
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "centsign.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(rateStr)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Maximum reference video length: 30 seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, -8)
    }

    /// Midjourney cost warning
    @ViewBuilder
    private var midjourneyWarning: some View {
        if isMidjourney {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Midjourney creates 4 videos by default: Total cost: \(item.resolvedCost.credits * 4) credits")
                    .font(.caption)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, -16)
        }
    }

    /// Generate button view
    @ViewBuilder
    private var generateButtonView: some View {
        let motionControlNoVideoPlaceholder: String? = {
            guard isMotionControlMode, motionControlVideoDuration == nil,
                  let modelName = item.display.modelName,
                  let rate = PricingManager.shared.motionControlPricePerSecond(for: modelName, tier: motionControlTier.rawValue) else { return nil }
            return "\(PricingManager.formatCredits(rate)) credits/sec"
        }()
        LazyView(
            GenerateButtonVideo(
                prompt: prompt,
                isGenerating: $isGenerating,
                keyboardHeight: $keyboardHeight,
                price: currentPrice,
                pricePlaceholder: motionControlNoVideoPlaceholder,
                selectedSize: videoAspectOptions[selectedAspectIndex].id,
                selectedResolution: hasVariableResolution
                    ? videoResolutionOptions[selectedResolutionIndex].id : nil,
                selectedDuration: "\(Int(videoDurationOptions[selectedDurationIndex].duration))s",
                isLoggedIn: authViewModel.user != nil,
                hasCredits: hasEnoughCredits,
                isConnected: networkMonitor.isConnected,
                onSignInTap: { showSignInSheet = true },
                action: generate
            ))
    }

    /// Auth-aware cost card view
    @ViewBuilder
    private var costCardView: some View {
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
        .padding(.top, -16)
    }

    /// Settings section (aspect ratio, resolution, duration)
    @ViewBuilder
    private var settingsSection: some View {
        VStack {
            LazyView(
                AspectRatioSectionVideo(
                    options: videoAspectOptions,
                    selectedIndex: $selectedAspectIndex
                ))

            if hasVariableResolution {
                LazyView(
                    ResolutionSectionVideo(
                        options: videoResolutionOptions,
                        selectedIndex: $selectedResolutionIndex
                    ))
            }

            if !isMotionControlMode {
                LazyView(
                    DurationSectionVideo(
                        options: videoDurationOptions,
                        selectedIndex: $selectedDurationIndex
                    ))
            }
        }
        .padding(.top, -16)
    }

    /// Audio toggle section
    @ViewBuilder
    private var audioToggleSection: some View {
        if supportsAudio && !isMotionControlMode {
            AudioToggleSectionVideo(
                generateAudio: $generateAudio,
                isRequired: audioRequired
            )
        }
    }

    /// Pricing table section
    @ViewBuilder
    private var pricingTableSection: some View {
        if let modelName = item.display.modelName,
           PricingManager.shared.hasVariablePricing(for: modelName) {
            LazyView(
                PricingTableSectionVideo(modelName: modelName)
            )
            Divider().padding(.horizontal)
        }
    }

    /// Example gallery section
    @ViewBuilder
    private var exampleGallerySection: some View {
        if let modelName = item.display.modelName, !modelName.isEmpty {
            LazyView(
                ModelGallerySection(
                    modelName: modelName,
                    userId: authViewModel.user?.id.uuidString.lowercased()
                )
            )
            Divider().padding(.horizontal)
        }
    }

    // MARK: BODY (split into 3 computed properties to reduce type-checker load)

    /// Core scroll content — GeometryReader + ScrollView
    private var scrollContent: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {
                        LazyView(
                            BannerSectionVideo(
                                item: item,
                                price: currentPrice,
                                pricePlaceholder: motionControlBannerPlaceholder))

                        Divider().padding(.horizontal)

                        LazyView(
                            PromptSectionVideo(
                                prompt: $prompt,
                                isFocused: $isPromptFocused,
                                isExamplePromptsPresented:
                                    $isExamplePromptsPresented,
                                examplePrompts: examplePrompts,
                                examplePromptsTransform: transformPrompts,
                                onCameraTap: {
                                    showPromptCameraSheet = true
                                },
                                onExpandTap: { showFullPromptSheet = true },
                                isProcessingOCR: $isProcessingOCR
                            ))

                        // Input mode pickers (extracted to reduce type-checker load)
                        googleVeoInputModePicker
                        klingAI25InputModePicker
                        klingVideo26InputModePicker
                        textImageInputModePicker

                        // Reference media sections (extracted to reduce type-checker load)
                        referenceImagesSection
                        frameImagesSection
                        motionControlSectionView

                        // Midjourney warning
                        midjourneyWarning

                        // Generate button and cost card (extracted)
                        generateButtonView
                        costCardView

                        // Settings (extracted)
                        settingsSection
                        audioToggleSection

                        // Pricing and gallery (extracted)
                        pricingTableSection
                        exampleGallerySection

                        Color.clear.frame(height: 130)  // bottom padding for floating button
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    /// Navigation chrome — toolbar, nav title, keyboard handlers
    private var bodyWithNavigation: some View {
        scrollContent
            .contentShape(Rectangle())
            .onTapGesture { isPromptFocused = false }
            .sheet(isPresented: $isExamplePromptsPresented) {
                ExamplePromptsSheet(
                    examplePrompts: examplePrompts,
                    examplePromptsTransform: transformPrompts,
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
                // Leading title
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Video Models")
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
                        borderColor: .purple,
                        showSignInSheet: $showSignInSheet,
                        showPurchaseCreditsView: $showPurchaseCreditsView
                    )
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OfflineToolbarIcon()
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
    }

    /// Full body — sheets, alerts, lifecycle modifiers
    var body: some View {
        bodyWithNavigation
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
            .sheet(isPresented: $showCameraSheet) {
                SimpleCameraPicker(isPresented: $showCameraSheet) { capturedImage in
                    // Limit to 1 image - replace existing if any
                    referenceImages = [capturedImage]
                }
            }
            .sheet(isPresented: $showFirstFrameCameraSheet) {
                SimpleCameraPicker(isPresented: $showFirstFrameCameraSheet) { capturedImage in
                    firstFrameImage = capturedImage
                }
            }
            .sheet(isPresented: $showLastFrameCameraSheet) {
                SimpleCameraPicker(isPresented: $showLastFrameCameraSheet) { capturedImage in
                    lastFrameImage = capturedImage
                }
            }
            .sheet(isPresented: $showPromptCameraSheet) {
                SimpleCameraPicker(isPresented: $showPromptCameraSheet) {
                    capturedImage in
                    processOCR(from: capturedImage)
                }
            }
            .sheet(isPresented: $showFullPromptSheet) {
                FullPromptSheet(
                    prompt: $prompt,
                    isPresented: $showFullPromptSheet,
                    placeholder: "Describe the video you want to generate...",
                    accentColor: .purple
                )
                .presentationDragIndicator(.visible)
            }
            .alert("Text Recognition", isPresented: $showOCRAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(ocrAlertMessage)
            }
            .onAppear {
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

                // Set model-specific default duration
                // Sora 2 defaults to 8 seconds (index 1)
                if let modelName = item.display.modelName, modelName == "Sora 2" {
                    if let defaultIndex = videoDurationOptions.firstIndex(where: {
                        $0.duration == 8.0
                    }) {
                        selectedDurationIndex = defaultIndex
                    }
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
            .alert("Motion Control Required", isPresented: $showMotionControlMissingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(motionControlMissingAlertMessage)
            }
            .alert("Image Required", isPresented: $showImageRequiredAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please add a reference image for Image to Video.")
            }
            .alert("Video Too Long", isPresented: $showVideoDurationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Reference videos must be 30 seconds or less. Please select a shorter video.")
            }
            .onChange(of: item.display.modelName) { newModelName in
                // Reset indices when model changes (if item changes)
                selectedAspectIndex = 0
                selectedResolutionIndex = 0

                // Set model-specific default duration
                // Sora 2 defaults to 8 seconds
                if let modelName = newModelName, modelName == "Sora 2" {
                    if let defaultIndex = videoDurationOptions.firstIndex(where: {
                        $0.duration == 8.0
                    }) {
                        selectedDurationIndex = defaultIndex
                    } else {
                        selectedDurationIndex = 0
                    }
                } else {
                    selectedDurationIndex = 0
                }
            }
    }

    // MARK: Helper Functions

    /// Resolves which image to use for generation based on current model and input mode.
    /// Extracted from generate() to reduce type-checker complexity from nested ternaries.
    private func resolveImageToUse() -> UIImage? {
        if isGoogleVeo31Fast {
            return googleVeoInputMode == .imageToVideo ? referenceImages.first : nil
        }
        if isKlingAI25TurboPro {
            return klingAI25InputMode == .imageToVideo ? referenceImages.first : nil
        }
        if isKlingVideo26Pro {
            // Motion Control uses motionControlCharacterImage, Image mode uses referenceImages
            if klingVideo26InputMode == .motionControl {
                return motionControlCharacterImage
            }
            return klingVideo26InputMode == .imageToVideo ? referenceImages.first : nil
        }
        if showsTextImageInputModePicker {
            return sora2InputMode == .imageToVideo ? referenceImages.first : nil
        }
        return referenceImages.first
    }

    // MARK: FUNCTION GENERATE

    private func generate() {
        guard !prompt.isEmpty else {
            showEmptyPromptAlert = true
            return
        }
        guard !isGenerating else { return }

        // Check Motion Control validation for Kling VIDEO 2.6 Pro
        if isKlingVideo26Pro && klingVideo26InputMode == .motionControl {
            if motionControlCharacterImage == nil && motionControlVideoURL == nil {
                motionControlMissingAlertMessage = "Please add both a character image and a reference video for Motion Control."
                showMotionControlMissingAlert = true
                return
            } else if motionControlCharacterImage == nil {
                motionControlMissingAlertMessage = "Please add a character image for Motion Control."
                showMotionControlMissingAlert = true
                return
            } else if motionControlVideoURL == nil {
                motionControlMissingAlertMessage = "Please add a reference video for Motion Control."
                showMotionControlMissingAlert = true
                return
            }
            // Validate video duration exists for Motion Control
            guard motionControlVideoDuration != nil else {
                motionControlMissingAlertMessage = "Could not determine reference video duration. Please try selecting the video again."
                showMotionControlMissingAlert = true
                return
            }
        }

        // Check Image-to-Video: require a reference image when that mode is selected
        if isInImageToVideoMode && resolveImageToUse() == nil {
            showImageRequiredAlert = true
            return
        }

        // Check credits before generating
        if !hasEnoughCredits {
            showInsufficientCreditsAlert = true
            return
        }

        isGenerating = true
        let selectedAspectOption = videoAspectOptions[selectedAspectIndex]
        let selectedDurationOption = videoDurationOptions[selectedDurationIndex]
        let selectedResolutionOption = videoResolutionOptions[
            selectedResolutionIndex]
        var modifiedItem = item
        modifiedItem.prompt = prompt
        // Use resolvedAPIConfig as base, then modify aspectRatio
        var config = modifiedItem.resolvedAPIConfig
        config.aspectRatio = selectedAspectOption.id
        modifiedItem.apiConfig = config

        // Calculate duration and cost for the task
        // Motion Control uses reference video duration and per-second pricing
        let taskDuration: Double
        if isMotionControlMode, let videoDuration = motionControlVideoDuration {
            taskDuration = videoDuration
            // Set motion control price on the item (by tier)
            modifiedItem.cost = PricingManager.shared.motionControlPrice(
                for: item.display.modelName ?? "",
                tier: motionControlTier.rawValue,
                durationSeconds: videoDuration
            )
        } else {
            taskDuration = selectedDurationOption.duration
        }

        // Reference image: only in Image mode for models with segmented input; else use when available
        let imageToUse = resolveImageToUse()
        let useFirstLastFrame: Bool = (isGoogleVeo31Fast && googleVeoInputMode == .frameImages)
            || (isKlingAI25TurboPro && klingAI25InputMode == .frameImages)

        // Motion Control: determine if we need to pass a reference video URL
        let referenceVideoForGeneration: URL? = isMotionControlMode ? motionControlVideoURL : nil

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
                image: imageToUse,
                userId: userId,
                duration: taskDuration,
                aspectRatio: selectedAspectOption.id,
                resolution: hasVariableResolution
                    ? selectedResolutionOption.id : nil,
                generateAudio: supportsAudio ? generateAudio : nil,
                firstFrameImage: useFirstLastFrame ? firstFrameImage : nil,
                lastFrameImage: useFirstLastFrame ? lastFrameImage : nil,
                referenceVideoURL: referenceVideoForGeneration,
                motionControlTier: isMotionControlMode ? motionControlTier.rawValue : nil,
                onVideoGenerated: { _ in
                    isGenerating = false
                },
                onError: { error in
                    isGenerating = false
                    print(
                        "Video generation failed: \(error.localizedDescription)"
                    )
                }
            )

            // Refresh pending credits after starting generation
            if let userIdUUID = authViewModel.user?.id {
                await creditsViewModel.fetchBalance(userId: userIdUUID)
            }
        }
    }

    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    // MARK: OCR PROCESSING

    private func processOCR(from image: UIImage) {
        isProcessingOCR = true

        Task { @MainActor in
            let recognizedText = await TextRecognitionService.recognizeText(
                from: image)

            isProcessingOCR = false

            if let text = recognizedText, !text.isEmpty {
                // Add the recognized text to the prompt
                // If prompt already has text, append with a space, otherwise replace
                if prompt.isEmpty {
                    prompt = text
                } else {
                    prompt = prompt + " " + text
                }
            } else {
                // Show alert if no text was found
                ocrAlertMessage =
                    "No text was found in the image. Please try again with a clearer image."
                showOCRAlert = true
            }
        }
    }
}

// MARK: BANNER SECTION

private struct BannerSectionVideo: View {
    let item: InfoPacket
    let price: Decimal?
    /// When set and price is nil (e.g. Motion Control before reference video), show this instead of base price and use "per second of reference video" as suffix.
    var pricePlaceholder: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Model identity card: image + title + pill + price + description
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    Image(item.resolvedModelImageName ?? "")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.display.title)
                            .font(.title2).fontWeight(.bold).foregroundColor(
                                .primary
                            )
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 6) {
                            Image(systemName: "video.fill").font(
                                .caption)
                            Text("Video Generation Model").font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.purple.opacity(0.8)))

                        HStack(spacing: 4) {
                            if let placeholder = pricePlaceholder, price == nil {
                                Text(placeholder)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            } else {
                                PriceDisplayView(
                                    price: price ?? item.resolvedCost ?? 0,
                                    showUnit: true,
                                    font: .title3,
                                    fontWeight: .bold,
                                    foregroundColor: .white
                                )
                                Text("per video")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let capabilities = ModelConfigurationManager.shared
                            .capabilities(for: item),
                            !capabilities.isEmpty
                        {
                            Text(capabilities.joined(separator: " • "))
                                .font(
                                    .system(
                                        size: 12, weight: .medium, design: .rounded
                                    )
                                )
                                .foregroundColor(.purple)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Model description at bottom of card
                if let description = item.resolvedModelDescription,
                    !description.isEmpty
                {
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
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
}

// MARK: PROMPT SECTION

private struct PromptSectionVideo: View {
    @Binding var prompt: String
    @FocusState.Binding var isFocused: Bool
    @Binding var isExamplePromptsPresented: Bool
    let examplePrompts: [String]
    let examplePromptsTransform: [String]
    let onCameraTap: () -> Void
    let onExpandTap: () -> Void
    @Binding var isProcessingOCR: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft").foregroundColor(.purple)
                Text("Prompt").font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.secondary)
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
                        .stroke(
                            isFocused
                                ? Color.purple.opacity(0.5)
                                : Color.gray.opacity(0.3),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("Describe the video you want to generate...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .focused($isFocused)

            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Take a photo of a prompt")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                        Text("to add it to the box above")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    Button(action: onCameraTap) {
                        Group {
                            if isProcessingOCR {
                                ProgressView()
                                    .progressViewStyle(
                                        CircularProgressViewStyle(tint: .purple)
                                    )
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Button(action: { isExamplePromptsPresented = true }) {
            //     HStack {
            //         Image(systemName: "lightbulb.fill").foregroundColor(.purple)
            //             .font(.caption)
            //         Text("Example Prompts").font(.caption).fontWeight(.semibold)
            //             .foregroundColor(.secondary)
            //         Spacer()
            //         Image(systemName: "chevron.right").font(.caption)
            //             .foregroundColor(.secondary)
            //     }
            //     .padding(.horizontal, 10)
            //     .padding(.vertical, 8)
            //     .background(Color.gray.opacity(0.06))
            //     .clipShape(RoundedRectangle(cornerRadius: 8))
            //     .overlay(
            //         RoundedRectangle(cornerRadius: 8).stroke(
            //             Color.purple.opacity(0.3), lineWidth: 1
            //         ))
            // }
            // .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
}

// MARK: ASPECT RATIO

private struct AspectRatioSectionVideo: View {
    let options: [AspectRatioOption]
    @Binding var selectedIndex: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AspectRatioSelector(
                options: options, selectedIndex: $selectedIndex, color: .purple
            )
        }
        .padding(.horizontal)
    }
}

// MARK: RESOLUTION

private struct ResolutionSectionVideo: View {
    let options: [ResolutionOption]
    @Binding var selectedIndex: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ResolutionSelector(
                options: options, selectedIndex: $selectedIndex, color: .purple
            )
        }
        .padding(.horizontal)
    }
}

// MARK: DURATION

private struct DurationSectionVideo: View {
    let options: [DurationOption]
    @Binding var selectedIndex: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DurationSelector(
                options: options, selectedIndex: $selectedIndex, color: .purple
            )
        }
        .padding(.horizontal)
    }
}

// MARK: PRICING TABLE

private struct PricingTableSectionVideo: View {
    let modelName: String
    @State private var showPricingSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header button to open sheet
            Button(action: {
                showPricingSheet = true
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
                        Text("View")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 32)
        .sheet(isPresented: $showPricingSheet) {
            PricingTableSheetView(modelName: modelName)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: PRICING TABLE SHEET VIEW

private struct PricingTableSheetView: View {
    let modelName: String
    @Environment(\.dismiss) private var dismiss

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

    /// Check if this model has motion control pricing (per-second of reference video)
    private var hasMotionControlPricing: Bool {
        PricingManager.shared.hasMotionControlPricing(for: modelName)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Motion Control pricing (e.g. Kling VIDEO 2.6 Pro)
                    if hasMotionControlPricing {
                        MotionControlPricingCard(modelName: modelName)
                    }

                    if let config = pricingConfig {
                        if hasAudioPricing {
                            // Show separate tables for audio/no-audio pricing
                            PricingTableContentWithAudio(
                                config: config,
                                modelName: modelName
                            )
                        } else {
                            // Standard pricing table (with audio label for audio-required models)
                            PricingTableContent(
                                config: config,
                                showAudioLabel: isAudioRequired
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Pricing Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: MOTION CONTROL PRICING CARD

private struct MotionControlPricingCard: View {
    let modelName: String

    private var tiers: [String] {
        PricingManager.shared.motionControlTiers(for: modelName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Motion Control pill
            HStack(spacing: 6) {
                Image(systemName: "video.badge.waveform")
                    .font(.system(size: 12))
                    .foregroundColor(.purple)
                Text("Motion Control")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.purple.opacity(0.12))
            )

            // Table: one row per tier (Standard, Pro) or single row if one tier
            if !tiers.isEmpty {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("Option")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Price")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)

                    ForEach(Array(tiers.enumerated()), id: \.offset) { _, tier in
                        let rate = PricingManager.shared.motionControlPricePerSecond(for: modelName, tier: tier)
                        let label = tier == "standard" ? "Standard (per sec)" : "Pro (per sec)"
                        if let rate = rate {
                            HStack(spacing: 0) {
                                Text(label)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                PriceDisplayView(
                                    price: rate,
                                    font: .system(size: 12, weight: .medium, design: .rounded),
                                    foregroundColor: .white
                                )
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.03))
                        }
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

// MARK: PRICING TABLE CONTENT WITH AUDIO

private struct PricingTableContentWithAudio: View {
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
            AudioPricingCard(
                title: "With Audio",
                icon: "speaker.wave.2.fill",
                aspectRatios: aspectRatios,
                resolutions: resolutions,
                durations: durations,
                config: config,
                audioAddonProvider: { _ in 0 }  // Base price includes audio
            )

            // Without Audio table
            AudioPricingCard(
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

private struct AudioPricingCard: View {
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

private struct PricingTableContent: View {
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
                ResolutionPricingCard(
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

private struct ResolutionPricingCard: View {
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

private struct GenerateButtonVideo: View {
    let prompt: String
    @Binding var isGenerating: Bool
    @Binding var keyboardHeight: CGFloat
    let price: Decimal?
    /// When set and price is nil, show this instead of "0 credits" (e.g. motion control before video: "8 credits/sec")
    let pricePlaceholder: String?
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

    private var priceText: String {
        if let p = price { return PricingManager.formatPrice(p) }
        if let placeholder = pricePlaceholder { return placeholder }
        return PricingManager.formatPrice(0)
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
                        Text(priceText)
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

private struct AudioToggleSectionVideo: View {
    @Binding var generateAudio: Bool
    let isRequired: Bool
    @State private var showWarning: Bool = false

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

                if isRequired {
                    // Custom non-interactive toggle that triggers warning on tap
                    Toggle("", isOn: .constant(true))
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .labelsHidden()
                        .allowsHitTesting(false)
                        .overlay(
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showWarning = true
                                    }
                                    // Reset after a delay
                                    DispatchQueue.main.asyncAfter(
                                        deadline: .now() + 2.0
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.3))
                                        {
                                            showWarning = false
                                        }
                                    }
                                }
                        )
                } else {
                    Toggle("", isOn: $generateAudio)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .labelsHidden()
                }
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

            // Disclaimer for models that require audio
            if isRequired {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(
                            showWarning ? .red : .purple.opacity(0.7))
                    Text(
                        "Audio required. This model can only generate video with audio"
                    )
                    .font(.caption)
                    .foregroundColor(showWarning ? .red : .secondary)
                }
                .padding(.horizontal, 4)
                .scaleEffect(showWarning ? 1.02 : 1.0)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: VEO MODE DESCRIPTION BLOCK

/// Title + icon + short instructions for Google Veo 3.1 Fast input mode (Text / Image / Frames).
private struct VeoModeDescriptionBlock: View {
    let mode: GoogleVeoInputMode
    let color: Color

    private var title: String {
        switch mode {
        case .textToVideo: return "Text To Video"
        case .imageToVideo: return "Image To Video"
        case .frameImages: return "Frame Images"
        }
    }

    private var iconName: String {
        switch mode {
        case .textToVideo: return "doc.text"
        case .imageToVideo: return "photo"
        case .frameImages: return "photo.on.rectangle.angled"
        }
    }

    private var instructions: String {
        switch mode {
        case .textToVideo: return "Describe your video with a prompt. No reference or frame images are used."
        case .imageToVideo: return "Upload one or more reference images to guide the style and content of your video. Use a prompt to guide the action."
        case .frameImages: return "Add first and last frame images to control the video start and end. Use a prompt to guide the action."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(instructions)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
}

// MARK: TEXT / IMAGE MODE DESCRIPTION BLOCK

/// Title + icon + short instructions for Sora 2, Seedance 1.0 Pro Fast, Wan2.6 input mode (Text | Image).
private struct TextImageModeDescriptionBlock: View {
    let mode: Sora2InputMode
    let color: Color

    private var title: String {
        switch mode {
        case .textToVideo: return "Text To Video"
        case .imageToVideo: return "Image To Video"
        }
    }

    private var iconName: String {
        switch mode {
        case .textToVideo: return "doc.text"
        case .imageToVideo: return "photo"
        }
    }

    private var instructions: String {
        switch mode {
        case .textToVideo: return "Describe your video with a prompt. No reference images are used."
        case .imageToVideo: return "Upload one or more reference images to guide the style and content of your video. Use a prompt to guide the action."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(instructions)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
}

// MARK: KLINGAI 2.5 TURBO PRO MODE DESCRIPTION BLOCK

/// Title + icon + short instructions for KlingAI 2.5 Turbo Pro (Text | Image | Frames).
private struct KlingAI25ModeDescriptionBlock: View {
    let mode: KlingAI25TurboProInputMode
    let color: Color

    private var title: String {
        switch mode {
        case .textToVideo: return "Text To Video"
        case .imageToVideo: return "Image To Video"
        case .frameImages: return "Frame Images"
        }
    }

    private var iconName: String {
        switch mode {
        case .textToVideo: return "doc.text"
        case .imageToVideo: return "photo"
        case .frameImages: return "photo.on.rectangle.angled"
        }
    }

    private var instructions: String {
        switch mode {
        case .textToVideo: return "Describe your video with a prompt. No reference or frame images are used."
        case .imageToVideo: return "Upload one or more reference images to guide the style and content of your video."
        case .frameImages: return "Add first and last frame images to control the video start and end."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(instructions)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
}

// MARK: KLING VIDEO 2.6 PRO MODE DESCRIPTION BLOCK

/// Title + icon + short instructions for Kling VIDEO 2.6 Pro (Text | Image | Motion Control).
private struct KlingVideo26ModeDescriptionBlock: View {
    let mode: KlingVideo26ProInputMode
    let color: Color

    private var title: String {
        switch mode {
        case .textToVideo: return "Text To Video"
        case .imageToVideo: return "Image To Video"
        case .motionControl: return "Motion Control"
        }
    }

    private var iconName: String {
        switch mode {
        case .textToVideo: return "doc.text"
        case .imageToVideo: return "photo"
        case .motionControl: return "video.badge.waveform"
        }
    }

    private var instructions: String {
        switch mode {
        case .textToVideo: return "Describe your video with a prompt. No reference or motion control inputs are used."
        case .imageToVideo: return "Upload one or more reference images to guide the style and content of your video."
        case .motionControl: return "Transfer movements from a reference video to any character image."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(instructions)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
}

// MARK: MOTION CONTROL SECTION

/// Motion Control (Kling VIDEO 2.6 Pro): character image + reference video.
private struct MotionControlSection: View {
    @Binding var videoItem: PhotosPickerItem?
    @Binding var videoURL: URL?
    @Binding var characterImage: UIImage?
    @Binding var characterPhotoItem: PhotosPickerItem?
    @Binding var videoDuration: Double?
    @Binding var showDurationAlert: Bool
    let color: Color
    /// When false (Kling VIDEO 2.6 Pro), title and description are hidden; caller shows them via KlingVideo26ModeDescriptionBlock.
    var showTitleAndDescription: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showTitleAndDescription {
                HStack(spacing: 6) {
                    Image(systemName: "video.badge.waveform")
                        .foregroundColor(color)
                    Text("Motion Control")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Text("Transfer movements from a reference video to any character image.")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.bottom, 4)
            }

            HStack(spacing: 12) {
                // Character Image slot (left)
                MotionControlImageSlotCard(
                    title: "Character Image",
                    image: $characterImage,
                    photoItem: $characterPhotoItem,
                    color: color
                )
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 20))
                    .foregroundColor(color.opacity(0.6))

                // Reference Video slot (right)
                MotionControlSlotCard(
                    title: "Reference Video",
                    iconName: "video.fill",
                    videoItem: $videoItem,
                    videoURL: $videoURL,
                    videoDuration: $videoDuration,
                    showDurationAlert: $showDurationAlert,
                    color: color
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Video thumbnail helper (Motion Control reference video)

/// Formats duration in seconds as "M:SS" (e.g. 15.3 → "0:15").
private func formatVideoDuration(_ seconds: Double) -> String {
    let m = Int(seconds) / 60
    let s = Int(seconds) % 60
    return "\(m):\(s < 10 ? "0" : "")\(s)"
}

/// Generates a thumbnail image from a local video URL (e.g. from PhotosPicker).
private func generateVideoThumbnail(from url: URL) async -> UIImage? {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 400, height: 400)
    let time = CMTime(seconds: 0.5, preferredTimescale: 60)
    return await withCheckedContinuation { continuation in
        generator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
            if let cgImage = cgImage {
                continuation.resume(returning: UIImage(cgImage: cgImage))
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: MOTION CONTROL SLOT CARD (VIDEO)

private struct MotionControlSlotCard: View {
    let title: String
    let iconName: String
    @Binding var videoItem: PhotosPickerItem?
    @Binding var videoURL: URL?
    @Binding var videoDuration: Double?
    @Binding var showDurationAlert: Bool
    let color: Color
    /// Thumbnail for the selected video; generated when videoURL is set.
    @State private var thumbnailImage: UIImage?

    var body: some View {
        VStack(spacing: 8) {
            // Loading state: user picked a video but loadTransferable is still in progress
            if videoItem != nil, videoURL == nil {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(color)
                        Text("Loading video…")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: DesignConstants.frameStyleSlotHeight)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .foregroundColor(color.opacity(0.3))
                    )
                    Button {
                        videoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.black)
                            .background(Circle().fill(.white))
                    }
                    .padding(6)
                }
                .frame(maxWidth: .infinity)
            } else if let url = videoURL {
                ZStack(alignment: .topTrailing) {
                    if let thumb = thumbnailImage {
                        // Show thumbnail (same style as Character Image slot)
                        Image(uiImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: DesignConstants.frameStyleSlotWidth, height: DesignConstants.frameStyleSlotHeight)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        // Thumbnail generating: subtle background + spinner
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.08))
                            .frame(width: DesignConstants.frameStyleSlotWidth, height: DesignConstants.frameStyleSlotHeight)
                            .overlay {
                                VStack(spacing: 6) {
                                    ProgressView()
                                    Text("Video selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                    }
                    // Duration overlay at bottom (keeps same card size as Character Image)
                    if let duration = videoDuration, duration > 0 {
                        let secondsStr: String = {
                            let oneDecimal = String(format: "%.1f", duration)
                            if oneDecimal.hasSuffix(".0") { return String(Int(duration)) }
                            return oneDecimal
                        }()
                        VStack {
                            Spacer()
                            Text("\(formatVideoDuration(duration)) (\(secondsStr) sec)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(8)
                        }
                        .frame(width: DesignConstants.frameStyleSlotWidth, height: DesignConstants.frameStyleSlotHeight)
                        .allowsHitTesting(false)
                    }
                    // Change button (top-right, like character image remove)
                    Button {
                        videoItem = nil
                        videoURL = nil
                        videoDuration = nil
                        thumbnailImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.black)
                            .background(Circle().fill(.white))
                    }
                    .padding(6)
                }
                .frame(width: DesignConstants.frameStyleSlotWidth, height: DesignConstants.frameStyleSlotHeight)
                .frame(maxWidth: .infinity)
                .task(id: url) {
                    thumbnailImage = await generateVideoThumbnail(from: url)
                }
            } else {
                PhotosPicker(
                    selection: $videoItem,
                    matching: .videos
                ) {
                    VStack(spacing: 8) {
                        Image(systemName: iconName)
                            .font(.system(size: 28))
                            .foregroundColor(color.opacity(0.7))
                        Text(title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text("Tap to add")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: DesignConstants.frameStyleSlotHeight)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .foregroundColor(color.opacity(0.3))
                    )
                }
            }
        }
        .onChange(of: videoItem) { _, newItem in
            Task {
                if let item = newItem,
                   let video = try? await item.loadTransferable(type: VideoTransferable.self) {
                    // Check video duration using AVURLAsset
                    let asset = AVURLAsset(url: video.url)
                    if let duration = try? await asset.load(.duration) {
                        let durationSeconds = CMTimeGetSeconds(duration)

                        if durationSeconds > 30 {
                            // Video too long - reject and show alert
                            await MainActor.run {
                                videoURL = nil
                                videoItem = nil
                                videoDuration = nil
                                showDurationAlert = true
                            }
                        } else {
                            await MainActor.run {
                                videoURL = video.url
                                videoDuration = durationSeconds
                            }
                        }
                    } else {
                        // Could not determine duration - allow but set nil
                        await MainActor.run {
                            videoURL = video.url
                            videoDuration = nil
                        }
                    }
                } else {
                    await MainActor.run {
                        videoURL = nil
                        videoDuration = nil
                    }
                }
            }
        }
    }
}

// MARK: MOTION CONTROL IMAGE SLOT CARD

private struct MotionControlImageSlotCard: View {
    let title: String
    @Binding var image: UIImage?
    @Binding var photoItem: PhotosPickerItem?
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: DesignConstants.frameStyleSlotWidth, height: DesignConstants.frameStyleSlotHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            image = nil
                            photoItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.black)
                                .background(Circle().fill(.white))
                        }
                        .padding(6)
                    }
            } else {
                PhotosPicker(
                    selection: $photoItem,
                    matching: .images
                ) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundColor(color.opacity(0.7))
                        Text(title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text("Tap to add")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(width: DesignConstants.frameStyleSlotWidth, height: DesignConstants.frameStyleSlotHeight)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .foregroundColor(color.opacity(0.3))
                    )
                }
                .onChange(of: photoItem) { _, newItem in
                    Task {
                        guard let item = newItem else {
                            image = nil
                            return
                        }
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            image = uiImage
                        }
                    }
                }
            }
        }
    }
}

// MARK: FRAME IMAGES SECTION

private struct FrameImagesSection: View {
    @Binding var firstFrameImage: UIImage?
    @Binding var lastFrameImage: UIImage?
    @Binding var showFirstFrameCameraSheet: Bool
    @Binding var showLastFrameCameraSheet: Bool
    let color: Color
    /// When false (e.g. Google Veo Frames mode), title and description are hidden; caller shows them via VeoModeDescriptionBlock.
    var showTitleAndDescription: Bool = true

    @State private var showFirstFrameActionSheet: Bool = false
    @State private var showLastFrameActionSheet: Bool = false
    @State private var selectedFirstFramePhotoItem: PhotosPickerItem? = nil
    @State private var selectedLastFramePhotoItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showTitleAndDescription {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(color)
                    Text("Frame Images (Optional)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Text("Add first and last frame images to control the video start and end. Use a prompt to guide the action.")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.bottom, 4)
            }

            // Horizontal layout with arrow icon between first and last frame images
            HStack(spacing: 0) {
                // First Frame Image - takes 50% of width
                FrameImageCard(
                    title: "Start Frame",
                    image: $firstFrameImage,
                    showCameraSheet: $showFirstFrameCameraSheet,
                    showActionSheet: $showFirstFrameActionSheet,
                    selectedPhotoItem: $selectedFirstFramePhotoItem,
                    color: color
                )
                .frame(maxWidth: .infinity)
                
                // Left-right arrows icon with padding
                HStack(spacing: 0) {
                    Spacer().frame(width: 12)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20))
                        .foregroundColor(color.opacity(0.6))
                    Spacer().frame(width: 12)
                }
                
                // Last Frame Image - takes 50% of width
                FrameImageCard(
                    title: "End Frame",
                    image: $lastFrameImage,
                    showCameraSheet: $showLastFrameCameraSheet,
                    showActionSheet: $showLastFrameActionSheet,
                    selectedPhotoItem: $selectedLastFramePhotoItem,
                    color: color
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showFirstFrameActionSheet) {
            SingleImageSourceSelectionSheet(
                showCameraSheet: $showFirstFrameCameraSheet,
                selectedPhotoItem: $selectedFirstFramePhotoItem,
                showActionSheet: $showFirstFrameActionSheet,
                image: $firstFrameImage,
                color: color
            )
        }
        .sheet(isPresented: $showLastFrameActionSheet) {
            SingleImageSourceSelectionSheet(
                showCameraSheet: $showLastFrameCameraSheet,
                selectedPhotoItem: $selectedLastFramePhotoItem,
                showActionSheet: $showLastFrameActionSheet,
                image: $lastFrameImage,
                color: color
            )
        }
    }
}

// MARK: SINGLE IMAGE SOURCE SELECTION SHEET

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

// MARK: FRAME IMAGE CARD

private struct FrameImageCard: View {
    let title: String
    @Binding var image: UIImage?
    @Binding var showCameraSheet: Bool
    @Binding var showActionSheet: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if let image = image {
                // Show image with remove button
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: DesignConstants.frameStyleSlotWidth, height: DesignConstants.frameStyleSlotHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(color.opacity(0.6), lineWidth: 1)
                        )
                    
                    Button(action: { self.image = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.gray))
                    }
                    .padding(6)
                }
            } else {
                // Show add button (styled to match Motion Control: colored dashed border, icon, Tap to add)
                Button {
                    showActionSheet = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundColor(color.opacity(0.7))
                        Text(title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text("Tap to add")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(width: DesignConstants.frameStyleSlotWidth, height: DesignConstants.frameStyleSlotHeight)
                    .background(color.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .foregroundColor(color.opacity(0.3))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// // MARK: - Credit Conversion Helper
// extension Decimal {
//     /// Converts dollar amount to credits (1 credit = $0.01)
//     var credits: Int {
//         let dollars = NSDecimalNumber(decimal: self).doubleValue
//         return Int((dollars * 100).rounded())
//     }
// }

// extension Optional where Wrapped == Decimal {
//     /// Converts dollar amount to credits, returns 0 if nil
//     var credits: Int {
//         guard let value = self else { return 0 }
//         return value.credits
//     }
// }
