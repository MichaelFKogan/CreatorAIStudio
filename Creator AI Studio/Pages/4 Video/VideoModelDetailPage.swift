//
//  VideoModelDetailPage.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/25/25.
//

import Kingfisher
import PhotosUI
import SwiftUI

//struct LazyView<Content: View>: View {
//    let build: () -> Content
//    init(_ build: @autoclosure @escaping () -> Content) { self.build = build }
//    var body: some View { build() }
//}

struct VideoModelDetailPage: View {
    @State var item: InfoPacket

    @State private var prompt: String = ""
    @FocusState private var isPromptFocused: Bool
    @State private var isExamplePromptsPresented: Bool = false

    @State private var referenceImages: [UIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    @State private var isGenerating: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showEmptyPromptAlert: Bool = false
    @State private var showCameraSheet: Bool = false
    @State private var showPromptCameraSheet: Bool = false
    @State private var isProcessingOCR: Bool = false
    @State private var showOCRAlert: Bool = false
    @State private var ocrAlertMessage: String = ""

    @State private var selectedAspectIndex: Int = 0
    @State private var selectedGenerationMode: Int = 0
    @State private var selectedDurationIndex: Int = 0
    @State private var selectedResolutionIndex: Int = 0
    @State private var generateAudio: Bool = true  // Default to ON for audio generation
    @State private var showSignInSheet: Bool = false

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

    private let examplePrompts: [String] = [
        "A serene landscape with mountains at sunset, photorealistic, 8k quality",
        "A futuristic cityscape with flying cars and neon lights at night",
        "A cute fluffy kitten playing with yarn, studio lighting, professional photography",
        "An astronaut riding a horse on the moon, cinematic lighting, detailed",
        "A cozy coffee shop interior with warm lighting and plants, architectural photography",
        "A majestic dragon soaring through clouds, fantasy art, highly detailed",
        "A vintage sports car on an empty road, golden hour lighting, 4k",
        "A magical forest with glowing mushrooms and fireflies, fantasy illustration",
        "A modern minimalist living room with large windows, interior design photography",
        "A colorful abstract painting with geometric shapes and vibrant colors",
        "A medieval castle on a cliff overlooking the ocean, dramatic lighting",
        "A cyberpunk street market with holographic signs, neon colors, ultra detailed",
        "A peaceful zen garden with cherry blossoms and koi pond, soft focus",
        "A powerful lion portrait with intense eyes, wildlife photography, 8k",
        "A steampunk airship in the clouds, brass and copper details, concept art",
        "A tropical beach at sunrise with palm trees, paradise scenery, HDR",
        "An enchanted library with floating books and magical lights, fantasy art",
        "A modern luxury yacht on crystal clear water, professional photography",
        "A mysterious alien landscape with purple sky and twin moons, sci-fi art",
        "A rustic farmhouse in autumn with falling leaves, warm colors, cozy atmosphere",
        "A sleek modern kitchen with marble countertops, architectural digest style",
        "A samurai warrior in traditional armor, dramatic pose, cinematic composition",
        "A vibrant coral reef with tropical fish, underwater photography, vivid colors",
        "A gothic cathedral interior with stained glass windows, divine lighting",
        "A bustling Tokyo street at night with neon signs, street photography",
        "A serene mountain lake reflection at dawn, mirror-like water, pristine nature",
        "A futuristic robot with intricate mechanical details, sci-fi concept art",
        "A cozy reading nook by a window on a rainy day, warm lighting",
        "A majestic phoenix rising from flames, mythical creature, vibrant colors",
        "A Victorian mansion in foggy weather, gothic atmosphere, haunting beauty",
    ]

    private let transformPrompts: [String] = [
        "Transform to anime style",
        "Transform to watercolor painting",
        "Transform to oil painting",
        "Transform to pencil sketch",
        "Transform to cyberpunk style",
        "Transform to vintage photograph",
        "Transform to impressionist painting",
        "Transform to pop art style",
        "Transform to black and white",
        "Transform to steampunk style",
        "Transform to fantasy art style",
        "Transform to minimalist design",
        "Transform to 3D render",
        "Transform to comic book style",
        "Transform to surrealist art",
        "Transform to abstract art",
        "Transform to pixel art",
        "Transform to neon art style",
        "Transform to gothic style",
        "Transform to kawaii style",
        "Transform to retro 80s style",
        "Transform to film noir style",
        "Transform to Van Gogh painting style",
        "Transform to Picasso cubist style",
        "Transform to Monet impressionist style",
    ]

    private var costString: String {
        NSDecimalNumber(decimal: currentPrice ?? item.resolvedCost ?? 0)
            .stringValue
    }

    private var creditsString: String {
        "\((currentPrice ?? item.resolvedCost ?? 0).credits)"
    }

    /// Computed property to get the current price based on selected aspect ratio, duration, and audio
    /// Returns variable pricing if available, otherwise falls back to base price
    /// This automatically updates the UI when aspect ratio, duration, or audio selections change
    private var currentPrice: Decimal? {
        guard let modelName = item.display.modelName else {
            return item.resolvedCost
        }

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
        let selectedResolutionOption = videoResolutionOptions[
            selectedResolutionIndex]
        let resolution = selectedResolutionOption.id

        // Get variable price for this combination
        if var variablePrice = PricingManager.shared.variablePrice(
            for: modelName,
            aspectRatio: selectedAspectOption.id,
            resolution: resolution,
            duration: selectedDurationOption.duration
        ) {
            // Adjust audio pricing if applicable
            // Base price includes audio (since audio is ON by default)
            // Subtract audio addon when audio is turned OFF
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

    private var isMidjourney: Bool {
        item.display.title.lowercased().contains("midjourney")
    }

    // MARK: BODY

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {
                        LazyView(
                            BannerSectionVideo(
                                item: item, creditsString: creditsString))

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
                                isProcessingOCR: $isProcessingOCR
                            ))

                        if ModelConfigurationManager.shared.capabilities(
                            for: item)?.contains("Image to Video") == true
                        {
                            LazyView(
                                ReferenceImagesSection(
                                    referenceImages: $referenceImages,
                                    selectedPhotoItems: $selectedPhotoItems,
                                    showCameraSheet: $showCameraSheet,
                                    color: .purple
                                ))
                        }

                        if isMidjourney {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(
                                    "Midjourney creates 4 videos by default: Total cost: \(item.resolvedCost.credits * 4) credits"
                                )
                                .font(.caption)
                                .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, -16)
                        }

                        // Login disclaimer (shown when not logged in)
                        if authViewModel.user == nil {
                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Spacer()
                                    Image(
                                        systemName:
                                            "exclamationmark.circle.fill"
                                    )
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    Text(
                                        "You must be logged in to generate a video"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    Spacer()
                                }

                                // Sign In / Sign Up text link (shown when not logged in)
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        showSignInSheet = true
                                    }) {
                                        Text("Sign In / Sign Up")
                                            .font(
                                                .system(
                                                    size: 15, weight: .medium,
                                                    design: .rounded)
                                            )
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        }

