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
    @State private var isSignUp = false
    @State private var navigateToEmail = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 🔹 Black background
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Text("Welcome")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.primary)
                            .padding(.top, 40)
                            .padding(.bottom, 8)

                        Spacer(minLength: 40)

                        VStack(spacing: 16) {
                            SignInButton(
                                title: "Continue with Apple",
                                icon: "applelogo",
                                background: Color.white
                            ) {
                                handleAppleSignIn()
                            }

                            SignInButton(
                                title: "Continue with Google",
                                icon: "globe",
                                background: Color.white
                            ) {
                                authViewModel.isSignedIn = true
                            }

                            NavigationLink(
                                destination: EmailSignInView(
                                    isSignUp: $isSignUp,
                                    navigateBack: $navigateToEmail
                                )
                                .environmentObject(authViewModel),
                                isActive: $navigateToEmail
                            ) {
                                SignInButton(
                                    title: "Continue with Email",
                                    icon: "envelope.fill",
                                    background: Color.white
                                ) {
                                    navigateToEmail = true
                                }
                            }
                        }
                        .padding(.horizontal)

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
                        .padding(.bottom, 100) // Extra padding for tab bar
                    }
                    .padding()
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
