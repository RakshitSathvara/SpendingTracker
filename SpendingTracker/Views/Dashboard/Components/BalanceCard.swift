//
//  BalanceCard.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Balance Card (iOS 26 Stable)

/// A beautiful balance card with animated amount transitions
struct BalanceCard: View {
    let total: Decimal
    let income: Decimal
    let expense: Decimal
    let incomeTrend: SpendingTrend
    let expenseTrend: SpendingTrend

    @Environment(\.colorScheme) private var colorScheme

    init(
        total: Decimal,
        income: Decimal,
        expense: Decimal,
        incomeTrend: SpendingTrend = .stable,
        expenseTrend: SpendingTrend = .stable
    ) {
        self.total = total
        self.income = income
        self.expense = expense
        self.incomeTrend = incomeTrend
        self.expenseTrend = expenseTrend
    }

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Main Amount with animated transition
            Text(total, format: .currency(code: "INR"))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: total)

            // Income and Expense Summary
            HStack(spacing: 24) {
                // Income
                incomeSection

                // Divider
                Divider()
                    .frame(height: 44)

                // Expense
                expenseSection
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background {
            glassBackground
        }
    }

    // MARK: - Income Section

    private var incomeSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: income)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Trend indicator
                    if case .up(let pct) = incomeTrend {
                        trendBadge(icon: "arrow.up.right", text: "+\(Int(pct))%", color: .green)
                    } else if case .down(let pct) = incomeTrend {
                        trendBadge(icon: "arrow.down.right", text: "-\(Int(pct))%", color: .red)
                    }
                }

                Text(income, format: .currency(code: "INR"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: income)
            }
        }
    }

    // MARK: - Expense Section

    private var expenseSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)
                .symbolEffect(.bounce, value: expense)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Expense")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Trend indicator
                    if case .up(let pct) = expenseTrend {
                        trendBadge(icon: "arrow.up.right", text: "+\(Int(pct))%", color: .red)
                    } else if case .down(let pct) = expenseTrend {
                        trendBadge(icon: "arrow.down.right", text: "-\(Int(pct))%", color: .green)
                    }
                }

                Text(expense, format: .currency(code: "INR"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
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
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
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

// MARK: - Compact Balance Card

/// A smaller version of the balance card for constrained spaces
struct CompactBalanceCard: View {
    let balance: Decimal
    let trend: SpendingTrend

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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Balance Card") {
    ZStack {
        AdaptiveBackground(style: .primary)

        VStack(spacing: 20) {
            BalanceCard(
                total: 45230.50,
                income: 50000,
                expense: 4769.50,
                incomeTrend: .up(percentage: 15.5),
                expenseTrend: .down(percentage: 8.2)
            )

            CompactBalanceCard(
                balance: 45230.50,
                trend: .up(percentage: 12.3)
            )
        }
        .padding()
    }
}
