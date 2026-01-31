//
//  ComponentTests.swift
//  SpendingTrackerTests
//
//  Created by Rakshit on 31/01/26.
//

import XCTest
import SwiftUI
@testable import SpendingTracker

final class ComponentTests: XCTestCase {

    // MARK: - Amount Display Size Tests

    func testAmountDisplaySizeFontSizes() {
        XCTAssertEqual(AmountDisplaySize.small.fontSize, 20)
        XCTAssertEqual(AmountDisplaySize.medium.fontSize, 28)
        XCTAssertEqual(AmountDisplaySize.large.fontSize, 40)
        XCTAssertEqual(AmountDisplaySize.hero.fontSize, 56)
    }

    func testAmountDisplaySizePadding() {
        // Horizontal padding
        XCTAssertEqual(AmountDisplaySize.small.horizontalPadding, 12)
        XCTAssertEqual(AmountDisplaySize.medium.horizontalPadding, 16)
        XCTAssertEqual(AmountDisplaySize.large.horizontalPadding, 20)
        XCTAssertEqual(AmountDisplaySize.hero.horizontalPadding, 24)

        // Vertical padding
        XCTAssertEqual(AmountDisplaySize.small.verticalPadding, 8)
        XCTAssertEqual(AmountDisplaySize.medium.verticalPadding, 12)
        XCTAssertEqual(AmountDisplaySize.large.verticalPadding, 16)
        XCTAssertEqual(AmountDisplaySize.hero.verticalPadding, 20)
    }

    func testAmountDisplaySizeCornerRadius() {
        XCTAssertEqual(AmountDisplaySize.small.cornerRadius, 10)
        XCTAssertEqual(AmountDisplaySize.medium.cornerRadius, 12)
        XCTAssertEqual(AmountDisplaySize.large.cornerRadius, 16)
        XCTAssertEqual(AmountDisplaySize.hero.cornerRadius, 20)
    }

    // MARK: - Mesh Gradient Color Scheme Tests

    func testMeshGradientColorSchemeHasNineColors() {
        // Each color scheme should have exactly 9 colors for the 3x3 mesh
        XCTAssertEqual(MeshGradientColorScheme.purple.colors.count, 9)
        XCTAssertEqual(MeshGradientColorScheme.blue.colors.count, 9)
        XCTAssertEqual(MeshGradientColorScheme.green.colors.count, 9)
        XCTAssertEqual(MeshGradientColorScheme.orange.colors.count, 9)
        XCTAssertEqual(MeshGradientColorScheme.pink.colors.count, 9)
        XCTAssertEqual(MeshGradientColorScheme.dark.colors.count, 9)
    }

    func testCustomMeshGradientColorScheme() {
        // Test custom colors are handled correctly
        let customColors: [Color] = Array(repeating: .red, count: 9)
        let scheme = MeshGradientColorScheme.custom(customColors)
        XCTAssertEqual(scheme.colors.count, 9)

        // Test with fewer colors (should pad to 9)
        let fewColors: [Color] = [.red, .blue]
        let fewScheme = MeshGradientColorScheme.custom(fewColors)
        XCTAssertEqual(fewScheme.colors.count, 9)
    }

    // MARK: - Password Strength Integration Tests

    func testPasswordStrengthIndicatorIntegration() {
        // These tests verify the PasswordStrengthIndicator works with AuthValidator

        // Weak password
        let weakStrength = AuthValidator.evaluatePasswordStrength("12345")
        XCTAssertEqual(weakStrength, .weak)
        XCTAssertEqual(weakStrength.color, .red)

        // Medium password
        let mediumStrength = AuthValidator.evaluatePasswordStrength("password")
        XCTAssertEqual(mediumStrength, .medium)
        XCTAssertEqual(mediumStrength.color, .orange)

        // Strong password
        let strongStrength = AuthValidator.evaluatePasswordStrength("Password123!")
        XCTAssertEqual(strongStrength, .strong)
        XCTAssertEqual(strongStrength.color, .green)
    }

    // MARK: - View Modifier Tests

