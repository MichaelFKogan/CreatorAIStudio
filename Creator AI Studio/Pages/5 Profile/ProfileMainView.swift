import SwiftUI

// MARK: PROFILE

struct Profile: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Always show gallery content (with placeholders if not signed in)
                if authViewModel.isCheckingSession {
                    // Show loading while checking session
                    ProgressView("Loading…")
                        .padding()
                } else {
                    ProfileViewContent(viewModel: viewModel, isSignedIn: authViewModel.user != nil)
                        .environmentObject(authViewModel)
                        .onAppear {
                            if let user = authViewModel.user {
                                let userIdChanged = viewModel.userId != user.id.uuidString
                                if userIdChanged {
                                    viewModel.userId = user.id.uuidString
                                }
                                Task {
                                    // Fetch stats FIRST so UI shows correct counts immediately
                                    // This is very cheap - just one row from user_stats table
                                    if !viewModel.hasLoadedStats || userIdChanged {
                                        await viewModel.fetchUserStats()
                                    }
                                    // Then fetch images
                                    await viewModel.fetchUserImages(
                                        forceRefresh: false)
                                }
                            }
                        }
                        .onChange(of: authViewModel.user) { oldUser, newUser in
                            // When user signs in or changes, fetch images
                            if let user = newUser {
                                let userIdChanged = viewModel.userId != user.id.uuidString
                                // Only fetch if this is a new sign-in or user changed
                                if oldUser == nil || userIdChanged {
                                    if userIdChanged {
                                        viewModel.userId = user.id.uuidString
                                    }
                                    Task {
                                        // Fetch stats FIRST so UI shows correct counts immediately
                                        if !viewModel.hasLoadedStats || userIdChanged {
                                            await viewModel.fetchUserStats()
                                        }
                                        // Then fetch images
                                        await viewModel.fetchUserImages(forceRefresh: false)
                                    }
                                }
                            }
                        }
                }
                
                // Show sign-in overlay when not signed in
                if !authViewModel.isCheckingSession && authViewModel.user == nil {
                    SignInOverlay()
                        .environmentObject(authViewModel)
                }
            }

            // MARK: NAVIGATION BAR

            .navigationTitle("")
            .toolbar {
                // Always show "Gallery" title
                if !authViewModel.isCheckingSession {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("Gallery")
                            .font(
                                .system(size: 28, weight: .bold, design: .rounded)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.gray, .white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
        }
    }
}

