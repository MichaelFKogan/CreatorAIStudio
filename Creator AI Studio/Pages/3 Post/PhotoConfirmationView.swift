import Kingfisher
import SwiftUI

struct PhotoConfirmationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationManager: NotificationManager

    let item: InfoPacket
    let images: [UIImage]
    let additionalFilters: [InfoPacket]?  // Additional filters for multi-select

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
    @State private var showSignInSheet: Bool = false
    @State private var showSubscriptionView: Bool = false
    @State private var showPurchaseCreditsView: Bool = false
    @State private var isSubscribed: Bool = false // TODO: Connect to actual subscription status
    @State private var hasCredits: Bool = true // TODO: Connect to actual credits check
    
    // Primary initializer for multiple images
    init(
        item: InfoPacket, images: [UIImage],
        additionalFilters: [InfoPacket]? = nil
    ) {
        self.item = item
        self.images = images
        self.additionalFilters = additionalFilters
    }
    
    // Convenience initializer for single image (backward compatibility)
    init(
        item: InfoPacket, image: UIImage, additionalFilters: [InfoPacket]? = nil
    ) {
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
    
    // Computed property to check if user can generate
    private var canGenerate: Bool {
        guard let _ = authViewModel.user else { return false }
        return isSubscribed && hasCredits
    }
    
    // Calculate total price: sum of all filter costs × number of images
    // Each image gets generated with each filter
    private var totalPrice: Decimal {
        let itemPrice = item.resolvedCost ?? 0
        let additionalPrice =
            additionalFilters?.reduce(Decimal(0)) { total, filter in
            total + (filter.resolvedCost ?? 0)
        } ?? 0
        let totalFilterCost = itemPrice + additionalPrice
        // Each image will be generated with each filter
        return totalFilterCost * Decimal(images.count)
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
                animatedTitleSection
                diagonalImageSection
                filterTitleSection
                additionalFiltersSection
                generatedImageSection
                multiSelectIndicators
                sizeSelectorSection
                generateButtonSection
                costDisplaySection
                infoSection
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .toolbar { toolbarContent }
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPurchaseCreditsView) {
            PurchaseCreditsView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - View Sections

    private var animatedTitleSection: some View {
                ZStack {
            titleText
            sparkleIcons
        }
        .padding(.top, 20)
        .onAppear { sparklePulse = true }
    }

    private var titleText: some View {
                    Text(images.count > 1 ? "Confirm Your Photos" : "Confirm Your Photo")
            .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
            .overlay(shimmerOverlay)
            .onAppear {
                withAnimation(
                    .linear(duration: 2.0).repeatForever(autoreverses: false)
                ) {
                    shimmer.toggle()
                }
            }
    }

    private var shimmerOverlay: some View {
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
            Text(
                images.count > 1 ? "Confirm Your Photos" : "Confirm Your Photo"
            )
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                            )
    }

    private var sparkleIcons: some View {
        Group {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow.opacity(0.9))
                        .offset(x: -80, y: -10)
                        .scaleEffect(sparklePulse ? 1.2 : 0.8)
                        .opacity(sparklePulse ? 1 : 0.7)
                        .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: sparklePulse)

                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .offset(x: 80, y: -5)
                        .scaleEffect(sparklePulse ? 0.9 : 0.6)
                        .opacity(sparklePulse ? 0.95 : 0.6)
                        .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        .delay(0.3), value: sparklePulse)
        }
    }

    private var diagonalImageSection: some View {
                GeometryReader { geometry in
                    let imageWidth = geometry.size.width * 0.48
                    let imageHeight = imageWidth * 1.38
                    let arrowYOffset = -imageHeight * 0.15

                    ZStack(alignment: .center) {
                rightImageExample(width: imageWidth, height: imageHeight)
                leftUserImage(width: imageWidth, height: imageHeight)
                animatedArrow(yOffset: arrowYOffset)
            }
            .onAppear { arrowWiggle = true }
            .frame(width: geometry.size.width, height: imageHeight + 20)
        }
        .frame(height: 260)
        .padding(.horizontal, 20)
    }

    private func rightImageExample(width: CGFloat, height: CGFloat) -> some View
    {
                        Group {
                            if item.display.imageName.hasPrefix("http://")
                                || item.display.imageName.hasPrefix("https://"),
                                let url = URL(string: item.display.imageName)
                            {
                                KFImage(url)
                                    .placeholder {
                        Rectangle().fill(Color.gray.opacity(0.2)).overlay(
                            ProgressView())
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(imageBorder)
                    .shadow(
                        color: Color.black.opacity(0.25), radius: 12, x: 4, y: 4
                    )
                            } else {
                                Image(item.display.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(imageBorder)
                    .shadow(
                        color: Color.black.opacity(0.25), radius: 12, x: 4, y: 4
                    )
                            }
                        }
                        .rotationEffect(.degrees(8))
        .offset(x: width * 0.50)
    }

    private func leftUserImage(width: CGFloat, height: CGFloat) -> some View {
                        Image(uiImage: firstImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(imageBorder)
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: -4, y: 4)
            .rotationEffect(.degrees(-6))
            .offset(x: -width * 0.50)
    }

    private var imageBorder: some View {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white, .gray],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing),
                                        lineWidth: 2
                                    )
    }

    private func animatedArrow(yOffset: CGFloat) -> some View {
                        Image("arrow")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 62, height: 62)
                            .rotationEffect(.degrees(arrowWiggle ? 6 : -6))
                            .animation(
                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: arrowWiggle
            )
            .offset(x: 0, y: yOffset)
    }

    private var filterTitleSection: some View {
                Text(item.display.title)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 8)
                    .padding(.horizontal)
    }

    @ViewBuilder
    private var additionalFiltersSection: some View {
        if let additionalFilters = additionalFilters, !additionalFilters.isEmpty
        {
                    VStack(alignment: .leading, spacing: 12) {
                additionalFiltersHeader
                additionalFiltersGrid
            }
        }
    }

    private var additionalFiltersHeader: some View {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("Additional Selected Filters")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            Spacer()
                        }
                        .padding(.horizontal)
    }
                        
    private var additionalFiltersGrid: some View {
                        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 12), count: 2),
                            spacing: 12
                        ) {
            ForEach(additionalFilters ?? []) { filter in
                additionalFilterCard(filter: filter)
            }
        }
        .padding(.horizontal)
    }

    private func additionalFilterCard(filter: InfoPacket) -> some View {
                                GeometryReader { geometry in
                                    Group {
                if let urlString = filter.display.imageName.hasPrefix("http")
                    ? filter.display.imageName : nil,
                    let url = URL(string: urlString)
                {
                                            KFImage(url)
                                                .placeholder {
                            Rectangle().fill(Color.gray.opacity(0.2)).overlay(
                                ProgressView())
                                                }
                                                .resizable()
                                                .scaledToFill()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.width
                        )
                                                .clipped()
                                                .cornerRadius(12)
                                        } else {
                                            Image(filter.display.imageName)
                                                .resizable()
                                                .scaledToFill()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.width
                        )
                                                .clipped()
                                                .cornerRadius(12)
                                        }
                                    }
            .overlay(filterTitleOverlay(filter: filter))
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func filterTitleOverlay(filter: InfoPacket) -> some View {
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
                .background(Capsule().fill(Color.black.opacity(0.6)))
                                                .padding(8)
        }
    }

    @ViewBuilder
    private var generatedImageSection: some View {
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
    }

    @ViewBuilder
    private var multiSelectIndicators: some View {
        if let additionalFilters = additionalFilters, !additionalFilters.isEmpty
        {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.blue)
                Text(
                    "\(additionalFilters.count + 1) filter\(additionalFilters.count + 1 == 1 ? "" : "s") selected"
                )
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                if images.count > 1 {
                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(.blue)
                Text(
                    "\(images.count) photo\(images.count == 1 ? "" : "s") selected"
                )
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
        }
                }

    @ViewBuilder
    private var sizeSelectorSection: some View {
                if item.resolvedAPIConfig.provider == .wavespeed {
            wavespeedSizeSelector
        } else {
            AspectRatioSection(
                options: imageAspectOptions,
                selectedIndex: $selectedAspectIndex
            )
        }
    }

    private var wavespeedSizeSelector: some View {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, -6)

                        Button(action: {
                            sizeButtonTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                sizeButtonTapped = false
                            }
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.2))
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.blue, lineWidth: 2)
                                        .padding(4)
                                }
                                .frame(width: 40, height: 40)

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

                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                    .foregroundColor(sizeButtonTapped ? .red : .secondary)
                            Text(
                                "This filter does not allow you to change the aspect ratio. The image size will be automatically matched to your uploaded image."
                            )
                            .font(.caption2)
                .foregroundColor(sizeButtonTapped ? .red : .secondary)
                        }
                        .padding(.top, 4)
                        .padding(.leading, 4)
                    }
                    .padding(.horizontal)
    }

    private var generateButtonSection: some View {
        VStack(spacing: 4) {
            if authViewModel.user == nil {
                loginDisclaimer

                signInTextLink
                    .padding(.bottom, 12)
            } else if !isSubscribed {
                subscriptionRequiredMessage
                    .padding(.bottom, 12)
            } else if !hasCredits {
                creditsRequiredMessage
                    .padding(.bottom, 12)
            }

            generateButton
                .onAppear {
                    setupGenerateButtonAnimations()
                }
        }
        .padding(.horizontal)
    }

    private var loginDisclaimer: some View {
        HStack(spacing: 6) {
            Spacer()
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
            Text("You must be logged in to generate an image")
                .font(.caption)
                .foregroundColor(.red)
            Spacer()
        }
    }

    private var generateButton: some View {
        Button(action: handleGenerate) {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(
                                    CircularProgressViewStyle(tint: .black)
                                )
                                .scaleEffect(1.2)
                        }
                        Text(isLoading ? generateButtonText : "Generate")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
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
            .overlay(generateButtonOverlay)
                    .shadow(
                        color: isLoading
                    ? Color.purple.opacity(0.4) : Color.purple.opacity(0.3),
                        radius: isLoading ? 12 : 8, x: 0, y: 4
                    )
            .scaleEffect(isLoading ? 0.98 : (generatePulse ? 1.05 : 1.0))
                    .animation(
                        isLoading
                            ? .easeInOut(duration: 0.3)
                            : .easeInOut(duration: 1.2).repeatForever(
                                autoreverses: true),
                        value: isLoading ? isLoading : generatePulse
                    )
                    .opacity(isLoading ? 0.85 : 1.0)
                }
        .disabled(isLoading || !canGenerate)
        .opacity(canGenerate ? 1.0 : 0.6)
                .padding(.horizontal, 24)
    }

    private var generateButtonOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                LinearGradient(
                    colors: [.clear, .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                lineWidth: 0
            )
            .animation(.easeInOut(duration: 0.3), value: isLoading)
    }

    private var signInTextLink: some View {
        HStack {
            Spacer()
            Button(action: {
                showSignInSheet = true
            }) {
                Text("Sign In / Sign Up")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.blue)
            }
            Spacer()
        }
    }
    
    private var subscriptionRequiredMessage: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Spacer()
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text("Please Subscribe to generate this image")
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            HStack {
                Spacer()
                Button(action: {
                    showSubscriptionView = true
                }) {
                    Text("Subscribe")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                }
                Spacer()
            }
        }
    }
    
    private var creditsRequiredMessage: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Spacer()
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text("Insufficient credits to generate")
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            HStack {
                Spacer()
                Button(action: {
                    showPurchaseCreditsView = true
                }) {
                    Text("Buy Credits")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                }
                Spacer()
            }
        }
    }

    private var costDisplaySection: some View {
                HStack {
                    Spacer()
                    Text("Cost")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    costBadge
        }
        .padding(.horizontal, 24)
    }

    private var costBadge: some View {
                    HStack(spacing: 6) {
                        if PricingManager.displayMode == .credits {
                            Image(systemName: "diamond.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing)
                                )
                                .font(.system(size: 11))
                        }

                        PriceDisplayView(
                            price: totalPrice,
                            showUnit: true,
                            font: .system(size: 16, weight: .semibold, design: .rounded),
                            foregroundColor: .primary
                        )
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


    private var infoSection: some View {
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
                        .system(size: 16, weight: .semibold, design: .rounded)
                            )
                            .foregroundColor(.primary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                InfoRow(number: "1", text: "AI will transform your photo")
                InfoRow(number: "2", text: "Processing usually takes 30-60 seconds, but may take longer")
                        InfoRow(
                            number: "3",
                            text:
                                "Feel free to close the app while the image is generating."
                        )
                        InfoRow(
                    number: "4", text: "You'll get a notification when ready")
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 100)
            }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            CreditsBadge(
                diamondColor: .teal,
                borderColor: .mint,
                creditsAmount: "$10.00"
            )
        }
    }

    // MARK: - Actions

    private func setupGenerateButtonAnimations() {
        generatePulse = true
        isAnimating = true
        withAnimation(.easeInOut(duration: 1.0)) {
            rotation += 360
        }
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                rotation += 360
            }
        }
    }

    private func handleGenerate() {
        guard !isLoading else { return }
        guard let userId = authViewModel.user?.id.uuidString.lowercased(),
            !userId.isEmpty
        else {
            isLoading = false
            showSignInSheet = true
            return
        }

        isLoading = true

        let selectedAspectOption = imageAspectOptions[selectedAspectIndex]
        var modifiedItem = item
        var config = modifiedItem.resolvedAPIConfig
        config.aspectRatio = selectedAspectOption.id
        modifiedItem.apiConfig = config

        var allFilters: [InfoPacket] = [item]
        if let additionalFilters = additionalFilters {
            allFilters.append(contentsOf: additionalFilters)
        }

        Task { @MainActor in
            var taskIds: [UUID] = []
            var completedCount = 0
            let totalCount = images.count * allFilters.count

            for image in images {
                for filter in allFilters {
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
                                generatedImage = downloadedImage
                                if completedCount == totalCount {
                                    isLoading = false
                                }
                            },
                            onError: { error in
                                completedCount += 1
                                print(
                                    "Image generation failed: \(error.localizedDescription)"
                                )
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
