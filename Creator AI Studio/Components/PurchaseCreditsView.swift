//
//  PurchaseCreditsView.swift
//  Creator AI Studio
//
//  Created for purchase balance UI
//

import SwiftUI

enum PaymentMethod: String, CaseIterable {
    case external = "External"
    case apple = "Apple"

    var displayName: String {
        switch self {
        case .apple:
            return "Apple Payment"
        case .external:
            return "Credit Card"
        }
    }

    var icon: String {
        switch self {
        case .apple:
            return "applelogo"
        case .external:
            return "creditcard.fill"
        }
    }
}

// Price calculation helpers
struct PriceCalculator {
    // Calculate price with Apple's 30% markup
    static func calculateApplePrice(basePrice: Double) -> Double {
        return basePrice * 1.30
    }

    // Calculate price with external processing (3% + $0.30)
    // Round the 3% portion up, then add $0.30, then round total up
    static func calculateExternalPrice(basePrice: Double) -> Double {
        // Calculate 3% and round up to nearest cent
        let percentageFee = ceil(basePrice * 0.03 * 100) / 100
        // Add flat $0.30 fee
        let totalFee = percentageFee + 0.30
        let total = basePrice + totalFee
        // Round total up to nearest cent
        return ceil(total * 100) / 100
    }

    // Calculate external fee amount (based on rounded total)
    static func calculateExternalFee(basePrice: Double) -> Double {
        let total = calculateExternalPrice(basePrice: basePrice)
        // Fee is the difference between rounded total and base price
        return total - basePrice
    }

    // Format price as string
    static func formatPrice(_ price: Double) -> String {
        return String(format: "$%.2f", price)
    }
}

struct PurchaseCreditsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var showPaywallView = false
    @State private var showWebPurchaseLinkAlert = false

    private let paymentMethod: PaymentMethod = .apple

    private var webCreditsPurchaseURL: URL? {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "WEB_CREDITS_PURCHASE_URL") as? String
        else {
            return nil
        }

        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return nil
        }

        return url
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Add Balance")
                            .font(
                                .system(
                                    size: 26, weight: .bold, design: .rounded)
                            )
                            .foregroundColor(.primary)

                        Text("Choose an amount to add to your wallet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Current balance display
                        if authViewModel.user?.id != nil {
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.green)
                                Text("Current Balance:")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(creditsViewModel.formattedBalance())
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // Apple-only + web checkout option
                    VStack(spacing: 10) {
                        Button {
                            guard let url = webCreditsPurchaseURL else {
                                showWebPurchaseLinkAlert = true
                                return
                            }
                            openURL(url)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Save 30%")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.95))
                        }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.purple.opacity(0.28), radius: 12, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.35))
                                .frame(height: 1)
                            Text("Other options")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.35))
                                .frame(height: 1)
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal)

                    // Balance Packages
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("Apple In‑App Purchase")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        CreditPackageCard(
                            title: "Test Pack",
                            baseCreditsValue: 1.00,
                            paymentMethod: paymentMethod,
                            onPurchase: {
                                showPaywallView = true
                            },
                            description: "Good for testing photos",
                            manualPrice: 2.99  // Set your manual price here
                        )

                        CreditPackageCard(
                            title: "Starter Pack",
                            baseCreditsValue: 5.00,
                            paymentMethod: paymentMethod,
                            onPurchase: {
                                showPaywallView = true
                            },
                            description: "Perfect for trying out features",
                            manualPrice: 7.99  // Set your manual price here
                        )

                        CreditPackageCard(
                            title: "Pro Pack",
                            baseCreditsValue: 10.00,
                            paymentMethod: paymentMethod,
                            onPurchase: {
                                showPaywallView = true
                            },
                            description: "Good for testing videos",
                            manualPrice: 14.99  // Set your manual price here
                        )

                        CreditPackageCard(
                            title: "Mega Pack",
                            baseCreditsValue: 20.00,
                            paymentMethod: paymentMethod,
                            onPurchase: {
                                showPaywallView = true
                            },
                            badge: "Best Value",
                            description: "Great for regular content creation",
                            manualPrice: 29.99  // Set your manual price here
                        )

                        CreditPackageCard(
                            title: "Ultra Pack",
                            baseCreditsValue: 50.00,
                            paymentMethod: paymentMethod,
                            onPurchase: {
                                showPaywallView = true
                            },
                            description:
                                "Ideal for power users and bulk projects",
                            manualPrice: 69.99  // Set your manual price here
                        )
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
            }
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
                        await revenueCatManager.fetchCustomerInfo()
                    }
                }
            }
            .sheet(isPresented: $showPaywallView) {
                CreditPackPaywallView()
                    .presentationDragIndicator(.visible)
            }
            .alert("Web checkout link not configured", isPresented: $showWebPurchaseLinkAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Set WEB_CREDITS_PURCHASE_URL in your Info.plist to enable web checkout.")
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("CreditsBalanceUpdated"))
            ) { notification in
                // Refresh balance when updated (e.g., after image/video generation)
                if let userId = authViewModel.user?.id {
                    Task {
                        await creditsViewModel.fetchBalance(userId: userId)
                    }
                }
            }
        }
    }
}

