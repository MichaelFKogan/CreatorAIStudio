//
//  MermaidFilterDetailPage.swift
//  Creator AI Studio
//
//  Mermaid-style video filters via WaveSpeed video-effects API (e.g. fishermen).
//  Single image in → video out; no reference video or duration picker.
//

import PhotosUI
import SwiftUI

struct MermaidFilterDetailPage: View {
    @State var item: InfoPacket
    
    @State private var referenceImage: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    @State private var isGenerating: Bool = false
    @State private var showEmptyImageAlert: Bool = false
    @State private var showCameraSheet: Bool = false
    @State private var showActionSheet: Bool = false
    @State private var showSignInSheet: Bool = false
    @State private var showPurchaseCreditsView: Bool = false
    @State private var showInsufficientCreditsAlert: Bool = false
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    /// Fixed price per video (from item / PricingManager).
    private var currentPrice: Decimal? {
        item.resolvedCost ?? item.cost
    }
    
    private var requiredCredits: Double {
        let price = currentPrice ?? item.resolvedCost ?? 0
        return NSDecimalNumber(decimal: price).doubleValue
    }
    
    private var hasEnoughCredits: Bool {
        guard authViewModel.user?.id != nil else { return false }
        return creditsViewModel.hasEnoughCredits(requiredAmount: requiredCredits)
    }
    
    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        AnimatedTitle(text: item.display.title)
                            .padding(.top, 16)
                        
                        LazyView(MermaidBannerSection(item: item, price: currentPrice))
                        
                        Divider().padding(.horizontal)
                        
                        MermaidImageUploadSection(
                            referenceImage: $referenceImage,
                            selectedPhotoItem: $selectedPhotoItem,
                            showCameraSheet: $showCameraSheet,
                            showActionSheet: $showActionSheet
                        )
                        
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Spacer()
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.cyan)
                                Text("Best results: upper body or full body clearly visible from the front")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                        
                        LazyView(
                            MermaidGenerateButton(
                                isGenerating: $isGenerating,
                                price: currentPrice,
                                isLoggedIn: authViewModel.user != nil,
                                hasCredits: hasEnoughCredits,
                                isConnected: networkMonitor.isConnected,
                                hasImage: referenceImage != nil,
                                onSignInTap: { showSignInSheet = true },
                                action: generate
                            )
                        )
                        
                        VStack(spacing: 12) {
                            AuthAwareCostCard(
                                price: currentPrice ?? item.resolvedCost ?? 0,
                                requiredCredits: requiredCredits,
                                primaryColor: .cyan,
                                secondaryColor: .teal,
                                loginMessage: "Log in to generate a video",
                                isConnected: networkMonitor.isConnected,
                                onSignIn: { showSignInSheet = true },
                                onBuyCredits: { showPurchaseCreditsView = true }
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, -8)
                        
                        LazyView(MermaidAspectRatioInfoSection())
                        
                        Divider().padding(.horizontal)
                        
                        Color.clear.frame(height: 130)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Video Filters")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                CreditsToolbarView(
                    diamondColor: .cyan,
                    borderColor: .teal,
                    showSignInSheet: $showSignInSheet,
                    showPurchaseCreditsView: $showPurchaseCreditsView
                )
            }
        }
        .alert("Image Required", isPresented: $showEmptyImageAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please upload an image to transform into a mermaid-style video.")
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCameraSheet) {
            SimpleCameraPicker(isPresented: $showCameraSheet) { capturedImage in
                referenceImage = capturedImage
            }
        }
        .sheet(isPresented: $showActionSheet) {
            MermaidImageSourceSheet(
                showCameraSheet: $showCameraSheet,
                selectedPhotoItem: $selectedPhotoItem,
                showActionSheet: $showActionSheet,
                image: $referenceImage
            )
        }
        .onAppear {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                try AVAudioSession.sharedInstance().setActive(true, options: [])
            } catch {
                print("Failed to configure audio session: \(error)")
            }
        }
        .onChange(of: showSignInSheet) { isPresented in
            if !isPresented, let userId = authViewModel.user?.id {
                Task { await creditsViewModel.fetchBalance(userId: userId) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { _ in
            if let userId = authViewModel.user?.id {
                Task { await creditsViewModel.fetchBalance(userId: userId) }
            }
        }
        .alert("Insufficient Credits", isPresented: $showInsufficientCreditsAlert) {
            Button("Purchase Credits") { showPurchaseCreditsView = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need \(String(format: "$%.2f", requiredCredits)) to generate this. Your current balance is \(creditsViewModel.formattedBalance()).")
        }
        .sheet(isPresented: $showPurchaseCreditsView) {
            PurchaseCreditsView()
        }
    }
    
    // MARK: - Generate
    
    private func generate() {
        guard let image = referenceImage else {
            showEmptyImageAlert = true
            return
        }
        guard !isGenerating else { return }
        if !hasEnoughCredits {
            showInsufficientCreditsAlert = true
            return
        }
        
        isGenerating = true
        let imageAspectRatio = calculateAspectRatio(from: image)
        let apiDuration = 5.0
        
        guard let userId = authViewModel.user?.id.uuidString.lowercased(), !userId.isEmpty else {
            isGenerating = false
            return
        }
        
        Task { @MainActor in
            await PushNotificationManager.shared.checkAuthorizationStatus()
            if PushNotificationManager.shared.authorizationStatus == .notDetermined {
                _ = await PushNotificationManager.shared.requestPermissions()
            }
            _ = VideoGenerationCoordinator.shared.startVideoGeneration(
                item: item,
                image: image,
                userId: userId,
                duration: apiDuration,
                aspectRatio: imageAspectRatio,
                resolution: nil,
                storedDuration: nil,
                generateAudio: false,
                firstFrameImage: nil,
                lastFrameImage: nil,
                referenceVideoURL: nil,
                motionControlTier: nil,
                onVideoGenerated: { _ in
                    isGenerating = false
                },
                onError: { error in
                    isGenerating = false
                    print("Mermaid video generation failed: \(error.localizedDescription)")
                }
            )
        }
    }
    
    private func calculateAspectRatio(from image: UIImage) -> String {
        let width = image.size.width
        let height = image.size.height
        let gcd = greatestCommonDivisor(Int(width), Int(height))
        let simplifiedWidth = Int(width) / gcd
        let simplifiedHeight = Int(height) / gcd
        let ratio = Double(width) / Double(height)
        if abs(ratio - (16.0/9.0)) < 0.1 { return "16:9" }
        if abs(ratio - (9.0/16.0)) < 0.1 { return "9:16" }
        if abs(ratio - 1.0) < 0.1 { return "1:1" }
        if abs(ratio - (4.0/3.0)) < 0.1 { return "4:3" }
        if abs(ratio - (3.0/4.0)) < 0.1 { return "3:4" }
        return "\(simplifiedWidth):\(simplifiedHeight)"
    }
    
    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var a = a, b = b
        while b != 0 { let t = b; b = a % b; a = t }
        return a
    }
    
}

// MARK: - Mermaid banner (image + title + price card)

private struct MermaidBannerSection: View {
    let item: InfoPacket
    let price: Decimal?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(item.display.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.display.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    if let p = price {
                        Text(PricingManager.formatPrice(p))
                            .font(.headline)
                            .foregroundColor(.cyan)
                    }
                }
                if let desc = item.display.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal)
    }
}

