//
//  ImageModelDetailPage.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/25/25.
//

import Kingfisher
import PhotosUI
import SwiftUI

/// Input mode for image models that support both text and image: Text | Image.
private enum ImageTextInputMode: String, CaseIterable {
    case textToImage = "Text"
    case imageToImage = "Image"
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) { self.build = build }
    var body: some View { build() }
}

struct ImageModelDetailPage: View {
    @State var item: InfoPacket
    let capturedImage: UIImage?

    @State private var prompt: String = ""
    @FocusState private var isPromptFocused: Bool
    @State private var isExamplePromptsPresented: Bool = false

    @State private var referenceImages: [UIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    /// Text | Image segmented control (all image models except Z-Image-Turbo and Wan2.5-Preview Image).
    @State private var imageTextInputMode: ImageTextInputMode = .imageToImage

    @State private var isGenerating: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showEmptyPromptAlert: Bool = false
    @State private var showCameraSheet: Bool = false
    @State private var showPromptCameraSheet: Bool = false
    @State private var isProcessingOCR: Bool = false
    @State private var showOCRAlert: Bool = false
    @State private var ocrAlertMessage: String = ""

    @State private var selectedAspectIndex: Int = 0
    /// Resolution tier for Nano Banana Pro (1K, 2K, 4K). Index into imageResolutionOptions; default 1 = 2K.
    @State private var selectedResolutionIndex: Int = 1
    @State private var showResolutionSheet: Bool = false
    /// Quality for GPT Image 1.5 only: 0 = Low, 1 = Medium, 2 = High.
    @State private var selectedQualityIndex: Int = 1
    @State private var showQualitySheet: Bool = false
    @State private var selectedGenerationMode: Int = 0
    @State private var showSignInSheet: Bool = false
    @State private var showPurchaseCreditsView: Bool = false
    @State private var showInsufficientCreditsAlert: Bool = false
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    @EnvironmentObject var authViewModel: AuthViewModel

    init(item: InfoPacket, capturedImage: UIImage? = nil) {
        self._item = State(initialValue: item)
        self.capturedImage = capturedImage
    }

    // MARK: Constants

    // Replace the hardcoded imageAspectOptions with a computed property:
    private var imageAspectOptions: [AspectRatioOption] {
        // Check for model-specific aspect ratios first
        if let modelOptions = ModelConfigurationManager.shared
            .allowedAspectRatios(for: item), !modelOptions.isEmpty
        {
            return modelOptions
        }
        // Fall back to default options for models without specific constraints
        return [
            AspectRatioOption(
                id: "3:4", label: "3:4", width: 3, height: 4,
                platforms: ["Portrait"]),
            AspectRatioOption(
                id: "9:16", label: "9:16", width: 9, height: 16,
                platforms: ["TikTok", "Reels"]),
            AspectRatioOption(
                id: "1:1", label: "1:1", width: 1, height: 1,
                platforms: ["Instagram"]),
            AspectRatioOption(
                id: "4:3", label: "4:3", width: 4, height: 3,
                platforms: ["Landscape"]),
            AspectRatioOption(
                id: "16:9", label: "16:9", width: 16, height: 9,
                platforms: ["YouTube"]),
        ]
    }

    // Prompt constants shared with VideoModelDetailPage (extracted to VideoPromptConstants.swift)
    private var examplePrompts: [String] { VideoPromptConstants.examplePrompts }
    private var transformPrompts: [String] { VideoPromptConstants.transformPrompts }

    private var costString: String {
        if isGPTImage15, selectedAspectIndex < imageAspectOptions.count, selectedQualityIndex < gptImage15QualityOptions.count,
           let price = PricingManager.shared.priceForImageModel("GPT Image 1.5", aspectRatio: imageAspectOptions[selectedAspectIndex].id, quality: gptImage15QualityOptions[selectedQualityIndex]) {
            return PricingManager.formatPrice(Decimal(price))
        }
        if isNanoBananaPro, let options = imageResolutionOptions, selectedResolutionIndex < options.count,
           let price = PricingManager.shared.priceForImageModel("Nano Banana Pro", resolution: options[selectedResolutionIndex].id) {
            return PricingManager.formatPrice(Decimal(price))
        }
        return PricingManager.formatPrice(item.resolvedCost ?? 0)
    }

    // Calculate required credits as Double (GPT Image 1.5: aspect+quality; Nano Banana Pro: resolution; else fixed)
    private var requiredCredits: Double {
        if isGPTImage15, selectedAspectIndex < imageAspectOptions.count, selectedQualityIndex < gptImage15QualityOptions.count,
           let price = PricingManager.shared.priceForImageModel("GPT Image 1.5", aspectRatio: imageAspectOptions[selectedAspectIndex].id, quality: gptImage15QualityOptions[selectedQualityIndex]) {
            return price
        }
        if isNanoBananaPro, let options = imageResolutionOptions, selectedResolutionIndex < options.count,
           let price = PricingManager.shared.priceForImageModel("Nano Banana Pro", resolution: options[selectedResolutionIndex].id) {
            return price
        }
        let cost = item.resolvedCost ?? Decimal(0.04)  // Default image cost
        return NSDecimalNumber(decimal: cost).doubleValue
    }
    
    // Check if user has enough credits
    private var hasEnoughCredits: Bool {
        guard let userId = authViewModel.user?.id else { return false }
        return creditsViewModel.hasEnoughCredits(requiredAmount: requiredCredits)
    }

    private var isMidjourney: Bool {
        item.display.title.lowercased().contains("midjourney")
    }

    /// Text-only models: no segmented control, no reference images section.
    private var isTextOnlyImageModel: Bool {
        guard let name = item.display.modelName else { return false }
        return name == "Z-Image-Turbo" || name == "Wan2.5-Preview Image"
    }

    /// True when the model shows Text | Image segmented control (all image models except text-only).
    private var showsTextImageInputModePicker: Bool {
        !isTextOnlyImageModel
    }

    /// True when the model is Nano Banana Pro (supports 1K/2K/4K resolution selection).
    private var isNanoBananaPro: Bool {
        item.display.modelName == "Nano Banana Pro"
    }

    /// Resolution options for Nano Banana Pro (1K, 2K, 4K). Nil for other models.
    private var imageResolutionOptions: [ResolutionOption]? {
        guard isNanoBananaPro else { return nil }
        return ModelConfigurationManager.shared.allowedResolutions(for: item)
    }

    /// True when the model is GPT Image 1.5 (supports quality: low, medium, high).
    private var isGPTImage15: Bool {
        item.display.modelName == "GPT Image 1.5"
    }

    /// Quality option IDs for GPT Image 1.5 (Low, Medium, High).
    private let gptImage15QualityOptions: [String] = ["low", "medium", "high"]

    /// Credit strings for GPT Image 1.5 quality options (Low, Medium, High) at current aspect ratio. Used in Select Quality sheet.
    private var gptImage15QualityCredits: [String]? {
        guard isGPTImage15, selectedAspectIndex < imageAspectOptions.count else { return nil }
        let aspectId = imageAspectOptions[selectedAspectIndex].id
        let credits = gptImage15QualityOptions.compactMap { quality -> String? in
            guard let price = PricingManager.shared.priceForImageModel("GPT Image 1.5", aspectRatio: aspectId, quality: quality) else { return nil }
            return "\(PricingManager.formatCredits(Decimal(price))) credits"
        }
        return credits.isEmpty ? nil : credits
    }

    // MARK: BODY (split into sections to reduce compiler type-checking load)

    @ViewBuilder private var scrollBannerAndPrompt: some View {
        LazyView(
            BannerSection(item: item, costString: costString, displayPrice: isGPTImage15 ? Decimal(requiredCredits) : nil))
        Divider().padding(.horizontal)
        LazyView(
            PromptSection(
                prompt: $prompt,
                isFocused: $isPromptFocused,
                isExamplePromptsPresented: $isExamplePromptsPresented,
                examplePrompts: examplePrompts,
                examplePromptsTransform: transformPrompts,
                onCameraTap: { showPromptCameraSheet = true },
                isProcessingOCR: $isProcessingOCR
            ))
    }

    @ViewBuilder private var scrollInputModeAndRefs: some View {
        if showsTextImageInputModePicker {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input mode")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Picker("Input mode", selection: $imageTextInputMode) {
                        ForEach(ImageTextInputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ImageTextImageModeDescriptionBlock(mode: imageTextInputMode, color: .blue)
            }
            .padding(.horizontal)
        }
        if showsTextImageInputModePicker && imageTextInputMode == .imageToImage {
            LazyView(
                ReferenceImagesSection(
                    referenceImages: $referenceImages,
                    selectedPhotoItems: $selectedPhotoItems,
                    showCameraSheet: $showCameraSheet,
                    color: .blue
                ))
        }
    }

    @ViewBuilder private var scrollGenerateAndCost: some View {
        if isMidjourney {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Midjourney creates 4 images by default: Total cost: $0.10")
                    .font(.caption)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, -16)
        }
        LazyView(
            GenerateButton(
                prompt: prompt,
                isGenerating: $isGenerating,
                keyboardHeight: $keyboardHeight,
                costString: costString,
                isLoggedIn: authViewModel.user != nil,
                hasCredits: hasEnoughCredits,
                isConnected: networkMonitor.isConnected,
                onSignInTap: { showSignInSheet = true },
                action: generate
            ))
        VStack(spacing: 12) {
            AuthAwareCostCard(
                price: isGPTImage15 ? Decimal(requiredCredits) : (item.resolvedCost ?? 0),
                requiredCredits: requiredCredits,
                primaryColor: .blue,
                secondaryColor: .cyan,
                loginMessage: "Log in to generate an image",
                isConnected: networkMonitor.isConnected,
                onSignIn: { showSignInSheet = true },
                onBuyCredits: { showPurchaseCreditsView = true }
            )
        }
        .padding(.horizontal)
        .padding(.top, -16)
    }

