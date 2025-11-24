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
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