// MARK: - Mermaid image upload section

private struct MermaidImageUploadSection: View {
    @Binding var referenceImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var showCameraSheet: Bool
    @Binding var showActionSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.cyan)
                Text("Upload Your Image")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text("Upload an image to transform into a mermaid-style video")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.bottom, 4)
            if let image = referenceImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 140, maxHeight: 196)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.6), lineWidth: 2))
                    Button(action: { referenceImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red))
                    }
                    .padding(8)
                }
            } else {
                Button { showActionSheet = true } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "camera")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        VStack(spacing: 4) {
                            Text("Add Image")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            Text("Camera or Gallery")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.gray.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 3.5, dash: [6, 4]))
                            .foregroundColor(.gray.opacity(0.4))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Mermaid generate button

private struct MermaidGenerateButton: View {
    @Binding var isGenerating: Bool
    let price: Decimal?
    let isLoggedIn: Bool
    let hasCredits: Bool
    let isConnected: Bool
    let hasImage: Bool
    let onSignInTap: () -> Void
    let action: () -> Void
    private var canGenerate: Bool { isLoggedIn && hasCredits && isConnected && hasImage }
    
    var body: some View {
        Button(action: {
            if !isLoggedIn { onSignInTap() }
            else { action() }
        }) {
            HStack {
                if isGenerating {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                }
                if isGenerating {
                    Text("Generating...").fontWeight(.semibold)
                } else {
                    Text("Generate").fontWeight(.semibold)
                    Image(systemName: "sparkle").font(.system(size: 14))
                    Text(PricingManager.formatPrice(price ?? 0)).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isGenerating || !canGenerate
                    ? LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.cyan.opacity(0.8), Color.teal], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isGenerating || !canGenerate)
        .opacity(canGenerate ? 1.0 : 0.6)
        .padding(.horizontal)
    }
}

// MARK: - Mermaid image source sheet

private struct MermaidImageSourceSheet: View {
    @Binding var showCameraSheet: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var showActionSheet: Bool
    @Binding var image: UIImage?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button {
                    showActionSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showCameraSheet = true }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.fill").font(.system(size: 24)).foregroundColor(.cyan).frame(width: 40)
                        Text("Camera").font(.headline).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 1, matching: .images) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 24)).foregroundColor(.cyan).frame(width: 40)
                        Text("Gallery").font(.headline).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .onChange(of: selectedPhotoItems) { newItems in
                    if let item = newItems.first {
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                                image = img
                            }
                            selectedPhotoItems.removeAll()
                            showActionSheet = false
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Add Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { showActionSheet = false }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}

// MARK: - Mermaid aspect ratio info (short copy)

private struct MermaidAspectRatioInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)
                Text("Video output")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            Text("The video will be generated to match your image. Use a clear, front-facing photo for best results.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cyan.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
    }
}
