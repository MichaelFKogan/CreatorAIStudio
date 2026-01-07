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
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let creditsManager = CreditsManager.shared
    
    /// Fetches and updates the current credit balance
    /// - Parameter userId: The user's UUID
    func fetchBalance(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let newBalance = try await creditsManager.fetchCreditBalance(userId: userId)
            self.balance = newBalance
            print("✅ [CreditsViewModel] Balance updated: $\(String(format: "%.2f", newBalance))")
        } catch {
            print("❌ [CreditsViewModel] Error fetching balance: \(error)")
            errorMessage = error.localizedDescription
            // Set balance to 0 on error to prevent showing stale data
            self.balance = 0.00
        }
        
        isLoading = false
    }
    
    /// Refreshes the balance (same as fetchBalance but with clearer naming)
    /// - Parameter userId: The user's UUID
    func refreshBalance(userId: UUID) async {
        await fetchBalance(userId: userId)
    }
    
    /// Formats the balance as a currency string
    /// - Returns: Formatted string like "$10.00"
    func formattedBalance() -> String {
        return String(format: "$%.2f", balance)
    }
    
    /// Checks if user has enough credits for a transaction
    /// - Parameter requiredAmount: The amount of credits required
    /// - Returns: True if user has sufficient credits
    func hasEnoughCredits(requiredAmount: Double) -> Bool {
        return balance >= requiredAmount
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

