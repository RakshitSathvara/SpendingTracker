//
//  SignUpView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Sign Up View (iOS 26 Stable)

/// Beautiful sign up screen with Liquid Glass design system and persona selection
struct SignUpView: View {

    // MARK: - Environment

    @Environment(AuthenticationService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var selectedPersona: UserPersona = .professional
    @State private var acceptedTerms = false
    @State private var hasAttemptedSubmit = false

    // Validation States
    @State private var nameValidation: ValidationResult = .init(isValid: true, message: nil)
    @State private var emailValidation: ValidationResult = .init(isValid: true, message: nil)
    @State private var passwordValidation: ValidationResult = .init(isValid: true, message: nil)
    @State private var confirmPasswordValidation: ValidationResult = .init(isValid: true, message: nil)

    // MARK: - Bindings

    @Binding var showingSignUp: Bool

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        let results = AuthValidator.validateSignUpForm(
            email: email,
            password: password,
            confirmPassword: confirmPassword,
            displayName: displayName
        )
        return AuthValidator.isFormValid(results) && acceptedTerms
    }

    private var passwordStrength: PasswordStrength {
        AuthValidator.evaluatePasswordStrength(password)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated Background
                AuthBackground(colorTheme: .blue)

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: geometry.size.height * 0.04)

                        // Header Section
                        headerSection

                        // Sign Up Form Card
                        formCard

                        // Sign In Link
                        signInLink

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            // App Icon
            Image(systemName: "indianrupeesign.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 15, y: 8)

            // Title
            Text("Create Account")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            // Subtitle
            Text("Start tracking your spending today")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 20) {
            // Name Field
            GlassTextField(
                placeholder: "Full Name",
                text: $displayName,
                icon: "person",
                textContentType: .name,
                autocapitalization: .words,
                isError: hasAttemptedSubmit && !nameValidation.isValid,
                errorMessage: hasAttemptedSubmit ? nameValidation.message : nil
            )
            .onChange(of: displayName) { _, newValue in
                if hasAttemptedSubmit {
                    nameValidation = AuthValidator.validateDisplayName(newValue)
                }
            }

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

            // Password Field with Strength Indicator
            VStack(spacing: 8) {
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

                // Password Strength Indicator
                if !password.isEmpty {
                    PasswordStrengthIndicator(password: password)
                        .transition(.asymmetric(
                            insertion: .push(from: .top).combined(with: .opacity),
                            removal: .push(from: .bottom).combined(with: .opacity)
                        ))
                }
            }

            // Confirm Password Field
            GlassSecureField(
                placeholder: "Confirm Password",
                text: $confirmPassword,
                showPassword: $showConfirmPassword,
                isError: hasAttemptedSubmit && !confirmPasswordValidation.isValid,
                errorMessage: hasAttemptedSubmit ? confirmPasswordValidation.message : nil
            )
            .onChange(of: confirmPassword) { _, newValue in
                if hasAttemptedSubmit {
                    confirmPasswordValidation = AuthValidator.validatePasswordMatch(password, confirmPassword: newValue)
                }
            }

            // Persona Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("I am a...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                CompactPersonaSelector(selectedPersona: $selectedPersona)
            }

            // Terms and Conditions
            termsCheckbox

            // Error Message
            if let error = authService.error {
                errorMessageView(error)
            }

            // Create Account Button
            GlassButton(
                title: "Create Account",
                icon: "person.badge.plus",
                tint: .blue,
                isLoading: authService.isLoading
            ) {
                signUp()
            }
            .disabled(authService.isLoading)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }

    // MARK: - Terms Checkbox

    private var termsCheckbox: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                acceptedTerms.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(acceptedTerms ? .blue : .secondary)

                Text("I agree to the [Terms of Service](terms) and [Privacy Policy](privacy)")
                    .font(.caption)
                    .tint(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: acceptedTerms)
        .accessibilityLabel("Accept terms and conditions")
        .accessibilityHint(acceptedTerms ? "Terms accepted" : "Double tap to accept terms")
        .accessibilityAddTraits(acceptedTerms ? .isSelected : [])
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
    }

    // MARK: - Sign In Link

    private var signInLink: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .foregroundStyle(.white.opacity(0.8))

            Button("Sign In") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSignUp = false
                }
            }
            .fontWeight(.semibold)
            .foregroundStyle(.white)
        }
        .font(.subheadline)
    }

    // MARK: - Actions

    private func signUp() {
        // Validate form
        hasAttemptedSubmit = true
        nameValidation = AuthValidator.validateDisplayName(displayName)
        emailValidation = AuthValidator.validateEmail(email)
        passwordValidation = AuthValidator.validatePassword(password)
        confirmPasswordValidation = AuthValidator.validatePasswordMatch(password, confirmPassword: confirmPassword)

        guard isFormValid else { return }

        // Clear any previous errors
        authService.clearError()

        // Perform sign up
        Task {
            do {
                try await authService.signUp(
                    email: email,
                    password: password,
                    displayName: displayName,
                    persona: selectedPersona
                )
            } catch {
                // Error is handled by authService
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SignUpView(showingSignUp: .constant(true))
        .environment(AuthenticationService())
}
