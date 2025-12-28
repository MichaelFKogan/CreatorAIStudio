//
//  PurchaseCreditsView.swift
//  Creator AI Studio
//
//  Created for purchase credits UI
//

import SwiftUI

struct PurchaseCreditsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSubscriptionView: Bool = false
    @State private var isSubscribed: Bool = false // TODO: Connect to actual subscription status
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: isSubscribed ? "diamond.fill" : "crown.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: isSubscribed ? [.blue, .purple] : [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(isSubscribed ? "Buy Credits" : "Get Started")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(isSubscribed ? "Choose a credit package" : "Subscribe and get credits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Info banner for non-subscribers
                    if !isSubscribed {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                
                                Text("Subscription required to use the app and purchase credits")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }
                    
                    // Start Packs (for non-subscribers) or Credit Packages (for subscribers)
                    VStack(spacing: 16) {
                        if !isSubscribed {
                            // Start Packs: Subscription + Credits bundles
                            StartPackCard(
                                title: "Starter Pack",
                                subscriptionPrice: "$4.99",
                                creditsValue: "$1.00",
                                totalPrice: "$5.99",
                                badge: "Popular"
                            )
                            
                            StartPackCard(
                                title: "Pro Pack",
                                subscriptionPrice: "$4.99",
                                creditsValue: "$5.00",
                                totalPrice: "$9.99",
                                badge: "Best Value"
                            )
                            
                            StartPackCard(
                                title: "Mega Pack",
                                subscriptionPrice: "$4.99",
                                creditsValue: "$10.00",
                                totalPrice: "$14.99"
                            )
                        } else {
                            // Credit Packages: Individual credit purchases for subscribers
                            CreditPackageCard(
                                title: "Starter Pack",
                                credits: "$10.00",
                                price: "$9.99",
                                badge: "Best Value"
                            )
                            
                            CreditPackageCard(
                                title: "Pro Pack",
                                credits: "$25.00",
                                price: "$24.99"
                            )
                            
                            CreditPackageCard(
                                title: "Mega Pack",
                                credits: "$50.00",
                                price: "$49.99"
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
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
        }
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionView()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
    }
}

// Placeholder credit package card
struct CreditPackageCard: View {
    let title: String
    let credits: String
    let price: String
    var badge: String? = nil
    
    var body: some View {
        Button(action: {
            // TODO: Handle purchase logic
            print("Purchase \(title)")
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            Text(credits)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(price)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Start Pack Card: Subscription + Credits bundle for non-subscribers
struct StartPackCard: View {
    let title: String
    let subscriptionPrice: String
    let creditsValue: String
    let totalPrice: String
    var badge: String? = nil
    
    var body: some View {
        Button(action: {
            // TODO: Handle start pack purchase (subscription + credits)
            print("Purchase \(title): \(subscriptionPrice)/month + \(creditsValue) credits = \(totalPrice)")
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with title and badge
                HStack {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let badge = badge {
                        Text(badge)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                
                // Subscription + Credits breakdown
                HStack(spacing: 16) {
                    // Subscription (left)
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(spacing: 4) {
                            Text("Subscription")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text(subscriptionPrice)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("/month")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Plus sign
                    Text("+")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    // Credits (right)
                    VStack(spacing: 8) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 4) {
                            Text("Credits")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text(creditsValue)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                
                // Total price
                HStack {
                    Text("Total")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(totalPrice)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.5), Color.orange.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

