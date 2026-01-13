import AuthenticationServices
import CommonCrypto
import GoogleSignIn
import SwiftUI
import UIKit

// MARK: - EMBEDDED SIGN IN VIEW

struct EmbeddedSignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEmailSignIn = false
    @State private var isSignUp = false
    @State private var isGoogleSigningIn = false
    @State private var googleSignInError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)
                
                // Welcome section
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Log In")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Sign in to view and manage your creations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)
                
                // Sign in buttons
                VStack(spacing: 16) {
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
                .padding(.horizontal, 24)
                
                // Terms and Privacy
                VStack(spacing: 4) {
                    Text("By continuing you agree to our")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                            .font(.footnote)
                            .underline()
                        Text("and")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                            .font(.footnote)
                            .underline()
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmbeddedEmailSignInView(isSignUp: $isSignUp, isPresented: $showEmailSignIn)
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
        .alert("Google Sign-In", isPresented: Binding(
            get: { googleSignInError != nil },
            set: { if !$0 { googleSignInError = nil } }
        )) {
            Button("OK", role: .cancel) {
                googleSignInError = nil
            }
            if googleSignInError == "No account found with this Google email. Please create an account first using the 'Create Your Account' page." {
                Button("Create Account") {
                    googleSignInError = nil
                    isSignUp = true
                }
            }
        } message: {
            if let error = googleSignInError {
                Text(error)
            }
        }
    }
    
    // MARK: - Apple Sign In
    func handleAppleSignIn() {
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
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        
        print("🔑 [EmbeddedSignInView] Generated nonce - raw: \(rawNonce.prefix(10))..., hashed: \(hashedNonce.prefix(10))...")
        
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

