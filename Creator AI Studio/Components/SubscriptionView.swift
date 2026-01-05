//
//  SubscriptionView.swift
//  Creator AI Studio
//
//  Created for subscription management UI
//

import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
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
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Choose a credit package")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
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
                    
                    // Terms and info
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Button("Terms of Service") {
                                // TODO: Open terms
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Privacy Policy") {
                                // TODO: Open privacy
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
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
    }
}
