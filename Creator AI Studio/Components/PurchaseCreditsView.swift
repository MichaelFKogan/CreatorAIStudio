//
//  PurchaseCreditsView.swift
//  Creator AI Studio
//
//  Created for purchase credits UI
//

import SwiftUI
import StoreKit

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
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var purchaseManager = StoreKitPurchaseManager.shared

    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingError = false
    @State private var showingRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showSignInSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.purple)

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

                        if authViewModel.user == nil {
                            HStack(spacing: 6) {
                                Text("Log in to purchase credits")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button(action: { showSignInSheet = true }) {
                                    Text("Sign In / Sign Up")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.purple)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.top, 12)

                    // Credit Packages
                    VStack(spacing: 12) {
                        SectionHeader(title: "Save with Web Purchase", subtitle: "30% off on all packs")

                        // Combined Web Purchase Card
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Purchase On Website")
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
                                    Text("SAVE 30%")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .padding(.horizontal)
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

                        Divider()

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
                        Text("Payment will be charged to your Apple ID account at confirmation of purchase. Credits are consumable and non-refundable. Credits expire after 90 days.")
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
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .disabled(isPurchasing)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
            .sheet(isPresented: $showSignInSheet) {
                SignInView()
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
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
                        successMessage = "Successfully purchased \(PricingManager.formatCredits(Decimal(creditAmount))) credits!"
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
    // Featured image models (matching website display)
    private let imageModelRates: [(name: String, imageName: String, price: Double)] = [
        (name: "Z-Image-Turbo", imageName: "zimageturbo", price: 0.005),
        (name: "Nano Banana", imageName: "geminiflashimage25", price: 0.039),
        (name: "Seedream 4.5", imageName: "seedream45", price: 0.04),
    ]

    // Featured video models (matching website display)
    private let videoModelRates: [(name: String, imageName: String, price: Double, duration: String)] = [
        (name: "Kling Video 2.6 Pro", imageName: "klingvideo26pro", price: 0.70, duration: "5s"),
        (name: "Sora 2", imageName: "sora2", price: 0.80, duration: "8s"),
        (name: "Veo 3.1 Fast", imageName: "veo31fast", price: 1.20, duration: "8s"),
    ]

    // Estimated generations based on average model prices
    private var estimatedImages: Int {
        // Use average of featured image model prices for a representative estimate
        let avgImagePrice = imageModelRates.map { $0.price }.reduce(0, +) / Double(imageModelRates.count)
        guard avgImagePrice > 0 else { return 0 }
        return Int(baseCreditsValue / avgImagePrice)
    }

    private var estimatedVideos: Int {
        // Use average of featured video model prices for a representative estimate
        let avgVideoPrice = videoModelRates.map { $0.price }.reduce(0, +) / Double(videoModelRates.count)
        guard avgVideoPrice > 0 else { return 0 }
        return Int(baseCreditsValue / avgVideoPrice)
    }

    /// SF Symbol name for the pack title (distinct icon per pack)
    private var titleIconName: String {
        switch productId {
        case .testPack: return "flask.fill"
        case .starterPack: return "star.fill"
        case .proPack: return "crown.fill"
        case .megaPack: return "flame.fill"
        case .ultraPack: return "sparkles"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content - full card tappable for purchase; Details button stays separate
            Button(action: {
                guard !isPurchasing else { return }
                onPurchase(productId, baseCreditsValue)
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    // Header: Credits (dominant), Title, and Price
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Credits first — primary decision factor, large and scannable
                            HStack(spacing: 6) {
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple)
                                Text(
                                    PricingManager.formatCredits(
                                        Decimal(baseCreditsValue)
                                    )
                                )
                                .font(
                                    .system(
                                        size: 20, weight: .bold,
                                        design: .rounded)
                                )
                                .monospacedDigit()
                                .foregroundColor(.primary)
                                Text("credits")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            // Pack name below — label size
                            HStack(spacing: 8) {
                                Image(systemName: titleIconName)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(title)
                                    .font(
                                        .system(
                                            size: 14, weight: .semibold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.secondary)

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

                            // Estimated generations summary
                            HStack(spacing: 8) {
                                // Estimated images badge
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.blue)
                                    Text("~\(estimatedImages) images")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )

                                // Estimated videos badge
                                HStack(spacing: 4) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.purple)
                                    Text("~\(estimatedVideos) videos")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.purple.opacity(0.1))
                                )
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if let product = storeKitProduct {
                                Text(product.displayPrice)
                                    .font(
                                        .system(
                                            size: 20, weight: .bold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)
                            } else {
                                // Fallback to formatted decimal
                                Text(formatPrice(totalPrice))
                                    .font(
                                        .system(
                                            size: 20, weight: .bold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)
                            }
                            Text("Total Price")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                            Text("Tap to purchase")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }

                    // Description and Details button row (Details is its own tap target)
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
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                                .contentShape(Rectangle())
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
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Estimated Generations")
                                    .font(
                                        .system(
                                            size: 14, weight: .semibold,
                                            design: .rounded)
                                    )
                                    .foregroundColor(.primary)

                                if !imageModelRates.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Image Models")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)

                                        ForEach(imageModelRates, id: \.name) { model in
                                            HStack(alignment: .center, spacing: 12) {
                                                // Circular thumbnail with background card
                                                if !model.imageName.isEmpty {
                                                    Image(model.imageName)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 36, height: 36)
                                                        .clipShape(Circle())
                                                        .overlay(
                                                            Circle()
                                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                        )
                                                        .background(
                                                            Circle()
                                                                .fill(Color(.secondarySystemBackground))
                                                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                                        )
                                                }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(model.name)
                                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                        .foregroundColor(.primary)
                                                    Text("\(PricingManager.formatCredits(Decimal(model.price))) credits per generation")
                                                        .font(.system(size: 10, design: .rounded))
                                                        .foregroundColor(.secondary)
                                                }

                                                Spacer()

                                                // Generation count multiplier
                                                Text("\(calculateGenerations(credits: baseCreditsValue, price: model.price))x")
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color(.tertiarySystemBackground))
                                            )
                                        }
                                    }
                                }

                                if !videoModelRates.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Video Models")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)

                                        ForEach(videoModelRates, id: \.name) { model in
                                            HStack(alignment: .center, spacing: 12) {
                                                // Circular thumbnail with background card
                                                if !model.imageName.isEmpty {
                                                    Image(model.imageName)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 36, height: 36)
                                                        .clipShape(Circle())
                                                        .overlay(
                                                            Circle()
                                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                        )
                                                        .background(
                                                            Circle()
                                                                .fill(Color(.secondarySystemBackground))
                                                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                                        )
                                                }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(model.name)
                                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                        .foregroundColor(.primary)
                                                    Text("\(PricingManager.formatCredits(Decimal(model.price))) credits per generation • \(model.duration)")
                                                        .font(.system(size: 10, design: .rounded))
                                                        .foregroundColor(.secondary)
                                                }

                                                Spacer()

                                                // Generation count multiplier
                                                Text("\(calculateGenerations(credits: baseCreditsValue, price: model.price))x")
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color(.tertiarySystemBackground))
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
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

    // Helper to calculate number of generations possible
    private func calculateGenerations(credits: Double, price: Double) -> Int {
        guard price > 0 else { return 0 }
        return Int(credits / price)
    }
}
