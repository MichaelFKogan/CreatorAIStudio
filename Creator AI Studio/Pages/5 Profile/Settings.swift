import SwiftUI

struct Settings: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showCopiedAlert = false
    @State private var showCacheClearedAlert = false
    @State private var isClearing = false
    
    // ProfileViewModel for cache clearing
    var profileViewModel: ProfileViewModel?

    var body: some View {
        List {
            // Account section
            Section("Account") {
                // User ID with copy button
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("User ID")
                            .font(.body)
                        if let userId = authViewModel.user?.id.uuidString {
                            Text(userId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Spacer()
                    Button(action: {
                        if let userId = authViewModel.user?.id.uuidString {
                            UIPasteboard.general.string = userId
                            showCopiedAlert = true

                            // Haptic feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                }

                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.blue)
                    Text("Account Settings")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }

                HStack {
                    Image(systemName: "lock.circle")
                        .foregroundColor(.green)
                    Text("Privacy & Security")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }

            // // App preferences
            // Section("Preferences") {
            //     HStack {
            //         Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
            //             .foregroundColor(.blue)
            //         Text("Dark Mode")
            //         Spacer()
            //         Toggle("", isOn: Binding(
            //             get: { themeManager.isDarkMode },
            //             set: { _ in themeManager.toggleTheme() }
            //         ))
            //     }
                
            //     // Clear Cache button
            //     Button(action: {
            //         clearCache()
            //     }) {
            //         HStack {
            //             Image(systemName: "trash")
            //                 .foregroundColor(.orange)
            //             Text("Clear Gallery Cache")
            //                 .foregroundColor(.primary)
            //             Spacer()
            //             if isClearing {
            //                 ProgressView()
            //                     .scaleEffect(0.8)
            //             }
            //         }
            //     }
            //     .disabled(isClearing)

//                HStack {
//                    Image(systemName: "paintbrush")
//                        .foregroundColor(.orange)
//                    Text("Default AI Model")
//                    Spacer()
//                    Text("GPT-4 Vision")
//                        .foregroundColor(.secondary)
//                    Image(systemName: "chevron.right")
//                        .foregroundColor(.gray)
//                }
//
//                HStack {
//                    Image(systemName: "photo")
//                        .foregroundColor(.purple)
//                    Text("Image Quality")
//                    Spacer()
//                    Text("High")
//                        .foregroundColor(.secondary)
//                    Image(systemName: "chevron.right")
//                        .foregroundColor(.gray)
//                }
//
//                HStack {
//                    Image(systemName: "square.and.arrow.down")
//                        .foregroundColor(.blue)
//                    Text("Auto-save to Gallery")
//                    Spacer()
//                    Toggle("", isOn: .constant(true))
//                }
            // }

            // Support
            Section("Support") {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                    Text("Help & FAQ")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }

                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.green)
                    Text("Contact Support")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }

                HStack {
                    Image(systemName: "star")
                        .foregroundColor(.yellow)
                    Text("Rate the App")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }

            // About
            Section("About") {
//                HStack {
//                    Image(systemName: "info.circle")
//                        .foregroundColor(.blue)
//                    Text("App Version")
//                    Spacer()
//                    Text("1.0.0")
//                        .foregroundColor(.secondary)
//                }

                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.gray)
                    Text("Terms of Service")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }

                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(.gray)
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }

            }

            // Sign out
            Section {
                Button(action: {
                    Task {
                        await authViewModel.signOut()
                    }
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("Sign Out")
                            .foregroundColor(.red)
                    }
                }
            }

            // Add spacing at the bottom
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .alert("Copied!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("User ID copied to clipboard")
        }
        .alert("Cache Cleared", isPresented: $showCacheClearedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Gallery cache has been cleared. Pull to refresh on the Gallery page to reload your images.")
        }
    }
    
    private func clearCache() {
        isClearing = true
        
        // Clear the profile cache
        profileViewModel?.clearCache()
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        isClearing = false
        showCacheClearedAlert = true
    }
}
