//
//  CreditsToolbarView.swift
//  Creator AI Studio
//
//  Single toolbar control for credits. When signed out shows "Credits" (diamond + label);
//  when signed in shows CreditsBadge. Supports optional bindings for AuthAwareCostCard.
//  "Sign in" in the toolbar is owned by the page that needs it (e.g. Home).
//

import SwiftUI

/// Unified toolbar view for credits. When signed out shows "Credits" (diamond + label);
/// when signed in shows CreditsBadge. Presents SignIn and PurchaseCredits sheets when
/// triggered (via bindings from AuthAwareCostCard or elsewhere).
struct CreditsToolbarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var localShowSignIn = false
    @State private var localShowPurchase = false

    var externalShowSignIn: Binding<Bool>?
    var externalShowPurchase: Binding<Bool>?
    let diamondColor: Color
    let borderColor: Color

    init(
        diamondColor: Color = .purple,
        borderColor: Color = .purple,
        showSignInSheet: Binding<Bool>? = nil,
        showPurchaseCreditsView: Binding<Bool>? = nil
    ) {
        self.diamondColor = diamondColor
        self.borderColor = borderColor
        self.externalShowSignIn = showSignInSheet
        self.externalShowPurchase = showPurchaseCreditsView
    }

    private var showSignInBinding: Binding<Bool> {
        externalShowSignIn ?? $localShowSignIn
    }

    private var showPurchaseBinding: Binding<Bool> {
        externalShowPurchase ?? $localShowPurchase
    }

    private var creditsButton: some View {
        Button(action: { showPurchaseBinding.wrappedValue = true }) {
            HStack(spacing: 6) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(diamondColor)
                Text("Credits")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
    }

    var body: some View {
        Group {
            if authViewModel.user == nil {
                creditsButton
            } else {
                CreditsBadge(diamondColor: diamondColor, borderColor: borderColor)
            }
        }
        .sheet(isPresented: showSignInBinding) {
            SignInView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: showPurchaseBinding) {
            PurchaseCreditsView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Offline toolbar icon (far right when no internet)

/// Red wifi.slash icon for toolbar; show as the last trailing item when offline.
struct OfflineToolbarIcon: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.red)
        }
    }
}
