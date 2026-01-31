//
//  GlassCard.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Glass Card (iOS 26 Stable)

/// A container view with iOS 26 Liquid Glass effect
struct GlassCard<Content: View>: View {
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
            .background {
                GlassBackground(tint: tint, cornerRadius: cornerRadius)
            }
    }
}

// MARK: - Glass Background

/// Reusable glass background component
struct GlassBackground: View {
    let tint: Color?
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    init(tint: Color? = nil, cornerRadius: CGFloat = 20) {
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint?.opacity(0.1) ?? Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.2 : 0.5),
                                .white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
}

// MARK: - Compact Glass Card

/// A more compact version of GlassCard for list items
struct CompactGlassCard<Content: View>: View {
    let tint: Color?
    @ViewBuilder let content: () -> Content

    init(tint: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.tint = tint
        self.content = content
    }

    var body: some View {
        GlassCard(tint: tint, cornerRadius: 12, padding: 12, content: content)
    }
}

// MARK: - Glass Card Styles

extension GlassCard {
    /// Standard glass card with accent tint
    static func accent(@ViewBuilder content: @escaping () -> Content) -> GlassCard {
        GlassCard(tint: .accentColor, content: content)
    }

    /// Glass card optimized for form sections
    static func form(@ViewBuilder content: @escaping () -> Content) -> GlassCard {
        GlassCard(cornerRadius: 16, padding: 20, content: content)
    }
}

// MARK: - Preview

#Preview("Glass Card") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Glass Card")
                        .font(.headline)
                    Text("This is a standard glass card with the Liquid Glass effect.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            GlassCard(tint: .blue) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Tinted Card")
                            .font(.headline)
                        Text("With blue tint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            CompactGlassCard(tint: .green) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Compact Card")
                    Spacer()
                    Text("Done")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
