import AuthenticationServices
import CommonCrypto
import GoogleSignIn
import SwiftUI
import UIKit

// MARK: - SIGN UP OVERLAY

struct SignUpOverlay: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEmailSignIn = false
    @State private var isGoogleSigningIn = false
    @State private var googleSignInError: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Sign-up card
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
                    
                    Text("Create Your Account")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Sign up to start creating amazing images")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Sign up buttons
                VStack(spacing: 14) {
                    // Apple Sign Up
                    Button(action: {
                        handleAppleSignUp()
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
                    
                    // Google Sign Up
                    Button(action: {
                        Task {
                            await handleGoogleSignIn()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            if isGoogleSigningIn {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.leading, 8)
                            }
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
                    .disabled(isGoogleSigningIn)
                    
                    // Email Sign Up
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
                    Text("By signing up you agree to our")
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
                
                // Sign In link
                Button(action: {
                    dismiss()
                }) {
                    Text("Already have an account? Sign In")
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
            EmbeddedEmailSignInView(isSignUp: .constant(true), isPresented: $showEmailSignIn)
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .alert("Sign Up Error", isPresented: Binding(
            get: { googleSignInError != nil },
            set: { if !$0 { googleSignInError = nil } }
        )) {
            Button("OK", role: .cancel) {
                googleSignInError = nil
            }
        } message: {
            if googleSignInError == "NONCE_ERROR" {
                Text("There was an authentication configuration error. Please try again or contact support if the issue persists.")
            } else if googleSignInError == "USER_NOT_FOUND" {
                // This shouldn't happen on sign-up page, but handle it just in case
                Text("Unable to create account. Please try again or contact support.")
            } else if let error = googleSignInError {
                Text(error)
            }
        }
    }
    
    // MARK: - Apple Sign Up
    func handleAppleSignUp() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator(authViewModel: authViewModel)
        controller.performRequests()
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
        // This raw nonce will be passed to Supabase
        // The SHA256 hash will be passed to Google
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        
        print("🔑 [SignUpOverlay] Generated nonce - raw: \(rawNonce.prefix(10))..., hashed: \(hashedNonce.prefix(10))...")
        
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
            // Google will include this hash in the ID token
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
            
            print("🔑 [SignUpOverlay] Calling signInWithGoogle with raw nonce...")
            // Sign in with Supabase - pass the RAW nonce (not hashed)
            // Supabase will hash it and compare to the hash in the ID token
            await authViewModel.signInWithGoogle(idToken: idToken, accessToken: accessToken, rawNonce: rawNonce)
            
            await MainActor.run {
                isGoogleSigningIn = false
                if authViewModel.isSignedIn {
                    print("✅ [SignUpOverlay] Sign-in successful, dismissing...")
                    dismiss()
                } else {
                    // Show the actual error message
                    if let error = authViewModel.lastError {
                        print("❌ [SignUpOverlay] Error from AuthViewModel: \(error)")
                        googleSignInError = error
                    } else {
                        print("❌ [SignUpOverlay] Unknown error - isSignedIn is false but no error set")
                        googleSignInError = "Failed to create account. Please check your Supabase configuration."
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
    
    /// Generates a random string for use as a nonce
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
    
    /// Creates a SHA256 hash of the input string
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

