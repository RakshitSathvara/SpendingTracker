//
//  AuthBackground.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Auth Background (iOS 26 Stable)

/// Animated MeshGradient background for authentication screens
struct AuthBackground: View {

    // MARK: - Properties

    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    var colorTheme: AuthBackgroundTheme = .purple

    // MARK: - Animated Points

    private var animatedPoints: [SIMD2<Float>] {
        let offset = Float(phase) * 0.1
        return [
            SIMD2(0, 0), SIMD2(0.5, 0 + offset), SIMD2(1, 0),
            SIMD2(0 + offset, 0.5), SIMD2(0.5, 0.5), SIMD2(1 - offset, 0.5),
            SIMD2(0, 1), SIMD2(0.5, 1 - offset), SIMD2(1, 1)
        ]
    }

    // MARK: - Body

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: animatedPoints,
            colors: colorTheme.colors(for: colorScheme)
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
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
        switch self {
        case .purple:
            return [
                .blue.opacity(0.3), .purple.opacity(0.4), .blue.opacity(0.3),
                .cyan.opacity(0.3), .purple.opacity(0.5), .pink.opacity(0.3),
                .blue.opacity(0.3), .cyan.opacity(0.4), .purple.opacity(0.3)
            ]
        case .blue:
            return [
                .blue.opacity(0.4), .cyan.opacity(0.3), .blue.opacity(0.4),
                .cyan.opacity(0.3), .blue.opacity(0.5), .teal.opacity(0.3),
                .blue.opacity(0.4), .cyan.opacity(0.4), .blue.opacity(0.4)
            ]
        case .green:
            return [
                .green.opacity(0.3), .teal.opacity(0.4), .green.opacity(0.3),
                .mint.opacity(0.3), .green.opacity(0.5), .cyan.opacity(0.3),
                .green.opacity(0.3), .teal.opacity(0.4), .mint.opacity(0.3)
            ]
        case .sunset:
            return [
                .orange.opacity(0.3), .pink.opacity(0.4), .red.opacity(0.3),
                .yellow.opacity(0.2), .orange.opacity(0.5), .pink.opacity(0.3),
                .orange.opacity(0.3), .red.opacity(0.4), .pink.opacity(0.3)
            ]
        case .dark:
            return [
                Color(white: 0.1), Color(white: 0.15), Color(white: 0.1),
                Color(white: 0.15), Color(white: 0.2), Color(white: 0.15),
                Color(white: 0.1), Color(white: 0.15), Color(white: 0.1)
            ]
        }
    }
}

// MARK: - Subtle Auth Background

/// A more subtle animated background for secondary auth screens
struct SubtleAuthBackground: View {
    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(white: 0.1), Color(white: 0.05)]
                    : [Color(white: 0.95), Color(white: 0.9)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle mesh overlay
            MeshGradient(
                width: 2,
                height: 2,
                points: [
                    SIMD2(0, 0), SIMD2(1, 0),
                    SIMD2(0, 1), SIMD2(1, 1)
                ],
                colors: [
                    .blue.opacity(0.1), .purple.opacity(0.1),
                    .purple.opacity(0.1), .blue.opacity(0.1)
                ]
            )
            .opacity(phase)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                phase = 0.6
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("Purple Theme") {
    AuthBackground(colorTheme: .purple)
}

#Preview("Blue Theme") {
    AuthBackground(colorTheme: .blue)
}

#Preview("Sunset Theme") {
    AuthBackground(colorTheme: .sunset)
}

#Preview("Subtle Background") {
    SubtleAuthBackground()
}
