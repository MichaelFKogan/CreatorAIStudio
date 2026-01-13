//
//  EntitlementHelper.swift
//  Creator AI Studio
//
//  Created for easy entitlement checking throughout the app
//

import SwiftUI
import RevenueCat

/// Helper extension for checking Pro entitlement
extension View {
    /// Checks if the user has the Pro entitlement
    /// - Returns: True if user has active Pro subscription
    func hasProEntitlement() -> Bool {
        return RevenueCatManager.shared.hasProEntitlement()
    }
}

/// View modifier to conditionally show content based on entitlement
struct EntitlementView<ProContent: View, FreeContent: View>: View {
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    let proContent: () -> ProContent
    let freeContent: () -> FreeContent
    
    var body: some View {
        Group {
            if revenueCatManager.isProUser {
                proContent()
            } else {
                freeContent()
            }
        }
        .task {
            await revenueCatManager.fetchCustomerInfo()
        }
    }
}

/// View modifier to show paywall when user doesn't have Pro
struct ProRequiredView<Content: View>: View {
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var showPaywall = false
    let content: () -> Content
    
    var body: some View {
        Group {
            if revenueCatManager.isProUser {
                content()
            } else {
                content()
                    .onTapGesture {
                        showPaywall = true
                    }
                    .sheet(isPresented: $showPaywall) {
                        PaywallView()
                    }
            }
        }
        .task {
            await revenueCatManager.fetchCustomerInfo()
        }
    }
}
