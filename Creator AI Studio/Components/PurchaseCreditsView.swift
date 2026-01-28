//
//  PurchaseCreditsView.swift
//  Creator AI Studio
//
//  Created for purchase credits UI
//

import SwiftUI
import StoreKit

// Price formatting helper
struct PriceCalculator {
    // Format price as string
    static func formatPrice(_ price: Double) -> String {
        return String(format: "$%.2f", price)
    }
}

// MARK: - StoreKit Product IDs
enum CreditProductID: String, CaseIterable {
    case testPack = "com.runspeedai.credits.test"
    case starterPack = "com.runspeedai.credits.starter"
    case proPack = "com.runspeedai.credits.pro"
    case megaPack = "com.runspeedai.credits.mega"
    case ultraPack = "com.runspeedai.credits.ultra"
}

struct PurchaseCreditsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @StateObject private var purchaseManager = StoreKitPurchaseManager.shared

    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingError = false
    @State private var showingRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("Buy Credits")
                                .font(
                                    .system(
                                        size: 26, weight: .bold,
                                        design: .rounded)
                                )
                                .foregroundColor(.primary)
                        }

                        Text("Choose a credit package")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Current Balance Display
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Text("Current Balance")
                                .font(
                                    .system(
                                        size: 14, weight: .semibold,
                                        design: .rounded)
                                )
                                .foregroundColor(.secondary)

                            if let userId = authViewModel.user?.id {
                                Text(creditsViewModel.formattedBalance())
                                    .font(
                                        .system(
                                            size: 16, weight: .bold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)
                            } else {
                                Text("Please log in to view your balance")
                                    .font(
                                        .system(
                                            size: 14, weight: .medium,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        // Credits never expire disclosure
                        if authViewModel.user?.id != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                Text("Credits never expire")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)

                    // Credit Packages
                    VStack(spacing: 12) {
                        SectionHeader(title: "Save with Web Purchase", subtitle: "30% off on all packs")

                        // Combined Web Purchase Card
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text("Save 30%")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)

                                Text("Best Deal")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.purple)
                                    )

                                Spacer()
                            }

                            Text("Purchase directly through our website to save on all credit packs.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)

                            Button(action: {
                                if let url = URL(string: "https://www.runspeedai.store") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "safari.fill")
                                        .font(.system(size: 16))
                                    Text("Purchase on Website")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                        SectionHeader(title: "In-App Credit Packs", subtitle: "Instant access in the app")

                        CreditPackageCard(
                            title: "Test Pack",
                            baseCreditsValue: 1.00,
                            totalPrice: 2.99,
                            productId: .testPack,
                            description: "Good for testing photos",
                            isPurchasing: $isPurchasing,
                            onPurchase: handlePurchase
                        )

                        CreditPackageCard(
                            title: "Starter Pack",
                            baseCreditsValue: 5.00,
                            totalPrice: 7.99,
                            productId: .starterPack,
                            description: "Perfect for trying out features",
                            isPurchasing: $isPurchasing,
                            onPurchase: handlePurchase
                        )

                        CreditPackageCard(
                            title: "Pro Pack",
                            baseCreditsValue: 10.00,
                            totalPrice: 15.99,
                            productId: .proPack,
                            badge: "Most Popular",
                            description: "Good for testing videos",
                            isPurchasing: $isPurchasing,
                            onPurchase: handlePurchase
                        )

                        CreditPackageCard(
                            title: "Mega Pack",
                            baseCreditsValue: 20.00,
                            totalPrice: 29.99,
                            productId: .megaPack,
                            description: "Great for regular content creation",
                            isPurchasing: $isPurchasing,
                            onPurchase: handlePurchase
                        )

                        CreditPackageCard(
                            title: "Ultra Pack",
                            baseCreditsValue: 50.00,
                            totalPrice: 72.99,
                            productId: .ultraPack,
                            badge: "Best Value",
                            description: "Ideal for power users and bulk projects",
                            isPurchasing: $isPurchasing,
                            onPurchase: handlePurchase
                        )
                    }
                    .padding(.horizontal)

                    // Legal disclosures
                    VStack(spacing: 8) {
                        Text("Payment will be charged to your Apple ID account at confirmation of purchase. Credits are consumable and non-refundable. Credits never expire.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Button(action: handleRestorePurchases) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11))
                                    Text("Restore Purchases")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                }
                            }
                            .foregroundColor(.blue)

                            Button("Terms of Use") {
                                // TODO: Open Terms of Use URL
                                if let url = URL(string: "https://www.runspeedai.store/terms") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(size: 11, weight: .medium, design: .rounded))

                            Button("Privacy Policy") {
                                // TODO: Open Privacy Policy URL
                                if let url = URL(string: "https://www.runspeedai.store/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    Spacer(minLength: 100)
                }
            }
                    .background(Color(.systemGroupedBackground))
            .disabled(isPurchasing)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let userId = authViewModel.user?.id {
                    Task {
                        await creditsViewModel.fetchBalance(userId: userId)
                    }
                }
                
                // Load products from StoreKit
                Task {
                    await purchaseManager.loadProducts()
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("CreditsBalanceUpdated"))
            ) { notification in
                // Refresh credits when balance is updated (e.g., after image/video generation)
                if let userId = authViewModel.user?.id {
                    Task {
                        await creditsViewModel.fetchBalance(userId: userId)
                    }
                }
            }
            .alert("Purchase Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(purchaseError ?? "An unknown error occurred")
            }
            .alert("Restore Purchases", isPresented: $showingRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreMessage)
            }
            .alert("Purchase Successful", isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) {
                    // Refresh balance after successful purchase
                    if let userId = authViewModel.user?.id {
                        Task {
                            await creditsViewModel.fetchBalance(userId: userId)
                        }
                    }
                }
            } message: {
                Text(successMessage)
            }
            .overlay {
                if isPurchasing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Processing...")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground).opacity(0.95))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Purchase Handlers

    private func handlePurchase(productId: CreditProductID, credits: Double) {
        guard let userId = authViewModel.user?.id else {
            purchaseError = "Please sign in to purchase credits"
            showingError = true
            return
        }
        
        guard let product = purchaseManager.getProduct(for: productId.rawValue) else {
            purchaseError = "Product not available. Please try again later."
            showingError = true
            return
        }
        
        isPurchasing = true
        
        Task {
            do {
                let success = try await purchaseManager.purchase(product, userId: userId)
                
                if success {
                    await MainActor.run {
                        isPurchasing = false
                        let creditAmount = purchaseManager.getCreditAmount(for: productId.rawValue)
                        successMessage = "Successfully purchased \(PricingManager.dollarsToCredits(Decimal(creditAmount))) credits!"
                        showingSuccessAlert = true
                        
                        // Refresh balance
                        Task {
                            await creditsViewModel.fetchBalance(userId: userId)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    
                    // Don't show error for user cancellation
                    if (error as NSError).code != -2 {
                        purchaseError = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }

    private func handleRestorePurchases() {
        guard let userId = authViewModel.user?.id else {
            restoreMessage = "Please sign in to restore purchases"
            showingRestoreAlert = true
            return
        }
        
        Task {
            do {
                try await purchaseManager.restorePurchases(userId: userId)
                await MainActor.run {
                    restoreMessage = "Purchases restored successfully"
                    showingRestoreAlert = true
                }
            } catch {
                await MainActor.run {
                    restoreMessage = error.localizedDescription
                    showingRestoreAlert = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getProductTitle(for productId: CreditProductID) -> String {
        switch productId {
        case .testPack: return "Test Pack"
        case .starterPack: return "Starter Pack"
        case .proPack: return "Pro Pack"
        case .megaPack: return "Mega Pack"
        case .ultraPack: return "Ultra Pack"
        }
    }
    
    private func getProductDescription(for productId: CreditProductID) -> String {
        switch productId {
        case .testPack: return "Good for testing photos"
        case .starterPack: return "Perfect for trying out features"
        case .proPack: return "Good for testing videos"
        case .megaPack: return "Great for regular content creation"
        case .ultraPack: return "Ideal for power users and bulk projects"
        }
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

// Credit package card
struct CreditPackageCard: View {
    let title: String
    let baseCreditsValue: Double  // This is the credits amount
    let totalPrice: Decimal  // StoreKit Product.price (Decimal)
    let productId: CreditProductID
    var badge: String? = nil
    var description: String? = nil
    @Binding var isPurchasing: Bool
    var onPurchase: (CreditProductID, Double) -> Void
    var storeKitProduct: Product? = nil

    @State private var isDetailsExpanded: Bool = false
    @State private var showAllImageModels: Bool = false
    @State private var showAllVideoModels: Bool = false
    private let initialModelsToShow = 4

    // Image model prices from PricingManager
    private let imageModelPrices: [String: Double] = [
        "Z-Image-Turbo": 0.005,
        "FLUX.2 [dev]": 0.0122,
        "Wan2.5-Preview Image": 0.027,
        "Seedream 4.0": 0.03,
        "GPT Image 1.5": 0.034,
        "Google Gemini Flash 2.5 (Nano Banana)": 0.039,
        "Seedream 4.5": 0.04,
        "FLUX.1 Kontext [pro]": 0.04,
        "FLUX.1 Kontext [max]": 0.08,
    ]

    private let imageModelImageNames: [String: String] = [
        "Z-Image-Turbo": "zimageturbo",
        "FLUX.2 [dev]": "flux2dev",
        "Wan2.5-Preview Image": "wan25previewimage",
        "Seedream 4.0": "seedream40",
        "GPT Image 1.5": "gptimage15",
        "Google Gemini Flash 2.5 (Nano Banana)": "geminiflashimage25",
        "Seedream 4.5": "seedream45",
        "FLUX.1 Kontext [pro]": "fluxkontextpro",
        "FLUX.1 Kontext [max]": "fluxkontextmax",
    ]

    private let imageModelShortNames: [String: String] = [
        "Z-Image-Turbo": "Z-Image Turbo",
        "FLUX.2 [dev]": "FLUX.2",
        "Wan2.5-Preview Image": "Wan2.5",
        "Seedream 4.0": "Seedream 4.0",
        "GPT Image 1.5": "GPT Image",
        "Google Gemini Flash 2.5 (Nano Banana)": "Gemini Flash",
        "Seedream 4.5": "Seedream 4.5",
        "FLUX.1 Kontext [pro]": "Kontext Pro",
        "FLUX.1 Kontext [max]": "Kontext Max",
    ]

    // Video model prices (using cheapest options)
    private let videoModelPrices: [String: Double] = [
        "Seedance 1.0 Pro Fast": 0.0304,  // 5s at 480p (cheapest)
        "Sora 2": 0.4,  // 4s at 720p (cheapest)
        "KlingAI 2.5 Turbo Pro": 0.35,  // 5s at 1080p
        "Wan2.6": 0.5,  // 5s at 720p (cheapest)
        "Kling VIDEO 2.6 Pro": 0.70,  // 5s at 1080p
        "Google Veo 3.1 Fast": 1.20,  // 8s at 1080p (only option)
    ]

    private let videoModelImageNames: [String: String] = [
        "Seedance 1.0 Pro Fast": "seedance10profast",
        "Sora 2": "sora2",
        "KlingAI 2.5 Turbo Pro": "klingai25turbopro",
        "Wan2.6": "wan26",
        "Kling VIDEO 2.6 Pro": "klingvideo26pro",
        "Google Veo 3.1 Fast": "veo31fast",
    ]

    private let videoModelShortNames: [String: String] = [
        "Seedance 1.0 Pro Fast": "Seedance",
        "Sora 2": "Sora 2",
        "KlingAI 2.5 Turbo Pro": "Kling 2.5",
        "Wan2.6": "Wan2.6",
        "Kling VIDEO 2.6 Pro": "Kling 2.6",
        "Google Veo 3.1 Fast": "Veo 3.1",
    ]

    private let videoModelDurations: [String: String] = [
        "Seedance 1.0 Pro Fast": "5s",
        "Sora 2": "4s",
        "KlingAI 2.5 Turbo Pro": "5s",
        "Wan2.6": "5s",
        "Kling VIDEO 2.6 Pro": "5s",
        "Google Veo 3.1 Fast": "8s",
    ]

    // Calculate actual image generation range based on all models
    private var imageGenerationsRange: (min: Int, max: Int) {
        var minImages = Int.max
        var maxImages = 0

        for (_, price) in imageModelPrices {
            guard price > 0 else { continue }
            let count = Int(baseCreditsValue / price)
            if count > 0 {
                minImages = min(minImages, count)
                maxImages = max(maxImages, count)
            }
        }

        return (min: minImages == Int.max ? 0 : minImages, max: maxImages)
    }

    // Calculate actual video generation range based on all models
    private var videoGenerationsRange: (min: Int, max: Int) {
        var minVideos = Int.max
        var maxVideos = 0

        for (_, price) in videoModelPrices {
            guard price > 0 else { continue }
            let count = Int(baseCreditsValue / price)
            if count > 0 {
                minVideos = min(minVideos, count)
                maxVideos = max(maxVideos, count)
            }
        }

        return (min: minVideos == Int.max ? 0 : minVideos, max: maxVideos)
    }

    // Get all image models that can be afforded
    private var allImageModels: [(name: String, shortName: String, imageName: String, count: Int)] {
        return imageModelPrices.compactMap { (modelName, price) in
            guard price > 0 else { return nil }
            guard baseCreditsValue >= price else { return nil }
            let count = Int(baseCreditsValue / price)
            guard count > 0 else { return nil }
            let imageName = imageModelImageNames[modelName] ?? ""
            let shortName = imageModelShortNames[modelName] ?? modelName
            return (name: modelName, shortName: shortName, imageName: imageName, count: count)
        }
        .sorted { $0.count > $1.count }  // Sort by count descending
    }

    // Get all video models that can be afforded (using lowest settings/duration)
    private var allVideoModels: [(name: String, shortName: String, imageName: String, count: Int, duration: String)] {
        return videoModelPrices.compactMap { (modelName, price) in
            guard price > 0 else { return nil }
            guard baseCreditsValue >= price else { return nil }
            let count = Int(baseCreditsValue / price)
            guard count > 0 else { return nil }
            let imageName = videoModelImageNames[modelName] ?? ""
            let shortName = videoModelShortNames[modelName] ?? modelName
            let duration = videoModelDurations[modelName] ?? ""
            return (name: modelName, shortName: shortName, imageName: imageName, count: count, duration: duration)
        }
        .sorted { $0.count > $1.count }  // Sort by count descending
    }

    // Displayed models based on expansion state
    private var displayedImageModels: [(name: String, shortName: String, imageName: String, count: Int)] {
        showAllImageModels ? allImageModels : Array(allImageModels.prefix(initialModelsToShow))
    }

    private var displayedVideoModels: [(name: String, shortName: String, imageName: String, count: Int, duration: String)] {
        showAllVideoModels ? allVideoModels : Array(allVideoModels.prefix(initialModelsToShow))
    }

    private var hiddenImageModelsCount: Int {
        max(0, allImageModels.count - initialModelsToShow)
    }

    private var hiddenVideoModelsCount: Int {
        max(0, allVideoModels.count - initialModelsToShow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content - tappable for purchase
            Button(action: {
                guard !isPurchasing else { return }
                onPurchase(productId, baseCreditsValue)
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    // Header: Title, Credits, and Price
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(title)
                                    .font(
                                        .system(
                                            size: 18, weight: .bold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)

                                if let badge = badge {
                                    Text(badge)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(badgeColor(for: badge))
                                        .clipShape(Capsule())
                                }
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text(
                                    "\(PricingManager.dollarsToCredits(Decimal(baseCreditsValue)))"
                                )
                                .font(
                                    .system(
                                        size: 16, weight: .semibold,
                                        design: .rounded)
                                )
                                .foregroundColor(.primary)
                                Text("credits")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if let product = storeKitProduct {
                                Text(product.displayPrice)
                                    .font(
                                        .system(
                                            size: 22, weight: .bold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)
                            } else {
                                // Fallback to formatted decimal
                                Text(formatPrice(totalPrice))
                                    .font(
                                        .system(
                                            size: 22, weight: .bold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)
                            }
                            Text("Total Price")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Description and Details button row
                    HStack {
                        if let description = description {
                            Text(description)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            withAnimation(
                                .spring(response: 0.3, dampingFraction: 0.8)
                            ) {
                                isDetailsExpanded.toggle()
                            }
                        }) {
                            Text(isDetailsExpanded ? "Hide ▴" : "Details ▾")
                                .font(
                                    .system(
                                        size: 13, weight: .medium,
                                        design: .rounded)
                                )
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Expanded details section - Estimated Generations
                    if isDetailsExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            // Divider
                            Divider()
                                .padding(.vertical, 4)

                            // Estimated Generations Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Estimated Generations")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)

                                // Image Models Grid
                                if !displayedImageModels.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.blue)
                                            Text("Images")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }

                                        // Models in horizontal flowing layout
                                        FlowLayout(spacing: 8) {
                                            ForEach(displayedImageModels, id: \.name) { model in
                                                EstimatedGenerationChip(
                                                    imageName: model.imageName,
                                                    modelName: model.shortName,
                                                    count: model.count
                                                )
                                            }

                                            // "+ More models" button
                                            if hiddenImageModelsCount > 0 && !showAllImageModels {
                                                Button(action: {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        showAllImageModels = true
                                                    }
                                                }) {
                                                    Text("+ \(hiddenImageModelsCount) more")
                                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                                        .foregroundColor(.blue)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill(Color.blue.opacity(0.1))
                                                        )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                }

                                // Video Models Grid
                                if !displayedVideoModels.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "video.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.purple)
                                            Text("Videos")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }

                                        // Models in horizontal flowing layout
                                        FlowLayout(spacing: 8) {
                                            ForEach(displayedVideoModels, id: \.name) { model in
                                                EstimatedGenerationChip(
                                                    imageName: model.imageName,
                                                    modelName: model.shortName,
                                                    count: model.count,
                                                    subtitle: model.duration
                                                )
                                            }

                                            // "+ More models" button
                                            if hiddenVideoModelsCount > 0 && !showAllVideoModels {
                                                Button(action: {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        showAllVideoModels = true
                                                    }
                                                }) {
                                                    Text("+ \(hiddenVideoModelsCount) more")
                                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                                        .foregroundColor(.blue)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill(Color.blue.opacity(0.1))
                                                        )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                }

                                // Estimates note
                                Text("Estimates vary based on model and settings chosen")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())

        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Helper to format Decimal price
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: price as NSDecimalNumber) ?? "$0.00"
    }

    // Helper to get badge color based on badge type
    private func badgeColor(for badge: String) -> Color {
        switch badge.lowercased() {
        case "most popular":
            return .orange
        case "best value":
            return .green
        default:
            return .blue
        }
    }
}

// MARK: - Flow Layout for wrapping model chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)

                if currentX + viewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, viewSize.height)
                currentX += viewSize.width + spacing
                size.width = max(size.width, currentX - spacing)
            }

            size.height = currentY + lineHeight
        }
    }
}

// MARK: - Estimated Generation Chip

struct EstimatedGenerationChip: View {
    let imageName: String
    let modelName: String
    let count: Int
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("\(count)x")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(modelName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}
