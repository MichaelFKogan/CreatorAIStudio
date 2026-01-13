//
//  RevenueCatManager.swift
//  Creator AI Studio
//
//  Created for RevenueCat subscription and entitlement management
//

import Foundation
import RevenueCat
import SwiftUI

/// Manages RevenueCat subscriptions, entitlements, and customer info
@MainActor
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var customerInfo: CustomerInfo?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isProUser: Bool = false
    
    // Entitlement identifier
    private let proEntitlementID = "Runspeed AI Pro"
    
    private override init() {
        super.init()
        // Listen for customer info updates
        Purchases.shared.delegate = self
    }
    
    // MARK: - Customer Info
    
    /// Fetches the latest customer info from RevenueCat
    func fetchCustomerInfo() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let info = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.customerInfo = info
                self.isProUser = info.entitlements.all[proEntitlementID]?.isActive == true
                self.isLoading = false
                print("✅ [RevenueCatManager] Customer info fetched. Pro: \(self.isProUser)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("❌ [RevenueCatManager] Error fetching customer info: \(error)")
            }
        }
    }
    
    /// Refreshes customer info (alias for fetchCustomerInfo)
    func refreshCustomerInfo() async {
        await fetchCustomerInfo()
    }
    
    // MARK: - Entitlement Checking
    
    /// Checks if the user has the Pro entitlement
    /// - Returns: True if user has active Pro subscription
    func hasProEntitlement() -> Bool {
        return isProUser
    }
    
    /// Gets the active entitlement if available
    /// - Returns: The active entitlement or nil
    func getActiveEntitlement() -> EntitlementInfo? {
        return customerInfo?.entitlements.all[proEntitlementID]
    }
    
    // MARK: - Offerings
    
    /// Fetches available offerings from RevenueCat
    /// - Returns: Offerings object with available packages
    func fetchOfferings() async throws -> Offerings {
        do {
            let offerings = try await Purchases.shared.offerings()
            return offerings
        } catch {
            print("❌ [RevenueCatManager] Error fetching offerings: \(error)")
            throw error
        }
    }
    
    // MARK: - Purchases
    
    /// Purchases a package
    /// - Parameter package: The package to purchase
    /// - Returns: CustomerInfo after purchase
    func purchase(package: Package) async throws -> CustomerInfo {
        isLoading = true
        errorMessage = nil
        
        do {
            let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            
            if userCancelled {
                isLoading = false
                throw RevenueCatError.userCancelled
            }
            
            await MainActor.run {
                self.customerInfo = customerInfo
                self.isProUser = customerInfo.entitlements.all[proEntitlementID]?.isActive == true
                self.isLoading = false
            }
            
            print("✅ [RevenueCatManager] Purchase successful. Transaction: \(transaction?.transactionIdentifier ?? "N/A")")
            return customerInfo
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            print("❌ [RevenueCatManager] Purchase error: \(error)")
            throw error
        }
    }
    
    /// Restores previous purchases
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await MainActor.run {
                self.customerInfo = customerInfo
                self.isProUser = customerInfo.entitlements.all[proEntitlementID]?.isActive == true
                self.isLoading = false
            }
            print("✅ [RevenueCatManager] Purchases restored")
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            print("❌ [RevenueCatManager] Restore error: \(error)")
            throw error
        }
    }
    
    // MARK: - User Identification
    
    /// Identifies the user with RevenueCat
    /// - Parameter userId: The user's ID (typically from your auth system)
    func identifyUser(userId: String) async throws {
        do {
            try await Purchases.shared.logIn(userId)
            print("✅ [RevenueCatManager] User identified: \(userId)")
            // Refresh customer info after identification
            await fetchCustomerInfo()
        } catch {
            print("❌ [RevenueCatManager] Error identifying user: \(error)")
            throw error
        }
    }
    
    /// Logs out the current user
    func logOut() async throws {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            await MainActor.run {
                self.customerInfo = customerInfo
                self.isProUser = false
            }
            print("✅ [RevenueCatManager] User logged out")
        } catch {
            print("❌ [RevenueCatManager] Error logging out: \(error)")
            throw error
        }
    }
    
    // MARK: - Subscription Status
    
    /// Gets subscription expiration date if available
    /// - Returns: Optional expiration date
    func getSubscriptionExpirationDate() -> Date? {
        return customerInfo?.entitlements.all[proEntitlementID]?.expirationDate
    }
    
    /// Gets subscription period type
    /// - Returns: Optional period type (monthly, annual, etc.)
    func getSubscriptionPeriodType() -> PeriodType? {
        return customerInfo?.entitlements.all[proEntitlementID]?.periodType
    }
    
    /// Checks if subscription is in grace period
    /// - Returns: True if in grace period
    func isInGracePeriod() -> Bool {
        return customerInfo?.entitlements.all[proEntitlementID]?.willRenew == false &&
               customerInfo?.entitlements.all[proEntitlementID]?.isActive == true
    }
}

// MARK: - PurchasesDelegate

extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.isProUser = customerInfo.entitlements.all[proEntitlementID]?.isActive == true
            print("✅ [RevenueCatManager] Customer info updated. Pro: \(self.isProUser)")
        }
    }
}

// MARK: - Custom Errors

enum RevenueCatError: LocalizedError {
    case userCancelled
    case purchaseFailed(String)
    case noOfferingsAvailable
    case invalidPackage
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .noOfferingsAvailable:
            return "No subscription offerings available"
        case .invalidPackage:
            return "Invalid package selected"
        }
    }
}
