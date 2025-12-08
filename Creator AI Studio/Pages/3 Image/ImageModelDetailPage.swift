//
//  ImageModelDetailPage.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/25/25.
//

import Kingfisher
import PhotosUI
import SwiftUI

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) { self.build = build }
    var body: some View { build() }
}

struct ImageModelDetailPage: View {
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

    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: Constants

    private let imageAspectOptions: [AspectRatioOption] = [
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
        NSDecimalNumber(decimal: item.cost ?? 0).stringValue
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
                            BannerSection(item: item, costString: costString))

                        Divider().padding(.horizontal)

                        //                        LazyView(TabSwitcher(selectedMode: $selectedGenerationMode))

                        LazyView(
                            PromptSection(
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

                        if item.capabilities?.contains("Image to Image") == true {
                            LazyView(
                                ReferenceImagesSection(
                                    referenceImages: $referenceImages,
                                    selectedPhotoItems: $selectedPhotoItems,
                                    showCameraSheet: $showCameraSheet,
                                    color: .blue
                                ))
                        }

                        if isMidjourney {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(
                                    "Midjourney creates 4 images by default: Total cost: $0.10"
                                )
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
                                action: generate
                            ))

                        Divider().padding(.horizontal)

                        //                        VStack {
                        //                            Button {
                        //                                //                            showActionSheet = true
                        //                            } label: {
                        //                                HStack(spacing: 8) {
                        //                                    Image(systemName: "camera")
                        //                                        .font(.system(size: 14))
                        //                                        .foregroundColor(.blue)
                        //                                    Text("Add Image")
                        //                                        .font(.subheadline)
                        //                                        .fontWeight(.semibold)
                        //                                        .foregroundColor(.secondary)
                        //                                    Text("(Optional)")
                        //                                        .font(.caption)
                        //                                        .foregroundColor(
                        //                                            .secondary.opacity(0.7))
                        //                                    Spacer()
                        //                                    //                                Image(systemName: "chevron.right")
                        //                                    //                                    .font(.system(size: 12))
                        //                                    //                                    .foregroundColor(.secondary.opacity(0.6))
                        //                                }
                        //                                //                                .padding(.horizontal, 12)
                        //                                //                                .padding(.vertical, 10)
                        //                                .padding()
                        //                                .background(Color.gray.opacity(0.06))
                        //                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        //                                .overlay(
                        //                                    RoundedRectangle(cornerRadius: 8)
                        //                                        //                                         .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        //                                        .strokeBorder(
                        //                                            style: StrokeStyle(
                        //                                                lineWidth: 3.5, dash: [6, 4]
                        //                                            )
                        //                                        )
                        //                                        .foregroundColor(.gray.opacity(0.4))
                        //                                )
                        //                            }
                        //                            .buttonStyle(PlainButtonStyle())
                        //                            .padding(.horizontal)
                        //                            //                        .confirmationDialog("Add Image", isPresented: $showActionSheet, titleVisibility: .visible) {
                        //                            //                            Button {
                        //                            //                                showCameraSheet = true
                        //                            //                            } label: {
                        //                            //                                Label("Take Photo", systemImage: "camera.fill")
                        //                            //                            }
                        //                            //
                        //                            //                            Button {
                        //                            //                                showPhotosPicker = true
                        //                            //                            } label: {
                        //                            //                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                        //                            //                            }
                        //                            //
                        //                            //                            Button("Cancel", role: .cancel) {}
                        //                            //                        }
                        //                            //                        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images)
                        //
                        //                            // Text("Upload an image to transform it, or use as reference with your prompt")
                        //                            //     .font(.caption)
                        //                            //     .foregroundColor(.secondary.opacity(0.8))
                        //                            //     .fixedSize(horizontal: false, vertical: true)
                        //                            //     .padding(.bottom, 4)
                        //                        }

                        LazyView(
                            AspectRatioSection(
                                options: imageAspectOptions,
                                selectedIndex: $selectedAspectIndex
                            ))

                        Divider().padding(.horizontal)

                        // LazyView(CostCardSection(costString: costString))

                        // Example Gallery Section - Only show if model name exists
                        if let modelName = item.display.modelName, !modelName.isEmpty {
                            LazyView(
                                ModelGallerySection(
                                    modelName: modelName,
                                    userId: authViewModel.user?.id.uuidString.lowercased()
                                )
                            )

                            Divider().padding(.horizontal)
                        }

                        Color.clear.frame(height: 130) // bottom padding for floating button
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
                CreditsView()
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
            Text("Please enter a prompt to generate an image.")
        }
        .sheet(isPresented: $showCameraSheet) {
            SimpleCameraPicker(isPresented: $showCameraSheet) { capturedImage in
                referenceImages.append(capturedImage)
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
    }

    // MARK: FUNCTION GENERATE

    private func generate() {
        guard !prompt.isEmpty else {
            showEmptyPromptAlert = true
            return
        }
        guard !isGenerating else { return }

        isGenerating = true
        let selectedAspectOption = imageAspectOptions[selectedAspectIndex]
        var modifiedItem = item
        modifiedItem.prompt = prompt
        modifiedItem.apiConfig.aspectRatio = selectedAspectOption.id

        let imageToUse = referenceImages.first ?? createPlaceholderImage()
        guard let userId = authViewModel.user?.id.uuidString.lowercased(),
              !userId.isEmpty
        else {
            isGenerating = false
            return
        }

        Task { @MainActor in
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
            let recognizedText = await TextRecognitionService.recognizeText(from: image)

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
                ocrAlertMessage = "No text was found in the image. Please try again with a clearer image."
                showOCRAlert = true
            }
        }
    }
}

