//
//  GlassButton.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Glass Button (iOS 26 Stable)

/// A button with iOS 26 Liquid Glass effect and haptic feedback
struct GlassButton: View {
    let title: String
    let icon: String?
    let tint: Color
    let isLoading: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    init(
        title: String,
        icon: String? = nil,
        tint: Color = .accentColor,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.gradient)
                    .opacity(isEnabled ? 1 : 0.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(isPressed ? 0.2 : 0))
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Glass Icon Button (iOS 26 Stable)

/// A circular icon button with glass effect and 44pt minimum touch target
struct GlassIconButton: View {
    let icon: String
    let tint: Color
    let size: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    init(
        icon: String,
        tint: Color = .primary,
        size: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.tint = tint
        self.size = max(size, 44) // Ensure minimum 44pt for accessibility
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .fill(tint.opacity(0.1))
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Glass Secondary Button

/// A secondary style glass button with outline
struct GlassSecondaryButton: View {
    let title: String
    let icon: String?
    let tint: Color
    let action: () -> Void

    @State private var isPressed = false

    init(
        title: String,
        icon: String? = nil,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint.opacity(0.3), lineWidth: 1)
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Glass Destructive Button

/// A destructive action button with glass effect
struct GlassDestructiveButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(
        title: String,
        icon: String? = "trash",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        GlassSecondaryButton(title: title, icon: icon, tint: .red, action: action)
    }
}

// MARK: - Preview

#Preview("Glass Buttons") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassButton(title: "Sign In", icon: "arrow.right") {
                print("Sign In tapped")
            }

            GlassButton(title: "Loading...", isLoading: true) {
                print("Loading")
            }

            GlassSecondaryButton(title: "Create Account", icon: "person.badge.plus") {
                print("Create Account tapped")
            }

            GlassDestructiveButton(title: "Delete Account") {
                print("Delete tapped")
            }

            HStack(spacing: 16) {
                GlassIconButton(icon: "plus", tint: .blue) {
                    print("Plus tapped")
                }

                GlassIconButton(icon: "heart.fill", tint: .red) {
                    print("Heart tapped")
                }

                GlassIconButton(icon: "gear", tint: .gray) {
                    print("Settings tapped")
                }

                GlassIconButton(icon: "bell.fill", tint: .orange, size: 50) {
                    print("Bell tapped")
                }
            }
        }
        .padding()
    }
}
