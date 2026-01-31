//
//  AuthenticationTests.swift
//  SpendingTrackerTests
//
//  Created by Rakshit on 31/01/26.
//

import XCTest
@testable import SpendingTracker

final class AuthenticationTests: XCTestCase {

    // MARK: - AuthError Tests

    func testAuthErrorDescriptions() {
        // Test all error descriptions are not empty
        let errors: [AuthError] = [
            .invalidEmail,
            .weakPassword,
            .emailAlreadyInUse,
            .userNotFound,
            .wrongPassword,
            .networkError,
            .requiresRecentLogin,
            .userDisabled,
            .operationNotAllowed,
            .tooManyRequests,
            .invalidCredential,
            .unknown("Test error")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testAuthErrorEquality() {
        XCTAssertEqual(AuthError.invalidEmail, AuthError.invalidEmail)
        XCTAssertEqual(AuthError.weakPassword, AuthError.weakPassword)
        XCTAssertNotEqual(AuthError.invalidEmail, AuthError.weakPassword)
        XCTAssertEqual(AuthError.unknown("test"), AuthError.unknown("test"))
        XCTAssertNotEqual(AuthError.unknown("test1"), AuthError.unknown("test2"))
    }

    func testAuthErrorRecoverySuggestions() {
        // Test errors with recovery suggestions
        XCTAssertNotNil(AuthError.invalidEmail.recoverySuggestion)
        XCTAssertNotNil(AuthError.weakPassword.recoverySuggestion)
        XCTAssertNotNil(AuthError.emailAlreadyInUse.recoverySuggestion)
        XCTAssertNotNil(AuthError.userNotFound.recoverySuggestion)
        XCTAssertNotNil(AuthError.wrongPassword.recoverySuggestion)
        XCTAssertNotNil(AuthError.networkError.recoverySuggestion)
        XCTAssertNotNil(AuthError.tooManyRequests.recoverySuggestion)
    }

    // MARK: - AuthValidator Email Tests

    func testValidEmailFormats() {
        // Valid emails
        XCTAssertTrue(AuthValidator.isValidEmail("test@example.com"))
        XCTAssertTrue(AuthValidator.isValidEmail("user.name@domain.co.uk"))
        XCTAssertTrue(AuthValidator.isValidEmail("user+tag@example.org"))
        XCTAssertTrue(AuthValidator.isValidEmail("test123@test.io"))
    }

    func testInvalidEmailFormats() {
        // Invalid emails
        XCTAssertFalse(AuthValidator.isValidEmail(""))
        XCTAssertFalse(AuthValidator.isValidEmail("invalid"))
        XCTAssertFalse(AuthValidator.isValidEmail("invalid@"))
        XCTAssertFalse(AuthValidator.isValidEmail("@example.com"))
        XCTAssertFalse(AuthValidator.isValidEmail("test@.com"))
        XCTAssertFalse(AuthValidator.isValidEmail("test@example"))
        XCTAssertFalse(AuthValidator.isValidEmail("   "))
    }

    func testEmailValidationResult() {
        let validResult = AuthValidator.validateEmail("test@example.com")
        XCTAssertTrue(validResult.isValid)
        XCTAssertNil(validResult.message)

        let emptyResult = AuthValidator.validateEmail("")
        XCTAssertFalse(emptyResult.isValid)
        XCTAssertEqual(emptyResult.message, "Email is required.")

        let invalidResult = AuthValidator.validateEmail("invalid")
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertEqual(invalidResult.message, "Please enter a valid email address.")
    }

    // MARK: - AuthValidator Password Tests

    func testPasswordValidation() {
        // Valid passwords (6+ characters)
        let valid = AuthValidator.validatePassword("password123")
        XCTAssertTrue(valid.isValid)

        // Empty password
        let empty = AuthValidator.validatePassword("")
        XCTAssertFalse(empty.isValid)
        XCTAssertEqual(empty.message, "Password is required.")

        // Too short
        let short = AuthValidator.validatePassword("12345")
        XCTAssertFalse(short.isValid)
        XCTAssertEqual(short.message, "Password must be at least 6 characters.")
    }

    func testPasswordStrengthWeak() {
        // Weak passwords (< 6 chars or just letters)
        XCTAssertEqual(AuthValidator.evaluatePasswordStrength("12345"), .weak)
        XCTAssertEqual(AuthValidator.evaluatePasswordStrength("abc"), .weak)
    }

    func testPasswordStrengthMedium() {
        // Medium passwords
        XCTAssertEqual(AuthValidator.evaluatePasswordStrength("password"), .medium)
        XCTAssertEqual(AuthValidator.evaluatePasswordStrength("test1234"), .medium)
    }

    func testPasswordStrengthStrong() {
        // Strong passwords (length + uppercase + number + special)
        XCTAssertEqual(AuthValidator.evaluatePasswordStrength("Password123!"), .strong)
        XCTAssertEqual(AuthValidator.evaluatePasswordStrength("MySecure@Pass1"), .strong)
    }

    func testPasswordMatch() {
        // Matching passwords
        let match = AuthValidator.validatePasswordMatch("password", confirmPassword: "password")
        XCTAssertTrue(match.isValid)

        // Non-matching
        let noMatch = AuthValidator.validatePasswordMatch("password1", confirmPassword: "password2")
        XCTAssertFalse(noMatch.isValid)
        XCTAssertEqual(noMatch.message, "Passwords do not match.")

        // Empty confirm
        let emptyConfirm = AuthValidator.validatePasswordMatch("password", confirmPassword: "")
        XCTAssertFalse(emptyConfirm.isValid)
        XCTAssertEqual(emptyConfirm.message, "Please confirm your password.")
    }

    // MARK: - AuthValidator Display Name Tests

    func testDisplayNameValidation() {
        // Valid names
        let valid = AuthValidator.validateDisplayName("John Doe")
        XCTAssertTrue(valid.isValid)

        let validWithHyphen = AuthValidator.validateDisplayName("Mary-Jane")
        XCTAssertTrue(validWithHyphen.isValid)

        let validWithApostrophe = AuthValidator.validateDisplayName("O'Connor")
        XCTAssertTrue(validWithApostrophe.isValid)
    }

    func testDisplayNameValidationErrors() {
        // Empty name
        let empty = AuthValidator.validateDisplayName("")
        XCTAssertFalse(empty.isValid)
        XCTAssertEqual(empty.message, "Name is required.")

        // Too short
        let short = AuthValidator.validateDisplayName("J")
        XCTAssertFalse(short.isValid)
        XCTAssertEqual(short.message, "Name must be at least 2 characters.")

        // Too long (> 50 chars)
        let long = AuthValidator.validateDisplayName(String(repeating: "a", count: 51))
        XCTAssertFalse(long.isValid)
        XCTAssertEqual(long.message, "Name must be less than 50 characters.")

        // Invalid characters
        let invalid = AuthValidator.validateDisplayName("John123")
        XCTAssertFalse(invalid.isValid)
        XCTAssertEqual(invalid.message, "Name contains invalid characters.")
    }

    // MARK: - Form Validation Tests

    func testSignUpFormValidation() {
        // Valid form
        let validResults = AuthValidator.validateSignUpForm(
            email: "test@example.com",
            password: "password123",
            confirmPassword: "password123",
            displayName: "Test User"
        )
        XCTAssertTrue(AuthValidator.isFormValid(validResults))

        // Invalid form (wrong email)
        let invalidEmail = AuthValidator.validateSignUpForm(
            email: "invalid",
            password: "password123",
            confirmPassword: "password123",
            displayName: "Test User"
        )
        XCTAssertFalse(AuthValidator.isFormValid(invalidEmail))

        // Invalid form (password mismatch)
        let mismatchPassword = AuthValidator.validateSignUpForm(
            email: "test@example.com",
            password: "password123",
            confirmPassword: "different",
            displayName: "Test User"
        )
        XCTAssertFalse(AuthValidator.isFormValid(mismatchPassword))
    }

    func testSignInFormValidation() {
        // Valid form
        let valid = AuthValidator.validateSignInForm(
            email: "test@example.com",
            password: "password"
        )
        XCTAssertTrue(AuthValidator.isFormValid(valid))

        // Invalid (empty password)
        let emptyPassword = AuthValidator.validateSignInForm(
            email: "test@example.com",
            password: ""
        )
        XCTAssertFalse(AuthValidator.isFormValid(emptyPassword))
    }

    // MARK: - PasswordStrength Tests

    func testPasswordStrengthColors() {
        XCTAssertEqual(PasswordStrength.weak.color, .red)
        XCTAssertEqual(PasswordStrength.medium.color, .orange)
        XCTAssertEqual(PasswordStrength.strong.color, .green)
    }

    func testPasswordStrengthProgress() {
        XCTAssertEqual(PasswordStrength.weak.progress, 1.0/3.0, accuracy: 0.01)
        XCTAssertEqual(PasswordStrength.medium.progress, 2.0/3.0, accuracy: 0.01)
        XCTAssertEqual(PasswordStrength.strong.progress, 1.0, accuracy: 0.01)
    }

    func testPasswordStrengthDisplayName() {
        XCTAssertEqual(PasswordStrength.weak.displayName, "Weak")
        XCTAssertEqual(PasswordStrength.medium.displayName, "Medium")
        XCTAssertEqual(PasswordStrength.strong.displayName, "Strong")
    }
}
