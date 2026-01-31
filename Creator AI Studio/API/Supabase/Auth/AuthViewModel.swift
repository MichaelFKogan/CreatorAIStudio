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
            // Push notifications: set user and request permissions so we get device token
            await setupPushNotificationsForUser(session.user.id.uuidString)
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
                await setupPushNotificationsForUser(session.user.id.uuidString)
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
            await setupPushNotificationsForUser(session.user.id.uuidString)
            
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

    /// Signs in with Apple using the ID token
    /// - Parameters:
    ///   - idToken: The identity token from Apple Sign-In
    ///   - rawNonce: The raw (unhashed) nonce that was passed to Apple Sign-In.
    ///               Apple hashes this and includes the hash in the ID token.
    ///               Supabase will hash this raw nonce and compare it to the hash in the token.
    func signInWithApple(idToken: String, rawNonce: String? = nil) async {
        lastError = nil
        print("🍎 [Apple Sign-In] Starting authentication...")
        print("🍎 [Apple Sign-In] ID Token length: \(idToken.count)")
        if let rawNonce = rawNonce {
            print("🍎 [Apple Sign-In] Raw nonce provided: \(rawNonce.prefix(10))...")
        } else {
            print("🍎 [Apple Sign-In] No raw nonce provided")
        }

        do {
            let credentials = OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                accessToken: nil,
                nonce: rawNonce  // Pass the raw (unhashed) nonce
            )

            let session = try await client.auth.signInWithIdToken(credentials: credentials)

            print("✅ Apple sign-in successful: \(session.user.id)")
            print("✅ User email: \(session.user.email ?? "no email")")
            self.user = session.user
            self.isSignedIn = true

            // Start listening for webhook job completions
            await JobStatusManager.shared.startListening(userId: session.user.id.uuidString)
        } catch {
            print("❌ Apple sign-in error: \(error)")
            print("❌ Error type: \(type(of: error))")
            if let supabaseError = error as? AuthError {
                print("❌ Supabase Auth Error: \(supabaseError)")
            }

            let errorMessage = error.localizedDescription.lowercased()
            let fullErrorDescription = String(describing: error)

            // Check for nonce-related errors
            if errorMessage.contains("nonce") || errorMessage.contains("nonces mismatch") {
                lastError = "Authentication configuration error. Please try again."
                print("❌ Nonce error detected")
            }
            // Check for user-related errors
            else if errorMessage.contains("user not found") ||
                    errorMessage.contains("invalid_credentials") ||
                    errorMessage.contains("invalid login credentials") {
                lastError = "Unable to sign in. Please try again."
            } else {
                lastError = fullErrorDescription
                print("❌ Full error description: \(fullErrorDescription)")
            }
        }
    }

    // MARK: - Google Sign In

    /// Signs in with Google using the ID token and access token
    /// - Parameters:
    ///   - idToken: The ID token from Google Sign-In
    ///   - accessToken: The access token from Google Sign-In
    ///   - rawNonce: The raw (unhashed) nonce that was passed to Google Sign-In. 
    ///               Google hashes this and includes the hash in the ID token.
    ///               Supabase will hash this raw nonce and compare it to the hash in the token.
    func signInWithGoogle(idToken: String, accessToken: String, rawNonce: String? = nil) async {
        lastError = nil
        print("🔑 [Google Sign-In] Starting authentication...")
        print("🔑 [Google Sign-In] ID Token length: \(idToken.count)")
        print("🔑 [Google Sign-In] Access Token length: \(accessToken.count)")
        if let rawNonce = rawNonce {
            print("🔑 [Google Sign-In] Raw nonce provided: \(rawNonce.prefix(10))...")
        } else {
            print("🔑 [Google Sign-In] No raw nonce provided")
        }
        
        do {
            // Use the SDK's signInWithIdToken with the raw nonce
            // Supabase will hash the raw nonce and compare it to the hash in the ID token
            let credentials = OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken,
                nonce: rawNonce  // Pass the raw (unhashed) nonce
            )
            
            let session = try await client.auth.signInWithIdToken(credentials: credentials)
            
            print("✅ Google sign-in successful: \(session.user.id)")
            print("✅ User email: \(session.user.email ?? "no email")")
            self.user = session.user
            self.isSignedIn = true
            
            // Start listening for webhook job completions
            await JobStatusManager.shared.startListening(userId: session.user.id.uuidString)
            await setupPushNotificationsForUser(session.user.id.uuidString)
        } catch {
            // Log the full error details
            print("❌ Google sign-in error: \(error)")
            print("❌ Error type: \(type(of: error))")
            if let supabaseError = error as? AuthError {
                print("❌ Supabase Auth Error: \(supabaseError)")
            }
            if let urlError = error as? URLError {
                print("❌ URL Error: \(urlError.localizedDescription)")
            }
            
            let errorMessage = error.localizedDescription.lowercased()
            let fullErrorDescription = String(describing: error)
            
            // Check for nonce-related errors - these are configuration issues, not "user not found"
            if errorMessage.contains("nonce") || errorMessage.contains("nonces mismatch") {
                lastError = "NONCE_ERROR"
                print("❌ Nonce error detected - this is a configuration issue, not a user account issue")
            }
            // Check for actual "user not found" errors (but not nonce errors)
            else if errorMessage.contains("user not found") ||
               errorMessage.contains("invalid_credentials") ||
               errorMessage.contains("invalid login credentials") ||
               errorMessage.contains("email not confirmed") ||
               errorMessage.contains("no user found") ||
               errorMessage.contains("user does not exist") ||
               errorMessage.contains("signup_disabled") {
                // This error typically means the user needs to create an account first
                lastError = "USER_NOT_FOUND"
            } else {
                // Store the full error for debugging
                lastError = fullErrorDescription
                print("❌ Full error description: \(fullErrorDescription)")
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
            // Clear push notification user so token isn't associated with this account
            PushNotificationManager.shared.setCurrentUser(nil)

            try await client.auth.signOut()
            self.isSignedIn = false
            self.user = nil
        } catch {
            print("Sign-out error: \(error.localizedDescription)")
        }
    }

    // MARK: - Push Notifications

    /// Sets the current user on PushNotificationManager and requests permissions so we get a device token.
    /// Call this when the user has signed in (session established).
    private func setupPushNotificationsForUser(_ userId: String) async {
        PushNotificationManager.shared.setCurrentUser(userId)
        _ = await PushNotificationManager.shared.requestPermissions()
    }
}
