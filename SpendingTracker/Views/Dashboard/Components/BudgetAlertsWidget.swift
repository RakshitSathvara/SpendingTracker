//
//  BudgetAlertsWidget.swift
//  SpendingTracker
//
//  Budget progress and alert widget for dashboard
//  Best Practice: Show contextual warnings for important information
//

import SwiftUI

// MARK: - Budget Alerts Widget (2026 Modern UI)

/// Widget showing budget progress with visual alerts
struct BudgetAlertsWidget: View {
    let budgets: [BudgetProgress]
    let onBudgetTap: ((BudgetProgress) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    init(budgets: [BudgetProgress], onBudgetTap: ((BudgetProgress) -> Void)? = nil) {
        self.budgets = budgets
        self.onBudgetTap = onBudgetTap
    }

    // Filter to show only budgets that need attention (>70% used)
    private var alertBudgets: [BudgetProgress] {
        budgets.filter { $0.percentage >= 70 }.sorted { $0.percentage > $1.percentage }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)

                Text("Budget Status")
                    .font(.headline)

                Spacer()

                if !alertBudgets.isEmpty {
                    alertCountBadge
                }
            }

            if budgets.isEmpty {
                emptyState
            } else if alertBudgets.isEmpty {
                allGoodState
            } else {
                // Budget Progress Items
                VStack(spacing: 10) {
                    ForEach(alertBudgets.prefix(3)) { budget in
                        BudgetProgressRow(budget: budget)
                            .onTapGesture {
                                onBudgetTap?(budget)
                            }
                    }
                }
            }
        }
        .padding(16)
        .background {
            glassBackground
        }
    }

    // MARK: - Alert Count Badge

    private var alertCountBadge: some View {
        let warningCount = alertBudgets.filter { $0.percentage >= 90 }.count

        return Group {
            if warningCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("\(warningCount)")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.gradient)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.dashed")
                .font(.title2)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("No budgets set")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Create budgets to track your spending limits")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - All Good State

    private var allGoodState: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("All budgets on track! 🎉")
                    .font(.subheadline.weight(.medium))

                Text("Keep up the good spending habits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ThemeColors.cardBackground)
                    .shadow(color: ThemeColors.cardShadow(for: colorScheme), radius: 2, x: 0, y: 1)
            }
        }
    }
}

// MARK: - Budget Progress Row

struct BudgetProgressRow: View {
    let budget: BudgetProgress

    @Environment(\.colorScheme) private var colorScheme
    @State private var animateProgress = false

    private var statusColor: Color {
        if budget.percentage >= 100 {
            return .red
        } else if budget.percentage >= 90 {
            return .orange
        } else if budget.percentage >= 70 {
            return .yellow
        } else {
            return .green
        }
    }

    private var statusIcon: String {
        if budget.percentage >= 100 {
            return "exclamationmark.circle.fill"
        } else if budget.percentage >= 90 {
            return "exclamationmark.triangle.fill"
        } else {
            return "clock.fill"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // Category Icon
                ZStack {
                    Circle()
                        .fill(budget.categoryColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: budget.categoryIcon)
                        .font(.caption)
                        .foregroundStyle(budget.categoryColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.categoryName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(budget.spent, format: .currency(code: "INR"))
                            .font(.caption)
                            .foregroundStyle(.primary)

                        Text("/")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(budget.limit, format: .currency(code: "INR"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Status Badge
                HStack(spacing: 3) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10))

                    Text("\(Int(budget.percentage))%")
                        .font(.caption.bold())
                }
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05))

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(statusColor.gradient)
                        .frame(width: animateProgress ? min(geometry.size.width * (budget.percentage / 100), geometry.size.width) : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateProgress)
                }
            }
            .frame(height: 6)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    animateProgress = true
                }
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(statusColor.opacity(colorScheme == .dark ? 0.1 : 0.05))
        }
    }
}

// MARK: - Budget Progress Model

struct BudgetProgress: Identifiable {
    let id: String
    let categoryName: String
    let categoryIcon: String
    let categoryColor: Color
    let spent: Decimal
    let limit: Decimal

    var percentage: CGFloat {
        guard limit > 0 else { return 0 }
        return CGFloat((spent as NSDecimalNumber).doubleValue / (limit as NSDecimalNumber).doubleValue * 100)
    }

    var remaining: Decimal {
        max(limit - spent, 0)
    }

    init(id: String = UUID().uuidString, categoryName: String, categoryIcon: String, categoryColor: Color, spent: Decimal, limit: Decimal) {
        self.id = id
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColor = categoryColor
        self.spent = spent
        self.limit = limit
    }
}

// MARK: - Preview

#Preview("Budget Alerts Widget") {
    let sampleBudgets = [
        BudgetProgress(categoryName: "Food & Dining", categoryIcon: "fork.knife", categoryColor: .orange, spent: 4800, limit: 5000),
        BudgetProgress(categoryName: "Entertainment", categoryIcon: "tv.fill", categoryColor: .purple, spent: 2800, limit: 3000),
        BudgetProgress(categoryName: "Shopping", categoryIcon: "bag.fill", categoryColor: .pink, spent: 1500, limit: 2000),
        BudgetProgress(categoryName: "Transport", categoryIcon: "car.fill", categoryColor: .blue, spent: 800, limit: 2000)
    ]

    ZStack {
        AdaptiveBackground(style: .primary)

        ScrollView {
            VStack(spacing: 20) {
                BudgetAlertsWidget(budgets: sampleBudgets)

                BudgetAlertsWidget(budgets: [])

                // All good state (no warnings)
                BudgetAlertsWidget(budgets: [
                    BudgetProgress(categoryName: "Food", categoryIcon: "fork.knife", categoryColor: .orange, spent: 1000, limit: 5000)
                ])
            }
            .padding()
        }
    }
}