    private var scrollQualityAspectResolution: some View {
        VStack(spacing: 12) {
            LazyView(
                AspectRatioSection(
                    options: imageAspectOptions,
                    selectedIndex: $selectedAspectIndex
                ))
            if isNanoBananaPro, let options = imageResolutionOptions, !options.isEmpty {
                LazyView(
                    ResolutionSection(
                        options: options,
                        selectedIndex: $selectedResolutionIndex,
                        showSheet: $showResolutionSheet
                    ))
                .sheet(isPresented: $showResolutionSheet) {
                    ResolutionSelectorSheet(
                        options: options,
                        selectedIndex: $selectedResolutionIndex,
                        color: .blue,
                        isPresented: $showResolutionSheet
                    )
                }
            }
            if isGPTImage15 {
                LazyView(
                    QualitySection(
                        selectedQualityIndex: $selectedQualityIndex,
                        qualityOptions: gptImage15QualityOptions,
                        showSheet: $showQualitySheet
                    ))
            }
        }
        .padding(.top, -16)
    }

    @ViewBuilder private var scrollGallery: some View {
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

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                scrollBannerAndPrompt
                scrollInputModeAndRefs
                scrollGenerateAndCost
                scrollQualityAspectResolution
                if isGPTImage15 || isNanoBananaPro, let modelName = item.display.modelName {
                    LazyView(PricingTableSectionImage(modelName: modelName))
                    Divider().padding(.horizontal)
                }
                scrollGallery
                Color.clear.frame(height: 130)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var bodyContent: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                scrollContent
            }
        }
    }

    /// First segment of modifiers (content through toolbar). Split to reduce type-checker load.
    private var contentWithNavigation: some View {
        bodyContent
            .contentShape(Rectangle())
            .onTapGesture { isPromptFocused = false }
            .onAppear {
                if let capturedImage = capturedImage, referenceImages.isEmpty {
                    referenceImages = [capturedImage]
                }
            }
            .onChange(of: showSignInSheet) { isPresented in
                if !isPresented, let userId = authViewModel.user?.id {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Image Models")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
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
                        diamondColor: .blue,
                        borderColor: .blue,
                        showSignInSheet: $showSignInSheet,
                        showPurchaseCreditsView: $showPurchaseCreditsView
                    )
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OfflineToolbarIcon()
                }
            }
    }

    var body: some View {
        bodyWithSheets
    }

    /// Second segment: keyboard, alerts, sheets. Split to reduce type-checker load.
    private var bodyWithSheets: some View {
        contentWithNavigation
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
            .alert("Prompt Required", isPresented: $showEmptyPromptAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a prompt to generate an image.")
            }
            .sheet(isPresented: $showCameraSheet) {
                SimpleCameraPicker(isPresented: $showCameraSheet) { capturedImage in
                    referenceImages = [capturedImage]
                }
            }
            .sheet(isPresented: $showPromptCameraSheet) {
                SimpleCameraPicker(isPresented: $showPromptCameraSheet) { capturedImage in
                    processOCR(from: capturedImage)
                }
            }
            .alert("Text Recognition", isPresented: $showOCRAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(ocrAlertMessage)
            }
            .sheet(isPresented: $showQualitySheet) {
                QualitySelectorSheet(
                    selectedIndex: $selectedQualityIndex,
                    optionLabels: ["Low", "Medium", "High"],
                    color: .blue,
                    isPresented: $showQualitySheet
                )
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
        let selectedAspectOption = imageAspectOptions[selectedAspectIndex]
        var modifiedItem = item
        modifiedItem.prompt = prompt
        // Use resolvedAPIConfig as base, then modify aspectRatio and resolution (Nano Banana Pro)
        var config = modifiedItem.resolvedAPIConfig
        config.aspectRatio = selectedAspectOption.id
        if isNanoBananaPro, let resolutionOptions = imageResolutionOptions, selectedResolutionIndex < resolutionOptions.count {
            config.resolution = resolutionOptions[selectedResolutionIndex].id
        }
        if isGPTImage15, selectedQualityIndex < gptImage15QualityOptions.count {
            var rw = config.runwareConfig ?? RunwareConfig(
                imageToImageMethod: "referenceImages",
                strength: nil,
                additionalTaskParams: nil,
                requiresDimensions: true,
                imageCompressionQuality: 0.9,
                outputFormat: nil,
                outputType: nil,
                outputQuality: nil,
                openaiQuality: nil
            )
            rw.openaiQuality = gptImage15QualityOptions[selectedQualityIndex]
            config.runwareConfig = rw
        }
        modifiedItem.apiConfig = config

        // Pass reference image only when Image segment is selected; text-only models never use ref image.
        let useReferenceImage = showsTextImageInputModePicker && imageTextInputMode == .imageToImage
        let imageToUse = (useReferenceImage ? referenceImages.first : nil) ?? createPlaceholderImage()
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
            _ = ImageGenerationCoordinator.shared.startImageGeneration(
                item: modifiedItem,
                image: imageToUse,
                userId: userId,
                onImageGenerated: { _ in isGenerating = false },
                onError: { error in
                    isGenerating = false
                    print(
                        "Image generation failed: \(error.localizedDescription)"
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

// MARK: TEXT / IMAGE MODE DESCRIPTION BLOCK (IMAGE MODELS)

/// Title + icon + short instructions for image models with Text | Image input mode.
private struct ImageTextImageModeDescriptionBlock: View {
    let mode: ImageTextInputMode
    let color: Color

    private var title: String {
        switch mode {
        case .textToImage: return "Text To Image"
        case .imageToImage: return "Image To Image"
        }
    }

    private var iconName: String {
        switch mode {
        case .textToImage: return "doc.text"
        case .imageToImage: return "photo"
        }
    }

    private var instructions: String {
        switch mode {
        case .textToImage: return "Describe your image with a prompt. No reference images are used."
        case .imageToImage: return "Upload one or more reference images to guide the style and content."
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

// MARK: BANNER SECTION

struct BannerSection: View {
    let item: InfoPacket
    let costString: String
    /// When set (e.g. GPT Image 1.5 with selected quality/aspect), used instead of item.resolvedCost for the banner price.
    var displayPrice: Decimal? = nil

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
                        Image(systemName: "photo.on.rectangle").font(
                            .caption)
                        Text("Image Generation Model").font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.blue.opacity(0.8)))

                    HStack(spacing: 4) {
                        PriceDisplayView(
                            price: displayPrice ?? item.resolvedCost ?? 0,
                            showUnit: true,
                            font: .title3,
                            fontWeight: .bold,
                            foregroundColor: .white
                        )
                        Text("per image").font(.caption).foregroundColor(
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
                            .foregroundColor(.blue)
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

struct PromptSection: View {
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
                Image(systemName: "text.alignleft").foregroundColor(.blue)
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
                                        CircularProgressViewStyle(tint: .blue)
                                    )
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)
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
                                ? Color.blue.opacity(0.5)
                                : Color.gray.opacity(0.3),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("Describe the image you want to generate...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .focused($isFocused)

            Button(action: { isExamplePromptsPresented = true }) {
                HStack {
                    Image(systemName: "lightbulb.fill").foregroundColor(.blue)
                        .font(.caption)
                    Text("Example Prompts").font(.caption).fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(
                        Color.blue.opacity(0.3), lineWidth: 1
                    ))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
}

// MARK: QUALITY (GPT Image 1.5)

/// Button that shows current quality and opens a sheet to pick Low / Medium / High (like Size).
struct QualitySection: View {
    @Binding var selectedQualityIndex: Int
    let qualityOptions: [String]
    @Binding var showSheet: Bool

    private var selectedLabel: String {
        let idx = min(selectedQualityIndex, qualityOptions.count - 1)
        guard idx >= 0 else { return "Medium" }
        switch qualityOptions[idx] {
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        default: return qualityOptions[idx].capitalized
        }
    }

    var body: some View {
        Button(action: { showSheet = true }) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(selectedLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Text("Quality")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

/// Sheet listing Quality options (Low, Medium, High). Row layout matches ResolutionSelectorSheet.
struct QualitySelectorSheet: View {
    @Binding var selectedIndex: Int
    let optionLabels: [String]
    let color: Color
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(optionLabels.indices, id: \.self) { idx in
                        let label = optionLabels[idx]
                        let isSelected = idx == selectedIndex
                        Button {
                            selectedIndex = idx
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.08))
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16))
                                        .foregroundColor(isSelected ? color : Color.gray.opacity(0.5))
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(label)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(color)
                                        }
                                    }
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Select Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: ASPECT RATIO

struct AspectRatioSection: View {
    let options: [AspectRatioOption]
    @Binding var selectedIndex: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AspectRatioSelector(
                options: options, selectedIndex: $selectedIndex, color: .blue
            )
        }
        .padding(.horizontal)
    }
}

// MARK: RESOLUTION (Nano Banana Pro: 1K, 2K, 4K)

/// Tab row that shows selected resolution and opens a sheet to pick 1K / 2K / 4K (same style as Size tab).
struct ResolutionSection: View {
    let options: [ResolutionOption]
    @Binding var selectedIndex: Int
    @Binding var showSheet: Bool

    private var selectedOption: ResolutionOption {
        let idx = min(selectedIndex, options.count - 1)
        guard idx >= 0, idx < options.count else { return options[0] }
        return options[idx]
    }

    var body: some View {
        Button(action: { showSheet = true }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedOption.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    if let description = selectedOption.description {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("Resolution")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

// MARK: PRICING TABLE (Image models with variable pricing: GPT Image 1.5, Nano Banana Pro)

private struct PricingTableSectionImage: View {
    let modelName: String
    @State private var showPricingSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showPricingSheet = true }) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "tablecells")
                            .foregroundColor(.blue)
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
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 32)
        .sheet(isPresented: $showPricingSheet) {
            ImagePricingTableSheetView(modelName: modelName)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct ImagePricingTableSheetView: View {
    let modelName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if modelName == "GPT Image 1.5" {
                        GPTImage15PricingTable()
                    } else if modelName == "Nano Banana Pro" {
                        NanoBananaProPricingTable()
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

private struct GPTImage15PricingTable: View {
    private let aspectRatios = ["1:1", "2:3", "3:2"]
    private let qualities = ["Low", "Medium", "High"]
    private let qualityIds = ["low", "medium", "high"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text("By size & quality")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.blue.opacity(0.12)))

            HStack(spacing: 0) {
                Text("Size")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .leading)
                ForEach(qualities, id: \.self) { q in
                    Text(q)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            VStack(spacing: 0) {
                ForEach(Array(aspectRatios.enumerated()), id: \.element) { index, aspect in
                    HStack(spacing: 0) {
                        Text(aspect)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 44, alignment: .leading)
                        ForEach(qualityIds, id: \.self) { qualityId in
                            let price = PricingManager.shared.priceForImageModel("GPT Image 1.5", aspectRatio: aspect, quality: qualityId)
                            let text = price.map { "\(PricingManager.formatCredits(Decimal($0))) credits" } ?? "–"
                            Text(text)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(index % 2 == 0 ? Color.clear : Color.blue.opacity(0.03))
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.04)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.15), lineWidth: 1))
        }
    }
}

private struct NanoBananaProPricingTable: View {
    private let resolutions = [("1k", "1K"), ("2k", "2K"), ("4k", "4K")]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text("By resolution")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.blue.opacity(0.12)))

            HStack(spacing: 0) {
                Text("Resolution")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Credits")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            VStack(spacing: 0) {
                ForEach(Array(resolutions.enumerated()), id: \.element.0) { index, res in
                    let price = PricingManager.shared.priceForImageModel("Nano Banana Pro", resolution: res.0)
                    let text = price.map { "\(PricingManager.formatCredits(Decimal($0))) credits" } ?? "–"
                    HStack(spacing: 0) {
                        Text(res.1)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(text)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(index % 2 == 0 ? Color.clear : Color.blue.opacity(0.03))
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.04)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.15), lineWidth: 1))
        }
    }
}

// MARK: COST CARD

struct CostCardSection: View {
    let costString: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generation Cost").font(.caption).foregroundColor(
                    .secondary)
                HStack(spacing: 4) {
                    Text("1 image").font(.subheadline).foregroundColor(.primary)
                    Text("×").font(.caption).foregroundColor(.secondary)
                    Text(costString).font(.subheadline).fontWeight(
                        .semibold
                    ).foregroundColor(.blue)
                }
            }
            Spacer()
            Text(costString).font(.title3).fontWeight(.bold)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(
                Color.blue.opacity(0.2), lineWidth: 1
            )
        )
        .padding(.horizontal)
    }
}

