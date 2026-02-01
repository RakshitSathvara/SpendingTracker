//
//  LoginView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Login View (iOS 26 Stable)

/// Beautiful login screen with Liquid Glass design system
struct LoginView: View {

    // MARK: - Environment

    @Environment(AuthenticationService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var emailValidation: ValidationResult = .init(isValid: true, message: nil)
    @State private var passwordValidation: ValidationResult = .init(isValid: true, message: nil)
    @State private var showingForgotPassword = false
    @State private var hasAttemptedSubmit = false

    // MARK: - Bindings

    @Binding var showingSignUp: Bool

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        let emailResult = AuthValidator.validateEmail(email)
        let passwordResult = AuthValidator.validatePassword(password)
        return emailResult.isValid && passwordResult.isValid
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated Background
                AuthBackground(colorTheme: .purple)

                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: geometry.size.height * 0.08)

                        // Logo Section
                        logoSection

                        // Login Form Card
                        formCard

                        // Sign Up Link
                        signUpLink

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 12) {
            // App Icon with Glass Effect
            Image(systemName: "indianrupeesign.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(colorScheme == .dark ? .white : .purple)
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)

            // App Name
            Text("Spending Tracker")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(colorScheme == .dark ? .white : .primary)

            // Tagline
            Text("Track your expenses with ease")
                .font(.subheadline)
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spending Tracker - Track your expenses with ease")
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 20) {
            // Welcome Text
            VStack(spacing: 4) {
                Text("Welcome Back")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Email Field
            GlassTextField(
                placeholder: "Email",
                text: $email,
                icon: "envelope",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never,
                isError: hasAttemptedSubmit && !emailValidation.isValid,
                errorMessage: hasAttemptedSubmit ? emailValidation.message : nil
            )
            .onChange(of: email) { _, newValue in
                if hasAttemptedSubmit {
                    emailValidation = AuthValidator.validateEmail(newValue)
                }
            }

            // Password Field
            GlassSecureField(
                placeholder: "Password",
                text: $password,
                showPassword: $showPassword,
                isError: hasAttemptedSubmit && !passwordValidation.isValid,
                errorMessage: hasAttemptedSubmit ? passwordValidation.message : nil
            )
            .onChange(of: password) { _, newValue in
                if hasAttemptedSubmit {
                    passwordValidation = AuthValidator.validatePassword(newValue)
                }
            }

            // Forgot Password Button
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    showingForgotPassword = true
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            // Error Message
            if let error = authService.error {
                errorMessageView(error)
            }

            // Sign In Button
            GlassButton(
                title: "Sign In",
                icon: "arrow.right",
                tint: .blue,
                isLoading: authService.isLoading
            ) {
                signIn()
            }
            .disabled(authService.isLoading)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }

    // MARK: - Error Message View

    private func errorMessageView(_ error: AuthError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(error.errorDescription ?? "An error occurred")
                .font(.subheadline)
                .foregroundStyle(.red)

            Spacer()
        }
        .padding(12)
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.asymmetric(
            insertion: .push(from: .top).combined(with: .opacity),
            removal: .push(from: .bottom).combined(with: .opacity)
        ))
        .accessibilityLabel("Error: \(error.errorDescription ?? "An error occurred")")
    }

    // MARK: - Sign Up Link

    private var signUpLink: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .secondary)

            Button("Sign Up") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSignUp = true
                }
            }
            .fontWeight(.semibold)
            .foregroundStyle(colorScheme == .dark ? .white : .blue)
        }
        .font(.subheadline)
    }

    // MARK: - Actions

    private func signIn() {
        // Validate form
        hasAttemptedSubmit = true
        emailValidation = AuthValidator.validateEmail(email)
        passwordValidation = AuthValidator.validatePassword(password)

        guard isFormValid else { return }

        // Clear any previous errors
        authService.clearError()

        // Perform sign in
        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                // Error is handled by authService
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView(showingSignUp: .constant(false))
        .environment(AuthenticationService())
}
