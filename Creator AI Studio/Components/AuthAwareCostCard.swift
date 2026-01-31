//
//  AuthAwareCostCard.swift
//  Creator AI Studio
//
//  Created to consolidate authentication and credit checking UI across all detail pages
//

import SwiftUI

/// A reusable component that handles four states:
/// 1. Not signed in: Shows sign in/sign up card
/// 2. Signed in, no internet: Shows "No internet connection" message (replaces insufficient credits slot)
/// 3. Signed in with enough credits: Shows EnhancedCostCard with success state
/// 4. Signed in without enough credits: Shows EnhancedCostCard with insufficient credits state
struct AuthAwareCostCard: View {
    let price: Decimal
    let requiredCredits: Double
    let primaryColor: Color
    let secondaryColor: Color
    let loginMessage: String  // e.g., "Log in to generate an image" or "Log in to generate a video"
    var isConnected: Bool = true  // When false, show no-internet message instead of insufficient credits
    let onSignIn: () -> Void
    let onBuyCredits: () -> Void
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    
    // Check if user has enough credits
    private var hasEnoughCredits: Bool {
        guard let userId = authViewModel.user?.id else { return false }
        return creditsViewModel.hasEnoughCredits(requiredAmount: requiredCredits)
    }
    
    var body: some View {
        Group {
            if authViewModel.user == nil {
                // Not logged in: Show login disclaimer and Sign In button
                notLoggedInCard
            } else if !isConnected {
                // Logged in but no internet: Show no-internet message (replaces insufficient credits slot)
                noInternetCard
            } else {
                // Logged in, connected: Show enhanced cost card
                EnhancedCostCard(
                    price: price,
                    balance: creditsViewModel.formattedBalance(),
                    hasEnoughCredits: hasEnoughCredits,
                    requiredAmount: requiredCredits,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    onBuyCredits: onBuyCredits
                )
            }
        }
        .onAppear {
            // Fetch credit balance when view appears
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
        .onChange(of: authViewModel.user) { oldUser, newUser in
            // Refresh credits when user signs in or changes
            if let userId = newUser?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            } else {
                // Reset balance when user signs out
                creditsViewModel.balance = 0.00
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { _ in
            // Refresh credits when balance is updated (e.g., after purchase)
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
    }
    
    private var notLoggedInCard: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
            Text(loginMessage)
                .font(.caption)
                .foregroundColor(.red)
            Spacer(minLength: 8)
            Button(action: onSignIn) {
                Text("Sign In / Sign Up")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(primaryColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    /// No-internet message shown below Generate/Upload button when user is logged in but offline
    private var noInternetCard: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
            Text("No internet connection. Please connect to the internet.")
                .font(.caption)
                .foregroundColor(.red)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
