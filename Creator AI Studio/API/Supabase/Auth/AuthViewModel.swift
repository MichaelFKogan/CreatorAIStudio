//
//  AuthViewModel.swift
//  AI Photo Generation
//
//  Created by Mike K on 10/18/25.
//

import Supabase
import Foundation
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var user: User?
    @Published var isCheckingSession = true
    
    private let client = SupabaseManager.shared.client
    private let sessionKey = "supabase.session"

    init() {
        Task {
            await checkSession()
        }
    }

    func checkSession() async {
//        print("🔍 Checking session...")
        do {
            let session = try await client.auth.session
//            print("✅ Session found: \(session.user.id)")
            self.user = session.user
            self.isSignedIn = true
            
            // Start listening for webhook job completions
            await JobStatusManager.shared.startListening(userId: session.user.id.uuidString)
        } catch {
            print("❌ Session check failed: \(error)")
            self.isSignedIn = false
        }
        self.isCheckingSession = false
//        print("Session check complete. isSignedIn: \(self.isSignedIn)")
    }

    // MARK: - Email Sign In / Sign Up

    func signUpWithEmail(email: String, password: String) async {
        print("📝 Attempting sign up with email: \(email)")
        do {
            let result = try await client.auth.signUp(
                email: email,
                password: password
            )
            print("✅ Sign up successful: \(result.user.id)")
            
            // Check if email confirmation is required
            if let session = result.session {
                print("✅ Session created immediately")
                self.user = session.user
                self.isSignedIn = true
                
                // Start listening for webhook job completions
                await JobStatusManager.shared.startListening(userId: session.user.id.uuidString)
            } else {
                print("⚠️ Email confirmation required - check your inbox")
                // You might want to show an alert to the user here
            }
        } catch {
            print("❌ Email sign-up error: \(error)")
        }
    }

    func signInWithEmail(email: String, password: String) async {
        print("🔑 Attempting sign in with email: \(email)")
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            print("✅ Sign in successful: \(session.user.id)")
            print("📦 Access token: \(session.accessToken.prefix(20))...")
            self.user = session.user
            self.isSignedIn = true
            
            // Start listening for webhook job completions
            await JobStatusManager.shared.startListening(userId: session.user.id.uuidString)
            
            // Test: Check if session persists in UserDefaults
            if let storedData = UserDefaults.standard.data(forKey: "supabase.session") {
                print("✅ Session stored in UserDefaults: \(storedData.count) bytes")
            } else {
                print("❌ Session NOT stored in UserDefaults")
            }
        } catch {
            print("❌ Email sign-in error: \(error)")
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple(idToken: String) async {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, accessToken: nil)
            )
            self.user = session.user
            self.isSignedIn = true
            
            // Start listening for webhook job completions
            await JobStatusManager.shared.startListening(userId: session.user.id.uuidString)
        } catch {
            print("Apple sign-in error: \(error.localizedDescription)")
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle(idToken: String, accessToken: String) async {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
            )
            self.user = session.user
            self.isSignedIn = true
            
            // Start listening for webhook job completions
            await JobStatusManager.shared.startListening(userId: session.user.id.uuidString)
        } catch {
            print("Google sign-in error: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            // Stop listening for webhook job completions
            await JobStatusManager.shared.stopListening()
            
            try await client.auth.signOut()
            self.isSignedIn = false
            self.user = nil
        } catch {
            print("Sign-out error: \(error.localizedDescription)")
        }
    }
}
