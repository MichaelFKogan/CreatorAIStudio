//
//  CreditsBalanceSheet.swift
//  Creator AI Studio
//
//  Small bottom sheet: credit balance available and Get more credits button.
//

import SwiftUI

/// Small sheet presented when user taps the toolbar credit badge.
/// Shows credit balance (available) and Get more credits button.
struct CreditsBalanceSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @State private var showPurchaseCredits: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Current Balance card
            VStack(spacing: 8) {
                Text("Current Balance")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                if creditsViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                        Text(creditsViewModel.formattedBalance())
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("Credits never expire")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal, 24)

            // Get more credits button (styled like PurchaseCreditsView)
            Button {
                showPurchaseCredits = true
            } label: {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Get More Credits")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .presentationDetents([.height(260), .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreditsBalanceUpdated"))) { _ in
            if let userId = authViewModel.user?.id {
                Task {
                    await creditsViewModel.fetchBalance(userId: userId)
                }
            }
        }
        .sheet(isPresented: $showPurchaseCredits) {
            PurchaseCreditsView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
    }
}
