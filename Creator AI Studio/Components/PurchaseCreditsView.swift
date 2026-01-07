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
    @StateObject private var creditsViewModel = CreditsViewModel()
    @State private var selectedPaymentMethod: PaymentMethod = .external

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
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            Text(creditsViewModel.formattedBalance())
                                .font(.system(size: 32, weight: .bold, design: .rounded))
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
                            description: "Ideal for power users and bulk projects"
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
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { notification in
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

    @State private var isExpanded: Bool = false

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content - tappable for purchase
            Button(action: {
                // TODO: Handle purchase logic with selected payment method
                print(
                    "Purchase \(title) via \(paymentMethod.rawValue) for \(PriceCalculator.formatPrice(adjustedPrice))"
                )
            }) {
                VStack(alignment: .leading, spacing: 12) {
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
                            
                            if let description = description {
                                Text(description)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
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

                    // Concise benefit summary with icons and Details button (full width)
                    HStack {
                        // What You Get Section
                        VStack(alignment: .leading, spacing: 6) {
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

                            HStack(spacing: 8) {

                                VStack(spacing: 6) {
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
                                            "Approx. \(imageGenerations) images"
                                        )
                                        .font(
                                            .system(
                                                size: 12, design: .rounded)
                                        )
                                        .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, -3)

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
                                            "Approx. \(videoGenerationsRange.min)–\(videoGenerationsRange.max) videos"
                                        )
                                        .font(
                                            .system(
                                                size: 12, design: .rounded)
                                        )
                                        .foregroundColor(.secondary)
                                    }
                                }
                                .environment(\.font, Font.system(size: 14))

                                VStack(spacing: 6) {
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Text("OR")
                                            .font(
                                                .system(
                                                    size: 12,
                                                    design: .rounded)
                                            )
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                    Spacer()
                                }

                            }
                            .padding(.leading, 20)

                            HStack{
                                Text(
                                    "Use credits for both images and videos"
                                )
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                                .italic()
                            }
                            .padding(.leading, 16)
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            Spacer()
                            // Details toggle button
                            Button(action: {
                                withAnimation(
                                    .spring(response: 0.3, dampingFraction: 0.8)
                                ) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Text(isExpanded ? "Hide Fees ▴" : "Fees ▾")
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
                    .frame(maxWidth: .infinity)

                    // Expanded details section
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 12) {
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
                                }

                                if paymentMethod == .apple {
                                    HStack {
                                        Text("Apple Fee")
                                            .font(
                                                .system(
                                                    size: 11, design: .rounded)
                                            )
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(
                                            "(30%) = \(PriceCalculator.formatPrice(feeAmount))"
                                        )
                                        .font(
                                            .system(size: 11, design: .rounded)
                                        )
                                        .foregroundColor(.secondary)
                                    }
                                } else {
                                    HStack {
                                        Text("Credit Card Fee")
                                            .font(
                                                .system(
                                                    size: 11, design: .rounded)
                                            )
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(
                                            "(3% + $0.30) = \(PriceCalculator.formatPrice(feeAmount))"
                                        )
                                        .font(
                                            .system(size: 11, design: .rounded)
                                        )
                                        .foregroundColor(.secondary)
                                    }
                                }

                                HStack {
                                    Text("App Fee")
                                        .font(
                                            .system(size: 11, design: .rounded)
                                        )
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(
                                        "= \(PriceCalculator.formatPrice(profitFee))"
                                    )
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text("Total Fees")
                                        .font(
                                            .system(size: 11, weight: .semibold, design: .rounded)
                                        )
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(
                                        "= \(PriceCalculator.formatPrice(paymentProcessorFee + profitFee))"
                                    )
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
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