    func testAdaptiveGlassModifierCreation() {
        // Test that the modifier can be created with various parameters
        let modifier1 = AdaptiveGlassModifier()
        XCTAssertNotNil(modifier1)

        let modifier2 = AdaptiveGlassModifier(tint: .blue)
        XCTAssertNotNil(modifier2)

        let modifier3 = AdaptiveGlassModifier(tint: .green, cornerRadius: 20)
        XCTAssertNotNil(modifier3)
    }

    func testReducedMotionModifierCreation() {
        let modifier = ReducedMotionModifier()
        XCTAssertNotNil(modifier)

        let customModifier = ReducedMotionModifier(
            animation: .easeInOut,
            reducedAnimation: .linear(duration: 0)
        )
        XCTAssertNotNil(customModifier)
    }

    func testHighContrastModifierCreation() {
        let modifier = HighContrastModifier()
        XCTAssertNotNil(modifier)

        let customModifier = HighContrastModifier(
            normalOpacity: 0.2,
            highContrastOpacity: 0.5
        )
        XCTAssertNotNil(customModifier)
    }

    // MARK: - Component Initialization Tests

    func testGlassCardInitialization() {
        // Test default initialization
        let card = GlassCard {
            Text("Test")
        }
        XCTAssertNotNil(card)
    }

    func testGlassButtonInitialization() {
        // Test default initialization
        let button = GlassButton(title: "Test") {
            print("Tapped")
        }
        XCTAssertNotNil(button)

        // Test with all parameters
        let fullButton = GlassButton(
            title: "Full Test",
            icon: "star",
            tint: .blue,
            isLoading: false
        ) {
            print("Tapped")
        }
        XCTAssertNotNil(fullButton)
    }

    func testGlassIconButtonInitialization() {
        // Test default initialization
        let button = GlassIconButton(icon: "star") {
            print("Tapped")
        }
        XCTAssertNotNil(button)

        // Test with custom size (should enforce minimum 44pt)
        let smallButton = GlassIconButton(icon: "star", size: 30) {
            print("Tapped")
        }
        XCTAssertNotNil(smallButton)
    }

    func testGlassTextFieldInitialization() {
        @State var text = ""

        let textField = GlassTextField(
            placeholder: "Test",
            text: $text
        )
        XCTAssertNotNil(textField)

        let fullTextField = GlassTextField(
            placeholder: "Email",
            text: $text,
            icon: "envelope",
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            autocapitalization: .never,
            isError: false,
            errorMessage: nil
        )
        XCTAssertNotNil(fullTextField)
    }

    func testGlassSecureFieldInitialization() {
        @State var text = ""
        @State var showPassword = false

        let secureField = GlassSecureField(
            placeholder: "Password",
            text: $text
        )
        XCTAssertNotNil(secureField)

        let fullSecureField = GlassSecureField(
            placeholder: "Password",
            text: $text,
            showPassword: $showPassword,
            isError: true,
            errorMessage: "Password is required"
        )
        XCTAssertNotNil(fullSecureField)
    }

    func testAnimatedMeshGradientInitialization() {
        let gradient = AnimatedMeshGradient()
        XCTAssertNotNil(gradient)

        let customGradient = AnimatedMeshGradient(colorScheme: .blue)
        XCTAssertNotNil(customGradient)
    }

    func testGlassAmountDisplayInitialization() {
        let display = GlassAmountDisplay(amount: 1000)
        XCTAssertNotNil(display)

        let fullDisplay = GlassAmountDisplay(
            amount: 2500.50,
            isExpense: false,
            currencyCode: "USD",
            showSign: true,
            size: .hero
        )
        XCTAssertNotNil(fullDisplay)
    }

    func testGlassSummaryCardInitialization() {
        let card = GlassSummaryCard(
            income: 50000,
            expenses: 30000
        )
        XCTAssertNotNil(card)

        let customCard = GlassSummaryCard(
            income: 100000,
            expenses: 75000,
            currencyCode: "USD"
        )
        XCTAssertNotNil(customCard)
    }

    func testGlassStatCardInitialization() {
        let card = GlassStatCard(
            title: "Total",
            value: "₹50,000",
            icon: "chart.bar",
            tint: .blue
        )
        XCTAssertNotNil(card)
    }
}
