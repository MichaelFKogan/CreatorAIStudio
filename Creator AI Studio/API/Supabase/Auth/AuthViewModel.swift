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
    @Published var lastError: String? = nil
    
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
        lastError = nil
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
            let errorMessage = error.localizedDescription
            // Check for common Supabase error messages
            if errorMessage.contains("already registered") || 
               errorMessage.contains("User already registered") ||
               errorMessage.contains("already exists") {
                lastError = "USER_EXISTS"
            } else {
                lastError = errorMessage
            }
        }
    }

    func signInWithEmail(email: String, password: String) async {
        print("🔑 Attempting sign in with email: \(email)")
        lastError = nil
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
            lastError = error.localizedDescription
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
        lastError = nil
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
            )
            print("✅ Google sign-in successful: \(session.user.id)")
            self.user = session.user
            self.isSignedIn = true
            
            // Start listening for webhook job completions
            await JobStatusManager.shared.startListening(userId: session.user.id.uuidString)
        } catch {
            print("❌ Google sign-in error: \(error.localizedDescription)")
            let errorMessage = error.localizedDescription.lowercased()
            // Check for common Supabase error messages indicating user doesn't exist or needs to sign up
            if errorMessage.contains("user not found") ||
               errorMessage.contains("invalid_credentials") ||
               errorMessage.contains("invalid login credentials") ||
               errorMessage.contains("email not confirmed") ||
               errorMessage.contains("no user found") ||
               errorMessage.contains("user does not exist") ||
               errorMessage.contains("signup_disabled") ||
               errorMessage.contains("nonce") ||
               errorMessage.contains("id_token") {
                // This error typically means the user needs to create an account first
                lastError = "USER_NOT_FOUND"
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async {
        print("📧 Attempting password reset for email: \(email)")
        lastError = nil
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "yourapp://reset-password") // Optional: deep link for web
            )
            print("✅ Password reset email sent successfully")
            // Success - email sent
        } catch {
            print("❌ Password reset error: \(error)")
            lastError = error.localizedDescription
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
