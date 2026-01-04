//
//  Creator_AI_StudioApp.swift
//  Creator AI Studio
//
//  Created by Mike K on 11/22/25.
//

import SwiftUI
import GoogleSignIn
import AVFoundation

@main
struct Creator_AI_StudioApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showSplash = false
    
    init() {
        // Enable webhook mode for image and video generation
        WebhookConfig.useWebhooks = true
        
        // Configure audio session at app startup to allow autoplay
        // This primes the audio session early, which can help with autoplay restrictions
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("Failed to configure audio session at app startup: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    // Show splash screen video
                    SplashScreenView {
                        showSplash = false
                    }
                } else {
                    // Skip authentication for now - go directly to ContentView
                    ContentView()
                        .environmentObject(authViewModel)
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.colorScheme)
                    
                    // Original authentication flow (commented out for now):
                    /*
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
                    */
                }
            }
            .animation(.easeInOut, value: showSplash)
            .animation(.easeInOut, value: authViewModel.isCheckingSession)
            .animation(.easeInOut, value: authViewModel.isSignedIn)
            .onOpenURL { url in
                // Handle Google Sign-In URL callback
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
