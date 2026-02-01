//
//  BalanceCard.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//  Enhanced with 2026 Modern Dashboard UI Best Practices
//

import SwiftUI

// MARK: - Balance Card (2026 Modern UI)

/// A beautiful balance card with animated amount transitions and visual hierarchy
struct BalanceCard: View {
    let total: Decimal
    let income: Decimal
    let expense: Decimal
    let incomeTrend: SpendingTrend
    let expenseTrend: SpendingTrend
    let savingsGoal: Decimal?
    let currentSavings: Decimal?

    @Environment(\.colorScheme) private var colorScheme
    @State private var animateRing = false

    init(
        total: Decimal,
        income: Decimal,
        expense: Decimal,
        incomeTrend: SpendingTrend = .stable,
        expenseTrend: SpendingTrend = .stable,
        savingsGoal: Decimal? = nil,
        currentSavings: Decimal? = nil
    ) {
        self.total = total
        self.income = income
        self.expense = expense
        self.incomeTrend = incomeTrend
        self.expenseTrend = expenseTrend
        self.savingsGoal = savingsGoal
        self.currentSavings = currentSavings
    }

    private var savingsProgress: CGFloat {
        guard let goal = savingsGoal, let current = currentSavings, goal > 0 else { return 0 }
        return min(CGFloat((current as NSDecimalNumber).doubleValue / (goal as NSDecimalNumber).doubleValue), 1.0)
    }

    private var netFlow: Decimal {
        income - expense
    }

    var body: some View {
        VStack(spacing: 20) {
            // Top Section: Balance with optional savings ring
            HStack(alignment: .center, spacing: 16) {
                // Main Balance Info
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(total, format: .currency(code: "INR"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: total)

                    // Net flow indicator
                    netFlowBadge
                }

                Spacer()

                // Savings Goal Ring (if set)
                if savingsGoal != nil && savingsGoal! > 0 {
                    savingsRing
                }
            }

            // Divider with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // Income and Expense Summary
            HStack(spacing: 0) {
                // Income
                incomeSection
                    .frame(maxWidth: .infinity)

                // Vertical Divider
                Rectangle()
                    .fill(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05))
                    .frame(width: 1, height: 50)

                // Expense
                expenseSection
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background {
            glassBackground
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animateRing = true
            }
        }
    }

    // MARK: - Net Flow Badge

    private var netFlowBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: netFlow >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))

            Text(netFlow >= 0 ? "+" : "")
                .font(.caption.bold()) +
            Text(netFlow, format: .currency(code: "INR"))
                .font(.caption.bold())

            Text("this period")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(netFlow >= 0 ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((netFlow >= 0 ? Color.green : Color.red).opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Savings Ring

    private var savingsRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.green.opacity(0.2), lineWidth: 6)

            // Progress ring
            Circle()
                .trim(from: 0, to: animateRing ? savingsProgress : 0)
                .stroke(
                    AngularGradient(
                        colors: [.green, .mint, .green],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 0) {
                Text("\(Int(savingsProgress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text("saved")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 60, height: 60)
    }

    // MARK: - Income Section

    private var incomeSection: some View {
        HStack(spacing: 10) {
            // Animated icon with glow effect
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: income)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Income")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    // Trend indicator
                    if case .up(let pct) = incomeTrend {
                        trendBadge(icon: "arrow.up.right", text: "+\(Int(pct))%", color: .green)
                    } else if case .down(let pct) = incomeTrend {
                        trendBadge(icon: "arrow.down.right", text: "-\(Int(pct))%", color: .red)
                    }
                }

                Text(income, format: .currency(code: "INR"))
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: income)
            }
        }
    }

    // MARK: - Expense Section

    private var expenseSection: some View {
        HStack(spacing: 10) {
            // Animated icon with glow effect
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                    .symbolEffect(.bounce, value: expense)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Expense")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    // Trend indicator
                    if case .up(let pct) = expenseTrend {
                        trendBadge(icon: "arrow.up.right", text: "+\(Int(pct))%", color: .red)
                    } else if case .down(let pct) = expenseTrend {
                        trendBadge(icon: "arrow.down.right", text: "-\(Int(pct))%", color: .green)
                    }
                }

                Text(expense, format: .currency(code: "INR"))
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: expense)
            }
        }
    }

    // MARK: - Helper Views

    private func trendBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var glassBackground: some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.2),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            } else {
                // iOS Settings-style solid white card
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(ThemeColors.cardBackground)
                    .shadow(color: ThemeColors.cardShadow(for: colorScheme), radius: 2, x: 0, y: 1)
            }
        }
    }
}

// MARK: - Compact Balance Card

/// A smaller version of the balance card for constrained spaces
struct CompactBalanceCard: View {
    let balance: Decimal
    let trend: SpendingTrend

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(balance, format: .currency(code: "INR"))
                    .font(.title2.bold())
                    .contentTransition(.numericText())
            }

            Spacer()

            // Trend indicator
            HStack(spacing: 4) {
                Image(systemName: trend.icon)
                Text(trend.description)
            }
            .font(.subheadline.bold())
            .foregroundStyle(trend.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(trend.color.opacity(0.15))
            .clipShape(Capsule())
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
}

// MARK: - Preview

#Preview("Balance Card") {
    ZStack {
        AdaptiveBackground(style: .primary)

        ScrollView {
            VStack(spacing: 20) {
                // With savings goal
                BalanceCard(
                    total: 45230.50,
                    income: 50000,
                    expense: 4769.50,
                    incomeTrend: .up(percentage: 15.5),
                    expenseTrend: .down(percentage: 8.2),
                    savingsGoal: 100000,
                    currentSavings: 45230.50
                )

                // Without savings goal
                BalanceCard(
                    total: 25000,
                    income: 30000,
                    expense: 5000,
                    incomeTrend: .stable,
                    expenseTrend: .up(percentage: 12)
                )

                CompactBalanceCard(
                    balance: 45230.50,
                    trend: .up(percentage: 12.3)
                )
            }
            .padding()
        }
    }
}
