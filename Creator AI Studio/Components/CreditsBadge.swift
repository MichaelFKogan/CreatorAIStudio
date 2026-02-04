//
//  CreditsBadge.swift
//  Creator AI Studio
//
//  Created for reusable credits badge component
//

import SwiftUI

/// A reusable credits badge component that shows "Sign in" when logged out,
/// and displays credits when logged in.
/// Handles sign-in and balance/usage sheet presentation.
/// Automatically fetches and updates credit balance.
struct CreditsBadge: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var creditsViewModel = CreditsViewModel()
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var showSignInSheet: Bool = false
    @State private var showBalanceSheet: Bool = false
    
    // Customization options
    let diamondColor: Color
    let borderColor: Color
    
    init(
        diamondColor: Color = .purple,
        borderColor: Color = .purple
    ) {
        self.diamondColor = diamondColor
        self.borderColor = borderColor
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
            } else if !networkMonitor.isConnected {
                // Offline: show nothing here; wifi icon is shown in toolbar (OfflineToolbarIcon)
                EmptyView()
            } else {
                // Show credits badge when logged in and online
                Button(action: {
                    showBalanceSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 8))
                            // .foregroundColor(diamondColor)
                            .foregroundColor(.white)
                        
                        Text(
                            PricingManager.formatCredits(
                                Decimal(creditsViewModel.balance)
                            )
                        )
                            .font(
                                .system(
                                    size: 14, weight: .semibold,
                                    design: .rounded)
                            )
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            // .strokeBorder(borderColor, lineWidth: 1)
                            .strokeBorder(.white, lineWidth: 1)
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
        .sheet(isPresented: $showBalanceSheet) {
            CreditsBalanceSheet()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Fetch credit balance when badge appears
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
        .onChange(of: authViewModel.user) { newUser in
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { notification in
            // Refresh credits when balance is updated (e.g., after purchase or generation)
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
    }
}
