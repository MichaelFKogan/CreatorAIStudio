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
    @State private var isTransformPromptsPresented: Bool = false
    @State private var referenceImages: [UIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    @State private var isGenerating: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showEmptyPromptAlert: Bool = false
    @State private var showCameraSheet: Bool = false
    
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
                        // Show captured image at top
                        CapturedImageSection(image: capturedImage)
                            .padding(.horizontal)
                            .padding(.top, 16)
                        
                        Divider().padding(.horizontal)
                        
                        LazyView(
                            BannerSection(item: item, costString: costString))
                        
                        Divider().padding(.horizontal)
                        
                        LazyView(
                            PromptSection(
                                prompt: $prompt,
                                isFocused: $isPromptFocused,
                                isExamplePromptsPresented:
                                $isExamplePromptsPresented,
                                examplePrompts: examplePrompts
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
                        
                        // ReferenceImagesSection with pre-populated image
                        LazyView(ReferenceImagesSectionWithPhoto(
                            referenceImages: $referenceImages,
                            selectedPhotoItems: $selectedPhotoItems,
                            showCameraSheet: $showCameraSheet,
                            color: .blue,
                            initialImage: capturedImage
                        ))
                        
                        // Example Image Prompts Button
                        Button(action: { isTransformPromptsPresented = true }) {
                            HStack {
                                Image(systemName: "lightbulb.fill").foregroundColor(.blue)
                                    .font(.caption)
                                Text("Example Image Prompts").font(.caption).fontWeight(.semibold)
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
                        .padding(.horizontal)
                        .padding(.top, -6)
                        .padding(.bottom, -12)
                        
                        Divider().padding(.horizontal)
                        
                        LazyView(
                            AspectRatioSection(
                                options: imageAspectOptions,
                                selectedIndex: $selectedAspectIndex
                            ))
                        
                        Divider().padding(.horizontal)
                        
                        LazyView(CostCardSection(costString: costString))
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
                selectedPrompt: $prompt,
                isPresented: $isExamplePromptsPresented,
                title: "Example Text Prompts"
            )
        }
        .sheet(isPresented: $isTransformPromptsPresented) {
            ExamplePromptsSheet(
                examplePrompts: transformPrompts,
                selectedPrompt: $prompt,
                isPresented: $isTransformPromptsPresented,
                title: "Example Image Prompts"
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
            CameraSheetView { capturedImage in
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
}

// MARK: - Captured Image Section

struct CapturedImageSection: View {
    let image: UIImage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .foregroundColor(.blue)
                Text("Your Photo")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )
        }
    }
}

// MARK: - Reference Images Section With Photo

struct ReferenceImagesSectionWithPhoto: View {
    @Binding var referenceImages: [UIImage]
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var showCameraSheet: Bool
    let color: Color
    let initialImage: UIImage
    
    @State private var showActionSheet: Bool = false
    @State private var showPhotosPicker: Bool = false
    
    private let columns: [GridItem] = Array(
        repeating: GridItem(.fixed(100), spacing: 12), count: 3)
    
    var body: some View {
        let gridWidth =
            CGFloat(columns.count) * 100 + CGFloat(columns.count - 1) * 12
        
        VStack {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(color)
                    Text("Image(s) (Optional)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Take Photo tile
                    Button {
                        showCameraSheet = true
                    } label: {
                        Image(systemName: "camera")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                }
                
                HStack {
                    Text(
                        "Your captured photo is included. You can add more images or use as reference with your prompt"
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
                    LazyVGrid(columns: columns, spacing: 12) {
                        // Take Photo tile
                        Button {
                            showCameraSheet = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray.opacity(0.5))
                                VStack(spacing: 4) {
                                    Text("Take Photo")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.gray)
                                    Text("Camera")
                                        .font(.caption2)
                                        .foregroundColor(.gray.opacity(0.7))
                                }
                            }
                            .frame(width: 100, height: 100)
                            .background(Color.gray.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        style: StrokeStyle(
                                            lineWidth: 3.5, dash: [6, 4])
                                    )
                                    .foregroundColor(.gray.opacity(0.4))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Add images tile
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray.opacity(0.5))
                                VStack(spacing: 4) {
                                    Text("Add Images")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.gray)
                                    Text("Up to 10")
                                        .font(.caption2)
                                        .foregroundColor(.gray.opacity(0.7))
                                }
                            }
                            .frame(width: 100, height: 100)
                            .background(Color.gray.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        style: StrokeStyle(
                                            lineWidth: 3.5, dash: [6, 4])
                                    )
                                    .foregroundColor(.gray.opacity(0.4))
                            )
                        }
                        .onChange(of: selectedPhotoItems) { newItems in
                            Task {
                                var newlyAdded: [UIImage] = []
                                for item in newItems {
                                    if let data =
                                        try? await item.loadTransferable(
                                            type: Data.self),
                                        let image = UIImage(data: data)
                                    {
                                        newlyAdded.append(image)
                                    }
                                }
                                referenceImages.append(contentsOf: newlyAdded)
                                selectedPhotoItems.removeAll()
                            }
                        }
                        
                        // Existing selected reference images
                        ForEach(referenceImages.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: referenceImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 12)
                                    )
                                    .clipped()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                color.opacity(0.6), lineWidth: 1
                                            )
                                    )
                                
                                Button(action: {
                                    referenceImages.remove(at: index)
                                }
                                ) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.red))
                                }
                                .padding(6)
                            }
                        }
                    }
                    .frame(width: gridWidth, alignment: .leading)
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
        }
    }
}

