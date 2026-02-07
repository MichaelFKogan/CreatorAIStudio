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
enum ImageTextInputMode: String, CaseIterable {
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
    @State private var showFullPromptSheet: Bool = false
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
                onExpandTap: { showFullPromptSheet = true },
                isProcessingOCR: $isProcessingOCR
            ))
    }

    @ViewBuilder private var scrollInputModeAndRefs: some View {
        if showsTextImageInputModePicker {
            InputModeCard(color: .blue) {
                ChipOptionPicker(
                    options: [
                        ("Text", "doc.text"),
                        ("Image", "photo")
                    ],
                    selection: Binding(
                        get: { ImageTextInputMode.allCases.firstIndex(of: imageTextInputMode) ?? 0 },
                        set: { idx in
                            if idx < ImageTextInputMode.allCases.count {
                                imageTextInputMode = ImageTextInputMode.allCases[idx]
                            }
                        }
                    ),
                    color: .blue
                )
            } description: {
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
            .sheet(isPresented: $showSignInSheet) {
                SignInView()
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
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
            .sheet(isPresented: $showFullPromptSheet) {
                FullPromptSheet(
                    prompt: $prompt,
                    isPresented: $showFullPromptSheet,
                    placeholder: "Describe the image you want to generate...",
                    accentColor: .blue
                )
                .presentationDragIndicator(.visible)
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
