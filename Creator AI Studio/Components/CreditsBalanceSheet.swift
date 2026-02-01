//
//  CreditsBalanceSheet.swift
//  Creator AI Studio
//
//  Balance & Usage sheet: balance, pending, short stats, link to full usage, Buy credits CTA.
//

import SwiftUI

/// Sheet presented when user taps the toolbar credit badge.
/// Shows balance, optional pending credits, short usage stats, "View full usage" link, and "Get more credits" CTA.
struct CreditsBalanceSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @StateObject private var usageViewModel = UsageViewModel()
    @State private var showPurchaseCredits: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                // Balance block
                Section {
                    if creditsViewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(creditsViewModel.formattedBalance())
                                    .font(.title2.weight(.semibold))
                            }
                            if creditsViewModel.pendingCredits > 0 {
                                HStack {
                                    Text("Pending")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(PricingManager.formatPriceWithUnit(Decimal(creditsViewModel.pendingCredits)))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Credit Balance")
                }
                
                // Short usage stats
                Section("Usage") {
                    if usageViewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.9)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    } else {
                        StatisticsRow(
                            title: "Total Attempts",
                            value: "\(usageViewModel.totalAttempts)",
                            icon: "number.circle.fill",
                            color: .blue
                        )
                        if usageViewModel.totalAttempts > 0 {
                            StatisticsRow(
                                title: "Success Rate",
                                value: String(format: "%.1f%%", usageViewModel.successRate),
                                icon: "percent",
                                color: .orange
                            )
                        }
                        StatisticsRow(
                            title: "Credits Added",
                            value: "\(usageViewModel.creditsAddedCount)",
                            icon: "plus.circle.fill",
                            color: .green
                        )
                    }
                }
                
                // View full usage
                Section {
                    NavigationLink {
                        UsageView()
                            .environmentObject(authViewModel)
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.orange)
                            Text("View Full Usage")
                        }
                    }
                }
                
                // Get more credits CTA
                Section {
                    Button {
                        showPurchaseCredits = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Get More Credits")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDragIndicator(.visible)
            .onAppear {
                if let userId = authViewModel.user?.id {
                    Task {
                        await creditsViewModel.fetchBalance(userId: userId)
                        await usageViewModel.fetchUsage(userId: authViewModel.user?.id.uuidString)
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
        }
        .sheet(isPresented: $showPurchaseCredits) {
            PurchaseCreditsView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
    }
}
