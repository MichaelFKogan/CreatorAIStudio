import SwiftUI

// MARK: - EMBEDDED EMAIL SIGN IN VIEW

struct EmbeddedEmailSignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isSignUp: Bool
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var message: String? = nil
    @State private var messageColor: Color = .red
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.primary)
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Message Area
                    if let message = message {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(messageColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Sign In / Sign Up button
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
                                // Close sheet after successful sign in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isPresented = false
                                }
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
                    .padding(.top, 8)
                    
                    // Forgot password (only for sign in)
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
                    
                    // Terms & Privacy (only for sign up)
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
                    }
                }
                .padding()
                .padding(.top, 20)
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(isPresented: $showForgotPassword)
                    .environmentObject(authViewModel)
                    .presentationDragIndicator(.visible)
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

