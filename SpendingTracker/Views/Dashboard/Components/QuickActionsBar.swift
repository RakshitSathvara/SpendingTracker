//
//  QuickActionsBar.swift
//  SpendingTracker
//
//  Quick action buttons for fast transaction entry
//  Best Practice: Most frequent actions easily accessible
//

import SwiftUI

// MARK: - Quick Actions Bar (2026 Modern UI)

/// Horizontal scrollable quick actions for common tasks
struct QuickActionsBar: View {
    let onAddExpense: () -> Void
    let onAddIncome: () -> Void
    let onTransfer: () -> Void
    let onScanReceipt: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Add Expense - Primary action
                QuickActionPillButton(
                    title: "Expense",
                    icon: "arrow.down.circle.fill",
                    color: .red,
                    isPrimary: true,
                    action: onAddExpense
                )

                // Add Income
                QuickActionPillButton(
                    title: "Income",
                    icon: "arrow.up.circle.fill",
                    color: .green,
                    isPrimary: false,
                    action: onAddIncome
                )

                // Transfer
                QuickActionPillButton(
                    title: "Transfer",
                    icon: "arrow.left.arrow.right.circle.fill",
                    color: .blue,
                    isPrimary: false,
                    action: onTransfer
                )

                // Scan Receipt (if available)
                if let scanAction = onScanReceipt {
                    QuickActionPillButton(
                        title: "Scan",
                        icon: "camera.viewfinder",
                        color: .purple,
                        isPrimary: false,
                        action: scanAction
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Quick Action Pill Button

struct QuickActionPillButton: View {
    let title: String
    let icon: String
    let color: Color
    let isPrimary: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(isPrimary ? .title3 : .body)
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(isPrimary ? .subheadline.bold() : .subheadline)
            }
            .foregroundStyle(isPrimary ? .white : color)
            .padding(.horizontal, isPrimary ? 20 : 16)
            .padding(.vertical, 12)
            .background {
                if isPrimary {
                    Capsule()
                        .fill(color.gradient)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                } else {
                    if colorScheme == .dark {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule()
                                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
                            }
                    } else {
                        Capsule()
                            .fill(color.opacity(0.12))
                            .overlay {
                                Capsule()
                                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
                            }
                    }
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: isPrimary ? .medium : .light), trigger: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Quick Stats Row

/// Compact row of key statistics
struct QuickStatsRow: View {
    let stats: [QuickStat]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(stats) { stat in
                QuickStatCard(stat: stat)
            }
        }
    }
}

struct QuickStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Double? // positive = up, negative = down

    init(title: String, value: String, icon: String, color: Color, trend: Double? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.trend = trend
    }
}

struct QuickStatCard: View {
    let stat: QuickStat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: stat.icon)
                    .font(.caption)
                    .foregroundStyle(stat.color)

                Text(stat.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Text(stat.value)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let trend = stat.trend {
                    trendIndicator(trend)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ThemeColors.cardBackground)
                    .shadow(color: ThemeColors.cardShadow(for: colorScheme), radius: 1, x: 0, y: 1)
            }
        }
    }

    @ViewBuilder
    private func trendIndicator(_ trend: Double) -> some View {
        HStack(spacing: 1) {
            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 8, weight: .bold))
            Text("\(abs(Int(trend)))%")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(trend >= 0 ? .red : .green)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background((trend >= 0 ? Color.red : Color.green).opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("Quick Actions") {
    ZStack {
        AdaptiveBackground(style: .primary)

        VStack(spacing: 24) {
            QuickActionsBar(
                onAddExpense: { print("Add Expense") },
                onAddIncome: { print("Add Income") },
                onTransfer: { print("Transfer") },
                onScanReceipt: { print("Scan") }
            )

            QuickStatsRow(stats: [
                QuickStat(title: "This Week", value: "₹4,500", icon: "calendar", color: .blue, trend: 12),
                QuickStat(title: "Avg/Day", value: "₹642", icon: "chart.line.uptrend.xyaxis", color: .purple, trend: -8),
                QuickStat(title: "Savings", value: "₹15K", icon: "banknote", color: .green, trend: 5)
            ])
        }
        .padding()
    }
}