                        LazyView(
                            GenerateButtonVideo(
                                prompt: prompt,
                                isGenerating: $isGenerating,
                                keyboardHeight: $keyboardHeight,
                                creditsString: creditsString,
                                selectedSize: videoAspectOptions[
                                    selectedAspectIndex
                                ].id,
                                selectedResolution: hasVariableResolution
                                    ? videoResolutionOptions[
                                        selectedResolutionIndex
                                    ].id : nil,
                                selectedDuration:
                                    "\(Int(videoDurationOptions[selectedDurationIndex].duration))s",
                                isLoggedIn: authViewModel.user != nil,
                                onSignInTap: {
                                    showSignInSheet = true
                                },
                                action: generate
                            ))

                        Divider().padding(.horizontal)

                        // Audio toggle - only show for models that support audio generation
                        if supportsAudio {
                            AudioToggleSectionVideo(
                                generateAudio: $generateAudio,
                                isRequired: audioRequired
                            )
                        }

                        LazyView(
                            AspectRatioSectionVideo(
                                options: videoAspectOptions,
                                selectedIndex: $selectedAspectIndex
                            ))

                        // Only show resolution selector for models with variable pricing
                        if hasVariableResolution {
                            LazyView(
                                ResolutionSectionVideo(
                                    options: videoResolutionOptions,
                                    selectedIndex: $selectedResolutionIndex
                                ))
                        }

                        LazyView(
                            DurationSectionVideo(
                                options: videoDurationOptions,
                                selectedIndex: $selectedDurationIndex
                            ))

