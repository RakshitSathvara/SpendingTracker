//
//  AuthBackground.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Auth Background (iOS 26 Stable)

/// Static gradient background for authentication screens that adapts to system color scheme
struct AuthBackground: View {

    // MARK: - Properties

    @Environment(\.colorScheme) private var colorScheme

    var colorTheme: AuthBackgroundTheme = .purple

    // MARK: - Body

    var body: some View {
        LinearGradient(
            colors: colorTheme.colors(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Auth Background Theme

enum AuthBackgroundTheme {
    case purple
    case blue
    case green
    case sunset
    case dark

    func colors(for colorScheme: ColorScheme) -> [Color] {
        switch colorScheme {
        case .dark:
            return darkColors
        case .light:
            return lightColors
        @unknown default:
            return darkColors
        }
    }

    private var darkColors: [Color] {
        switch self {
        case .purple:
            return [
                Color(red: 0.15, green: 0.10, blue: 0.28),
                Color(red: 0.10, green: 0.08, blue: 0.20),
                Color(red: 0.06, green: 0.05, blue: 0.14)
            ]
        case .blue:
            return [
                Color(red: 0.08, green: 0.12, blue: 0.25),
                Color(red: 0.06, green: 0.10, blue: 0.20),
                Color(red: 0.04, green: 0.06, blue: 0.14)
            ]
        case .green:
            return [
                Color(red: 0.08, green: 0.18, blue: 0.15),
                Color(red: 0.05, green: 0.14, blue: 0.12),
                Color(red: 0.04, green: 0.10, blue: 0.08)
            ]
        case .sunset:
            return [
                Color(red: 0.22, green: 0.12, blue: 0.15),
                Color(red: 0.18, green: 0.10, blue: 0.12),
                Color(red: 0.12, green: 0.06, blue: 0.08)
            ]
        case .dark:
            return [
                Color(white: 0.12),
                Color(white: 0.08),
                Color(white: 0.05)
            ]
        }
    }

    private var lightColors: [Color] {
        switch self {
        case .purple:
            return [
                Color(red: 0.95, green: 0.93, blue: 1.0),
                Color(red: 0.96, green: 0.94, blue: 0.99),
                Color(red: 0.98, green: 0.97, blue: 1.0)
            ]
        case .blue:
            return [
                Color(red: 0.93, green: 0.96, blue: 1.0),
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.97, green: 0.98, blue: 1.0)
            ]
        case .green:
            return [
                Color(red: 0.93, green: 0.98, blue: 0.96),
                Color(red: 0.95, green: 0.99, blue: 0.97),
                Color(red: 0.97, green: 1.0, blue: 0.98)
            ]
        case .sunset:
            return [
                Color(red: 1.0, green: 0.96, blue: 0.94),
                Color(red: 1.0, green: 0.97, blue: 0.95),
                Color(red: 1.0, green: 0.98, blue: 0.97)
            ]
        case .dark:
            return [
                Color(white: 0.94),
                Color(white: 0.96),
                Color(white: 0.98)
            ]
        }
    }
}

// MARK: - Subtle Auth Background

/// A more subtle static background for secondary auth screens
struct SubtleAuthBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.10), Color(white: 0.06)]
                : [Color(white: 0.96), Color(white: 0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("Purple Theme - Dark") {
    AuthBackground(colorTheme: .purple)
        .preferredColorScheme(.dark)
}

#Preview("Purple Theme - Light") {
    AuthBackground(colorTheme: .purple)
        .preferredColorScheme(.light)
}

#Preview("Blue Theme - Dark") {
    AuthBackground(colorTheme: .blue)
        .preferredColorScheme(.dark)
}

#Preview("Blue Theme - Light") {
    AuthBackground(colorTheme: .blue)
        .preferredColorScheme(.light)
}

#Preview("Subtle Background") {
    SubtleAuthBackground()
}
