//
//  AppTheme.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Theme Colors (iOS 26 Stable)

/// Centralized theme system that adapts to system light/dark mode
enum ThemeColors {

    // MARK: - Background Colors

    /// iOS Settings-style light gray background (systemGroupedBackground)
    static let systemGroupedBackground = Color(red: 0.949, green: 0.949, blue: 0.969)

    /// iOS Settings-style white card background (secondarySystemGroupedBackground)
    static let cardBackground = Color.white

    /// Primary background gradient for main screens
    static func primaryBackground(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.08, green: 0.06, blue: 0.14), Color(red: 0.05, green: 0.04, blue: 0.10)]
                : [systemGroupedBackground, systemGroupedBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Secondary background for sheets and modals
    static func secondaryBackground(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.10, green: 0.08, blue: 0.16), Color(red: 0.06, green: 0.05, blue: 0.12)]
                : [systemGroupedBackground, systemGroupedBackground],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Auth screen background with subtle accent
    static func authBackground(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.12, green: 0.08, blue: 0.22),
                    Color(red: 0.08, green: 0.06, blue: 0.16),
                    Color(red: 0.05, green: 0.04, blue: 0.12)
                ]
                : [systemGroupedBackground, systemGroupedBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Text Colors

    /// Primary text color
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.15)
    }

    /// Secondary text color
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 0.4, green: 0.4, blue: 0.45)
    }

    // MARK: - Card Colors

    /// Glass card background material
    static func cardMaterial(for colorScheme: ColorScheme) -> Material {
        colorScheme == .dark ? .ultraThinMaterial : .regularMaterial
    }

    /// Card border color
    static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? .white.opacity(0.15)
            : .clear
    }

    /// Card shadow for light mode (iOS Settings style)
    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .clear : .black.opacity(0.04)
    }

    // MARK: - Accent Colors

    /// Primary accent gradient
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Income color
    static let incomeColor = Color.green

    /// Expense color
    static let expenseColor = Color.red
}

// MARK: - Adaptive Background View

/// A static background view that adapts to system color scheme
struct AdaptiveBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    enum Style {
        case primary
        case secondary
        case auth
    }

    let style: Style

    init(style: Style = .primary) {
        self.style = style
    }

    var body: some View {
        Group {
            switch style {
            case .primary:
                ThemeColors.primaryBackground(for: colorScheme)
            case .secondary:
                ThemeColors.secondaryBackground(for: colorScheme)
            case .auth:
                ThemeColors.authBackground(for: colorScheme)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Adaptive Card Modifier

struct AdaptiveCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    ThemeColors.cardBorder(for: colorScheme),
                                    lineWidth: 0.5
                                )
                        }
                } else {
                    // iOS Settings-style solid white card
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(ThemeColors.cardBackground)
                        .shadow(color: ThemeColors.cardShadow(for: colorScheme), radius: 1, x: 0, y: 1)
                }
            }
    }
}

extension View {
    func adaptiveCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(AdaptiveCardStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#Preview("Adaptive Backgrounds - Dark") {
    VStack(spacing: 20) {
        Text("Primary Background")
            .padding()
            .background(AdaptiveBackground(style: .primary))

        Text("Auth Background")
            .padding()
            .background(AdaptiveBackground(style: .auth))
    }
    .preferredColorScheme(.dark)
}

#Preview("Adaptive Backgrounds - Light") {
    VStack(spacing: 20) {
        Text("Primary Background")
            .padding()
            .background(AdaptiveBackground(style: .primary))

        Text("Auth Background")
            .padding()
            .background(AdaptiveBackground(style: .auth))
    }
    .preferredColorScheme(.light)
}
