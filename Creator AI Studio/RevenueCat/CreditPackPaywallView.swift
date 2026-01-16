//
//  CreditPackPaywallView.swift
//  Creator AI Studio
//
//  Created for RevenueCat Paywalls integration for consumable credit packs
//

import SwiftUI
import RevenueCat
import RevenueCatUI

/// Paywall view for purchasing consumable credit packs using RevenueCat Paywalls
struct CreditPackPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var showPaywall = false
    @State private var isProcessingPurchase = false
    
    // Optional: Specify a specific offering identifier for credit packs
    // If nil, will use the current offering
    var offeringIdentifier: String? = nil
    
    var body: some View {
        ZStack {
            if showPaywall {
                // RevenueCat PaywallView - handles all UI and purchase flow
                // We handle scroll views for you, no need to wrap this in a ScrollView
                PaywallView()
                    .onPurchaseCompleted { transaction, customerInfo in
                        handlePurchaseCompleted(customerInfo: customerInfo)
                    }
                    .onRestoreCompleted { customerInfo in
                        handleRestoreCompleted(customerInfo: customerInfo)
                    }
                    .onRequestedDismissal {
                        // Handle dismissal - check if purchase was completed
                        // This is a fallback in case onPurchaseCompleted doesn't fire
                        Task {
                            await checkPurchaseStatusAndDismiss()
                        }
                    }
            } else {
                // Loading state
                ProgressView("Loading credit packs...")
                    .scaleEffect(1.2)
                    .task {
                        await checkAndShowPaywall()
                    }
            }
        }
        .alert("Purchase Completed", isPresented: .constant(isProcessingPurchase && !showPaywall)) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your credits have been added to your account.")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Checks if offerings are available and shows the paywall
    private func checkAndShowPaywall() async {
        do {
            let offerings = try await revenueCatManager.fetchOfferings()
            
            // Check if we have a specific offering or use current
            let offering: Offering?
            if let identifier = offeringIdentifier {
                offering = offerings.all[identifier]
            } else {
                offering = offerings.current
            }
            
            await MainActor.run {
                if offering != nil {
                    showPaywall = true
                } else {
                    // No offering available - could show error or fallback UI
                    print("⚠️ [CreditPackPaywallView] No offering available")
                    dismiss()
                }
            }
        } catch {
            print("❌ [CreditPackPaywallView] Error fetching offerings: \(error)")
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    /// Handles successful purchase completion
    private func handlePurchaseCompleted(customerInfo: CustomerInfo) {
        Task {
            isProcessingPurchase = true
            
            // Get the latest transaction info
            guard let latestTransaction = customerInfo.latestExpirationDate else {
                // For consumables, we need to check non-subscription transactions
                // RevenueCat handles consumables differently - we'll process via webhook or check active purchases
                await processCreditPurchase(customerInfo: customerInfo)
                return
            }
            
            // Process the purchase to add credits
            await processCreditPurchase(customerInfo: customerInfo)
        }
    }
    
    /// Handles restore purchases completion
    private func handleRestoreCompleted(customerInfo: CustomerInfo) {
        Task {
            // For consumables, restore might not be applicable, but we can check for any active purchases
            await processCreditPurchase(customerInfo: customerInfo)
        }
    }
    
    /// Checks purchase status when paywall is dismissed (fallback method)
    private func checkPurchaseStatusAndDismiss() async {
        // Refresh customer info to check for new purchases
        await revenueCatManager.fetchCustomerInfo()
        
        if let customerInfo = revenueCatManager.customerInfo {
            // Check if there are new transactions
            let recentTransactions = customerInfo.nonSubscriptionTransactions
            if !recentTransactions.isEmpty {
                // Process any new purchases
                await processCreditPurchase(customerInfo: customerInfo)
            } else {
                // No new purchases, just dismiss
                await MainActor.run {
                    dismiss()
                }
            }
        } else {
            // No customer info, just dismiss
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    /// Processes the credit purchase by extracting package info and adding credits to Supabase
    private func processCreditPurchase(customerInfo: CustomerInfo) async {
        guard let userId = authViewModel.user?.id else {
            print("❌ [CreditPackPaywallView] No user ID available")
            await MainActor.run {
                isProcessingPurchase = false
            }
            return
        }
        
        // For consumables, RevenueCat processes purchases and you typically:
        // 1. Use webhooks to handle server-side credit addition (recommended)
        // 2. Or check nonSubscriptionTransactions for recent purchases
        
        // Check for recent non-subscription transactions (consumables)
        let recentTransactions = customerInfo.nonSubscriptionTransactions
        if let latestTransaction = recentTransactions.last {
            // Get the product identifier from the transaction
            let productId = latestTransaction.productIdentifier
            
            // Map product ID to credit amount
            if let creditAmount = getCreditAmountForProduct(productId) {
                do {
                    // Add credits to user's account
                    let transactionId = latestTransaction.transactionIdentifier
                    let _ = try await CreditsManager.shared.addCredits(
                        userId: userId,
                        amount: creditAmount,
                        paymentMethod: "apple", // RevenueCat purchases go through Apple
                        paymentTransactionId: transactionId,
                        description: "Credit pack purchase - \(productId)"
                    )
                    
                    print("✅ [CreditPackPaywallView] Added \(creditAmount) credits for product \(productId)")
                    
                    // Refresh credit balance
                    await creditsViewModel.fetchBalance(userId: userId)
                    
                    // Post notification to refresh UI
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CreditsBalanceUpdated"),
                            object: nil,
                            userInfo: ["userId": userId.uuidString]
                        )
                        isProcessingPurchase = false
                        dismiss()
                    }
                } catch {
                    print("❌ [CreditPackPaywallView] Error adding credits: \(error)")
                    await MainActor.run {
                        isProcessingPurchase = false
                    }
                }
            } else {
                print("⚠️ [CreditPackPaywallView] No credit mapping found for product: \(productId)")
                // Still refresh balance in case webhook processed it
                await creditsViewModel.fetchBalance(userId: userId)
                await MainActor.run {
                    isProcessingPurchase = false
                    dismiss()
                }
            }
        } else {
            // No recent transactions found - might be processed via webhook
            print("ℹ️ [CreditPackPaywallView] No recent transactions found. Credits may be processed via webhook.")
            await creditsViewModel.fetchBalance(userId: userId)
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CreditsBalanceUpdated"),
                    object: nil,
                    userInfo: ["userId": userId.uuidString]
                )
                isProcessingPurchase = false
                dismiss()
            }
        }
    }
}

// MARK: - Helper Extension for Product to Credit Mapping

extension CreditPackPaywallView {
    /// Maps a StoreKit product identifier to a credit amount
    /// You should customize this based on your App Store Connect product configuration
    /// This should match the product IDs you configure in RevenueCat dashboard
    private func getCreditAmountForProduct(_ productId: String) -> Double? {
        // Map your App Store Connect product identifiers to credit amounts
        // Example mapping - adjust based on your actual product IDs
        // These should match the product IDs in your RevenueCat dashboard
        let creditMapping: [String: Double] = [
            // Example product IDs - replace with your actual ones
            "com.yourapp.credits.test": 1.00,
            "com.yourapp.credits.starter": 5.00,
            "com.yourapp.credits.pro": 10.00,
            "com.yourapp.credits.mega": 20.00,
            "com.yourapp.credits.ultra": 50.00
        ]
        
        return creditMapping[productId]
    }
}
