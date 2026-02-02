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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @State private var showPurchaseCredits: Bool = false
    @State private var showCopiedAlert: Bool = false
    @State private var isSigningOut: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Signed-in account (email + user ID)
            if authViewModel.user != nil {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("Signed in as")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            if let email = authViewModel.user?.email {
                                Text(email)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        Spacer(minLength: 8)
                        Button {
                            isSigningOut = true
                            Task {
                                await authViewModel.signOut()
                                isSigningOut = false
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                dismiss()
                            }
                        } label: {
                            if isSigningOut {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sign out")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.red)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isSigningOut)
                    }
                    if let userId = authViewModel.user?.id.uuidString {
                        HStack(spacing: 6) {
                            Text("User ID:")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(userId)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button {
                                UIPasteboard.general.string = userId
                                showCopiedAlert = true
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            }

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
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        Text(creditsViewModel.formattedBalance())
                            .font(.system(size: 20, weight: .bold, design: .rounded))
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
                    Image(systemName: "cart.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
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
        .presentationDetents([.height(320), .large])
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
        .alert("Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("User ID copied to clipboard.")
        }
    }
}
