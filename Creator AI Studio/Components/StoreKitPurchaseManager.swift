//
//  StoreKitPurchaseManager.swift
//  Creator AI Studio
//
//  Manages StoreKit 2 in-app purchases for credit packs
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class StoreKitPurchaseManager: ObservableObject {
    static let shared = StoreKitPurchaseManager()
    
    @Published var products: [Product] = []
    @Published var isLoadingProducts = false
    @Published var purchaseError: String?
    
    // Map product IDs to credit amounts (in dollars/credits)
    private let creditAmounts: [String: Double] = [
        "com.runspeedai.credits.test": 1.00,
        "com.runspeedai.credits.starter": 5.00,
        "com.runspeedai.credits.pro": 10.00,
        "com.runspeedai.credits.mega": 20.00,
        "com.runspeedai.credits.ultra": 50.00
    ]
    
    private var updateListenerTask: Task<Void, Never>?
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    /// Loads all available products from App Store Connect
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        
        do {
            let productIDs = CreditProductID.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIDs)
            
            // Sort products by credit amount (ascending)
            products = storeProducts.sorted { product1, product2 in
                let credits1 = creditAmounts[product1.id] ?? 0
                let credits2 = creditAmounts[product2.id] ?? 0
                return credits1 < credits2
            }
            
            print("✅ [StoreKitPurchaseManager] Loaded \(products.count) products")
        } catch {
            print("❌ [StoreKitPurchaseManager] Error loading products: \(error)")
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Purchase Product
    
    /// Purchases a product and adds credits to user's account
    /// - Parameters:
    ///   - product: The StoreKit Product to purchase
    ///   - userId: The user's UUID
    /// - Returns: True if purchase was successful
    func purchase(_ product: Product, userId: UUID) async throws -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)
                
                // Get credit amount for this product
                guard let creditAmount = creditAmounts[product.id] else {
                    throw NSError(
                        domain: "PurchaseError",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown product: \(product.id)"]
                    )
                }
                
                // Add credits to user's account
                let _ = try await CreditsManager.shared.addCredits(
                    userId: userId,
                    amount: creditAmount,
                    paymentMethod: "apple",
                    paymentTransactionId: transaction.id.description,
                    description: "In-app purchase: \(product.displayName)"
                )
                
                // Finish the transaction
                await transaction.finish()
                
                print("✅ [StoreKitPurchaseManager] Purchase successful: \(product.id)")
                return true
                
            case .userCancelled:
                print("ℹ️ [StoreKitPurchaseManager] User cancelled purchase")
                throw NSError(
                    domain: "PurchaseError",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Purchase was cancelled"]
                )
                
            case .pending:
                print("⏳ [StoreKitPurchaseManager] Purchase is pending approval")
                throw NSError(
                    domain: "PurchaseError",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Purchase is pending approval"]
                )
                
            @unknown default:
                print("❓ [StoreKitPurchaseManager] Unknown purchase result")
                throw NSError(
                    domain: "PurchaseError",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown purchase result"]
                )
            }
        } catch {
            print("❌ [StoreKitPurchaseManager] Purchase error: \(error)")
            throw error
        }
    }
    
    // MARK: - Get Product by ID
    
    /// Gets a Product by its product ID
    /// - Parameter productId: The product ID string
    /// - Returns: The Product if found, nil otherwise
    func getProduct(for productId: String) -> Product? {
        return products.first { $0.id == productId }
    }
    
    // MARK: - Get Credit Amount
    
    /// Gets the credit amount for a product ID
    /// - Parameter productId: The product ID string
    /// - Returns: The credit amount in dollars/credits
    func getCreditAmount(for productId: String) -> Double {
        return creditAmounts[productId] ?? 0.0
    }
    
    // MARK: - Transaction Listener
    
    /// Listens for transaction updates from StoreKit
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached { [weak self] in
            guard let self = self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Handle the transaction (e.g., restore purchases)
                    // For consumables, we typically don't restore, but we can handle
                    // transactions that were pending or interrupted
                    print("📦 [StoreKitPurchaseManager] Transaction update: \(transaction.productID)")
                    
                    await transaction.finish()
                } catch {
                    print("❌ [StoreKitPurchaseManager] Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Transaction Verification
    
    /// Verifies a StoreKit transaction
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Attempts to restore previous purchases
    /// Note: Consumables cannot be restored, but this method handles any pending transactions
    func restorePurchases(userId: UUID) async throws {
        // For consumables, we can't restore them, but we can check for any
        // pending transactions that might have been interrupted
        
        var restoredCount = 0
        
        // Check all transaction history
        for await result in Transaction.all {
            do {
                let transaction = try checkVerified(result)
                
                // Only process transactions for our products
                guard creditAmounts.keys.contains(transaction.productID) else {
                    await transaction.finish()
                    continue
                }
                
                // Check if we've already processed this transaction
                // (In a real app, you'd check your database)
                // For now, we'll just finish the transaction
                await transaction.finish()
                restoredCount += 1
                
            } catch {
                print("❌ [StoreKitPurchaseManager] Error processing transaction: \(error)")
            }
        }
        
        if restoredCount == 0 {
            throw NSError(
                domain: "RestoreError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No purchases to restore. Credits are consumable and cannot be restored after use."]
            )
        }
    }
}
