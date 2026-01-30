import AuthenticationServices
import CommonCrypto
import GoogleSignIn
import SwiftUI
import UIKit

// MARK: - SIGN IN OVERLAY

struct SignInOverlay: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEmailSignIn = false
    @State private var showSignUpOverlay = false
    @State private var isGoogleSigningIn = false
    @State private var googleSignInError: String?
    @State private var appleSignInError: String?
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow dismissing by tapping outside (optional)
                }
            
            // Sign-in card
            VStack(spacing: 24) {
                // Welcome section
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Log In")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Sign in to view and manage your creations")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Sign in buttons
                VStack(spacing: 14) {
                    // Apple Sign In
                    Button(action: {
                        handleAppleSignIn()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "applelogo")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Google Sign In
                    Button(action: {
                        Task {
                            await handleGoogleSignIn()
                        }
                    }) {
                        HStack {
                            Spacer()
                            GoogleLogoView(size: 18)
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Email Sign In
                    Button(action: {
                        showEmailSignIn = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Email")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 32)
                
                // Terms and Privacy
                VStack(spacing: 4) {
                    Text("By continuing you agree to our")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                            .font(.footnote)
                            .underline()
                            .foregroundColor(.white.opacity(0.9))
                        Text("and")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                        Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                            .font(.footnote)
                            .underline()
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.top, 8)
                
                // Sign Up link
                Button(action: {
                    showSignUpOverlay = true
                }) {
                    Text("Don't have an account? Sign Up")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .underline()
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmbeddedEmailSignInView(isSignUp: .constant(false), isPresented: $showEmailSignIn)
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSignUpOverlay) {
            SignUpOverlay()
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .alert("Sign In Error", isPresented: Binding(
            get: { googleSignInError != nil },
            set: { if !$0 { googleSignInError = nil } }
        )) {
            Button("OK", role: .cancel) {
                googleSignInError = nil
            }
            if googleSignInError == "USER_NOT_FOUND" {
                Button("Create Account") {
                    googleSignInError = nil
                    showSignUpOverlay = true
                }
            }
        } message: {
            if googleSignInError == "NONCE_ERROR" {
                Text("There was an authentication configuration error. Please try again or contact support if the issue persists.")
            } else if googleSignInError == "USER_NOT_FOUND" {
                Text("No account found with this Google email. Please create an account first.")
            } else if let error = googleSignInError {
                Text(error)
            }
        }
        .alert("Apple Sign In Error", isPresented: Binding(
            get: { appleSignInError != nil },
            set: { if !$0 { appleSignInError = nil } }
        )) {
            Button("OK", role: .cancel) {
                appleSignInError = nil
            }
        } message: {
            if let error = appleSignInError {
                Text(error)
            }
        }
    }
    
    // MARK: - Apple Sign In
    func handleAppleSignIn() {
        print("🍎 handleAppleSignIn called (SignInOverlay)")
        AppleSignInCoordinator.startSignIn(
            authViewModel: authViewModel,
            onError: { error in
                print("🍎 onError callback: \(error)")
                appleSignInError = error
            },
            onSuccess: {
                print("🍎 onSuccess callback - user signed in!")
            }
        )
    }
    
    // MARK: - Google Sign In
    func handleGoogleSignIn() async {
        isGoogleSigningIn = true
        googleSignInError = nil
        
        // Get the Google Client ID from Info.plist or environment
        guard let clientID = getGoogleClientID() else {
            await MainActor.run {
                googleSignInError = "Google Client ID not configured. Please add GOOGLE_CLIENT_ID to your Info.plist."
                isGoogleSigningIn = false
            }
            print("❌ Google Client ID not found")
            return
        }
        
        // Generate a random nonce for security
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        
        print("🔑 [SignInOverlay] Generated nonce - raw: \(rawNonce.prefix(10))..., hashed: \(hashedNonce.prefix(10))...")
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the presenting view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            await MainActor.run {
                googleSignInError = "Unable to find root view controller"
                isGoogleSigningIn = false
            }
            print("❌ Unable to find root view controller")
            return
        }
        
        do {
            // Perform the sign-in with the hashed nonce
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce
            )
            
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                await MainActor.run {
                    googleSignInError = "Failed to get Google ID token"
                    isGoogleSigningIn = false
                }
                print("❌ Failed to get Google ID token")
                return
            }
            
            // Get access token
            let accessToken = user.accessToken.tokenString
            
            // Sign in with Supabase - pass the RAW nonce
            await authViewModel.signInWithGoogle(idToken: idToken, accessToken: accessToken, rawNonce: rawNonce)
            
            await MainActor.run {
                isGoogleSigningIn = false
                // Check if sign-in failed and show appropriate message
                if !authViewModel.isSignedIn {
                    if let error = authViewModel.lastError {
                        if error == "USER_NOT_FOUND" {
                            googleSignInError = "USER_NOT_FOUND"
                        } else {
                            googleSignInError = error
                        }
                    } else {
                        googleSignInError = "Failed to sign in with Google. Please try again."
                    }
                }
            }
        } catch {
            await MainActor.run {
                googleSignInError = error.localizedDescription
                isGoogleSigningIn = false
            }
            print("❌ Google sign-in error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Nonce Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        inputData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(inputData.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func getGoogleClientID() -> String? {
        // Try to get from Info.plist first
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String {
            return clientID
        }
        
        // Try to get from environment variable (for development)
        if let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] {
            return clientID
        }
        
        return nil
    }
}
