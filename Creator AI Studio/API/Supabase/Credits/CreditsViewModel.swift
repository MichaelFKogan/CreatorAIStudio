//
//  CreditsViewModel.swift
//  Creator AI Studio
//
//  Created for managing credit state in the UI
//

import Foundation
import SwiftUI

/// Observable view model for managing user credits in the UI
@MainActor
class CreditsViewModel: ObservableObject {
    @Published var balance: Double = 0.00
    @Published var pendingCredits: Double = 0.00
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let creditsManager = CreditsManager.shared
    
    // Shared instance for accessing credits from anywhere
    static let shared = CreditsViewModel()
    
    /// Fetches and updates the current credit balance and pending credits
    /// - Parameter userId: The user's UUID
    func fetchBalance(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let newBalance = try await creditsManager.fetchCreditBalance(userId: userId)
            self.balance = newBalance
            
            // Also fetch pending credits
            let pending = try await creditsManager.calculatePendingCredits(userId: userId)
            self.pendingCredits = pending
            
            print("✅ [CreditsViewModel] Balance updated: $\(String(format: "%.2f", newBalance)), Pending: $\(String(format: "%.2f", pending))")
        } catch {
            print("❌ [CreditsViewModel] Error fetching balance: \(error)")
            errorMessage = error.localizedDescription
            // Set balance to 0 on error to prevent showing stale data
            self.balance = 0.00
            self.pendingCredits = 0.00
        }
        
        isLoading = false
    }
    
    /// Refreshes the balance (same as fetchBalance but with clearer naming)
    /// - Parameter userId: The user's UUID
    func refreshBalance(userId: UUID) async {
        await fetchBalance(userId: userId)
    }
    
    /// Formats the balance as credits
    /// - Returns: Formatted string like "1000 credits" or "1000" depending on display mode
    func formattedBalance() -> String {
        let balanceDecimal = Decimal(balance)
        return PricingManager.formatPriceWithUnit(balanceDecimal)
    }
    
    /// Checks if user has enough credits for a transaction
    /// Accounts for pending credits that will be deducted when jobs complete
    /// - Parameter requiredAmount: The amount of credits required
    /// - Returns: True if user has sufficient credits (including pending)
    func hasEnoughCredits(requiredAmount: Double) -> Bool {
        // Available credits = balance - pending credits
        let availableCredits = balance - pendingCredits
        return availableCredits >= requiredAmount
    }
    
    /// Gets a warning message if credits are low
    /// - Returns: Optional warning message if credits are low or zero
    func getLowCreditsWarning() -> String? {
        if balance <= 0 {
            return "You have no credits remaining. Please purchase credits to continue."
        } else if balance < 1.00 {
            return "You're running low on credits ($\(String(format: "%.2f", balance))). Consider purchasing more."
        }
        return nil
    }
}

