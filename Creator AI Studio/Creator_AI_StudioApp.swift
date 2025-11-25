//
//  Creator_AI_StudioApp.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/22/25.
//

import SwiftUI

@main
struct Creator_AI_StudioApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isCheckingSession {
                    // Show a loading indicator while checking session
                    ProgressView()
                        .scaleEffect(1.5)
                } else if authViewModel.isSignedIn {
                    ContentView()
                        .environmentObject(authViewModel)
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.colorScheme)
                } else {
                    SignInView()
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.colorScheme)
                        .environmentObject(authViewModel)
                }
            }
            .animation(.easeInOut, value: authViewModel.isCheckingSession)
            .animation(.easeInOut, value: authViewModel.isSignedIn)
        }
    }
}
