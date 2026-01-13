//
//  SignInView.swift
//  AI Photo Generation
//
//  Created by Mike K on 10/18/25.
//

import AuthenticationServices // For Apple Sign-In
import CommonCrypto // For SHA256 hashing
import SwiftUI
import GoogleSignIn

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var navigateToSignUp = false
    @State private var navigateToEmail = false
    @State private var isGoogleSigningIn = false
    @State private var googleSignInError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // 🔹 Black background
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)
                        
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
                                NavigationLink(
                                    destination: EmailSignInView(
                                        isSignUp: .constant(false),
                                        navigateBack: $navigateToEmail
                                    )
                                    .environmentObject(authViewModel),
                                    isActive: $navigateToEmail
                                ) {
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
                            NavigationLink(
                                destination: SignUpView()
                                    .environmentObject(authViewModel),
                                isActive: $navigateToSignUp
                            ) {
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
                        
                        Spacer(minLength: 100)
                    }
                }
            }
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
                    navigateToSignUp = true
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
        
        print("🔑 [SignInView] Generated nonce - raw: \(rawNonce.prefix(10))..., hashed: \(hashedNonce.prefix(10))...")
        
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

// MARK: - Email Sign In Page

struct EmailSignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isSignUp: Bool
    @Binding var navigateBack: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var message: String? = nil
    @State private var messageColor: Color = .red
    @State private var showForgotPassword = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 🔹 Email Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color(.darkGray).opacity(0.4))
                            .cornerRadius(8)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .foregroundColor(.white)
                    }

                    // 🔹 Password Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(.darkGray).opacity(0.4))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }

                    // ✅ Message Area
                    if let message = message {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(messageColor)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .scale))
                            .animation(.easeInOut, value: message)
                            .padding(.horizontal)
                    }

                    // 🔹 Sign In / Sign Up button
                    Button(isSignUp ? "Sign Up" : "Sign In") {
                        Task {
                            guard !email.isEmpty, !password.isEmpty else {
                                showMessage("Please enter both email and password.", color: .red)
                                return
                            }

                            if isSignUp {
                                await authViewModel.signUpWithEmail(email: email, password: password)
                            } else {
                                await authViewModel.signInWithEmail(email: email, password: password)
                            }

                            if authViewModel.isSignedIn {
                                showMessage("Signed in successfully ✅", color: .green)
                            } else {
                                // Check for specific error messages
                                if let error = authViewModel.lastError {
                                    if error == "USER_EXISTS" {
                                        showMessage("This email is already registered. Please sign in instead.", color: .orange)
                                    } else {
                                        showMessage(error, color: .red)
                                    }
                                } else {
                                    showMessage("Incorrect email or password.", color: .red)
                                }
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top)

                    // 🔹 Forgot password (only for sign in)
                    if !isSignUp {
                        Button(action: {
                            showForgotPassword = true
                        }) {
                            Text("Forgot password?")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 8)
                    }

                    // 🔹 Terms & Privacy
                    if isSignUp {
                        VStack(spacing: 4) {
                            Text("By signing up you agree to our")
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
                        .padding(.bottom, 100) // Extra padding for tab bar
                    } else {
                        // Add bottom padding even when not showing terms
                        Spacer(minLength: 100)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
        .navigationTitle(isSignUp ? "Create Account" : "Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(isPresented: $showForgotPassword)
                .environmentObject(authViewModel)
                .presentationDragIndicator(.visible)
        }
    }

    private func showMessage(_ text: String, color: Color) {
        withAnimation {
            message = text
            messageColor = color
        }
    }
}

// MARK: - Sign In Button

struct SignInButton: View {
    let title: String
    let icon: String
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.trailing, 4)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.vertical, 12)
            .foregroundColor(.black)
            .background(background)
            .cornerRadius(12)
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var navigateToEmail = false
    @State private var isGoogleSigningIn = false
    @State private var googleSignInError: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 🔹 Black background
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)
                        
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
                                
                                // Email Sign Up
                                NavigationLink(
                                    destination: EmailSignInView(
                                        isSignUp: .constant(true),
                                        navigateBack: $navigateToEmail
                                    )
                                    .environmentObject(authViewModel),
                                    isActive: $navigateToEmail
                                ) {
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
                        
                        Spacer(minLength: 100)
                    }
                }
            }
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
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        
        print("🔑 [SignUpView] Generated nonce - raw: \(rawNonce.prefix(10))..., hashed: \(hashedNonce.prefix(10))...")
        
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

// MARK: - Apple Sign In Coordinator

class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    let authViewModel: AuthViewModel

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
           let identityToken = appleIDCredential.identityToken,
           let idTokenString = String(data: identityToken, encoding: .utf8)
        {
            Task {
                await authViewModel.signInWithApple(idToken: idTokenString)
            }
        }
    }

    func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple sign in failed: \(error)")
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var message: String? = nil
    @State private var messageColor: Color = .red
    @State private var isResetting = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Reset Password")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Enter your email address and we'll send you a link to reset your password")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 40)
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disabled(isResetting)
                    }
                    
                    // Message Area
                    if let message = message {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(messageColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Reset Password Button
                    Button(action: {
                        Task {
                            await handleResetPassword()
                        }
                    }) {
                        HStack {
                            if isResetting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Send Reset Link")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(email.isEmpty || isResetting)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func handleResetPassword() async {
        guard !email.isEmpty else {
            showMessage("Please enter your email address.", color: .red)
            return
        }
        
        // Basic email validation
        guard email.contains("@") && email.contains(".") else {
            showMessage("Please enter a valid email address.", color: .red)
            return
        }
        
        await MainActor.run {
            isResetting = true
            message = nil
        }
        
        await authViewModel.resetPassword(email: email)
        
        await MainActor.run {
            isResetting = false
            
            if authViewModel.lastError == nil {
                showMessage("Password reset email sent! Please check your inbox.", color: .green)
                // Optionally auto-dismiss after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isPresented = false
                }
            } else {
                // Handle specific errors
                if let error = authViewModel.lastError {
                    if error.lowercased().contains("user not found") {
                        showMessage("No account found with this email address.", color: .orange)
                    } else {
                        showMessage(error, color: .red)
                    }
                }
            }
        }
    }
    
    private func showMessage(_ text: String, color: Color) {
        withAnimation {
            message = text
            messageColor = color
        }
    }
}