// Placeholder balance package card
struct CreditPackageCard: View {
    let title: String
    let baseCreditsValue: Double  // This is both the balance amount and the base price
    let paymentMethod: PaymentMethod
    let onPurchase: () -> Void
    var badge: String? = nil
    var description: String? = nil
    var manualPrice: Double? = nil  // Manual total price override

    @State private var isDetailsExpanded: Bool = false

    // Calculate app fee (fixed amounts based on pack size)
    private var profitFee: Double {
        switch baseCreditsValue {
        case 1.00:
            return 1.00
        case 5.00:
            return 1.00
        case 10.00:
            return 2.00
        case 20.00:
            return 4.00
        case 50.00:
            return 6.00
        default:
            return baseCreditsValue * 0.10  // Fallback to 10% for any other values
        }
    }

    private var paymentProcessorFee: Double {
        switch paymentMethod {
        case .apple:
            // Apple fee is 30% of (base + app fee)
            let subtotal = baseCreditsValue + profitFee
            return subtotal * 0.30
        case .external:
            return PriceCalculator.calculateExternalFee(
                basePrice: baseCreditsValue)
        }
    }

    private var adjustedPrice: Double {
        // Use manual price if provided, otherwise calculate using adjusted pricing
        if let manualPrice = manualPrice {
            return manualPrice
        }
        // For Apple: Total = (Base + App Fee) * 1.30
        // For External: Total = Base + External Fee + App Fee
        switch paymentMethod {
        case .apple:
            let subtotal = baseCreditsValue + profitFee
            return subtotal * 1.30
        case .external:
            let baseWithProcessorFee = PriceCalculator.calculateExternalPrice(
                basePrice: baseCreditsValue)
            return baseWithProcessorFee + profitFee
        }
    }

    private var feeAmount: Double {
        return paymentProcessorFee
    }

    // Calculate number of image generations at $0.04 per image
    private var imageGenerations: Int {
        let costPerImage = 0.04
        return Int(baseCreditsValue / costPerImage)
    }

    // Calculate video generation range (cost ranges from $1.10 to $0.30 per video)
    // For $5.00 pack: 4-20 videos as specified, calculate others proportionally
    private var videoGenerationsRange: (min: Int, max: Int) {
        let minCostPerVideo = 1.10
        let minVideos = Int(baseCreditsValue / minCostPerVideo)
        // Use proportional multiplier based on $5.00 = 4-20 example
        // Max videos = balance * 4 (since $5.00 * 4 = 20)
        let maxVideos = Int(baseCreditsValue * 4)
        return (min: minVideos, max: maxVideos)
    }

