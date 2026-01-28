//
//  CreditsManager.swift
//  Creator AI Studio
//
//  Created for managing user credits
//

import Foundation
import Supabase

/// Manages all credit-related operations with Supabase
@MainActor
class CreditsManager {
    static let shared = CreditsManager()
    
    private let client = SupabaseManager.shared.client
    private let balanceScale: Int = 4
    
    private init() {}
    
    // MARK: - Helpers
    
    private func roundBalance(_ value: Decimal) -> Decimal {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, balanceScale, .bankers)
        return rounded
    }
    
    private func roundBalance(_ value: Double) -> Double {
        let rounded = roundBalance(Decimal(value))
        return NSDecimalNumber(decimal: rounded).doubleValue
    }
    
    // MARK: - Fetch Credit Balance
    
    /// Fetches the current credit balance for a user
    /// - Parameter userId: The user's UUID
    /// - Returns: The current credit balance (0.00 if no record exists)
    func fetchCreditBalance(userId: UUID) async throws -> Double {
        do {
            // Try to fetch existing balance
            let response: [UserCredits] = try await client.database
                .from("user_credits")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            if let credits = response.first {
                return roundBalance(credits.balance)
            } else {
                // No record exists, create one with 0 balance
                try await initializeUserCredits(userId: userId)
                return 0.00
            }
        } catch {
            print("❌ [CreditsManager] Error fetching credit balance: \(error)")
            throw error
        }
    }
    
    // MARK: - Initialize User Credits
    
    /// Initializes a new user_credits record with 0 balance
    /// - Parameter userId: The user's UUID
    private func initializeUserCredits(userId: UUID) async throws {
        let newCredits = UserCredits(
            id: UUID(),
            user_id: userId,
            balance: 0.00,
            created_at: Date(),
            updated_at: Date()
        )
        
        try await client.database
            .from("user_credits")
            .insert(newCredits)
            .execute()
        
        print("✅ [CreditsManager] Initialized credits for user: \(userId)")
    }
    
    // MARK: - Add Credits (Purchase)
    
    /// Adds credits to a user's account after a purchase
    /// - Parameters:
    ///   - userId: The user's UUID
    ///   - amount: The amount of credits to add (positive value)
    ///   - paymentMethod: The payment method used ('apple' or 'external')
    ///   - paymentTransactionId: The transaction ID from the payment provider
    ///   - description: Optional description for the transaction
    /// - Returns: The new balance after adding credits
    func addCredits(
        userId: UUID,
        amount: Double,
        paymentMethod: String,
        paymentTransactionId: String?,
        description: String? = nil
    ) async throws -> Double {
        let amountDecimal = roundBalance(Decimal(amount))
        guard amountDecimal > 0 else {
            throw NSError(
                domain: "CreditsError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Credit amount must be positive"]
            )
        }
        
        do {
            // First, ensure user_credits record exists
            let currentBalance = roundBalance(Decimal(try await fetchCreditBalance(userId: userId)))
            
            // Calculate new balance
            let newBalance = roundBalance(currentBalance + amountDecimal)
            
            // Update user_credits table using a Codable struct
            struct BalanceUpdate: Codable {
                let balance: Decimal
                let updated_at: String
            }
            
            let update = BalanceUpdate(
                balance: newBalance,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client.database
                .from("user_credits")
                .update(update)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            // Create transaction record
            let transaction = CreditTransaction(
                id: UUID(),
                user_id: userId,
                amount: NSDecimalNumber(decimal: amountDecimal).doubleValue,
                transaction_type: "purchase",
                description: description ?? "Credit purchase - $\(String(format: "%.2f", NSDecimalNumber(decimal: amountDecimal).doubleValue))",
                related_media_id: nil,
                payment_method: paymentMethod,
                payment_transaction_id: paymentTransactionId,
                created_at: Date()
            )
            
            try await client.database
                .from("credit_transactions")
                .insert(transaction)
                .execute()
            
            let newBalanceDouble = NSDecimalNumber(decimal: newBalance).doubleValue
            print("✅ [CreditsManager] Added \(amount) credits to user \(userId). New balance: \(newBalanceDouble)")
            return newBalanceDouble
        } catch {
            print("❌ [CreditsManager] Error adding credits: \(error)")
            throw error
        }
    }
    
    // MARK: - Deduct Credits
    
    /// Deducts credits from a user's account
    /// - Parameters:
    ///   - userId: The user's UUID
    ///   - amount: The amount of credits to deduct (positive value)
    ///   - description: Description of what the credits were used for
    ///   - relatedMediaId: Optional UUID of the generated media item
    /// - Returns: The new balance after deduction
    /// - Throws: Error if insufficient credits
    func deductCredits(
        userId: UUID,
        amount: Double,
        description: String,
        relatedMediaId: UUID? = nil
    ) async throws -> Double {
        let amountDecimal = roundBalance(Decimal(amount))
        guard amountDecimal > 0 else {
            throw NSError(
                domain: "CreditsError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Deduction amount must be positive"]
            )
        }
        
        do {
            // Get current balance
            let currentBalance = roundBalance(Decimal(try await fetchCreditBalance(userId: userId)))
            
            // Check if user has enough credits
            guard currentBalance >= amountDecimal else {
                throw NSError(
                    domain: "CreditsError",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Insufficient credits. Current balance: $\(String(format: "%.4f", NSDecimalNumber(decimal: currentBalance).doubleValue)), Required: $\(String(format: "%.4f", NSDecimalNumber(decimal: amountDecimal).doubleValue))"]
                )
            }
            
            // Calculate new balance
            let newBalance = roundBalance(currentBalance - amountDecimal)
            
            // Update user_credits table using a Codable struct
            struct BalanceUpdate: Codable {
                let balance: Decimal
                let updated_at: String
            }
            
            let update = BalanceUpdate(
                balance: newBalance,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client.database
                .from("user_credits")
                .update(update)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            // Create transaction record (negative amount for deduction)
            let transaction = CreditTransaction(
                id: UUID(),
                user_id: userId,
                amount: -NSDecimalNumber(decimal: amountDecimal).doubleValue,
                transaction_type: "deduction",
                description: description,
                related_media_id: relatedMediaId,
                payment_method: nil,
                payment_transaction_id: nil,
                created_at: Date()
            )
            
            try await client.database
                .from("credit_transactions")
                .insert(transaction)
                .execute()
            
            let newBalanceDouble = NSDecimalNumber(decimal: newBalance).doubleValue
            print("✅ [CreditsManager] Deducted \(amount) credits from user \(userId). New balance: \(newBalanceDouble)")
            return newBalanceDouble
        } catch {
            print("❌ [CreditsManager] Error deducting credits: \(error)")
            throw error
        }
    }
    
    // MARK: - Set Credits (Testing Only)
    
    /// Directly sets the credit balance to a specific amount (for testing purposes)
    /// - Parameters:
    ///   - userId: The user's UUID
    ///   - amount: The amount to set the balance to
    /// - Returns: The new balance
    func setCredits(userId: UUID, amount: Double) async throws -> Double {
        do {
            // Ensure user_credits record exists
            _ = try await fetchCreditBalance(userId: userId)
            let amountDecimal = roundBalance(Decimal(amount))
            
            // Update user_credits table using a Codable struct
            struct BalanceUpdate: Codable {
                let balance: Decimal
                let updated_at: String
            }
            
            let update = BalanceUpdate(
                balance: amountDecimal,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client.database
                .from("user_credits")
                .update(update)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            // Create transaction record for testing
            let transaction = CreditTransaction(
                id: UUID(),
                user_id: userId,
                amount: NSDecimalNumber(decimal: amountDecimal).doubleValue,
                transaction_type: "purchase",
                description: "Test credits - Set to $\(String(format: "%.4f", NSDecimalNumber(decimal: amountDecimal).doubleValue))",
                related_media_id: nil,
                payment_method: "test",
                payment_transaction_id: nil,
                created_at: Date()
            )
            
            try await client.database
                .from("credit_transactions")
                .insert(transaction)
                .execute()
            
            let amountDouble = NSDecimalNumber(decimal: amountDecimal).doubleValue
            print("✅ [CreditsManager] Set credits to \(amountDouble) for user \(userId)")
            return amountDouble
        } catch {
            print("❌ [CreditsManager] Error setting credits: \(error)")
            throw error
        }
    }
    
    // MARK: - Get Transaction History
    
    /// Fetches transaction history for a user
    /// - Parameters:
    ///   - userId: The user's UUID
    ///   - limit: Maximum number of transactions to return (default: 50)
    /// - Returns: Array of credit transactions
    func getTransactionHistory(userId: UUID, limit: Int = 50) async throws -> [CreditTransaction] {
        do {
            let transactions: [CreditTransaction] = try await client.database
                .from("credit_transactions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            return transactions
        } catch {
            print("❌ [CreditsManager] Error fetching transaction history: \(error)")
            throw error
        }
    }
    
    // MARK: - Calculate Pending Credits
    
    /// Calculates the total cost of all pending/processing jobs for a user
    /// This represents credits that will be deducted when jobs complete
    /// - Parameter userId: The user's UUID
    /// - Returns: Total pending credits (sum of costs from pending/processing jobs)
    func calculatePendingCredits(userId: UUID) async throws -> Double {
        do {
            // Fetch all pending jobs that are not completed or failed
            let pendingJobs: [PendingJob] = try await client.database
                .from("pending_jobs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .in("status", values: ["pending", "processing"])
                .execute()
                .value
            
            // Sum up the costs from metadata
            let totalPending = pendingJobs.reduce(0.0) { total, job in
                let cost = job.metadata?.cost ?? 0.0
                return total + cost
            }
            
            let roundedTotal = roundBalance(totalPending)
            print("✅ [CreditsManager] Calculated pending credits: $\(String(format: "%.4f", roundedTotal)) for user \(userId)")
            return roundedTotal
        } catch {
            print("❌ [CreditsManager] Error calculating pending credits: \(error)")
            throw error
        }
    }
}

// MARK: - Data Models

/// Represents a user's credit balance
struct UserCredits: Codable {
    let id: UUID
    let user_id: UUID
    let balance: Double
    let created_at: Date
    let updated_at: Date
}

/// Represents a credit transaction
struct CreditTransaction: Codable {
    let id: UUID
    let user_id: UUID
    let amount: Double
    let transaction_type: String // 'purchase', 'deduction', 'refund'
    let description: String?
    let related_media_id: UUID?
    let payment_method: String? // 'apple', 'external', null for deductions
    let payment_transaction_id: String?
    let created_at: Date
}