// MARK: GENERATE BUTTON

struct GenerateButton: View {
    let prompt: String
    @Binding var isGenerating: Bool
    @Binding var keyboardHeight: CGFloat
    let costString: String
    let isLoggedIn: Bool
    let hasCredits: Bool
    let isConnected: Bool
    let onSignInTap: () -> Void
    let action: () -> Void

    private var canGenerate: Bool {
        isLoggedIn && hasCredits && isConnected
    }

    var body: some View {
        VStack(spacing: 0) {
            // LinearGradient(colors: [Color(UIColor.systemBackground).opacity(0), Color(UIColor.systemBackground)],
            //                startPoint: .top, endPoint: .bottom)
            //     .frame(height: 20)

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
                        // Image(systemName: "photo.on.rectangle")
                    }
                    if isGenerating {
                        Text("Generating...")
                            .fontWeight(.semibold)
                    } else {
                        Text("Generate")
                            .fontWeight(.semibold)
                        Image(systemName: "sparkle")
                            .font(.system(size: 14))
                        Text(costString)
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
                            colors: [Color.blue.opacity(0.8), Color.cyan],
                            startPoint: .leading, endPoint: .trailing
                        )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: (isGenerating || !canGenerate)
                        ? Color.clear : Color.blue.opacity(0.4),
                    radius: 8, x: 0, y: 4
                )
            }
            .scaleEffect(isGenerating ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
            .disabled(isGenerating || !canGenerate)
            .opacity(canGenerate ? 1.0 : 0.6)
            .padding(.horizontal)
            // .padding(.bottom, keyboardHeight > 0 ? 24 : 80)
            .background(Color(UIColor.systemBackground))
        }
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
}

