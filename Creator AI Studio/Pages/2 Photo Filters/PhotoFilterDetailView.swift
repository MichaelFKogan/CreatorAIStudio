//
//  ImageDetailView.swift
//  AI Photo Generation
//
//  Created by Mike K on 10/16/25.
//

import Kingfisher
import PhotosUI
import SwiftUI

struct PhotoFilterDetailView: View {
    let item: InfoPacket
    let additionalFilters: [InfoPacket]?  // Additional filters for multi-select (if 2+ selected)
    @State private var prompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCamera: Bool = false
    @State private var showActionSheet: Bool = false
    @State private var createArrowMove: Bool = false
    @State private var navigateToConfirmation: Bool = false
    @State private var showSignInSheet: Bool = false
    @State private var showPurchaseCreditsView: Bool = false
    @State private var showInsufficientCreditsAlert: Bool = false
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    @EnvironmentObject var authViewModel: AuthViewModel

    init(item: InfoPacket, additionalFilters: [InfoPacket]? = nil) {
        self.item = item
        self.additionalFilters = additionalFilters
    }

    func allMoreStyles(for packet: InfoPacket) -> [InfoPacket] {
        guard let moreStyles = packet.resolvedMoreStyles, !moreStyles.isEmpty
        else {
            return []
        }

        let viewModel = PhotoFiltersViewModel.shared
        var result: [InfoPacket] = []

        // Iterate through each style group (each inner array contains category names)
        for styleGroup in moreStyles {
            // Each styleGroup is [String] - typically contains one category name
            // Handle both single category ["Anime"] and multiple categories ["Art", "Character"]
            for categoryName in styleGroup {
                // Get all filters from this category
                let categoryFilters = viewModel.filters(for: categoryName)

                // Add filters from this category, excluding the current item
                for filter in categoryFilters {
                    // Avoid duplicates and exclude the current item
                    if filter.id != packet.id
                        && !result.contains(where: { $0.id == filter.id })
                    {
                        result.append(filter)
                    }
                }
            }
        }

        return result
    }

    // Calculate total price (item + additional filters)
    private var totalPrice: Decimal {
        let itemPrice = item.resolvedCost ?? 0
        let additionalPrice =
            additionalFilters?.reduce(Decimal(0)) { total, filter in
                total + (filter.resolvedCost ?? 0)
            } ?? 0
        return itemPrice + additionalPrice
    }
    
    // Calculate required credits as Double
    private var requiredCredits: Double {
        NSDecimalNumber(decimal: totalPrice).doubleValue
    }
    
    // Check if user has enough credits
    private var hasEnoughCredits: Bool {
        guard let userId = authViewModel.user?.id else { return false }
        return creditsViewModel.hasEnoughCredits(requiredAmount: requiredCredits)
    }

    // Computed property to check if user can upload
    private var canUpload: Bool {
        guard authViewModel.user != nil else { return false }
        guard networkMonitor.isConnected else { return false }
        return hasEnoughCredits
    }

    // MARK: - View Sections
    private var heroSection: some View {
        VStack(spacing: 0) {
            AnimatedTitle(text: item.display.title)

            // Hero Images Section - Two overlapping diagonal images
            DiagonalOverlappingImages(
                leftImageName: item.display.imageNameOriginal
                    ?? item.display.imageName,
                rightImageName: item.display.imageName
            )
            .padding(.bottom, 8)
        }
    }
    