// MARK: BANNER SECTION

struct BannerSection: View {
    let item: InfoPacket
    let costString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                Image(item.display.modelImageName ?? "")
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
                        Image(systemName: "photo.on.rectangle.angled").font(
                            .caption)
                        Text("Image Generation Model").font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.blue.opacity(0.8)))

                    HStack(spacing: 4) {
                        Text("$\(costString)").font(.title3).fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("per image").font(.caption).foregroundColor(
                            .secondary)
                    }

                    if let capabilities = item.capabilities,
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
            if let description = item.display.modelDescription, !description.isEmpty {
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
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "viewfinder").foregroundColor(.blue)
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

// MARK: ASPECT RATIO

struct AspectRatioSection: View {
    let options: [AspectRatioOption]
    @Binding var selectedIndex: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            //            HStack(spacing: 6) {
            //                Image(systemName: "slider.horizontal.3").foregroundColor(.blue)
            Text("Size")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, -6)
            //            }
            AspectRatioSelector(
                options: options, selectedIndex: $selectedIndex, color: .blue
            )
        }
        .padding(.horizontal)
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
                    Text("$\(costString)").font(.subheadline).fontWeight(
                        .semibold
                    ).foregroundColor(.blue)
                }
            }
            Spacer()
            Text("$\(costString)").font(.title3).fontWeight(.bold)
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
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // LinearGradient(colors: [Color(UIColor.systemBackground).opacity(0), Color(UIColor.systemBackground)],
            //                startPoint: .top, endPoint: .bottom)
            //     .frame(height: 20)

            Button(action: action) {
                HStack {
                    if isGenerating {
                        ProgressView().progressViewStyle(
                            CircularProgressViewStyle(tint: .white)
                        ).scaleEffect(0.8)
                    } else {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Text(
                        isGenerating
                            ? "Generating..."
                            : "Generate Image - $\(costString)"
                    ).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isGenerating
                        ? LinearGradient(
                            colors: [Color.gray, Color.gray],
                            startPoint: .leading, endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.blue],
                            startPoint: .leading, endPoint: .trailing
                        )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: isGenerating ? Color.clear : Color.blue.opacity(0.4),
                    radius: 8, x: 0, y: 4
                )
            }
            .scaleEffect(isGenerating ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
            .disabled(isGenerating)
            .padding(.horizontal)
            // .padding(.bottom, keyboardHeight > 0 ? 24 : 80)
            .background(Color(UIColor.systemBackground))
        }
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
}

// MARK: CREDITS VIEW

struct CreditsView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "diamond.fill")
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan], startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .font(.system(size: 8))
            Text("$5.00").font(
                .system(size: 14, weight: .semibold, design: .rounded)
            ).foregroundColor(.primary)
            Text("credits left").font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(Color.blue.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20).strokeBorder(
                LinearGradient(
                    colors: [.blue, .cyan], startPoint: .leading,
                    endPoint: .trailing
                ), lineWidth: 1.5
            ))
    }
}

// MARK: MODEL GALLERY SECTION

struct ModelGallerySection: View {
    let modelName: String?
    let userId: String?

    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var modelImages: [UserImage] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var selectedUserImage: UserImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                    .font(.subheadline)
                Text("Your Creations")
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
                    onSelect: { userImage in
                        selectedUserImage = userImage
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
            let images = await viewModel.fetchModelImages(
                modelName: modelName,
                limit: 50,
                forceRefresh: false
            )

            await MainActor.run {
                modelImages = images
                isLoading = false
            }
        }
    }
}

// MARK: MODEL GALLERY GRID VIEW

struct ModelGalleryGridView: View {
    let userImages: [UserImage]
    var onSelect: (UserImage) -> Void

    private let spacing: CGFloat = 2
    private let gridColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 3
    )

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 16
            let totalHorizontalSpacing = spacing * 2  // 2 gaps between 3 columns
            let availableWidth = proxy.size.width - (horizontalPadding * 2) - totalHorizontalSpacing
            let itemWidth = max(44, availableWidth / 3)
            let itemHeight = itemWidth * 1.4

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
                                KFImage(url)
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
                    } else if let url = URL(string: userImage.image_url) {
                        // Fallback for videos without thumbnails
                        Button {
                            onSelect(userImage)
                        } label: {
                            ZStack {
                                KFImage(url)
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
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: calculateHeight(for: userImages.count))
    }

    private func calculateHeight(for count: Int) -> CGFloat {
        let rows = ceil(Double(count) / 3.0)
        let horizontalPadding: CGFloat = 16
        let totalHorizontalSpacing = spacing * 2
        let availableWidth = UIScreen.main.bounds.width - (horizontalPadding * 2) - totalHorizontalSpacing
        let itemWidth = availableWidth / 3
        return CGFloat(rows) * (itemWidth * 1.4 + spacing)
    }
}