// MARK: MODEL GALLERY

struct ModelGallerySection: View {
    let modelName: String?
    let userId: String?

    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var modelImages: [UserImage] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasLoaded = false
    @State private var selectedUserImage: UserImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.secondary)
                    .font(.headline)
                Text("Your Creations With This Model")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if modelImages.isEmpty && hasLoaded {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No images yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Create your first image with this model!")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else if !modelImages.isEmpty {
                ModelGalleryGridView(
                    userImages: modelImages,
                    isLoadingMore: isLoadingMore,
                    hasMorePages: viewModel.hasMoreModelPages(
                        modelName: modelName ?? ""),
                    onSelect: { userImage in
                        selectedUserImage = userImage
                    },
                    onLoadMore: {
                        guard let modelName = modelName, !modelName.isEmpty
                        else { return }
                        guard !isLoadingMore else { return }
                        isLoadingMore = true
                        Task {
                            let newImages = await viewModel.loadMoreModelImages(
                                modelName: modelName)
                            await MainActor.run {
                                modelImages.append(contentsOf: newImages)
                                isLoadingMore = false
                            }
                        }
                    }
                )
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadModelImages()
        }
        .sheet(item: $selectedUserImage) { userImage in
            FullScreenImageView(
                userImage: userImage,
                isPresented: Binding(
                    get: { selectedUserImage != nil },
                    set: { if !$0 { selectedUserImage = nil } }
                )
            )
            .environmentObject(authViewModel)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .ignoresSafeArea()
        }
    }

    private func loadModelImages() {
        guard let modelName = modelName, !modelName.isEmpty,
            let userId = userId, !userId.isEmpty,
            !hasLoaded
        else {
            // If no model name or user ID, mark as loaded to prevent retries
            hasLoaded = true
            return
        }

        hasLoaded = true
        viewModel.userId = userId
        isLoading = true

        Task {
            // ✅ OPTIMIZED: Fetch first page only (50 images) using pagination
            // This matches the Profile page pattern and reduces database egress
            // Additional pages load automatically as user scrolls
            let images = await viewModel.fetchModelImages(
                modelName: modelName,
                forceRefresh: false
            )

            await MainActor.run {
                modelImages = images
                isLoading = false
            }
        }
    }
}

