//
//  SignInView.swift
//  AI Photo Generation
//
//  Created by Mike K on 10/18/25.
//

import AuthenticationServices // For Apple Sign-In
import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var navigateToSignUp = false
    @State private var navigateToEmail = false

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
                                
                                Text("Welcome to Runspeed AI")
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
                                    authViewModel.isSignedIn = true
                                }) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "globe")
                                            .font(.system(size: 18, weight: .semibold))
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
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator(authViewModel: authViewModel)
        controller.performRequests()
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
                                showMessage("Incorrect email or password.", color: .red)
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top)

                    // 🔹 Toggle Sign Up / Sign In
                    Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                        withAnimation {
                            isSignUp.toggle()
                            message = nil
                        }
                    }
                    .font(.footnote)
                    .padding(.top, 4)
                    .foregroundColor(.blue)

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
//        .navigationBarBackButtonHidden(true)
        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button {
//                    navigateBack = false
//                } label: {
//                    Image(systemName: "chevron.left")
//                        .foregroundColor(.blue)
//                        .fontWeight(.bold)
//                }
//            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSignUp ? "Sign In" : "Sign Up") {
                    withAnimation {
                        isSignUp.toggle()
                        message = nil
                    }
                }
                .fontWeight(.bold)
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
                                    authViewModel.isSignedIn = true
                                }) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "globe")
                                            .font(.system(size: 18, weight: .semibold))
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
                            NavigationLink(
                                destination: SignInView()
                                    .environmentObject(authViewModel)
                            ) {
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
    }
    
    // MARK: - Apple Sign Up
    func handleAppleSignUp() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator(authViewModel: authViewModel)
        controller.performRequests()
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
