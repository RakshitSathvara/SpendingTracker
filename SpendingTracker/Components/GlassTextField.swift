//
//  GlassTextField.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Glass Text Field (iOS 26 Stable)

/// A text field with iOS 26 Liquid Glass effect
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let autocapitalization: TextInputAutocapitalization
    let isError: Bool
    let errorMessage: String?

    @FocusState private var isFocused: Bool

    init(
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        isError: Bool = false,
        errorMessage: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.isError = isError
        self.errorMessage = errorMessage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .frame(width: 24)
                }

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .focused($isFocused)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: isFocused ? 2 : 0.5)
                    }
            }

            if let errorMessage, isError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: isError)
    }

    private var iconColor: Color {
        if isError { return .red }
        if isFocused { return .accentColor }
        return .secondary
    }

    private var borderColor: Color {
        if isError { return .red }
        if isFocused { return .accentColor }
        return .white.opacity(0.2)
    }
}

// MARK: - Glass Secure Field (iOS 26 Stable)

/// A secure text field with password visibility toggle and glass effect
struct GlassSecureField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    let isError: Bool
    let errorMessage: String?

    @FocusState private var isFocused: Bool

    init(
        placeholder: String,
        text: Binding<String>,
        showPassword: Binding<Bool> = .constant(false),
        isError: Bool = false,
        errorMessage: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self._showPassword = showPassword
        self.isError = isError
        self.errorMessage = errorMessage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .textContentType(showPassword ? .password : .newPassword)
                .focused($isFocused)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: showPassword)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: isFocused ? 2 : 0.5)
                    }
            }

            if let errorMessage, isError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: isError)
    }

    private var iconColor: Color {
        if isError { return .red }
        if isFocused { return .accentColor }
        return .secondary
    }

    private var borderColor: Color {
        if isError { return .red }
        if isFocused { return .accentColor }
        return .white.opacity(0.2)
    }
}

// MARK: - Password Strength Indicator (iOS 26 Stable)

/// Visual indicator for password strength
struct PasswordStrengthIndicator: View {
    let password: String

    private var strength: PasswordStrength {
        AuthValidator.evaluatePasswordStrength(password)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < strength.rawValue ? strength.color : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }

            if !password.isEmpty {
                Text(strength.displayName)
                    .font(.caption)
                    .foregroundStyle(strength.color)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: strength)
    }
}

// MARK: - Glass Text Area

/// A multiline text input with glass effect
struct GlassTextArea: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat

    @FocusState private var isFocused: Bool

    init(
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 100
    ) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(minHeight: minHeight)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.accentColor : Color.white.opacity(0.2),
                            lineWidth: isFocused ? 2 : 0.5
                        )
                }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Preview

#Preview("Glass Text Fields") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 20) {
                GlassTextField(
                    placeholder: "Email",
                    text: .constant(""),
                    icon: "envelope",
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    autocapitalization: .never
                )

                GlassTextField(
                    placeholder: "Name",
                    text: .constant("John Doe"),
                    icon: "person",
                    textContentType: .name
                )

                GlassTextField(
                    placeholder: "Invalid Email",
                    text: .constant("invalid"),
                    icon: "envelope",
                    isError: true,
                    errorMessage: "Please enter a valid email"
                )

                GlassSecureField(
                    placeholder: "Password",
                    text: .constant(""),
                    showPassword: .constant(false)
                )

                VStack(alignment: .leading, spacing: 8) {
                    GlassSecureField(
                        placeholder: "Password",
                        text: .constant("password123"),
                        showPassword: .constant(false)
                    )
                    PasswordStrengthIndicator(password: "password123")
                }

                GlassTextArea(
                    placeholder: "Enter notes...",
                    text: .constant("")
                )
            }
            .padding()
        }
    }
}
