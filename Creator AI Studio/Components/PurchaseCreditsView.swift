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

    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingError = false
    @State private var showingRestoreAlert = false
    @State private var restoreMessage = ""

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

                    // Web Purchase Button with Badge
                    VStack(spacing: 12) {
                        Button(action: {
                            if let url = URL(string: "https://runspeed.ai/purchase") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "safari.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        Text("Purchase on Website")
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Text("Save 30% on all credit packs")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("Save 30%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.green.opacity(0.2))
                                    )
                            }
                            .padding(.vertical, 18)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)

                    // Current Balance Display
                    if let userId = authViewModel.user?.id {
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

                                Text(creditsViewModel.formattedBalance())
                                    .font(
                                        .system(
                                            size: 16, weight: .bold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)
                                Spacer()
                            }

                            // Credits never expire disclosure
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                Text("Credits never expire")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                    }

                    // Credit Packages
                    VStack(spacing: 12) {
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
                            description: "Good for testing videos",
                            isPurchasing: $isPurchasing,
                            onPurchase: handlePurchase
                        )

                        CreditPackageCard(
                            title: "Mega Pack",
                            baseCreditsValue: 20.00,
                            totalPrice: 29.99,
                            productId: .megaPack,
                            badge: "Best Value",
                            description: "Great for regular content creation",
                            isPurchasing: $isPurchasing,
                            onPurchase: handlePurchase
                        )

                        CreditPackageCard(
                            title: "Ultra Pack",
                            baseCreditsValue: 50.00,
                            totalPrice: 72.99,
                            productId: .ultraPack,
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
                                if let url = URL(string: "https://runspeed.ai/terms") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(size: 11, weight: .medium, design: .rounded))

                            Button("Privacy Policy") {
                                // TODO: Open Privacy Policy URL
                                if let url = URL(string: "https://runspeed.ai/privacy") {
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
        // TODO: Implement StoreKit purchase
        // 1. Fetch product from App Store using productId.rawValue
        // 2. Call product.purchase()
        // 3. Handle transaction result
        // 4. On success, add credits to user's balance via CreditsManager
        // 5. Finish transaction

        print("Purchase requested for \(productId.rawValue) with \(credits) credits")

        // Placeholder for StoreKit integration
        isPurchasing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isPurchasing = false
            // Remove this placeholder when implementing real StoreKit
            purchaseError = "StoreKit not yet configured. Please set up products in App Store Connect."
            showingError = true
        }
    }

    private func handleRestorePurchases() {
        // TODO: Implement restore purchases
        // Note: Consumables cannot be restored, but Apple requires this button
        // Show appropriate message to user

        restoreMessage = "Credits are consumable purchases and cannot be restored. If you believe there was an issue with a recent purchase, please contact support."
        showingRestoreAlert = true
    }
}

// Credit package card
struct CreditPackageCard: View {
    let title: String
    let baseCreditsValue: Double  // This is the credits amount
    let totalPrice: Double  // Manually set total price (placeholder until StoreKit provides real price)
    let productId: CreditProductID
    var badge: String? = nil
    var description: String? = nil
    @Binding var isPurchasing: Bool
    var onPurchase: (CreditProductID, Double) -> Void

    @State private var isDetailsExpanded: Bool = false

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
    private var exampleImageModels:
        [(name: String, imageName: String, count: Int)]
    {
        return imageModelPrices.compactMap { (modelName, price) in
            guard price > 0 else { return nil }
            guard baseCreditsValue >= price else { return nil }
            let count = Int(baseCreditsValue / price)
            guard count > 0 else { return nil }
            let imageName = imageModelImageNames[modelName] ?? ""
            return (name: modelName, imageName: imageName, count: count)
        }
        .sorted { $0.count > $1.count }  // Sort by count descending
    }