                        Divider().padding(.horizontal)

                        // Pricing Table - Only show for models with variable pricing
                        if let modelName = item.display.modelName,
                            PricingManager.shared.hasVariablePricing(
                                for: modelName)
                        {
                            LazyView(
                                PricingTableSectionVideo(modelName: modelName)
                            )

                            Divider().padding(.horizontal)
                        }

                        // Example Gallery Section - Only show if model name exists
                        if let modelName = item.display.modelName,
                            !modelName.isEmpty
                        {
                            LazyView(
                                ModelGallerySection(
                                    modelName: modelName,
                                    userId: authViewModel.user?.id.uuidString
                                        .lowercased()
                                )
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
                CreditsViewVideo()
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
        .sheet(isPresented: $showCameraSheet) {
            SimpleCameraPicker(isPresented: $showCameraSheet) { capturedImage in
                referenceImages.append(capturedImage)
            }
        }
        .sheet(isPresented: $showPromptCameraSheet) {
            SimpleCameraPicker(isPresented: $showPromptCameraSheet) {
                capturedImage in
                processOCR(from: capturedImage)
            }
        }
        .alert("Text Recognition", isPresented: $showOCRAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ocrAlertMessage)
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
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

    // MARK: FUNCTION GENERATE

    private func generate() {
        guard !prompt.isEmpty else {
            showEmptyPromptAlert = true
            return
        }
        guard !isGenerating else { return }

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

        let imageToUse = referenceImages.first
        guard let userId = authViewModel.user?.id.uuidString.lowercased(),
            !userId.isEmpty
        else {
            isGenerating = false
            return
        }

        Task { @MainActor in
            _ = VideoGenerationCoordinator.shared.startVideoGeneration(
                item: modifiedItem,
                image: imageToUse,
                userId: userId,
                duration: selectedDurationOption.duration,
                aspectRatio: selectedAspectOption.id,
                resolution: hasVariableResolution
                    ? selectedResolutionOption.id : nil,
                generateAudio: supportsAudio ? generateAudio : nil,
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
    let creditsString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        Text("\(creditsString) credits").font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text("per video").font(.caption).foregroundColor(
                            .secondary)
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

            // Model Description
            if let description = item.resolvedModelDescription,
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
    @Binding var isProcessingOCR: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft").foregroundColor(.purple)
                Text("Prompt").font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()

                HStack(spacing: 8) {
                    VStack(alignment: .leading) {
                        Text("Take a photo of a prompt")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("to add it to the box below")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
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
                                    .font(.system(size: 22))
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
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

private struct ResolutionSectionVideo: View {
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

private struct DurationSectionVideo: View {
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

private struct PricingTableSectionVideo: View {
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
        .padding(.horizontal)
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
                                        Text("\(adjustedPrice.credits)")
                                            .font(
                                                .system(
                                                    size: 12, weight: .medium,
                                                    design: .rounded)
                                            )
                                            .foregroundColor(.purple)
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
                                Text("\(price.credits)")
                                    .font(
                                        .system(
                                            size: 12, weight: .medium,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.purple)
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
    let creditsString: String
    let selectedSize: String
    let selectedResolution: String?
    let selectedDuration: String
    let isLoggedIn: Bool
    let onSignInTap: () -> Void
    let action: () -> Void

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
                        Image(systemName: "video.fill")
                    }
                    Text(
                        isGenerating
                            ? "Generating..."
                            : "Generate Video - \(creditsString) credits"
                    ).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isGenerating || !isLoggedIn
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
                    color: (isGenerating || !isLoggedIn)
                        ? Color.clear : Color.purple.opacity(0.4),
                    radius: 8, x: 0, y: 4
                )
            }
            .scaleEffect(isGenerating ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
            .disabled(isGenerating || !isLoggedIn)
            .opacity(!isLoggedIn ? 0.6 : 1.0)
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

// MARK: CREDITS VIEW

private struct CreditsViewVideo: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "diamond.fill")
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink], startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .font(.system(size: 8))
            Text("250").font(
                .system(size: 14, weight: .semibold, design: .rounded)
            ).foregroundColor(.primary)
            Text("credits").font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(Color.purple.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20).strokeBorder(
                LinearGradient(
                    colors: [.purple, .pink], startPoint: .leading,
                    endPoint: .trailing
                ), lineWidth: 1.5
            ))
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
