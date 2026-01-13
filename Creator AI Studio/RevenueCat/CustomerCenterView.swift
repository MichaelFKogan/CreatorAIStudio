//
//  CustomerCenterView.swift
//  Creator AI Studio
//
//  Created for RevenueCat Customer Center integration
//

import SwiftUI
import RevenueCat

struct CustomerCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading...")
                        .scaleEffect(1.2)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundColor(.blue)
                                
                                Text("Account")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .padding(.top, 20)
                            
                            // Subscription Status
                            if revenueCatManager.isProUser {
                                SubscriptionStatusCard(
                                    customerInfo: revenueCatManager.customerInfo,
                                    entitlement: revenueCatManager.getActiveEntitlement()
                                )
                            } else {
                                NoSubscriptionCard()
                            }
                            
                            // Customer Info Details
                            if let customerInfo = revenueCatManager.customerInfo {
                                CustomerInfoCard(customerInfo: customerInfo)
                            }
                            
                            // Actions
                            VStack(spacing: 12) {
                                Button(action: {
                                    Task {
                                        await restorePurchases()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Restore Purchases")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(.secondarySystemBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                                }
                                
                                if revenueCatManager.isProUser {
                                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                        HStack {
                                            Image(systemName: "gear")
                                            Text("Manage Subscription")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Footer
                            Text("For subscription management, visit your Apple ID settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.bottom, 32)
                        }
                    }
                }
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
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .task {
                await refreshCustomerInfo()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshCustomerInfo() async {
        isLoading = true
        await revenueCatManager.fetchCustomerInfo()
        isLoading = false
    }
    
    private func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await revenueCatManager.restorePurchases()
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
            }
        }
    }
}

// MARK: - Subscription Status Card

struct SubscriptionStatusCard: View {
    let customerInfo: CustomerInfo?
    let entitlement: EntitlementInfo?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Runspeed AI Pro")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Active Subscription")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let expirationDate = entitlement?.expirationDate {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Renews:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(expirationDate, style: .date)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    if let periodType = entitlement?.periodType {
                        HStack {
                            Text("Period:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(periodTypeDescription(periodType))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private func periodTypeDescription(_ periodType: PeriodType) -> String {
        switch periodType {
        case .intro:
            return "Introductory"
        case .normal:
            return "Normal"
        case .trial:
            return "Trial"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - No Subscription Card

struct NoSubscriptionCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("No Active Subscription")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Upgrade to Pro to unlock all features")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Customer Info Card

struct CustomerInfoCard: View {
    let customerInfo: CustomerInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Information")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                CustomerInfoRow(label: "User ID", value: customerInfo.originalAppUserId)
                
                CustomerInfoRow(
                    label: "Member Since",
                    value: ISO8601DateFormatter().string(from: customerInfo.firstSeen),
                    style: .date
                )
                
                if let managementURL = customerInfo.managementURL {
                    Link(destination: managementURL) {
                        HStack {
                            Text("Manage Subscription")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Info Row

struct CustomerInfoRow: View {
    let label: String
    let value: String
    var style: Text.DateStyle? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if let style = style, let date = ISO8601DateFormatter().date(from: value) {
                Text(date, style: style)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            } else {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
}
