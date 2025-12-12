//
//  ImageModelDetailPageWithPhoto.swift
//  Creator AI Studio
//
//  Created for Post page integration
//

import PhotosUI
import SwiftUI

// MARK: - Image Model Detail Page With Pre-Captured Photo

struct ImageModelDetailPageWithPhoto: View {
    @State var item: InfoPacket
    let capturedImage: UIImage

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

    // MARK: BODY

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {
                        LazyView(
                            BannerSection(item: item, costString: costString))

                        Divider().padding(.horizontal)

                        //                        // Show captured image at top
                        //                        CapturedImageSection(image: capturedImage)
                        //                            .padding(.horizontal)

                        // ReferenceImagesSection with pre-populated image
                        if item.capabilities?.contains("Image to Image") == true {
                            LazyView(
                                ReferenceImagesSectionWithPhoto(
                                    image: capturedImage,
                                    referenceImages: $referenceImages,
                                    selectedPhotoItems: $selectedPhotoItems,
                                    showCameraSheet: $showCameraSheet,
                                    color: .blue,
                                    initialImage: capturedImage
                                ))
                        }

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

                        LazyView(
                            GenerateButton(
                                prompt: prompt,
                                isGenerating: $isGenerating,
                                keyboardHeight: $keyboardHeight,
                                costString: costString,
                                action: generate
                            ))

                        Divider().padding(.horizontal)

                        LazyView(
                            AspectRatioSection(
                                options: imageAspectOptions,
                                selectedIndex: $selectedAspectIndex
                            ))

                        Divider().padding(.horizontal)

                        // LazyView(CostCardSection(costString: costString))

                        Color.clear.frame(height: 130) // bottom padding for floating button
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isPromptFocused = false }
        .onAppear {
            // Pre-populate reference images with captured image
            if referenceImages.isEmpty {
                referenceImages = [capturedImage]
            }
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
        // Use resolvedAPIConfig as base, then modify aspectRatio
        var config = modifiedItem.resolvedAPIConfig
        config.aspectRatio = selectedAspectOption.id
        modifiedItem.apiConfig = config

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

// MARK: CAPTURED IMAGE SECTION

struct CapturedImageSection: View {
    let image: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "camera")
                    .foregroundColor(.blue)
                Text("Your Photo")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack {
                Text(
                    "You can add more images or use as reference with your prompt"
                )
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.bottom, 8)

                Spacer()
            }

            HStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 115, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                    )
            }
        }
    }
}

// MARK: - Reference Images Section With Photo

struct ReferenceImagesSectionWithPhoto: View {
    let image: UIImage
    @Binding var referenceImages: [UIImage]
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var showCameraSheet: Bool
    let color: Color
    let initialImage: UIImage

    @State private var showActionSheet: Bool = false

    private let columns: [GridItem] = Array(
        repeating: GridItem(.fixed(115), spacing: 12), count: 3
    )

    var body: some View {
        let gridWidth =
            CGFloat(columns.count) * 115 + CGFloat(columns.count - 1) * 12

        VStack {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(color)
                    Text("Your Photo")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()
                }

                HStack {
                    Text(
                        "Add a prompt to transform your photo."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.bottom, 8)

                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.top, -4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if referenceImages.isEmpty {
                        // // Full-width button when no images
                        // Button {
                        //     showActionSheet = true
                        // } label: {
                        //     VStack(spacing: 8) {
                        //         Image(systemName: "camera")
                        //             .font(.system(size: 26))
                        //             .foregroundColor(.gray.opacity(0.6))
                        //         Text("Add Images")
                        //             .font(.subheadline)
                        //             .fontWeight(.medium)
                        //             .foregroundColor(.gray)
                        //         Text("Camera or Gallery")
                        //             .font(.caption)
                        //             .foregroundColor(.gray.opacity(0.7))
                        //     }
                        //     .frame(maxWidth: .infinity)
                        //     .frame(height: 160)
                        //     .background(Color.gray.opacity(0.03))
                        //     .clipShape(RoundedRectangle(cornerRadius: 6))
                        //     .overlay(
                        //         RoundedRectangle(cornerRadius: 6)
                        //             .strokeBorder(
                        //                 style: StrokeStyle(
                        //                     lineWidth: 3.5, dash: [6, 4]
                        //                 )
                        //             )
                        //             .foregroundColor(.gray.opacity(0.4))
                        //     )
                        // }
                        // .buttonStyle(PlainButtonStyle())
                    } else {
                        // Grid layout when images exist
                        LazyVGrid(columns: columns, spacing: 12) {
                            // Existing selected reference images
                            ForEach(referenceImages.indices, id: \.self) {
                                index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: referenceImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 115, height: 160)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 6)
                                        )
                                        .clipped()
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(
                                                    color.opacity(0.6),
                                                    lineWidth: 1
                                                )
                                        )

                                    Button(action: {
                                        referenceImages.remove(at: index)
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 20, height: 20)

                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(4)
                                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                                }
                            }

                            // // Grid-sized add button
                            // Button {
                            //     showActionSheet = true
                            // } label: {
                            //     VStack(spacing: 8) {
                            //         Image(systemName: "camera")
                            //             .font(.system(size: 26))
                            //             .foregroundColor(.gray.opacity(0.6))
                            //         Text("Add Images")
                            //             .font(.subheadline)
                            //             .fontWeight(.medium)
                            //             .foregroundColor(.gray)
                            //         Text("Camera or Gallery")
                            //             .font(.caption)
                            //             .foregroundColor(.gray.opacity(0.7))
                            //     }
                            //     .frame(width: 115, height: 160)
                            //     .background(Color.gray.opacity(0.03))
                            //     .clipShape(RoundedRectangle(cornerRadius: 6))
                            //     .overlay(
                            //         RoundedRectangle(cornerRadius: 6)
                            //             .strokeBorder(
                            //                 style: StrokeStyle(
                            //                     lineWidth: 3.5, dash: [6, 4]
                            //                 )
                            //             )
                            //             .foregroundColor(.gray.opacity(0.4))
                            //     )
                            // }
                            // .buttonStyle(PlainButtonStyle())
                        }
                        .frame(width: gridWidth, alignment: .leading)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showActionSheet) {
            ImageSourceSelectionSheet(
                showCameraSheet: $showCameraSheet,
                selectedPhotoItems: $selectedPhotoItems,
                showActionSheet: $showActionSheet,
                referenceImages: $referenceImages
            )
        }
    }
}