    // Concise benefit summary for collapsed state
    private var benefitSummary: String {
        return
            "~\(imageGenerations) images • \(videoGenerationsRange.min)–\(videoGenerationsRange.max) videos"
    }

    // Get example image models with generation counts
    private var exampleImageModels:
        [(name: String, imageName: String, count: Int)]
    {
        let imageModelPrices: [String: Double] = [
            "Z-Image-Turbo": 0.005,
            // "Wavespeed Ghibli": 0.005,
            "FLUX.2 [dev]": 0.0122,
            "Wan2.5-Preview Image": 0.027,
            "Seedream 4.0": 0.03,
            "GPT Image 1.5": 0.034,
            "Google Gemini Flash 2.5 (Nano Banana)": 0.039,
            "Seedream 4.5": 0.04,
            "FLUX.1 Kontext [pro]": 0.04,
            "FLUX.1 Kontext [max]": 0.08,
        ]

        let modelImageNames: [String: String] = [
            "Z-Image-Turbo": "zimageturbo",
            // "Wavespeed Ghibli": "wavespeedghibli",
            "FLUX.2 [dev]": "flux2dev",
            "Wan2.5-Preview Image": "wan25previewimage",
            "Seedream 4.0": "seedream40",
            "GPT Image 1.5": "gptimage15",
            "Google Gemini Flash 2.5 (Nano Banana)": "geminiflashimage25",
            "Seedream 4.5": "seedream45",
            "FLUX.1 Kontext [pro]": "fluxkontextpro",
            "FLUX.1 Kontext [max]": "fluxkontextmax",
        ]

        return imageModelPrices.compactMap { (modelName, price) in
            guard price > 0 else { return nil }
            guard baseCreditsValue >= price else { return nil }  // Only show if pack can afford at least one
            let count = Int(baseCreditsValue / price)
            guard count > 0 else { return nil }
            let imageName = modelImageNames[modelName] ?? ""
            return (name: modelName, imageName: imageName, count: count)
        }.sorted { $0.count > $1.count }  // Sort by count descending
    }

    // Get example video models with generation counts (for larger packs)
    private var exampleVideoModels:
        [(name: String, imageName: String, count: Int)]
    {
        // Use default/cheapest pricing for each model
        let videoModelPrices: [String: Double] = [
            "Seedance 1.0 Pro Fast": 0.0304,  // 5s at 480p (cheapest option)
            "Google Veo 3.1 Fast": 1.20,  // 8s at 1080p (only option)
            "Sora 2": 0.4,  // 4s at 720p (cheapest option)
            "KlingAI 2.5 Turbo Pro": 0.35,  // 5s at 1080p
            "Kling VIDEO 2.6 Pro": 0.70,  // 5s at 1080p
            "Wan2.6": 0.5,  // 5s at 720p (cheapest option)
        ]

        let videoModelImageNames: [String: String] = [
            "Seedance 1.0 Pro Fast": "seedance10profast",
            "Google Veo 3.1 Fast": "veo31fast",
            "Sora 2": "sora2",
            "KlingAI 2.5 Turbo Pro": "klingai25turbopro",
            "Kling VIDEO 2.6 Pro": "klingvideo26pro",
            "Wan2.6": "wan26",
        ]

        return videoModelPrices.compactMap { (modelName, price) in
            guard price > 0 else { return nil }
            let count = Int(baseCreditsValue / price)
            guard count > 0 else { return nil }
            let imageName = videoModelImageNames[modelName] ?? ""
            return (name: modelName, imageName: imageName, count: count)
        }.sorted { $0.count > $1.count }  // Sort by count descending
    }

