//
//  AuthValidator.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftUI

// MARK: - Password Strength

enum PasswordStrength: Int, CaseIterable {
    case weak = 1
    case medium = 2
    case strong = 3

    var displayName: String {
        switch self {
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }

    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }

    var progress: Double {
        Double(rawValue) / 3.0
    }
}

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let message: String?

    static let valid = ValidationResult(isValid: true, message: nil)

    static func invalid(_ message: String) -> ValidationResult {
        ValidationResult(isValid: false, message: message)
    }
}

// MARK: - Auth Validator

struct AuthValidator {

    // MARK: - Email Validation

    /// Validates email format
    static func validateEmail(_ email: String) -> ValidationResult {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            return .invalid("Email is required.")
        }

        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let isValidFormat = trimmedEmail.range(of: emailRegex, options: .regularExpression) != nil

        guard isValidFormat else {
            return .invalid("Please enter a valid email address.")
        }

        return .valid
    }

    /// Simple email format check (returns Bool)
    static func isValidEmail(_ email: String) -> Bool {
        validateEmail(email).isValid
    }

    // MARK: - Password Validation

    /// Validates password meets minimum requirements
    static func validatePassword(_ password: String) -> ValidationResult {
        guard !password.isEmpty else {
            return .invalid("Password is required.")
        }

        guard password.count >= 6 else {
            return .invalid("Password must be at least 6 characters.")
        }

        return .valid
    }

    /// Evaluates password strength
    static func evaluatePasswordStrength(_ password: String) -> PasswordStrength {
        guard password.count >= 6 else {
            return .weak
        }

        var score = 0

        // Length scoring
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }

        // Character type scoring
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSpecialChar = password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) })

        if hasUppercase { score += 1 }
        if hasLowercase { score += 1 }
        if hasNumber { score += 1 }
        if hasSpecialChar { score += 1 }

        // Convert score to strength
        switch score {
        case 0...2:
            return .weak
        case 3...4:
            return .medium
        default:
            return .strong
        }
    }

    /// Validates password confirmation matches
    static func validatePasswordMatch(_ password: String, confirmPassword: String) -> ValidationResult {
        guard !confirmPassword.isEmpty else {
            return .invalid("Please confirm your password.")
        }

        guard password == confirmPassword else {
            return .invalid("Passwords do not match.")
        }

        return .valid
    }

    // MARK: - Display Name Validation

    /// Validates display name
    static func validateDisplayName(_ name: String) -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return .invalid("Name is required.")
        }

        guard trimmedName.count >= 2 else {
            return .invalid("Name must be at least 2 characters.")
        }

        guard trimmedName.count <= 50 else {
            return .invalid("Name must be less than 50 characters.")
        }

        // Check for valid characters (letters, spaces, hyphens, apostrophes)
        let allowedCharacters = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'"))

        guard trimmedName.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return .invalid("Name contains invalid characters.")
        }

        return .valid
    }

    // MARK: - Form Validation

    /// Validates complete sign up form
    static func validateSignUpForm(
        email: String,
        password: String,
        confirmPassword: String,
        displayName: String
    ) -> [String: ValidationResult] {
        [
            "email": validateEmail(email),
            "password": validatePassword(password),
            "confirmPassword": validatePasswordMatch(password, confirmPassword: confirmPassword),
            "displayName": validateDisplayName(displayName)
        ]
    }

    /// Validates complete sign in form
    static func validateSignInForm(
        email: String,
        password: String
    ) -> [String: ValidationResult] {
        var results: [String: ValidationResult] = [:]

        results["email"] = validateEmail(email)

        // For sign in, we just check password isn't empty
        if password.isEmpty {
            results["password"] = .invalid("Password is required.")
        } else {
            results["password"] = .valid
        }

        return results
    }

    /// Checks if all validation results are valid
    static func isFormValid(_ results: [String: ValidationResult]) -> Bool {
        results.values.allSatisfy { $0.isValid }
    }
}
