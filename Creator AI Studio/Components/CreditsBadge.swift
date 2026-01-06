//
//  CreditsBadge.swift
//  Creator AI Studio
//
//  Created for reusable credits badge component
//

import SwiftUI

/// A reusable credits badge component that shows "Sign in" when logged out,
/// and displays credits when logged in.
/// Handles sign-in and purchase credits sheet presentation.
struct CreditsBadge: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignInSheet: Bool = false
    @State private var showPurchaseCreditsSheet: Bool = false
    
    // Customization options
    let diamondColor: Color
    let borderColor: Color
    let creditsAmount: String
    
    init(
        diamondColor: Color = .purple,
        borderColor: Color = .purple,
        creditsAmount: String = "$1.97"
    ) {
        self.diamondColor = diamondColor
        self.borderColor = borderColor
        self.creditsAmount = creditsAmount
    }
    
    var body: some View {
        Group {
            if authViewModel.user == nil {
                // Show "Sign in" button when logged out
                Button(action: {
                    showSignInSheet = true
                }) {
                    Text("Sign in")
                        .font(
                            .system(
                                size: 16, weight: .semibold,
                                design: .rounded)
                        )
                        .foregroundColor(.primary)
                }
            } else {
                // Show credits badge when logged in - make it tappable
                Button(action: {
                    showPurchaseCreditsSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [diamondColor, diamondColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .font(.system(size: 8))
                        
                        Text(creditsAmount)
                            .font(
                                .system(
                                    size: 14, weight: .semibold,
                                    design: .rounded)
                            )
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.secondary.opacity(0.1))
                            .shadow(
                                color: Color.black.opacity(0.2), radius: 4,
                                x: 0, y: 2
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [borderColor, borderColor],
                                    startPoint: .leading,
                                    endPoint: .trailing),
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPurchaseCreditsSheet) {
            PurchaseCreditsView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
    }
}