    // Header section with title, balance, and price
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
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
                        PricingManager.formatPrice(
                            Decimal(baseCreditsValue)) + " credits"
                    )
                    .font(
                        .system(
                            size: 16, weight: .semibold,
                            design: .rounded)
                    )
                    .foregroundColor(.primary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(PriceCalculator.formatPrice(adjustedPrice))
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
    }
    
    // Description row
    private var descriptionRow: some View {
        HStack {
            if let description = description {
                Text(description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // Details toggle button
    private var detailsButton: some View {
        HStack {
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
    }
    
    // Expanded details section
    @ViewBuilder
    private var expandedDetailsSection: some View {
        if isDetailsExpanded {
            VStack(alignment: .leading, spacing: 12) {
                // Divider
                Divider()
                    .padding(.vertical, 4)

                // What You Get Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("What You Get")
                            .font(
                                .system(
                                    size: 12, weight: .semibold,
                                    design: .rounded)
                            )
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(
                                    systemName:
                                        "photo.on.rectangle.angled"
                                )
                                .font(
                                    .system(
                                        size: 14, weight: .medium)
                                )
                                .imageScale(.medium)
                                .foregroundColor(.blue)
                                .frame(width: 20, height: 20)

                                Text(
                                    "*Approx. \(imageGenerations) images (depending on model)"
                                )
                                .font(
                                    .system(
                                        size: 12, design: .rounded)
                                )
                                .foregroundColor(.secondary)
                            }

                            // Image model pills
                            if !exampleImageModels.isEmpty {
                                ScrollView(
                                    .horizontal,
                                    showsIndicators: false
                                ) {
                                    HStack(spacing: 8) {
                                        ForEach(
                                            exampleImageModels,
                                            id: \.name
                                        ) { model in
                                            ModelPill(
                                                modelName: model
                                                    .name,
                                                imageName: model
                                                    .imageName,
                                                count: model.count
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        // OR divider
                        HStack {
                            Text("OR")
                                .font(
                                    .system(
                                        size: 12,
                                        weight: .semibold,
                                        design: .rounded)
                                )
                                .foregroundColor(.primary)
                                .padding(.leading, 20)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(
                                        .system(
                                            size: 14,
                                            weight: .medium)
                                    )
                                    .imageScale(.medium)
                                    .foregroundColor(.purple)
                                    .frame(width: 20, height: 20)

                                Text(
                                    "*Approx. \(videoGenerationsRange.min)–\(videoGenerationsRange.max) videos (at lowest settings)"
                                )
                                .font(
                                    .system(
                                        size: 12, design: .rounded)
                                )
                                .foregroundColor(.secondary)
                            }

                            // Video model pills
                            if !exampleVideoModels.isEmpty {
                                ScrollView(
                                    .horizontal,
                                    showsIndicators: false
                                ) {
                                    HStack(spacing: 8) {
                                        ForEach(
                                            exampleVideoModels,
                                            id: \.name
                                        ) { model in
                                            VideoModelPill(
                                                modelName: model
                                                    .name,
                                                imageName: model
                                                    .imageName,
                                                count: model.count
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }

                                Text(
                                    "Video examples shown for shortest length videos"
                                )
                                .font(
                                    .system(
                                        size: 10, design: .rounded)
                                )
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.leading, 20)
                                .padding(.top, 2)
                            }
                        }

                        Text(
                            "Balance can be used for both images and videos"
                        )
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.leading, 20)
                        .padding(.top, 2)

                        Text(
                            "*Approximate usage depends on models used"
                        )
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.leading, 20)
                    }
                    .padding(.leading, 18)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    // Main button content
    private var buttonContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerSection
            descriptionRow
            detailsButton
            expandedDetailsSection
        }
        .padding()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content - tappable for purchase
            Button(action: {
                onPurchase()
            }) {
                buttonContent
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

// Model Pill Component
struct ModelPill: View {
    let modelName: String
    let imageName: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            if !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            }

            Text(modelName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            HStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                Text("images")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// Video Model Pill Component
struct VideoModelPill: View {
    let modelName: String
    let imageName: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            if !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            }

            Text(modelName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            HStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                Text("videos")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
