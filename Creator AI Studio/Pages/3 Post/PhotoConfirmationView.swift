import Kingfisher
import SwiftUI

struct PhotoConfirmationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationManager: NotificationManager

    let item: InfoPacket
    let images: [UIImage]
    let additionalFilters: [InfoPacket]? // Additional filters for multi-select

    @State private var shimmer: Bool = false
    @State private var sparklePulse: Bool = false
    @State private var generatePulse: Bool = false

    @State private var rotation: Double = 0
    @State private var isAnimating = false

    @State private var generatedImage: UIImage? = nil
    @State private var isLoading = false

    @State private var arrowWiggle: Bool = false
    @State private var currentTaskIds: [UUID] = []
    @State private var selectedAspectIndex: Int = 0
    @State private var sizeButtonTapped: Bool = false
    
    // Primary initializer for multiple images
    init(item: InfoPacket, images: [UIImage], additionalFilters: [InfoPacket]? = nil) {
        self.item = item
        self.images = images
        self.additionalFilters = additionalFilters
    }
    
    // Convenience initializer for single image (backward compatibility)
    init(item: InfoPacket, image: UIImage, additionalFilters: [InfoPacket]? = nil) {
        self.item = item
        self.images = [image]
        self.additionalFilters = additionalFilters
    }
    
    // Computed property for first image (for UI display)
    private var firstImage: UIImage {
        images.first ?? UIImage()
    }
    
    // Computed property for generate button text
    private var generateButtonText: String {
        let totalFilters = 1 + (additionalFilters?.count ?? 0)
        let totalGenerations = images.count * totalFilters
        if totalGenerations > 1 {
            return "Generating \(totalGenerations) images..."
        } else {
            return "Generating..."
        }
    }
    
    // Calculate total credits: sum of all filter costs × number of images
    // Each image gets generated with each filter
    private var totalCredits: Int {
        let itemCredits = item.resolvedCost?.credits ?? 0
        let additionalCredits = additionalFilters?.reduce(0) { total, filter in
            total + (filter.resolvedCost?.credits ?? 0)
        } ?? 0
        let totalFilterCost = itemCredits + additionalCredits
        // Each image will be generated with each filter
        return totalFilterCost * images.count
    }

    // MARK: - Aspect Ratio Options
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

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Animated Title

                ZStack {
                    Text(images.count > 1 ? "Confirm Your Photos" : "Confirm Your Photo")
                        .font(
                            .system(size: 28, weight: .bold, design: .rounded)
                        )
                        .foregroundColor(.primary)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.0),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .rotationEffect(.degrees(20))
                            .offset(x: shimmer ? 300 : -300)
                            .mask(
                                Text(images.count > 1 ? "Confirm Your Photos" : "Confirm Your Photo")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                            )
                        )
                        .onAppear {
                            withAnimation(
                                .linear(duration: 2.0).repeatForever(
                                    autoreverses: false)
                            ) {
                                shimmer.toggle()
                            }
                        }

                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow.opacity(0.9))
                        .offset(x: -80, y: -10)
                        .scaleEffect(sparklePulse ? 1.2 : 0.8)
                        .opacity(sparklePulse ? 1 : 0.7)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(
                                autoreverses: true), value: sparklePulse)

                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .offset(x: 80, y: -5)
                        .scaleEffect(sparklePulse ? 0.9 : 0.6)
                        .opacity(sparklePulse ? 0.95 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(
                                autoreverses: true
                            ).delay(0.3), value: sparklePulse)
                }
                .padding(.top, 20)
                .onAppear { sparklePulse = true }
        

                // MARK: - Main Photo

                // MARK: - Diagonal Overlapping Images

                GeometryReader { geometry in
                    let imageWidth = geometry.size.width * 0.48
                    let imageHeight = imageWidth * 1.38
                    let arrowYOffset = -imageHeight * 0.15

                    ZStack(alignment: .center) {
                        // Right image (example result) - drawn first so it's behind
                        // Check if imageName is a URL (for presets)
                        Group {
                            if item.display.imageName.hasPrefix("http://")
                                || item.display.imageName.hasPrefix("https://"),
                                let url = URL(string: item.display.imageName)
                            {
                                KFImage(url)
                                    .placeholder {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(ProgressView())
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(
                                        width: imageWidth, height: imageHeight
                                    )
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 16)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.white, .gray],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing),
                                                lineWidth: 2
                                            )
                                    )
                                    .shadow(
                                        color: Color.black.opacity(0.25),
                                        radius: 12, x: 4, y: 4)
                            } else {
                                Image(item.display.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(
                                        width: imageWidth, height: imageHeight
                                    )
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 16)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.white, .gray],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing),
                                                lineWidth: 2
                                            )
                                    )
                                    .shadow(
                                        color: Color.black.opacity(0.25),
                                        radius: 12, x: 4, y: 4)
                            }
                        }
                        .rotationEffect(.degrees(8))
                        .offset(x: imageWidth * 0.50)

                        // Left image (user's photo) - drawn second so it's on top
                        Image(uiImage: firstImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imageWidth, height: imageHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white, .gray],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(
                                color: Color.black.opacity(0.25), radius: 12,
                                x: -4, y: 4
                            )
                            .rotationEffect(.degrees(-6))
                            .offset(x: -imageWidth * 0.50)

                        // Arrow with gentle wiggle
                        Image("arrow")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 62, height: 62)
                            .rotationEffect(.degrees(arrowWiggle ? 6 : -6))
                            .animation(
                                .easeInOut(duration: 0.6).repeatForever(
                                    autoreverses: true), value: arrowWiggle
                            )
                            .offset(x: 0, y: arrowYOffset)
                    }
                    .onAppear {
                        arrowWiggle = true
                    }
                    .frame(width: geometry.size.width, height: imageHeight + 20)
                }
                .frame(height: 260)
                .padding(.horizontal, 20)

                // Filter Title
                Text(item.display.title)
                    .font(
                        .system(size: 20, weight: .semibold, design: .rounded)
                    )
                    .foregroundColor(.primary)
                    .padding(.top, 8)
                    .padding(.horizontal)
                
                // Additional selected filters (if multi-select with 2+ filters)
                if let additionalFilters = additionalFilters, !additionalFilters.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("Additional Selected Filters")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Grid of additional filter images (2 columns = 50% width each, square)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                            spacing: 12
                        ) {
                            ForEach(additionalFilters) { filter in
                                GeometryReader { geometry in
                                    Group {
                                        if let urlString = filter.display.imageName.hasPrefix("http") ? filter.display.imageName : nil,
                                           let url = URL(string: urlString) {
                                            KFImage(url)
                                                .placeholder {
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .overlay(ProgressView())
                                                }
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: geometry.size.width, height: geometry.size.width)
                                                .clipped()
                                                .cornerRadius(12)
                                        } else {
                                            Image(filter.display.imageName)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: geometry.size.width, height: geometry.size.width)
                                                .clipped()
                                                .cornerRadius(12)
                                        }
                                    }
                                    .overlay(
                                        VStack {
                                            Spacer()
                                            Text(filter.display.title)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.black.opacity(0.6))
                                                )
                                                .padding(8)
                                        }
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if let generated = generatedImage {
                    VStack {
                        Text("Generated Image")
                            .font(.headline)
                        Image(uiImage: generated)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 8)
                    }
                }

                // Multi-select indicator for filters
                if let additionalFilters = additionalFilters, !additionalFilters.isEmpty {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.blue)
                        Text("\(additionalFilters.count + 1) filter\(additionalFilters.count + 1 == 1 ? "" : "s") selected")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                // Multi-image indicator
                if images.count > 1 {
                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(.blue)
                        Text("\(images.count) photo\(images.count == 1 ? "" : "s") selected")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // MARK: - Size Selector
                if item.resolvedAPIConfig.provider == .wavespeed {
                    // For wavespeed, show only "auto" and disable interaction
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, -6)
                        Button(action: {
                            // Show feedback when tapped
                            sizeButtonTapped = true
                            // Reset after a short delay
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 2.0
                            ) {
                                sizeButtonTapped = false
                            }
                        }) {
                            HStack(spacing: 12) {
                                // Rectangular preview (matching normal style)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.2))
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.blue, lineWidth: 2)
                                        .padding(4)
                                }
                                .frame(width: 40, height: 40)

                                // Label
                                Text("Auto")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    Color.blue.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        // Disclaimer text with info icon
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .foregroundColor(
                                    sizeButtonTapped ? .red : .secondary)
                            Text(
                                "This filter does not allow you to change the aspect ratio. The image size will be automatically matched to your uploaded image."
                            )
                            .font(.caption2)
                            .foregroundColor(
                                sizeButtonTapped ? .red : .secondary)
                        }
                        .padding(.top, 4)
                        .padding(.leading, 4)
                    }
                    .padding(.horizontal)
                } else {
                    AspectRatioSection(
                        options: imageAspectOptions,
                        selectedIndex: $selectedAspectIndex
                    )
                }

                // MARK: - Generate Button

                Button(action: {
                    guard !isLoading else { return }
                    guard
                        let userId = authViewModel.user?.id.uuidString
                            .lowercased(), !userId.isEmpty
                    else {
                        isLoading = false
                        return
                    }

                    isLoading = true

                    // Get selected aspect ratio and update item
                    let selectedAspectOption = imageAspectOptions[
                        selectedAspectIndex]
                    var modifiedItem = item
                    // Use resolvedAPIConfig as base, then modify aspectRatio
                    var config = modifiedItem.resolvedAPIConfig
                    config.aspectRatio = selectedAspectOption.id
                    modifiedItem.apiConfig = config

                    // Collect all filters to generate (primary + additional)
                    var allFilters: [InfoPacket] = [item]
                    if let additionalFilters = additionalFilters {
                        allFilters.append(contentsOf: additionalFilters)
                    }
                    
                    // Start background generation for ALL images × ALL filters
                    Task { @MainActor in
                        var taskIds: [UUID] = []
                        var completedCount = 0
                        let totalCount = images.count * allFilters.count
                        
                        // Generate each image with each filter
                        for image in images {
                            for filter in allFilters {
                                // Create modified filter with aspect ratio
                                var modifiedFilter = filter
                                var config = modifiedFilter.resolvedAPIConfig
                                config.aspectRatio = selectedAspectOption.id
                                modifiedFilter.apiConfig = config
                                
                                let taskId = ImageGenerationCoordinator.shared
                                    .startImageGeneration(
                                        item: modifiedFilter,
                                        image: image,
                                        userId: userId,
                                        onImageGenerated: { downloadedImage in
                                            completedCount += 1
                                            // Update local state with the last generated image
                                            generatedImage = downloadedImage
                                            
                                            // Only stop loading when all tasks complete
                                            if completedCount == totalCount {
                                                isLoading = false
                                            }
                                        },
                                        onError: { error in
                                            completedCount += 1
                                            print(
                                                "Image generation failed: \(error.localizedDescription)"
                                            )
                                            // If all tasks completed (success or failure), stop loading
                                            if completedCount == totalCount {
                                                isLoading = false
                                            }
                                        }
                                    )
                                taskIds.append(taskId)
                            }
                        }
                        
                        currentTaskIds = taskIds
                    }
                }) {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(
                                    CircularProgressViewStyle(tint: .black)
                                )
                                .scaleEffect(1.2)
                        }
                        Text(isLoading ? generateButtonText : "Generate")
                            .font(
                                .system(
                                    size: 18, weight: .bold, design: .rounded)
                            )
                            .foregroundColor(.black)
                        if !isLoading {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 18))
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .rotationEffect(.degrees(rotation))
                                .drawingGroup()
                        }
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.clear, .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing),
                                lineWidth: 0
                            )
                            .animation(
                                .easeInOut(duration: 0.3), value: isLoading)
                    )
                    .shadow(
                        color: isLoading
                            ? Color.purple.opacity(0.4)
                            : Color.purple.opacity(0.3),
                        radius: isLoading ? 12 : 8, x: 0, y: 4
                    )
                    .scaleEffect(
                        isLoading ? 0.98 : (generatePulse ? 1.05 : 1.0)
                    )
                    .animation(
                        isLoading
                            ? .easeInOut(duration: 0.3)
                            : .easeInOut(duration: 1.2).repeatForever(
                                autoreverses: true),
                        value: isLoading ? isLoading : generatePulse
                    )
                    .opacity(isLoading ? 0.85 : 1.0)
                }
                .disabled(isLoading)
                .padding(.horizontal, 24)
                .onAppear {
                    generatePulse = true

                    isAnimating = true
                    // Kick off the first rotation immediately
                    withAnimation(.easeInOut(duration: 1.0)) {
                        rotation += 360
                    }
                    // Then continue spinning every 4 seconds
                    Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) {
                        _ in
                        withAnimation(.easeInOut(duration: 1.0)) {
                            rotation += 360
                        }
                    }
                }

                // MARK: - Cost Display

                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing)
                            )
                            .font(.system(size: 11))

                        Text("\(totalCredits)")
                            .font(
                                .system(size: 16, weight: .semibold, design: .rounded)
                            )
                            .foregroundColor(.primary)
                        Text("credits")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing)
                            )
                    )
                }
                .padding(.horizontal, 24)

                // MARK: - Info Section

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing)
                            )
                            .font(.system(size: 16))
                        Text("What to expect")
                            .font(
                                .system(
                                    size: 16, weight: .semibold,
                                    design: .rounded)
                            )
                            .foregroundColor(.primary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        InfoRow(
                            number: "1", text: "AI will transform your photo")
                        InfoRow(
                            number: "2", text: "Processing takes 30-60 seconds")
                        InfoRow(
                            number: "3",
                            text:
                                "Feel free to close the app while the image is generating."
                        )
                        InfoRow(
                            number: "4",
                            text: "You'll get a notification when ready")
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .font(.system(size: 9))

                        Text("\(totalCredits)")
                            .font(
                                .system(
                                    size: 16, weight: .semibold,
                                    design: .rounded)
                            )
                            .foregroundColor(.primary)
                        Text("credits")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
    }
}

// MARK: - InfoRow Helper View

struct InfoRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple], startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                )
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}
