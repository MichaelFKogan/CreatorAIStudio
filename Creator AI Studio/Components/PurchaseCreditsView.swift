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
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Buy Credits")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Choose a credit package")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Info banner for non-subscribers
                    if !isSubscribed {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            
                            Text("Subscription required to purchase credits")
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
                    
                    // Credit Packages
                    VStack(spacing: 12) {
                        CreditPackageCard(
                            title: "Starter Pack",
                            baseCreditsValue: 5.00,
                            paymentMethod: selectedPaymentMethod
                        )
                        
                        CreditPackageCard(
                            title: "Pro Pack",
                            baseCreditsValue: 10.00,
                            paymentMethod: selectedPaymentMethod,
                            badge: "Best Value"
                        )
                        
                        CreditPackageCard(
                            title: "Mega Pack",
                            baseCreditsValue: 20.00,
                            paymentMethod: selectedPaymentMethod
                        )
                        
                        CreditPackageCard(
                            title: "Ultra Pack",
                            baseCreditsValue: 50.00,
                            paymentMethod: selectedPaymentMethod
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
    let baseCreditsValue: Double // This is both the credits amount and the base price
    let paymentMethod: PaymentMethod
    var badge: String? = nil
    
    private var adjustedPrice: Double {
        switch paymentMethod {
        case .apple:
            return PriceCalculator.calculateApplePrice(basePrice: baseCreditsValue)
        case .external:
            return PriceCalculator.calculateExternalPrice(basePrice: baseCreditsValue)
        }
    }
    
    private var feeAmount: Double {
        switch paymentMethod {
        case .apple:
            return adjustedPrice - baseCreditsValue
        case .external:
            return PriceCalculator.calculateExternalFee(basePrice: baseCreditsValue)
        }
    }
    
    // Calculate number of image generations at $0.04 per image
    private var imageGenerations: Int {
        let costPerImage = 0.04
        return Int(baseCreditsValue / costPerImage)
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
                        
                        Text("About \(imageGenerations)+ image generations")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
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
