//
//  PurchaseCreditsView.swift
//  Creator AI Studio
//
//  Created for purchase credits UI
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
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var selectedPaymentMethod: PaymentMethod = .external
    @State private var showPaywallView = false

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

                        Text("Buy Credits")
                            .font(
                                .system(
                                    size: 26, weight: .bold, design: .rounded)
                            )
                            .foregroundColor(.primary)

                        Text("Choose a credit package")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Current Balance Display
                    if let userId = authViewModel.user?.id {
                        VStack(spacing: 8) {
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
                                        size: 32, weight: .bold,
                                        design: .rounded)
                                )
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                    }

                    // Payment Method Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payment Method")
                            .font(
                                .system(
                                    size: 14, weight: .semibold,
                                    design: .rounded)
                            )
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        PaymentMethodSelector(
                            selectedMethod: $selectedPaymentMethod
                        )
                        .padding(.horizontal)

                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 10))
                                Text("3% + $0.30 fee")
                                    .font(.system(size: 11, design: .rounded))
                            }
                            .foregroundColor(.secondary)

                            Spacer()

                            // Fee information - show both
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 10))
                                    Text("30% fee")
                                        .font(
                                            .system(size: 11, design: .rounded))
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    // Credit Packages
                    VStack(spacing: 12) {
                        CreditPackageCard(
                            title: "Test Pack",
                            baseCreditsValue: 1.00,
                            paymentMethod: selectedPaymentMethod,
                            description: "Good for testing photos"
                        )

                        CreditPackageCard(
                            title: "Starter Pack",
                            baseCreditsValue: 5.00,
                            paymentMethod: selectedPaymentMethod,
                            description: "Perfect for trying out features"
                        )

                        CreditPackageCard(
                            title: "Pro Pack",
                            baseCreditsValue: 10.00,
                            paymentMethod: selectedPaymentMethod,
                            description: "Good for testing videos"
                        )

                        CreditPackageCard(
                            title: "Mega Pack",
                            baseCreditsValue: 20.00,
                            paymentMethod: selectedPaymentMethod,
                            badge: "Best Value",
                            description: "Great for regular content creation"
                        )

                        CreditPackageCard(
                            title: "Ultra Pack",
                            baseCreditsValue: 50.00,
                            paymentMethod: selectedPaymentMethod,
                            description:
                                "Ideal for power users and bulk projects"
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
                PaywallView()
                    .presentationDragIndicator(.visible)
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
        }
    }
}

// Payment Method Selector
struct PaymentMethodSelector: View {
    @Binding var selectedMethod: PaymentMethod

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PaymentMethod.allCases, id: \.self) { method in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMethod = method
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: method.icon)
                            .font(.system(size: 14))
                        Text(method.displayName)
                            .font(
                                .system(
                                    size: 13, weight: .semibold,
                                    design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedMethod == method
                            ? Color.blue
                            : Color(.secondarySystemBackground)
                    )
                    .foregroundColor(
                        selectedMethod == method
                            ? .white
                            : .primary
                    )
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// Placeholder credit package card
struct CreditPackageCard: View {
    let title: String
    let baseCreditsValue: Double  // This is both the credits amount and the base price
    let paymentMethod: PaymentMethod
    var badge: String? = nil
    var description: String? = nil

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
            return 5.00
        default:
            return baseCreditsValue * 0.10  // Fallback to 10% for any other values
        }
    }

    private var paymentProcessorFee: Double {
        switch paymentMethod {
        case .apple:
            return PriceCalculator.calculateApplePrice(
                basePrice: baseCreditsValue) - baseCreditsValue
        case .external:
            return PriceCalculator.calculateExternalFee(
                basePrice: baseCreditsValue)
        }
    }

    private var adjustedPrice: Double {
        // Total price = base price + payment processor fee + app fee
        let baseWithProcessorFee: Double
        switch paymentMethod {
        case .apple:
            baseWithProcessorFee = PriceCalculator.calculateApplePrice(
                basePrice: baseCreditsValue)
        case .external:
            baseWithProcessorFee = PriceCalculator.calculateExternalPrice(
                basePrice: baseCreditsValue)
        }
        return baseWithProcessorFee + profitFee
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
        // Max videos = credits * 4 (since $5.00 * 4 = 20)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content - tappable for purchase
            Button(action: {
                // TODO: Handle purchase logic with selected payment method
                print(
                    "Purchase \(title) via \(paymentMethod.rawValue) for \(PriceCalculator.formatPrice(adjustedPrice))"
                )
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    // Header: Title, Credits, and Price
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
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
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(
                                    PriceCalculator.formatPrice(
                                        baseCreditsValue)
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
                    
                    // Description and Total Fees row
                    HStack {
                        if let description = description {
                            Text(description)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("Total Fees")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(
                                PriceCalculator.formatPrice(
                                    paymentProcessorFee + profitFee)
                            )
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // Details button row
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

                    // Expanded details section - What You Get and Fees
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
                                                "*Approx. \(imageGenerations) images"
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
                                        "Credits can be used for both images and videos"
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

                            // Divider
                            Divider()
                                .padding(.vertical, 4)

                            // Fees Section
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                    Text("Fee Breakdown")
                                        .font(
                                            .system(
                                                size: 12, weight: .semibold,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.secondary)

                                    Spacer()
                                }

                                VStack {
                                    if paymentMethod == .apple {
                                        HStack {
                                            Text("Apple Fee")
                                                .font(
                                                    .system(
                                                        size: 11,
                                                        design: .rounded)
                                                )
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(
                                                "(30%) = \(PriceCalculator.formatPrice(feeAmount))"
                                            )
                                            .font(
                                                .system(
                                                    size: 11, design: .rounded)
                                            )
                                            .foregroundColor(.secondary)
                                        }
                                    } else {
                                        HStack {
                                            Text("Credit Card Fee")
                                                .font(
                                                    .system(
                                                        size: 11,
                                                        design: .rounded)
                                                )
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(
                                                "(3% + $0.30) = \(PriceCalculator.formatPrice(feeAmount))"
                                            )
                                            .font(
                                                .system(
                                                    size: 11, design: .rounded)
                                            )
                                            .foregroundColor(.secondary)
                                        }
                                    }

                                    HStack {
                                        Text("App Fee")
                                            .font(
                                                .system(
                                                    size: 11, design: .rounded)
                                            )
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(
                                            "= \(PriceCalculator.formatPrice(profitFee))"
                                        )
                                        .font(
                                            .system(size: 11, design: .rounded)
                                        )
                                        .foregroundColor(.secondary)
                                    }

                                    HStack {
                                        Text("Total Fees")
                                            .font(
                                                .system(
                                                    size: 11, weight: .semibold,
                                                    design: .rounded)
                                            )
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(
                                            "= \(PriceCalculator.formatPrice(paymentProcessorFee + profitFee))"
                                        )
                                        .font(
                                            .system(
                                                size: 11, weight: .semibold,
                                                design: .rounded)
                                        )
                                        .foregroundColor(.primary)
                                    }
                                }
                                .padding(.leading, 18)
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
