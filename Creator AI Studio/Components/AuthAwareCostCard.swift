//
//  AuthAwareCostCard.swift
//  Creator AI Studio
//
//  Created to consolidate authentication and credit checking UI across all detail pages
//

import SwiftUI

/// A reusable component that handles three states:
/// 1. Not signed in: Shows sign in/sign up card
/// 2. Signed in with enough credits: Shows EnhancedCostCard with success state
/// 3. Signed in without enough credits: Shows EnhancedCostCard with insufficient credits state
struct AuthAwareCostCard: View {
    let price: Decimal
    let requiredCredits: Double
    let primaryColor: Color
    let secondaryColor: Color
    let loginMessage: String  // e.g., "Log in to generate an image" or "Log in to generate a video"
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
                VStack(spacing: 0) {
                    notLoggedInCard
                    
                    // Cost display below the card, aligned to the right
                    // Add padding to position it closer to the Generate button
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Cost:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            PriceDisplayView(
                                price: price,
                                showUnit: true,
                                font: .caption,
                                fontWeight: .semibold,
                                foregroundColor: .primary
                            )
                        }
                    }
                    .padding(.top, 20)
                }
            } else {
                // Logged in: Show enhanced cost card
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
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                Text(loginMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
                Spacer()
            }
            
            Button(action: onSignIn) {
                Text("Sign In / Sign Up")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [primaryColor.opacity(0.08), secondaryColor.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}
