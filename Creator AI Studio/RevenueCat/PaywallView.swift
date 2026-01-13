//
//  PaywallView.swift
//  Creator AI Studio
//
//  Created for RevenueCat Paywall integration
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var offerings: Offerings?
    @State private var isLoadingOfferings = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoadingOfferings {
                    ProgressView("Loading subscriptions...")
                        .scaleEffect(1.2)
                } else if let offerings = offerings, let currentOffering = offerings.current {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text("Upgrade to Pro")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("Unlock all premium features")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 20)
                            
                            // Current Status
                            if revenueCatManager.isProUser {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("You have an active Pro subscription")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.green.opacity(0.1))
                                )
                                .padding(.horizontal)
                            }
                            
                            // Packages
                            VStack(spacing: 16) {
                                ForEach(currentOffering.availablePackages, id: \.identifier) { package in
                                    PackageCard(
                                        package: package,
                                        isSelected: selectedPackage?.identifier == package.identifier,
                                        isPurchasing: isPurchasing
                                    ) {
                                        selectedPackage = package
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Purchase Button
                            if let selectedPackage = selectedPackage {
                                Button(action: {
                                    Task {
                                        await purchasePackage(selectedPackage)
                                    }
                                }) {
                                    HStack {
                                        if isPurchasing {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("Subscribe")
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .disabled(isPurchasing)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            
                            // Restore Purchases
                            Button(action: {
                                Task {
                                    await restorePurchases()
                                }
                            }) {
                                Text("Restore Purchases")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 8)
                            
                            // Terms and Privacy
                            HStack(spacing: 16) {
                                Link("Terms of Service", destination: URL(string: "https://www.revenuecat.com/terms")!)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .foregroundColor(.secondary)
                                
                                Link("Privacy Policy", destination: URL(string: "https://www.revenuecat.com/privacy")!)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("No subscriptions available")
                            .font(.headline)
                        
                        Text("Please try again later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Retry") {
                            Task {
                                await loadOfferings()
                            }
                        }
                        .buttonStyle(.borderedProminent)
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
                await loadOfferings()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadOfferings() async {
        isLoadingOfferings = true
        errorMessage = nil
        
        do {
            let fetchedOfferings = try await revenueCatManager.fetchOfferings()
            await MainActor.run {
                self.offerings = fetchedOfferings
                // Auto-select first package if available
                if let firstPackage = fetchedOfferings.current?.availablePackages.first {
                    self.selectedPackage = firstPackage
                }
                self.isLoadingOfferings = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoadingOfferings = false
                self.showErrorAlert = true
            }
        }
    }
    
    private func purchasePackage(_ package: Package) async {
        isPurchasing = true
        errorMessage = nil
        
        do {
            _ = try await revenueCatManager.purchase(package: package)
            await MainActor.run {
                self.isPurchasing = false
                // Dismiss on successful purchase
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.isPurchasing = false
                // Check if error is user cancellation - RevenueCat uses ErrorCode for this
                if let purchasesError = error as? ErrorCode, purchasesError == .purchaseCancelledError {
                    // Don't show error for user cancellation
                    return
                }
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
            }
        }
    }
    
    private func restorePurchases() async {
        do {
            try await revenueCatManager.restorePurchases()
            await MainActor.run {
                // Refresh offerings after restore
                Task {
                    await loadOfferings()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
            }
        }
    }
}

// MARK: - Package Card

struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let isPurchasing: Bool
    let onTap: () -> Void
    
    private var packageType: String {
        switch package.packageType {
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        case .sixMonth:
            return "6 Months"
        case .threeMonth:
            return "3 Months"
        case .twoMonth:
            return "2 Months"
        case .weekly:
            return "Weekly"
        case .lifetime:
            return "Lifetime"
        case .custom:
            return "Custom"
        case .unknown:
            return ""
        @unknown default:
            return ""
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(package.storeProduct.localizedTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if !packageType.isEmpty {
                            Text(packageType)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if !package.storeProduct.localizedDescription.isEmpty {
                        Text(package.storeProduct.localizedDescription)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if package.packageType == .annual {
                        // Calculate savings for annual vs monthly
                        if let monthlyPackage = findMonthlyPackage() {
                            let monthlyPrice = NSDecimalNumber(decimal: monthlyPackage.storeProduct.price).doubleValue
                            let annualPrice = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue
                            let monthlyEquivalent = annualPrice / 12.0
                            if monthlyEquivalent < monthlyPrice {
                                let savings = ((monthlyPrice - monthlyEquivalent) / monthlyPrice) * 100
                                Text("Save \(Int(savings))%")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isPurchasing)
    }
    
    private func findMonthlyPackage() -> Package? {
        // This would need access to offerings to find monthly package
        // For now, return nil
        return nil
    }
}
