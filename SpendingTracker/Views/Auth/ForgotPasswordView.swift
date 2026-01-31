//
//  ForgotPasswordView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Forgot Password View (iOS 26 Stable)

/// Password reset screen with Liquid Glass design system
struct ForgotPasswordView: View {

    // MARK: - Environment

    @Environment(AuthenticationService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var email = ""
    @State private var emailValidation: ValidationResult = .init(isValid: true, message: nil)
    @State private var hasAttemptedSubmit = false
    @State private var isSuccess = false
    @State private var showSuccessFeedback = false

    // MARK: - Computed Properties

    private var isEmailValid: Bool {
        AuthValidator.validateEmail(email).isValid
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle Background
                SubtleAuthBackground()

                // Content
                VStack(spacing: 32) {
                    Spacer()

                    if isSuccess {
                        successView
                    } else {
                        formView
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: showSuccessFeedback)
    }

    // MARK: - Form View

    private var formView: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "key.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(Circle())

            // Instructions
            VStack(spacing: 8) {
                Text("Forgot your password?")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Form Card
            VStack(spacing: 20) {
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

                // Error Message
                if let error = authService.error {
                    errorMessageView(error)
                }

                // Send Reset Link Button
                GlassButton(
                    title: "Send Reset Link",
                    icon: "paperplane.fill",
                    tint: .blue,
                    isLoading: authService.isLoading
                ) {
                    sendResetLink()
                }
                .disabled(authService.isLoading)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: isSuccess)

            // Success Message
            VStack(spacing: 8) {
                Text("Email Sent!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("We've sent a password reset link to:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(email)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }

            // Instructions Card
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Check your email inbox")
                    Spacer()
                }

                HStack(spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Click the reset link")
                    Spacer()
                }

                HStack(spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Create a new password")
                    Spacer()
                }
            }
            .font(.subheadline)
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Didn't receive email
            VStack(spacing: 8) {
                Text("Didn't receive the email?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Resend") {
                    isSuccess = false
                    sendResetLink()
                }
                .font(.caption)
                .fontWeight(.semibold)
                .disabled(authService.isLoading)
            }

            // Done Button
            GlassButton(
                title: "Done",
                icon: "checkmark",
                tint: .green
            ) {
                dismiss()
            }
        }
        .transition(.asymmetric(
            insertion: .push(from: .trailing).combined(with: .opacity),
            removal: .push(from: .leading).combined(with: .opacity)
        ))
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

    // MARK: - Actions

    private func sendResetLink() {
        // Validate email
        hasAttemptedSubmit = true
        emailValidation = AuthValidator.validateEmail(email)

        guard isEmailValid else { return }

        // Clear any previous errors
        authService.clearError()

        // Send reset link
        Task {
            do {
                try await authService.resetPassword(email: email)
                withAnimation(.easeInOut(duration: 0.4)) {
                    isSuccess = true
                    showSuccessFeedback = true
                }
            } catch {
                // Error is handled by authService
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ForgotPasswordView()
        .environment(AuthenticationService())
}

#Preview("Success State") {
    ForgotPasswordView()
        .environment(AuthenticationService())
}
