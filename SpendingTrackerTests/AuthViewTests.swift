//
//  AuthViewTests.swift
//  SpendingTrackerTests
//
//  Created by Rakshit on 31/01/26.
//

import XCTest
import SwiftUI
@testable import SpendingTracker

final class AuthViewTests: XCTestCase {

    // MARK: - Auth Background Theme Tests

    func testAuthBackgroundThemeColors() {
        // Verify each theme has 9 colors for the 3x3 mesh
        XCTAssertEqual(AuthBackgroundTheme.purple.colors(for: .light).count, 9)
        XCTAssertEqual(AuthBackgroundTheme.blue.colors(for: .light).count, 9)
        XCTAssertEqual(AuthBackgroundTheme.green.colors(for: .light).count, 9)
        XCTAssertEqual(AuthBackgroundTheme.sunset.colors(for: .light).count, 9)
        XCTAssertEqual(AuthBackgroundTheme.dark.colors(for: .light).count, 9)
    }

    func testAuthBackgroundThemeDarkMode() {
        // Verify dark mode colors also have 9 colors
        XCTAssertEqual(AuthBackgroundTheme.purple.colors(for: .dark).count, 9)
        XCTAssertEqual(AuthBackgroundTheme.blue.colors(for: .dark).count, 9)
    }

    // MARK: - User Persona Extension Tests

    func testUserPersonaIcons() {
        XCTAssertEqual(UserPersona.student.icon, "graduationcap.fill")
        XCTAssertEqual(UserPersona.professional.icon, "briefcase.fill")
        XCTAssertEqual(UserPersona.family.icon, "house.fill")
    }

    func testUserPersonaColors() {
        XCTAssertEqual(UserPersona.student.color, .blue)
        XCTAssertEqual(UserPersona.professional.color, .purple)
        XCTAssertEqual(UserPersona.family.color, .green)
    }

    func testUserPersonaDescriptions() {
        // Verify descriptions are not empty
        XCTAssertFalse(UserPersona.student.description.isEmpty)
        XCTAssertFalse(UserPersona.professional.description.isEmpty)
        XCTAssertFalse(UserPersona.family.description.isEmpty)
    }

    // MARK: - View Initialization Tests

    func testAuthBackgroundInitialization() {
        let background = AuthBackground()
        XCTAssertNotNil(background)

        let customBackground = AuthBackground(colorTheme: .blue)
        XCTAssertNotNil(customBackground)
    }

    func testSubtleAuthBackgroundInitialization() {
        let subtleBackground = SubtleAuthBackground()
        XCTAssertNotNil(subtleBackground)
    }

    func testPersonaButtonInitialization() {
        let button = PersonaButton(
            persona: .student,
            isSelected: true
        ) {
            // Action
        }
        XCTAssertNotNil(button)
    }

    func testPersonaSelectionRowInitialization() {
        @State var selectedPersona: UserPersona = .professional

        let row = PersonaSelectionRow(selectedPersona: $selectedPersona)
        XCTAssertNotNil(row)

        let rowWithoutLabel = PersonaSelectionRow(
            selectedPersona: $selectedPersona,
            showLabel: false
        )
        XCTAssertNotNil(rowWithoutLabel)
    }

    func testCompactPersonaSelectorInitialization() {
        @State var selectedPersona: UserPersona = .professional

        let selector = CompactPersonaSelector(selectedPersona: $selectedPersona)
        XCTAssertNotNil(selector)
    }

    func testCompactPersonaChipInitialization() {
        let chip = CompactPersonaChip(
            persona: .student,
            isSelected: false
        ) {
            // Action
        }
        XCTAssertNotNil(chip)
    }

    func testPersonaDescriptionCardInitialization() {
        let card = PersonaDescriptionCard(persona: .family)
        XCTAssertNotNil(card)
    }

    func testLoginViewInitialization() {
        @State var showingSignUp = false

        let loginView = LoginView(showingSignUp: $showingSignUp)
        XCTAssertNotNil(loginView)
    }

    func testSignUpViewInitialization() {
        @State var showingSignUp = true

        let signUpView = SignUpView(showingSignUp: $showingSignUp)
        XCTAssertNotNil(signUpView)
    }

    func testForgotPasswordViewInitialization() {
        let forgotPasswordView = ForgotPasswordView()
        XCTAssertNotNil(forgotPasswordView)
    }

    func testAuthenticationCoordinatorInitialization() {
        let coordinator = AuthenticationCoordinator()
        XCTAssertNotNil(coordinator)
    }

    // MARK: - Form Validation Integration Tests

    func testLoginFormValidationIntegration() {
        // Test valid form
        let validEmail = AuthValidator.validateEmail("test@example.com")
        let validPassword = AuthValidator.validatePassword("password123")

        XCTAssertTrue(validEmail.isValid)
        XCTAssertTrue(validPassword.isValid)

        // Test invalid email
        let invalidEmail = AuthValidator.validateEmail("invalid")
        XCTAssertFalse(invalidEmail.isValid)
        XCTAssertNotNil(invalidEmail.message)
    }

    func testSignUpFormValidationIntegration() {
        // Test valid form
        let validResults = AuthValidator.validateSignUpForm(
            email: "test@example.com",
            password: "Password123!",
            confirmPassword: "Password123!",
            displayName: "John Doe"
        )

        XCTAssertTrue(AuthValidator.isFormValid(validResults))

        // Test invalid form - password mismatch
        let invalidResults = AuthValidator.validateSignUpForm(
            email: "test@example.com",
            password: "Password123!",
            confirmPassword: "Different456!",
            displayName: "John Doe"
        )

        XCTAssertFalse(AuthValidator.isFormValid(invalidResults))
    }

    func testPasswordStrengthInSignUp() {
        // Test that password strength indicator works with sign up validation
        let weakPassword = "12345"
        let strongPassword = "MySecure@Pass1"

        XCTAssertEqual(AuthValidator.evaluatePasswordStrength(weakPassword), .weak)
        XCTAssertEqual(AuthValidator.evaluatePasswordStrength(strongPassword), .strong)
    }

    // MARK: - Accessibility Tests

    func testUserPersonaAccessibilityInfo() {
        // Verify personas have proper display names for accessibility
        for persona in UserPersona.allCases {
            XCTAssertFalse(persona.displayName.isEmpty)
            XCTAssertFalse(persona.icon.isEmpty)
            XCTAssertFalse(persona.description.isEmpty)
        }
    }

    // MARK: - Theme Consistency Tests

    func testAllBackgroundThemesHaveCorrectColorCount() {
        let themes: [AuthBackgroundTheme] = [.purple, .blue, .green, .sunset, .dark]

        for theme in themes {
            let lightColors = theme.colors(for: .light)
            let darkColors = theme.colors(for: .dark)

            // MeshGradient with width: 3, height: 3 requires exactly 9 colors
            XCTAssertEqual(lightColors.count, 9, "Theme \(theme) should have 9 colors for light mode")
            XCTAssertEqual(darkColors.count, 9, "Theme \(theme) should have 9 colors for dark mode")
        }
    }
}