    @ViewBuilder
    private var additionalFiltersSection: some View {
        if let additionalFilters = additionalFilters,
            !additionalFilters.isEmpty
        {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                    Text("Additional Selected Filters")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Spacer()
                }

                // Grid of additional filter images (2 columns = 50% width each, square)
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 12),
                        count: 2),
                    spacing: 12
                ) {
                    ForEach(additionalFilters) { filter in
                        GeometryReader { geometry in
                            Group {
                                if let urlString =
                                    filter.display.imageName.hasPrefix("http")
                                    ? filter.display.imageName : nil,
                                    let url = URL(string: urlString)
                                {
                                    KFImage(url)
                                        .placeholder {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .overlay(ProgressView())
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
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 4, x: 0, y: 2)
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
    
    private var photoUploadSection: some View {
        VStack(alignment: .leading) {
            multiSelectIndicator
            networkConnectivityDisclaimer
            userInfoCard
            photoUploadButton
            multiSelectDisclaimer
            costSection
            exampleImagesSection
            moreStylesSection
        }
    }
    
    @ViewBuilder
    private var multiSelectIndicator: some View {
        if let additionalFilters = additionalFilters,
            !additionalFilters.isEmpty
        {
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
    }
    
    @ViewBuilder
    private var networkConnectivityDisclaimer: some View {
        if !networkMonitor.isConnected {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("No internet connection. Please connect to the internet.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    @ViewBuilder
    private var userInfoCard: some View {
        VStack(spacing: 12) {
            if authViewModel.user == nil {
                notLoggedInCard
            } else {
                loggedInCard
            }
        }
        .padding(.bottom, 8)
    }
    
    private var notLoggedInCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                Text("Log in to upload your photo")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Button(action: {
                showSignInSheet = true
            }) {
                Text("Sign In / Sign Up")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
    
    private var loggedInCard: some View {
        EnhancedCostCard(
            price: totalPrice,
            balance: creditsViewModel.formattedBalance(),
            hasEnoughCredits: hasEnoughCredits,
            requiredAmount: requiredCredits,
            primaryColor: .blue,
            secondaryColor: .purple,
            onBuyCredits: {
                showPurchaseCreditsView = true
            }
        )
        .frame(maxWidth: .infinity)
    }
    
    private var photoUploadButton: some View {
        HStack(alignment: .center, spacing: 16) {
            SpinningPlusButton(
                showActionSheet: $showActionSheet,
                isLoggedIn: authViewModel.user != nil,
                hasCredits: hasEnoughCredits,
                isConnected: networkMonitor.isConnected
            )
        }
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var multiSelectDisclaimer: some View {
        if let additionalFilters = additionalFilters,
            !additionalFilters.isEmpty
        {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("You will not be charged yet. Upload a photo and go to the next page to confirm.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    private var costSection: some View {
        HStack {
            Spacer()
            Text("Cost")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                if PricingManager.displayMode == .credits {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        )
                        .font(.system(size: 12))
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
        .padding(.trailing, 6)
    }
    
    @ViewBuilder
    private var exampleImagesSection: some View {
        if let exampleImages = item.resolvedExampleImages,
            !exampleImages.isEmpty
        {
            ExampleImagesSection(images: exampleImages)
        }
    }
    
    @ViewBuilder
    private var moreStylesSection: some View {
        if let moreStyles = item.resolvedMoreStyles,
            !moreStyles.isEmpty
        {
            VStack {
                HStack {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.blue)
                    Text("More Styles")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Spacer()
                }

                HStack {
                    Text("See what's possible with this image style")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            MoreStylesImageSection(items: allMoreStyles(for: item))
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSection
                additionalFiltersSection
                photoUploadSection
            }
            .padding(.horizontal)
            .padding(.bottom, 150)

            NavigationLink(isActive: $navigateToConfirmation) {
                if !selectedImages.isEmpty {
                    PhotoConfirmationView(
                        item: item, images: selectedImages,
                        additionalFilters: additionalFilters)
                }
            } label: {
                EmptyView()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CreditsBadge(
                    diamondColor: .teal,
                    borderColor: .mint
                )
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedImages: $selectedImages)
        }
        .sheet(isPresented: $showActionSheet) {
            ImageSourceSelectionSheetForSingleImage(
                showCameraSheet: $showCamera,
                selectedPhotoItems: $selectedPhotoItems,
                showActionSheet: $showActionSheet,
                selectedImages: $selectedImages,
                navigateToConfirmation: $navigateToConfirmation
            )
        }
        .onChange(of: selectedImages) { newImages in
            if !newImages.isEmpty {
                // Small delay to ensure state is fully updated before navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigateToConfirmation = true
                }
            }
        }
        .onAppear {
            prompt = item.prompt ?? ""
            // kick off the subtle arrow motion next to the Create text
            createArrowMove = true
            // Fetch credit balance when view appears
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
        .onChange(of: showSignInSheet) { isPresented in
            // When sign-in sheet is dismissed, refresh credits if user signed in
            if !isPresented, let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
        .onChange(of: showPurchaseCreditsView) { isPresented in
            // When purchase credits sheet is dismissed, refresh credits
            if !isPresented, let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
        .onChange(of: authViewModel.user) { oldUser, newUser in
            // Refresh credits when user signs in or changes
            if let userId = newUser?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            } else {
                // Reset balance when user signs out
                creditsViewModel.balance = 0.00
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { notification in
            // Refresh credits when balance is updated (e.g., after purchase)
            if let userId = authViewModel.user?.id {
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
        .sheet(isPresented: $showSignInSheet, onDismiss: {
            // Fetch credits when sign-in sheet is dismissed (user may have signed in)
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }) {
            SignInView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPurchaseCreditsView, onDismiss: {
            // Fetch credits when purchase credits sheet is dismissed (user may have purchased credits)
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }) {
            PurchaseCreditsView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Animated Title
struct AnimatedTitle: View {
    let text: String
    @State private var shimmer: Bool = false
    @State private var sparklePulse: Bool = false

    var body: some View {
        ZStack {
            Text(text)
                .font(.system(size: 28, weight: .bold, design: .rounded))
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
                        Text(text)
                            .font(.title)
                            .fontWeight(.bold)
                    )
                )
                .onAppear {
                    withAnimation(
                        .linear(duration: 2.2).repeatForever(
                            autoreverses: false)
                    ) {
                        shimmer.toggle()
                    }
                }

            // Subtle sparkles around the title
            Image(systemName: "sparkles")
                .foregroundColor(.yellow.opacity(0.9))
                .offset(x: -70, y: -18)
                .scaleEffect(sparklePulse ? 1.15 : 0.85)
                .opacity(sparklePulse ? 1.0 : 0.7)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: sparklePulse)

            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .offset(x: 72, y: -6)
                .scaleEffect(sparklePulse ? 0.9 : 0.6)
                .opacity(sparklePulse ? 0.95 : 0.6)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        .delay(0.3), value: sparklePulse)
        }
        .onAppear { sparklePulse = true }
    }
}

// MARK: - Diagonal Overlapping Images
struct DiagonalOverlappingImages: View {
    let leftImageName: String
    let rightImageName: String

    @State private var arrowWiggle: Bool = false

    var body: some View {
        // Calculate height based on available width (screen width minus horizontal padding)
        // This ensures consistent sizing across devices
        let availableWidth = UIScreen.main.bounds.width - 40  // Account for horizontal padding (20 on each side)
        let imageWidth = availableWidth * 0.53
        let imageHeight = imageWidth * 1.38
        let contentHeight = imageHeight + 40  // Extra space for shadows and arrow
        let calculatedHeight = max(240, min(280, contentHeight))  // Clamp between 240 and 280

        GeometryReader { geometry in
            let imageWidth = geometry.size.width * 0.53
            let imageHeight = imageWidth * 1.38
            let arrowYOffset = -imageHeight * 0.15

            ZStack(alignment: .center) {
                // Left image
                Image(leftImageName)
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
                        color: Color.black.opacity(0.25), radius: 12, x: -4,
                        y: 4
                    )
                    .rotationEffect(.degrees(-6))
                    .offset(x: -imageWidth * 0.50)

                // Right image
                Image(rightImageName)
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
                        color: Color.black.opacity(0.25), radius: 12, x: 4, y: 4
                    )
                    .rotationEffect(.degrees(8))
                    .offset(x: imageWidth * 0.50)

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
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: calculatedHeight)  // Use calculated height for consistency
        .padding(.horizontal, 20)
    }
}

struct SpinningPlusButton: View {
    @Binding var showActionSheet: Bool
    let isLoggedIn: Bool
    let hasCredits: Bool
    let isConnected: Bool
    @State private var rotation: Double = 0
    @State private var shine = false
    @State private var isAnimating = false

    private var canUpload: Bool {
        isLoggedIn && hasCredits && isConnected
    }

    var body: some View {
        Button(action: {
            if canUpload {
                showActionSheet = true
            } else if isLoggedIn && !hasCredits {
                // This will be handled by parent view's alert
                showActionSheet = false
            }
        }) {
            HStack {
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .opacity(0)
                    .foregroundColor(.black)
                Spacer()
                Text("Upload Your Photo")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(rotation))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(0.0), .white.opacity(0.25),
                        .white.opacity(0.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: shine ? 250 : -250)
                .mask(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(lineWidth: 2)
                )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .scaleEffect(isAnimating ? 1.04 : 1.0)
            .animation(
                .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .opacity(canUpload ? 1.0 : 0.6)
        }
        .frame(maxWidth: .infinity)
        .disabled(!canUpload)
        .onAppear {
            isAnimating = true
            // Initial spin
            withAnimation(.easeInOut(duration: 1.0)) {
                rotation += 360
            }

            // Continuous spin every few seconds
            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        rotation += 360
                    }
                }
            }

            // Gradient shine animation
            withAnimation(
                .linear(duration: 3.5).repeatForever(autoreverses: false)
            ) {
                shine.toggle()
            }
        }
    }
}

// MARK: - ImagePicker for Camera
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController, context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController
                .InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImages = [image]
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Example Images Section
struct ExampleImagesSection: View {
    let images: [String]
    @State private var selectedImageIndex: Int = 0
    @State private var showFullScreen = false
    @State private var appeared = false  // <- new

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                Text("Example Gallery")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
            }

            Text("See what's possible with this style")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 6), count: 2),
                spacing: 6
            ) {
                ForEach(Array(images.enumerated()), id: \.element) {
                    index, imageName in
                    GeometryReader { geo in
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: geo.size.width, height: geo.size.width
                            )
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(
                                color: Color.black.opacity(0.1), radius: 4,
                                x: 0, y: 2
                            )
                            .onTapGesture {
                                selectedImageIndex = index
                                showFullScreen = true
                            }
                    }
                    .aspectRatio(1.0, contentMode: .fit)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(.easeOut(duration: 0.8), value: appeared)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                appeared = true
            }
        }
        .sheet(isPresented: $showFullScreen) {
            FullScreenImageViewer(
                images: images,
                selectedIndex: selectedImageIndex,
                isPresented: $showFullScreen
            )
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Full Screen Image Viewer
struct FullScreenImageViewer: View {
    let images: [String]
    let selectedIndex: Int
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    init(images: [String], selectedIndex: Int, isPresented: Binding<Bool>) {
        self.images = images
        self.selectedIndex = selectedIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: selectedIndex)
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black.edgesIgnoringSafeArea(.all)

            // TabView for swipeable images
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) {
                    index, imageName in
                    GeometryReader { geometry in
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { value in
                                        lastScale = scale
                                        // Reset if zoomed out too much
                                        if scale < 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                lastScale = 1.0
                                            }
                                        }
                                    }
                            )
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _ in
                // Reset zoom when changing images
                withAnimation {
                    scale = 1.0
                    lastScale = 1.0
                }
            }

            // Custom page indicator dots
            VStack {
                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<images.count, id: \.self) { index in
                        Circle()
                            .fill(
                                currentIndex == index
                                    ? Color.white : Color.white.opacity(0.5)
                            )
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentIndex == index ? 1.2 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.2), value: currentIndex)
                    }
                }
                .padding(.bottom, 40)
            }

            // Close button - positioned at top right
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(1))
                                .frame(width: 32, height: 32)

                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - More Styles Image Section
struct MoreStylesImageSection: View {
    let items: [InfoPacket]  // InfoPacket-driven version for images

    // 2x2 grid
    private let gridColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: Grid
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(items) { item in
                    NavigationLink(
                        destination: PhotoFilterDetailView(item: item)
                    ) {
                        GeometryReader { geo in
                            Image(item.display.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: 260)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(
                                    color: .black.opacity(0.1), radius: 4, x: 0,
                                    y: 2)
                        }
                        .frame(height: 260)
                    }
                }
            }
        }
    }
}

// MARK: - Image Source Selection Sheet for Single Image
struct ImageSourceSelectionSheetForSingleImage: View {
    @Binding var showCameraSheet: Bool
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var showActionSheet: Bool
    @Binding var selectedImages: [UIImage]
    @Binding var navigateToConfirmation: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button {
                    showActionSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCameraSheet = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 40)
                        Text("Camera")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())

                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 40)
                        Text("Gallery")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .onChange(of: selectedPhotoItems) { newItems in
                    guard !newItems.isEmpty else { return }

                    Task {
                        var loadedImages: [UIImage] = []

                        // Load all selected images
                        for item in newItems {
                            if let data = try? await item.loadTransferable(
                                type: Data.self),
                                let image = UIImage(data: data)
                            {
                                loadedImages.append(image)
                            }
                        }

                        await MainActor.run {
                            selectedImages = loadedImages
                            selectedPhotoItems.removeAll()
                            showActionSheet = false

                            // Navigate to confirmation if we have images
                            if !selectedImages.isEmpty {
                                navigateToConfirmation = true
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle(
                "Add Photo\(selectedPhotoItems.count > 1 ? "s" : "")"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showActionSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}

// MARK: - Enhanced Cost Card

struct EnhancedCostCard: View {
    let price: Decimal
    let balance: String
    let hasEnoughCredits: Bool
    let requiredAmount: Double
    let primaryColor: Color
    let secondaryColor: Color
    let onBuyCredits: () -> Void
    
    private var disclaimerText: String {
        let requiredAmountText = String(format: "$%.2f", requiredAmount)
        return "Insufficient credits. You need \(requiredAmountText) but your balance is \(balance)."
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Warning message (only when insufficient)
            if !hasEnoughCredits {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text(disclaimerText)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
            
            // Cost and balance
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Cost")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    PriceDisplayView(
                        price: price,
                        showUnit: true,
                        font: .subheadline,
                        fontWeight: .semibold,
                        foregroundColor: .primary
                    )
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "banknote.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Your balance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(balance)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary.opacity(0.8))
                }
            }
            .padding(.horizontal, 4)
            
            // Buy Credits button (only when insufficient)
            if !hasEnoughCredits {
                Button(action: onBuyCredits) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Buy Credits")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: !hasEnoughCredits
                    ? [Color.red.opacity(0.12), Color.red.opacity(0.08)]
                    : [primaryColor.opacity(0.08), secondaryColor.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: !hasEnoughCredits
                            ? [Color.red.opacity(0.4), Color.red.opacity(0.3)]
                            : [primaryColor, secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Insufficient Credits Disclaimer Helper View

private struct InsufficientCreditsDisclaimer: View {
    let requiredAmount: Double
    let currentBalance: String
    
    private var disclaimerText: String {
        let requiredAmountText = String(format: "$%.2f", requiredAmount)
        return "Insufficient credits to generate this. You need \(requiredAmountText) but your balance is \(currentBalance)."
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.yellow)
            Text(disclaimerText)
                .font(.caption)
                .foregroundColor(.yellow)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
