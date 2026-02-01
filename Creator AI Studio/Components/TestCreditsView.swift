//
//  TestCreditsView.swift
//  Creator AI Studio
//
//  Created for testing credit amounts
//

import SwiftUI

struct TestCreditsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var creditsViewModel = CreditsViewModel()
    @State private var isUpdating = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    let testAmounts: [Double] = [0.00, 0.05, 5.00, 10.00, 20.00, 50.00]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.purple)
                    
                    Text("Test Credits")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Set your credit balance for testing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Current Balance Display
                if let userId = authViewModel.user?.id {
                    VStack(spacing: 8) {
                        Text("Current Balance")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text(creditsViewModel.formattedBalance())
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                }
                
                // Test Amount Buttons
                VStack(spacing: 12) {
                    ForEach(testAmounts, id: \.self) { amount in
                        Button(action: {
                            setCredits(amount: amount)
                        }) {
                            HStack {
                                Image(systemName: "diamond.fill")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 16))
                                
                                Text(formatAmount(amount))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if isUpdating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(isUpdating)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let userId = authViewModel.user?.id {
                    Task {
                        await creditsViewModel.fetchBalance(userId: userId)
                    }
                }
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Credit balance updated successfully")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount == 0 {
            return "$0.00"
        } else if amount < 1 {
            return String(format: "$%.2f", amount)
        } else {
            return String(format: "$%.2f", amount)
        }
    }
    
    private func setCredits(amount: Double) {
        guard let userId = authViewModel.user?.id else {
            errorMessage = "You must be signed in to test credits"
            showErrorAlert = true
            return
        }
        
        isUpdating = true
        
        Task {
            do {
                let newBalance = try await CreditsManager.shared.setCredits(userId: userId, amount: amount)
                await MainActor.run {
                    creditsViewModel.balance = newBalance
                    isUpdating = false
                    showSuccessAlert = true
                    
                    // Post notification to refresh credit balance in UI
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CreditsBalanceUpdated"),
                        object: nil,
                        userInfo: ["userId": userId]
                    )
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
}