    // Get all video models that can be afforded (using lowest settings/duration)
    private var exampleVideoModels:
        [(name: String, imageName: String, count: Int)]
    {
        return videoModelPrices.compactMap { (modelName, price) in
            guard price > 0 else { return nil }
            guard baseCreditsValue >= price else { return nil }
            let count = Int(baseCreditsValue / price)
            guard count > 0 else { return nil }
            let imageName = videoModelImageNames[modelName] ?? ""
            return (name: modelName, imageName: imageName, count: count)
        }
        .sorted { $0.count > $1.count }  // Sort by count descending
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
                                        .background(Color.blue)
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
                            Text(PriceCalculator.formatPrice(totalPrice))
                                .font(
                                    .system(
                                        size: 22, weight: .bold,
                                        design: .rounded)
                                )
                                .foregroundColor(.primary)
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

                    // Expanded details section - What You Get
                    if isDetailsExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            // Divider
                            Divider()
                                .padding(.vertical, 4)

                            // What You Get Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("What You Get")
                                    .font(
                                        .system(
                                            size: 14, weight: .semibold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 4)

                                // Checklist items
                                VStack(alignment: .leading, spacing: 12) {
                                    // Credits
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(
                                            systemName: "dollarsign.circle.fill"
                                        )
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                        .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2)
                                        {
                                            Text(
                                                "\(PricingManager.dollarsToCredits(Decimal(baseCreditsValue))) Credits"
                                            )
                                            .font(
                                                .system(
                                                    size: 13, weight: .medium,
                                                    design: .rounded)
                                            )
                                            .foregroundColor(.primary)
                                            Text(
                                                "Use for images, videos, or any combination"
                                            )
                                            .font(
                                                .system(
                                                    size: 11, design: .rounded)
                                            )
                                            .foregroundColor(.secondary)
                                        }
                                    }

                                    // Images section
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(
                                                systemName:
                                                    "photo.on.rectangle.angled"
                                            )
                                            .font(.system(size: 16))
                                            .foregroundColor(.blue)
                                            .frame(width: 20)

                                            VStack(
                                                alignment: .leading, spacing: 4
                                            ) {
                                                Text(
                                                    imageGenerationsRange.min
                                                        == imageGenerationsRange
                                                        .max
                                                        ? "\(imageGenerationsRange.max) Images"
                                                        : "\(imageGenerationsRange.min)–\(imageGenerationsRange.max) Images"
                                                )
                                                .font(
                                                    .system(
                                                        size: 13,
                                                        weight: .medium,
                                                        design: .rounded)
                                                )
                                                .foregroundColor(.primary)

                                                Text(
                                                    "Depending on model chosen"
                                                )
                                                .font(
                                                    .system(
                                                        size: 11,
                                                        design: .rounded)
                                                )
                                                .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        // Example image models - aligned to left edge
                                        if !exampleImageModels.isEmpty {
                                            VStack(
                                                alignment: .leading,
                                                spacing: 4
                                            ) {
                                                ForEach(
                                                    exampleImageModels,
                                                    id: \.name
                                                ) { model in
                                                    HStack(
                                                        alignment: .top,
                                                        spacing: 8
                                                    ) {
                                                        if !model
                                                            .imageName
                                                            .isEmpty
                                                        {
                                                            Image(
                                                                model
                                                                    .imageName
                                                            )
                                                            .resizable()
                                                            .aspectRatio(
                                                                contentMode:
                                                                    .fit
                                                            )
                                                            .frame(
                                                                width:
                                                                    30,
                                                                height:
                                                                    30)
                                                        }
                                                        VStack(
                                                            alignment:
                                                                .leading,
                                                            spacing: 2
                                                        ) {
                                                            Text(
                                                                model
                                                                    .name
                                                            )
                                                            .font(
                                                                .system(
                                                                    size:
                                                                        12,
                                                                    weight:
                                                                        .semibold,
                                                                    design:
                                                                        .rounded
                                                                )
                                                            )
                                                            .foregroundColor(
                                                                .white)
                                                            Text(
                                                                "For \(PriceCalculator.formatPrice(baseCreditsValue)) you can run this model approximately \(model.count) times"
                                                            )
                                                            .font(
                                                                .system(
                                                                    size:
                                                                        11,
                                                                    design:
                                                                        .rounded
                                                                )
                                                            )
                                                            .foregroundColor(
                                                                .secondary
                                                            )
                                                            .italic()
                                                        }
                                                        Spacer()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Videos section
                                    if videoGenerationsRange.max > 0 {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(alignment: .top, spacing: 10) {
                                                Image(systemName: "video.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.purple)
                                                    .frame(width: 20)

                                                VStack(
                                                    alignment: .leading,
                                                    spacing: 4
                                                ) {
                                                    Text(
                                                        videoGenerationsRange
                                                            .min
                                                            == videoGenerationsRange
                                                            .max
                                                            ? "\(videoGenerationsRange.max) Videos"
                                                            : "\(videoGenerationsRange.min)–\(videoGenerationsRange.max) Videos"
                                                    )
                                                    .font(
                                                        .system(
                                                            size: 13,
                                                            weight: .medium,
                                                            design: .rounded)
                                                    )
                                                    .foregroundColor(.primary)
                                                    Text(
                                                        "Based on lowest settings and shortest duration"
                                                    )
                                                    .font(
                                                        .system(
                                                            size: 11,
                                                            design: .rounded)
                                                    )
                                                    .foregroundColor(.secondary)
                                                }
                                            }
                                            
                                            // Example video models - aligned to left edge
                                            if !exampleVideoModels.isEmpty {
                                                VStack(
                                                    alignment: .leading,
                                                    spacing: 4
                                                ) {
                                                    ForEach(
                                                        exampleVideoModels,
                                                        id: \.name
                                                    ) { model in
                                                        HStack(
                                                            alignment: .top,
                                                            spacing: 8
                                                        ) {
                                                            if !model
                                                                .imageName
                                                                .isEmpty
                                                            {
                                                                Image(
                                                                    model
                                                                        .imageName
                                                                )
                                                                .resizable()
                                                                .aspectRatio(
                                                                    contentMode:
                                                                        .fit
                                                                )
                                                                .frame(
                                                                    width:
                                                                        30,
                                                                    height:
                                                                        30
                                                                )
                                                            }
                                                            VStack(
                                                                alignment:
                                                                    .leading,
                                                                spacing: 2
                                                            ) {
                                                                Text(
                                                                    model
                                                                        .name
                                                                )
                                                                .font(
                                                                    .system(
                                                                        size:
                                                                            12,
                                                                        weight:
                                                                            .semibold,
                                                                        design:
                                                                            .rounded
                                                                    )
                                                                )
                                                                .foregroundColor(
                                                                    .white
                                                                )
                                                                Text(
                                                                    "For \(PriceCalculator.formatPrice(baseCreditsValue)) you can run this model approximately \(model.count) times (lowest settings)"
                                                                )
                                                                .font(
                                                                    .system(
                                                                        size:
                                                                            11,
                                                                        design:
                                                                            .rounded
                                                                    )
                                                                )
                                                                .foregroundColor(
                                                                    .secondary
                                                                )
                                                                .italic()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
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
}
