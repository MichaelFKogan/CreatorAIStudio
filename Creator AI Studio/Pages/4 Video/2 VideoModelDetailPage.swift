//import PhotosUI
//import SwiftUI
//
//struct VideoModelDetailPage: View {
//    @State var item: InfoPacket
//
//    @State private var prompt: String = ""
//    @FocusState private var isPromptFocused: Bool
//    @State private var isExamplePromptsPresented: Bool = false
//    @State private var referenceImages: [UIImage] = []
//    @State private var selectedPhotoItems: [PhotosPickerItem] = []
//
//    @State private var selectedAspectIndex: Int = 0 // default to 1:1
//    private let imageAspects: [String] = ["1:1", "3:4", "4:3", "9:16", "16:9"]
//    private let imageAspectOptions: [AspectRatioOption] = [
//        AspectRatioOption(id: "3:4", label: "3:4", width: 3, height: 4, platforms: ["Portrait"]),
//        AspectRatioOption(id: "9:16", label: "9:16", width: 9, height: 16, platforms: ["TikTok", "Reels"]),
//        AspectRatioOption(id: "1:1", label: "1:1", width: 1, height: 1, platforms: ["Instagram"]),
//        AspectRatioOption(id: "4:3", label: "4:3", width: 4, height: 3, platforms: ["Photo Prints"]),
//        AspectRatioOption(id: "16:9", label: "16:9", width: 16, height: 9, platforms: ["YouTube"]),
//    ]
//
//    private let examplePrompts: [String] = [
//        "A serene landscape with mountains at sunset, photorealistic, 8k quality",
//        "A futuristic cityscape with flying cars and neon lights at night",
//        "A cute fluffy kitten playing with yarn, studio lighting, professional photography",
//        "An astronaut riding a horse on the moon, cinematic lighting, detailed",
//        "A cozy coffee shop interior with warm lighting and plants, architectural photography",
//        "A majestic dragon soaring through clouds, fantasy art, highly detailed",
//        "A vintage sports car on an empty road, golden hour lighting, 4k",
//        "A magical forest with glowing mushrooms and fireflies, fantasy illustration",
//        "A modern minimalist living room with large windows, interior design photography",
//        "A colorful abstract painting with geometric shapes and vibrant colors",
//        "A medieval castle on a cliff overlooking the ocean, dramatic lighting",
//        "A cyberpunk street market with holographic signs, neon colors, ultra detailed",
//        "A peaceful zen garden with cherry blossoms and koi pond, soft focus",
//        "A powerful lion portrait with intense eyes, wildlife photography, 8k",
//        "A steampunk airship in the clouds, brass and copper details, concept art",
//        "A tropical beach at sunrise with palm trees, paradise scenery, HDR",
//        "An enchanted library with floating books and magical lights, fantasy art",
//        "A modern luxury yacht on crystal clear water, professional photography",
//        "A mysterious alien landscape with purple sky and twin moons, sci-fi art",
//        "A rustic farmhouse in autumn with falling leaves, warm colors, cozy atmosphere",
//        "A sleek modern kitchen with marble countertops, architectural digest style",
//        "A samurai warrior in traditional armor, dramatic pose, cinematic composition",
//        "A vibrant coral reef with tropical fish, underwater photography, vivid colors",
//        "A gothic cathedral interior with stained glass windows, divine lighting",
//        "A bustling Tokyo street at night with neon signs, street photography",
//        "A serene mountain lake reflection at dawn, mirror-like water, pristine nature",
//        "A futuristic robot with intricate mechanical details, sci-fi concept art",
//        "A cozy reading nook by a window on a rainy day, warm lighting",
//        "A majestic phoenix rising from flames, mythical creature, vibrant colors",
//        "A Victorian mansion in foggy weather, gothic atmosphere, haunting beauty",
//    ]
//
//    var body: some View {
//        GeometryReader { geometry in
//            ScrollView {
//                VStack(spacing: 0) {
//                    // MARK: BANNER IMAGE SECTION
//
//                    // Banner Image at top - extends behind navigation bar
//                    ZStack(alignment: .bottom) {
//                        Image(item.display.modelImageName)
//                            .resizable()
//                            .aspectRatio(contentMode: .fill)
//                            .frame(height: geometry.size.height * 0.35)
//                            .clipped()
//
//                        // Only gradient behind the text section
//                        VStack {
//                            Spacer()
//
//                            VStack {
//                                HStack {
//                                    VStack(alignment: .leading, spacing: 6) {
//                                        Text(item.display.modelName)
//                                            .font(.title2)
//                                            .fontWeight(.bold)
//                                            .foregroundColor(.white)
//
//                                        HStack(spacing: 6) {
//                                            Image(
//                                                systemName:
//                                                "photo.on.rectangle.angled"
//                                            )
//                                            .font(.caption)
//                                            Text("Video Generation Model")
//                                                .font(.caption)
//                                        }
//                                        .foregroundColor(.white)
//                                        .padding(.horizontal, 10)
//                                        .padding(.vertical, 5)
//                                        .background(
//                                            Capsule()
//                                                .fill(Color.purple.opacity(0.8))
//                                        )
//                                    }
//
//                                    Spacer()
//
//                                    VStack(alignment: .trailing, spacing: 2) {
//                                        Text("$\(NSDecimalNumber(decimal: item.cost).stringValue)")
//                                            .font(.caption)
//                                            .foregroundColor(.white)
//                                            .padding(.horizontal, 8)
//                                            .padding(.vertical, 4)
//                                            .background(
//                                                Color.black.opacity(0.8)
//                                            )
//                                            .cornerRadius(6)
//
//                                        Text("per image")
//                                            .font(.caption2)
//                                            .foregroundColor(
//                                                .white.opacity(0.9))
//                                    }
//                                }
//                                .padding(.horizontal)
//                                .padding(.bottom, 8)
//
//                                // Model Details Card (without image now)
//                                VStack(alignment: .leading, spacing: 8) {
//                                    Text(item.display.modelDescription)
//                                        .font(.caption2)
//                                        .foregroundColor(.white.opacity(0.8))
//                                        .lineLimit(4)
//                                }
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                                .padding(.horizontal)
//                            }
//                            .padding(.top, 8)
//                            .padding(.bottom, 12)
//                            .background(
//                                LinearGradient(
//                                    colors: [
//                                        Color.black.opacity(0.6),
//                                        Color.black.opacity(0.05),
//                                    ],
//                                    startPoint: .bottom,
//                                    endPoint: .top
//                                )
//                            )
//                        }
//                    }
//                    .frame(height: geometry.size.height * 0.35)
//                    .clipShape(RoundedRectangle(cornerRadius: 12))
//                    .padding(.horizontal)
//                    .padding(.bottom, 16)
//
//                    VStack(spacing: 24) {
//                        // MARK: PROMPT BOX
//
//                        // Prompt
//                        VStack(alignment: .leading, spacing: 8) {
//                            HStack(spacing: 6) {
//                                Image(systemName: "text.alignleft")
//                                    .foregroundColor(.purple)
//                                Text("Prompt")
//                                    .font(.subheadline)
//                                    .fontWeight(.semibold)
//                                    .foregroundColor(.secondary)
//                            }
//
//                            TextEditor(text: $prompt)
//                                .font(.system(size: 15)).opacity(0.8)
//                                .frame(minHeight: 140)
//                                .padding(8)
//                                .background(Color.gray.opacity(0.1))
//                                .clipShape(RoundedRectangle(cornerRadius: 12))
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .stroke(
//                                            isPromptFocused
//                                                ? Color.purple.opacity(0.5)
//                                                : Color.gray.opacity(0.3),
//                                            lineWidth: isPromptFocused ? 2 : 1
//                                        )
//                                )
//                                .overlay(alignment: .topLeading) {
//                                    if prompt.isEmpty {
//                                        Text(
//                                            "Describe the image you want to generate..."
//                                        )
//                                        .font(.system(size: 14))
//                                        .foregroundColor(.gray.opacity(0.5))
//                                        .padding(.horizontal, 12)
//                                        .padding(.vertical, 16)
//                                        .allowsHitTesting(false)
//                                    }
//                                }
//                                .animation(
//                                    .easeInOut(duration: 0.2),
//                                    value: isPromptFocused
//                                )
//                                .focused($isPromptFocused)
//                                .accessibilityLabel("Image generation prompt")
//                                .accessibilityHint(
//                                    "Enter a description of the image you want to create"
//                                )
//
//                            // MARK: EX: PROMPTS
//
//                            // Example Prompts Button
//                            Button(action: {
//                                isExamplePromptsPresented = true
//                            }) {
//                                HStack(spacing: 6) {
//                                    Image(systemName: "lightbulb.fill")
//                                        .foregroundColor(.purple)
//                                        .font(.caption)
//                                    Text("Example Prompts")
//                                        .font(.caption)
//                                        .fontWeight(.semibold)
//                                        .foregroundColor(.secondary)
//
//                                    Spacer()
//
//                                    Image(systemName: "chevron.right")
//                                        .font(.caption)
//                                        .foregroundColor(.secondary)
//                                }
//                                .padding(.horizontal, 10)
//                                .padding(.vertical, 8)
//                                .background(Color.gray.opacity(0.06))
//                                .clipShape(RoundedRectangle(cornerRadius: 8))
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 8)
//                                        .stroke(
//                                            Color.purple.opacity(0.3), lineWidth: 1
//                                        )
//                                )
//                            }
//                            .buttonStyle(PlainButtonStyle())
//                        }
//                        .padding(.horizontal)
//
//                        // Reference Images (Optional) - multi-image picker and grid
//                        ReferenceImagesSection(referenceImages: $referenceImages, selectedPhotoItems: $selectedPhotoItems, color: .purple)
//                            .padding(.horizontal)
//
//                        // MARK: ASPECT RATIO
//
//                        // Core Image Options
//                        VStack(alignment: .leading, spacing: 12) {
//                            HStack(spacing: 6) {
//                                Image(systemName: "slider.horizontal.3")
//                                    .foregroundColor(.purple)
//                                Text("Aspect Ratio")
//                                    .font(.subheadline)
//                                    .fontWeight(.semibold)
//                                    .foregroundColor(.secondary)
//                            }
//
//                            VStack(alignment: .leading, spacing: 6) {
//                                //                                Text("Aspect Ratio")
//                                //                                    .font(.caption)
//                                //                                    .foregroundColor(.secondary)
//                                AspectRatioSelector(options: imageAspectOptions, selectedIndex: $selectedAspectIndex, color: .purple)
//                            }
//                        }
//                        .padding(.horizontal)
//
//                        // MARK: COST CARD
//
//                        HStack {
//                            VStack(alignment: .leading, spacing: 4) {
//                                Text("Generation Cost")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                                HStack(spacing: 4) {
//                                    Text("1 image")
//                                        .font(.subheadline)
//                                        .foregroundColor(.primary)
//                                    Text("×")
//                                        .font(.caption)
//                                        .foregroundColor(.secondary)
//                                    Text("$\(NSDecimalNumber(decimal: item.cost).stringValue)")
//                                        .font(.subheadline)
//                                        .fontWeight(.semibold)
//                                        .foregroundColor(.purple)
//                                }
//                            }
//
//                            Spacer()
//
//                            Text("$\(NSDecimalNumber(decimal: item.cost).stringValue)")
//                                .font(.title3)
//                                .fontWeight(.bold)
//                                .foregroundColor(.purple)
//                        }
//                        .padding()
//                        .background(Color.purple.opacity(0.08))
//                        .cornerRadius(12)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 12)
//                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
//                        )
//                        .padding(.horizontal)
//                    }
//                }
//            }
//            .scrollDismissesKeyboard(.interactively)
//        }
//        .contentShape(Rectangle())
//        .onTapGesture {
//            isPromptFocused = false
//        }
//        .sheet(isPresented: $isExamplePromptsPresented) {
//            ExamplePromptsSheet(
//                examplePrompts: examplePrompts,
//                selectedPrompt: $prompt,
//                isPresented: $isExamplePromptsPresented
//            )
//        }
//        .navigationTitle("")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbarBackground(Color.black, for: .navigationBar)
//        .toolbarBackground(.visible, for: .navigationBar)
//        .toolbar {
//            ToolbarItemGroup(placement: .keyboard) {
//                Spacer()
//                Button("Done") {
//                    isPromptFocused = false
//                }
//            }
//            ToolbarItem(placement: .navigationBarTrailing) {
//                HStack(spacing: 6) {
//                    Image(systemName: "diamond.fill")
//                        .foregroundStyle(
//                            LinearGradient(
//                                colors: [.purple, .purple],
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            )
//                        )
//                        .font(.system(size: 8))
//                    Text("$5.00")
//                        .font(.system(size: 14, weight: .semibold, design: .rounded))
//                        .foregroundColor(.white)
//                    Text("credits left")
//                        .font(.caption2)
//                        .foregroundColor(.white.opacity(0.9))
//                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 6)
//                .background(
//                    RoundedRectangle(cornerRadius: 20)
//                        .fill(Color.black.opacity(0.4))
//                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: 20)
//                        .strokeBorder(
//                            LinearGradient(
//                                colors: [.purple, .purple],
//                                startPoint: .leading,
//                                endPoint: .trailing
//                            ),
//                            lineWidth: 1.5
//                        )
//                )
//            }
//        }
//    }
//}
