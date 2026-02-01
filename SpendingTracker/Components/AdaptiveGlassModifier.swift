//
//  AdaptiveGlassModifier.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Adaptive Glass Modifier (iOS 26 Stable - Accessibility)

/// A view modifier that adapts glass effects based on accessibility settings
struct AdaptiveGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let tint: Color?
    let cornerRadius: CGFloat

    init(tint: Color? = nil, cornerRadius: CGFloat = 16) {
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        if reduceTransparency || colorScheme == .light {
            // Solid background for reduced transparency or light mode (iOS Settings style)
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(colorScheme == .dark ? Color(white: 0.15) : ThemeColors.cardBackground)
                        .shadow(color: colorScheme == .light ? ThemeColors.cardShadow(for: colorScheme) : .clear, radius: 1, x: 0, y: 1)
                }
        } else {
            // Full Liquid Glass effect (dark mode only)
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            if let tint {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .fill(tint.opacity(0.1))
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                        }
                }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies an adaptive glass effect that respects accessibility settings
    func adaptiveGlass(tint: Color? = nil, cornerRadius: CGFloat = 16) -> some View {
        modifier(AdaptiveGlassModifier(tint: tint, cornerRadius: cornerRadius))
    }
}

// MARK: - Adaptive Glass Card

/// A card that automatically adapts to accessibility settings
struct AdaptiveGlassCard<Content: View>: View {
    let tint: Color?
    let cornerRadius: CGFloat
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        tint: Color? = nil,
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .adaptiveGlass(tint: tint, cornerRadius: cornerRadius)
    }
}

// MARK: - Reduced Motion Modifier

/// A modifier that respects reduce motion accessibility settings
struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let animation: Animation
    let reducedAnimation: Animation

    init(animation: Animation = .spring(), reducedAnimation: Animation = .linear(duration: 0)) {
        self.animation = animation
        self.reducedAnimation = reducedAnimation
    }

    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? reducedAnimation : animation, value: UUID())
    }
}

extension View {
    /// Applies animation that respects reduced motion settings
    func adaptiveAnimation(_ animation: Animation = .spring()) -> some View {
        modifier(ReducedMotionModifier(animation: animation))
    }
}

// MARK: - Accessibility Enhanced Button

/// A button with enhanced accessibility features
struct AccessibleGlassButton: View {
    let title: String
    let icon: String?
    let tint: Color
    let accessibilityHint: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    init(
        title: String,
        icon: String? = nil,
        tint: Color = .accentColor,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.accessibilityHint = accessibilityHint
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.gradient)
            }
            .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
        .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
        }, perform: {})
    }
}

// MARK: - High Contrast Support

/// A modifier that enhances contrast for accessibility
struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var contrast

    let normalOpacity: Double
    let highContrastOpacity: Double

    init(normalOpacity: Double = 0.1, highContrastOpacity: Double = 0.3) {
        self.normalOpacity = normalOpacity
        self.highContrastOpacity = highContrastOpacity
    }

    func body(content: Content) -> some View {
        content
            .opacity(contrast == .increased || differentiateWithoutColor ? highContrastOpacity : normalOpacity)
    }
}

extension View {
    /// Adapts opacity for high contrast mode
    func adaptiveOpacity(normal: Double = 0.1, highContrast: Double = 0.3) -> some View {
        modifier(HighContrastModifier(normalOpacity: normal, highContrastOpacity: highContrast))
    }
}

// MARK: - Preview

#Preview("Accessibility Features") {
    struct PreviewWrapper: View {
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Adaptive Glass Card
                    AdaptiveGlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Adaptive Glass Card")
                                .font(.headline)
                            Text("This card adapts based on accessibility settings like Reduce Transparency.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Accessible Button
                    AccessibleGlassButton(
                        title: "Sign In",
                        icon: "arrow.right",
                        accessibilityHint: "Double tap to sign in to your account"
                    ) {
                        print("Sign in tapped")
                    }

                    // Regular glass for comparison
                    Text("Standard Glass Effect")
                        .padding()
                        .adaptiveGlass(tint: .green)

                    Spacer()
                }
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
