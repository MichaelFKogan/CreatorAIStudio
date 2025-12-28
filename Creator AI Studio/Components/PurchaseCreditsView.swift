//
//  PurchaseCreditsView.swift
//  Creator AI Studio
//
//  Created for purchase credits UI
//

import SwiftUI

enum PaymentMethod: String, CaseIterable {
    case apple = "Apple"
    case external = "External"
    
    var displayName: String {
        switch self {
        case .apple:
            return "Apple Payment"
        case .external:
            return "Credit Card or Apple Pay"
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
    @State private var showSubscriptionView: Bool = false
    @State private var isSubscribed: Bool = false // TODO: Connect to actual subscription status
    @State private var selectedPaymentMethod: PaymentMethod = .apple
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: isSubscribed ? "diamond.fill" : "crown.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: isSubscribed ? [.blue, .purple] : [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(isSubscribed ? "Buy Credits" : "Get Started")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(isSubscribed ? "Choose a credit package" : "Subscribe and get credits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Info banner for non-subscribers
                    if !isSubscribed {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            
                            Text("Subscription required to use the app and purchase credits")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }
                    
                    // Payment Method Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payment Method")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        PaymentMethodSelector(selectedMethod: $selectedPaymentMethod)
                            .padding(.horizontal)
                    }
                    
                    // Start Packs (for non-subscribers) or Credit Packages (for subscribers)
                    VStack(spacing: 12) {
                        if isSubscribed {
                            // Start Packs: Subscription + Credits bundles
                            // Subscription is always $5.00/month, credits vary
                            StartPackCard(
                                title: "Starter Pack",
                                baseCreditsValue: 1.00,
                                paymentMethod: selectedPaymentMethod,
                                badge: "Popular"
                            )
                            
                            StartPackCard(
                                title: "Pro Pack",
                                baseCreditsValue: 5.00,
                                paymentMethod: selectedPaymentMethod,
                                badge: "Best Value"
                            )
                            
                            StartPackCard(
                                title: "Mega Pack",
                                baseCreditsValue: 10.00,
                                paymentMethod: selectedPaymentMethod
                            )
                        } else {
                            // Credit Packages: Individual credit purchases for subscribers
                            // Base credit values and prices
                            CreditPackageCard(
                                title: "Starter Pack",
                                baseCreditsValue: 5.00,
                                basePrice: 4.99,
                                paymentMethod: selectedPaymentMethod
                            )
                            
                            CreditPackageCard(
                                title: "Pro Pack",
                                baseCreditsValue: 10.00,
                                basePrice: 9.99,
                                paymentMethod: selectedPaymentMethod,
                                badge: "Best Value"
                            )
                            
                            CreditPackageCard(
                                title: "Mega Pack",
                                baseCreditsValue: 20.00,
                                basePrice: 19.99,
                                paymentMethod: selectedPaymentMethod
                            )
                            
                            CreditPackageCard(
                                title: "Ultra Pack",
                                baseCreditsValue: 50.00,
                                basePrice: 49.99,
                                paymentMethod: selectedPaymentMethod
                            )
                        }
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
        }
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
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
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
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
    let baseCreditsValue: Double
    let basePrice: Double
    let paymentMethod: PaymentMethod
    var badge: String? = nil
    
    private var adjustedPrice: Double {
        switch paymentMethod {
        case .apple:
            return PriceCalculator.calculateApplePrice(basePrice: basePrice)
        case .external:
            return PriceCalculator.calculateExternalPrice(basePrice: basePrice)
        }
    }
    
    private var feeAmount: Double {
        switch paymentMethod {
        case .apple:
            return adjustedPrice - basePrice
        case .external:
            return PriceCalculator.calculateExternalFee(basePrice: basePrice)
        }
    }
    
    var body: some View {
        Button(action: {
            // TODO: Handle purchase logic with selected payment method
            print("Purchase \(title) via \(paymentMethod.rawValue) for \(PriceCalculator.formatPrice(adjustedPrice))")
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            Text(PriceCalculator.formatPrice(baseCreditsValue))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(PriceCalculator.formatPrice(adjustedPrice))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(paymentMethod == .apple ? "Apple fee (30%): \(PriceCalculator.formatPrice(feeAmount))" : "Credit Card fee (3% + $0.30): \(PriceCalculator.formatPrice(feeAmount))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
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
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Start Pack Card: Subscription + Credits bundle for non-subscribers
struct StartPackCard: View {
    let title: String
    let baseCreditsValue: Double
    let paymentMethod: PaymentMethod
    var badge: String? = nil
    
    // Subscription is always $5.00/month, no fees
    private let subscriptionPrice: Double = 5.00
    
    // Credits with fees applied (only credits have fees)
    private var creditsPriceWithFees: Double {
        switch paymentMethod {
        case .apple:
            return PriceCalculator.calculateApplePrice(basePrice: baseCreditsValue)
        case .external:
            return PriceCalculator.calculateExternalPrice(basePrice: baseCreditsValue)
        }
    }
    
    // Total: subscription (no fees) + credits (with fees)
    private var totalPrice: Double {
        return subscriptionPrice + creditsPriceWithFees
    }
    
    // Fee amount (only on credits)
    private var feeAmount: Double {
        switch paymentMethod {
        case .apple:
            return creditsPriceWithFees - baseCreditsValue
        case .external:
            return PriceCalculator.calculateExternalFee(basePrice: baseCreditsValue)
        }
    }
    
    var body: some View {
        Button(action: {
            // TODO: Handle start pack purchase (subscription + credits) with selected payment method
            print("Purchase \(title) via \(paymentMethod.rawValue): \(PriceCalculator.formatPrice(subscriptionPrice))/month + \(PriceCalculator.formatPrice(baseCreditsValue)) credits (with fees: \(PriceCalculator.formatPrice(creditsPriceWithFees))) = \(PriceCalculator.formatPrice(totalPrice))")
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Header with title and badge
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let badge = badge {
                        Text(badge)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                
                // Subscription + Credits breakdown
                HStack(spacing: 12) {
                    // Subscription (left)
                    VStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(spacing: 2) {
                            Text("Subscription")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(PriceCalculator.formatPrice(subscriptionPrice))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("/mo")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Plus sign
                    Text("+")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    // Credits (right) - always show base value
                    VStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 2) {
                            Text("Credits")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text(PriceCalculator.formatPrice(baseCreditsValue))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                )
                
                // Total price with fees
                VStack(alignment: .trailing, spacing: 2) {
                    HStack {
                        Text("Total")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(PriceCalculator.formatPrice(totalPrice))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Spacer()
                        Text(paymentMethod == .apple ? "Apple's fee (30%): \(PriceCalculator.formatPrice(feeAmount))" : "Credit Card fee (3% + $0.30): \(PriceCalculator.formatPrice(feeAmount))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.5), Color.orange.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

