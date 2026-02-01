//
//  QuickActionsRow.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Quick Actions Row (iOS 26 Stable)

/// A row of quick action buttons for common dashboard actions
struct QuickActionsRow: View {
    let onAddExpense: () -> Void
    let onAddIncome: () -> Void
    let onTransfer: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                title: "Expense",
                icon: "arrow.down.circle",
                tint: .red,
                action: onAddExpense
            )

            QuickActionButton(
                title: "Income",
                icon: "arrow.up.circle",
                tint: .green,
                action: onAddIncome
            )

            QuickActionButton(
                title: "Transfer",
                icon: "arrow.left.arrow.right.circle",
                tint: .blue,
                action: onTransfer
            )
        }
    }
}

// MARK: - Quick Action Button (iOS 26 Stable)

/// A single quick action button with glass effect
struct QuickActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .symbolEffect(.bounce, value: isPressed)

                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                glassBackground(tint: tint)
            }
        }
        .buttonStyle(QuickActionButtonStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }

    private func glassBackground(tint: Color) -> some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.1))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.3),
                                        tint.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            } else {
                // iOS Settings-style solid white card with subtle tint
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ThemeColors.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.05))
                    }
                    .shadow(color: ThemeColors.cardShadow(for: colorScheme), radius: 1, x: 0, y: 1)
            }
        }
    }
}

// MARK: - Quick Action Button Style

/// Custom button style for quick action buttons
struct QuickActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Large Quick Action Button

/// A larger variant of the quick action button for prominent actions
struct LargeQuickActionButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.15))
                    .clipShape(Circle())
                    .symbolEffect(.bounce, value: isPressed)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(ThemeColors.cardBackground)
                        .shadow(color: ThemeColors.cardShadow(for: colorScheme), radius: 1, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(QuickActionButtonStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Floating Action Button

/// A floating action button for adding new transactions
struct FloatingAddButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
                }
        }
        .buttonStyle(FloatingButtonStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Custom button style for floating action button
struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Quick Actions") {
    ZStack {
        AdaptiveBackground(style: .primary)

        VStack(spacing: 24) {
            QuickActionsRow(
                onAddExpense: { print("Add Expense") },
                onAddIncome: { print("Add Income") },
                onTransfer: { print("Transfer") }
            )

            LargeQuickActionButton(
                title: "Add Transaction",
                subtitle: "Record a new expense or income",
                icon: "plus.circle.fill",
                tint: .blue
            ) {
                print("Add Transaction")
            }

            Spacer()

            HStack {
                Spacer()
                FloatingAddButton {
                    print("FAB tapped")
                }
            }
        }
        .padding()
    }
}
