//
//  ImageModelDetailPage.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/25/25.
//

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

    @State private var selectedAspectIndex: Int = 0
    @State private var selectedGenerationMode: Int = 0

    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: Constants

    private let imageAspectOptions: [AspectRatioOption] = [
        AspectRatioOption(id: "3:4", label: "3:4", width: 3, height: 4, platforms: ["Portrait"]),
        AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
        AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
        AspectRatioOption(id: "4:3", label: "4:3", width: 4, height: 3, platforms: ["Photo Prints"]),
        AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
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

    private var costString: String { NSDecimalNumber(decimal: item.cost).stringValue }

    // MARK: BODY

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {
                        LazyView(BannerSection(item: item, costString: costString))
                        LazyView(TabSwitcher(selectedMode: $selectedGenerationMode))

                        // Show ReferenceImagesSection only when "Image to Image" tab is selected
                        if selectedGenerationMode == 1 {
                            LazyView(ReferenceImagesSection(
                                referenceImages: $referenceImages,
                                selectedPhotoItems: $selectedPhotoItems,
                                color: .blue
                            ))
                        }

                        LazyView(PromptSection(
                            prompt: $prompt,
                            isFocused: $isPromptFocused,
                            isExamplePromptsPresented: $isExamplePromptsPresented,
                            examplePrompts: examplePrompts
                        ))
                        LazyView(AspectRatioSection(
                            options: imageAspectOptions,
                            selectedIndex: $selectedAspectIndex
                        ))
                        LazyView(CostCardSection(costString: costString))
                        Color.clear.frame(height: 130) // bottom padding for floating button
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                LazyView(GenerateButton(
                    prompt: prompt,
                    isGenerating: $isGenerating,
                    keyboardHeight: $keyboardHeight,
                    costString: costString,
                    action: generate
                ))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isPromptFocused = false }
        .sheet(isPresented: $isExamplePromptsPresented) {
            ExamplePromptsSheet(
                examplePrompts: examplePrompts,
                selectedPrompt: $prompt,
                isPresented: $isExamplePromptsPresented
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isPromptFocused = false }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                CreditsView()
            }
        }
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
    }

    // MARK: FUNC GENERATE

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
        guard let userId = authViewModel.user?.id.uuidString.lowercased(), !userId.isEmpty else {
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
                    print("Image generation failed: \(error.localizedDescription)")
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

// MARK: BANNER SECTION

struct BannerSection: View {
    let item: InfoPacket
    let costString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 16) {
                Image(item.display.modelImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.display.modelName)
                        .font(.title2).fontWeight(.bold).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled").font(.caption)
                        Text("Image Generation Model").font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.blue.opacity(0.8)))

                    HStack(spacing: 4) {
                        Text("$\(costString)").font(.title3).fontWeight(.bold).foregroundColor(.white)
                        Text("per image").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
}

// MARK: TAB SWITCHER

struct TabSwitcher: View {
    @Binding var selectedMode: Int

    var body: some View {
        HStack(spacing: 0) {
            // Text to Image button with icon
            Button(action: { selectedMode = 0 }) {
                HStack(spacing: 6) {
                    Image(systemName: "character.textbox")
                        .font(.system(size: 10))
                    Text("Text to Image")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .tabButtonStyle(isSelected: selectedMode == 0)

            // Image to Image button with icon
            Button(action: { selectedMode = 1 }) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 10))
                    Text("Image to Image")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .tabButtonStyle(isSelected: selectedMode == 1)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        .padding(.horizontal)
    }
}

extension View {
    func tabButtonStyle(isSelected: Bool) -> some View {
        font(.caption).fontWeight(.medium)
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.gray.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: PROMPT SECTION

struct PromptSection: View {
    @Binding var prompt: String
    @FocusState.Binding var isFocused: Bool
    @Binding var isExamplePromptsPresented: Bool
    let examplePrompts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft").foregroundColor(.blue)
                Text("Prompt").font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
            }
            TextEditor(text: $prompt)
                .font(.system(size: 15, weight: .semibold))
                .opacity(0.9)
                .frame(minHeight: 140)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3),
                                lineWidth: isFocused ? 2 : 1)
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
                    Image(systemName: "lightbulb.fill").foregroundColor(.blue).font(.caption)
                    Text("Example Prompts").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.3), lineWidth: 1))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3").foregroundColor(.blue)
                Text("Aspect Ratio").font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
            }
            AspectRatioSelector(options: options, selectedIndex: $selectedIndex, color: .blue)
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
                Text("Generation Cost").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Text("1 image").font(.subheadline).foregroundColor(.primary)
                    Text("×").font(.caption).foregroundColor(.secondary)
                    Text("$\(costString)").font(.subheadline).fontWeight(.semibold).foregroundColor(.blue)
                }
            }
            Spacer()
            Text("$\(costString)").font(.title3).fontWeight(.bold).foregroundColor(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
    }
}

// MARK: STRUCT GENERATE BUTTON

struct GenerateButton: View {
    let prompt: String
    @Binding var isGenerating: Bool
    @Binding var keyboardHeight: CGFloat
    let costString: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(UIColor.systemBackground).opacity(0), Color(UIColor.systemBackground)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 20)

            Button(action: action) {
                HStack {
                    if isGenerating {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                    } else {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Text(isGenerating ? "Generating..." : "Generate Image - $\(costString)").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isGenerating
                        ? LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.blue.opacity(0.8), Color.blue], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: isGenerating ? Color.clear : Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(isGenerating ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
            .disabled(isGenerating)
            .padding(.horizontal)
            .padding(.bottom, keyboardHeight > 0 ? 24 : 80)
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
                .foregroundStyle(LinearGradient(colors: [.blue, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .font(.system(size: 8))
            Text("$5.00").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
            Text("credits left").font(.caption2).foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.4)).shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient(colors: [.blue, .blue], startPoint: .leading, endPoint: .trailing), lineWidth: 1.5))
    }
}
