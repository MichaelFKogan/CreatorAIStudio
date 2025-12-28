//
//  SubscriptionView.swift
//  Creator AI Studio
//
//  Created for subscription management UI
//

import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSubscribed: Bool = false // TODO: Connect to actual subscription status
    @State private var subscriptionStatus: SubscriptionStatus = .notSubscribed
    
    var body: some View {
        NavigationStack {
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
                        
                        Text("Subscription")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Unlock unlimited access")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Current subscription status
                    SubscriptionStatusCard(status: subscriptionStatus)
                        .padding(.horizontal)
                    
                    // Subscription plan
                    VStack(spacing: 16) {
                        SubscriptionPlanCard(
                            title: "Premium",
                            price: "$4.99",
                            period: "per month",
                            features: [
                                "Unlimited access to all features",
                                "Priority processing",
                                "No watermarks",
                                "Early access to new models",
                                "Buy credits at discounted rates"
                            ],
                            isSubscribed: isSubscribed,
                            onSubscribe: {
                                // TODO: Handle subscription purchase
                                print("Subscribe to Premium")
                            },
                            onManage: {
                                // TODO: Handle subscription management
                                print("Manage subscription")
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Benefits section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What's Included")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            BenefitRow(
                                icon: "sparkles",
                                title: "Unlimited Generations",
                                description: "Create as many images and videos as you want"
                            )
                            
                            BenefitRow(
                                icon: "bolt.fill",
                                title: "Priority Processing",
                                description: "Your jobs get processed faster"
                            )
                            
                            BenefitRow(
                                icon: "checkmark.seal.fill",
                                title: "No Watermarks",
                                description: "All your creations are watermark-free"
                            )
                            
                            BenefitRow(
                                icon: "star.fill",
                                title: "Early Access",
                                description: "Try new models and features first"
                            )
                            
                            BenefitRow(
                                icon: "diamond.fill",
                                title: "Discounted Credits",
                                description: "Save up to 20% on credit purchases"
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Terms and info
                    VStack(spacing: 8) {
                        Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 4) {
                            Button("Terms of Service") {
                                // TODO: Open terms
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Privacy Policy") {
                                // TODO: Open privacy
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
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
    }
}

// Subscription status enum
enum SubscriptionStatus {
    case notSubscribed
    case active
    case expired
    case cancelled
    
    var displayText: String {
        switch self {
        case .notSubscribed:
            return "Not Subscribed"
        case .active:
            return "Active"
        case .expired:
            return "Expired"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .notSubscribed:
            return .gray
        case .active:
            return .green
        case .expired:
            return .orange
        case .cancelled:
            return .red
        }
    }
}

// Subscription status card
struct SubscriptionStatusCard: View {
    let status: SubscriptionStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                    
                    Text(status.displayText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            if status == .active {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
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
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// Subscription plan card
struct SubscriptionPlanCard: View {
    let title: String
    let price: String
    let period: String
    let features: [String]
    let isSubscribed: Bool
    let onSubscribe: () -> Void
    let onManage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(price)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(period)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSubscribed {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            
            // Features list
            VStack(alignment: .leading, spacing: 12) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .padding(.top, 2)
                        
                        Text(feature)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
            
            // Action button
            Button(action: isSubscribed ? onManage : onSubscribe) {
                HStack {
                    Spacer()
                    Text(isSubscribed ? "Manage Subscription" : "Subscribe Now")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: isSubscribed ? [Color.gray, Color.gray] : [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.5), Color.purple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
}

// Benefit row component
struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