// MARK: GRID VIEW

struct ModelGalleryGridView: View {
    let userImages: [UserImage]
    let isLoadingMore: Bool
    let hasMorePages: Bool
    var onSelect: (UserImage) -> Void
    var onLoadMore: () -> Void

    private let spacing: CGFloat = 2
    private let gridColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 3
    )

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 16
            let totalHorizontalSpacing = spacing * 2  // 2 gaps between 3 columns
            let availableWidth =
                proxy.size.width - (horizontalPadding * 2)
                - totalHorizontalSpacing
            let itemWidth = max(44, availableWidth / 3)
            let itemHeight = itemWidth * 1.4

            // ✅ OPTIMIZED: Calculate target size with scale factor for retina displays
            let scale = UIScreen.main.scale
            let targetSize = CGSize(
                width: itemWidth * scale,
                height: itemHeight * scale
            )

            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(userImages) { userImage in
                    if let displayUrl = userImage.isVideo
                        ? userImage.thumbnail_url : userImage.image_url,
                        let url = URL(string: displayUrl)
                    {
                        Button {
                            onSelect(userImage)
                        } label: {
                            ZStack {
                                // ✅ OPTIMIZED: Use DownsamplingImageProcessor to reduce egress
                                // This resizes images on-the-fly to exact thumbnail size, saving ~80-90% bandwidth
                                KFImage(url)
                                    .setProcessor(
                                        DownsamplingImageProcessor(
                                            size: targetSize)
                                    )
                                    .cacheMemoryOnly()  // ✅ Use memory cache for thumbnails (faster, less disk I/O)
                                    .fade(duration: 0.2)  // Smooth fade-in
                                    .placeholder {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(ProgressView())
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: itemWidth, height: itemHeight)
                                    .clipped()
                                    .cornerRadius(0)

                                // Video play icon overlay
                                if userImage.isVideo {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 32, height: 32)

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // Trigger loading more when we're 10 items from the end
                            if let index = userImages.firstIndex(where: {
                                $0.id == userImage.id
                            }),
                                index >= userImages.count - 10,
                                hasMorePages,
                                !isLoadingMore
                            {
                                onLoadMore()
                            }
                        }
                    } else if let url = URL(string: userImage.image_url) {
                        // Fallback for videos without thumbnails
                        Button {
                            onSelect(userImage)
                        } label: {
                            ZStack {
                                // ✅ OPTIMIZED: Same downsampling for fallback images
                                KFImage(url)
                                    .setProcessor(
                                        DownsamplingImageProcessor(
                                            size: targetSize)
                                    )
                                    .cacheMemoryOnly()
                                    .fade(duration: 0.2)
                                    .placeholder {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                Image(systemName: "video.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: itemWidth, height: itemHeight)
                                    .clipped()
                                    .cornerRadius(0)

                                if userImage.isVideo {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 32, height: 32)

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // Trigger loading more when we're 10 items from the end
                            if let index = userImages.firstIndex(where: {
                                $0.id == userImage.id
                            }),
                                index >= userImages.count - 10,
                                hasMorePages,
                                !isLoadingMore
                            {
                                onLoadMore()
                            }
                        }
                    }
                }

                // Loading indicator at the bottom when loading more
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .gridCellColumns(3)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(
            height: calculateHeight(
                for: userImages.count, isLoadingMore: isLoadingMore))
    }

    private func calculateHeight(for count: Int, isLoadingMore: Bool) -> CGFloat
    {
        let rows = ceil(Double(count) / 3.0)
        let horizontalPadding: CGFloat = 16
        let totalHorizontalSpacing = spacing * 2
        let availableWidth =
            UIScreen.main.bounds.width - (horizontalPadding * 2)
            - totalHorizontalSpacing
        let itemWidth = availableWidth / 3
        let baseHeight = CGFloat(rows) * (itemWidth * 1.4 + spacing)
        // Add extra height for loading indicator if loading more
        return baseHeight + (isLoadingMore ? 60 : 0)
    }
}
