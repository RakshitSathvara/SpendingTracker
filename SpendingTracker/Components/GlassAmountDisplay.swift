//
//  GlassAmountDisplay.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Glass Amount Display (iOS 26 Stable)

/// A large currency display with glass effect and animated number transitions
struct GlassAmountDisplay: View {
    let amount: Decimal
    let isExpense: Bool
    let currencyCode: String
    let showSign: Bool
    let size: AmountDisplaySize

    init(
        amount: Decimal,
        isExpense: Bool = true,
        currencyCode: String = "INR",
        showSign: Bool = true,
        size: AmountDisplaySize = .large
    ) {
        self.amount = amount
        self.isExpense = isExpense
        self.currencyCode = currencyCode
        self.showSign = showSign
        self.size = size
    }

    private var tintColor: Color {
        isExpense ? .red : .green
    }

    private var signSymbol: String {
        isExpense ? "-" : "+"
    }

    var body: some View {
        HStack(spacing: 4) {
            if showSign {
                Text(signSymbol)
                    .foregroundStyle(tintColor)
            }
            Text(amount, format: .currency(code: currencyCode))
                .contentTransition(.numericText()) // iOS 26 animated number transition
        }
        .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
        .foregroundStyle(tintColor)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(tintColor.opacity(0.1))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .strokeBorder(tintColor.opacity(0.2), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Amount Display Size

enum AmountDisplaySize {
    case small
    case medium
    case large
    case hero

    var fontSize: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 28
        case .large: return 40
        case .hero: return 56
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        case .hero: return 24
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 12
        case .large: return 16
        case .hero: return 20
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 12
        case .large: return 16
        case .hero: return 20
        }
    }
}

// MARK: - Glass Summary Card

/// A summary card showing total income and expenses
struct GlassSummaryCard: View {
    let income: Decimal
    let expenses: Decimal
    let currencyCode: String

    init(
        income: Decimal,
        expenses: Decimal,
        currencyCode: String = "INR"
    ) {
        self.income = income
        self.expenses = expenses
        self.currencyCode = currencyCode
    }

    private var balance: Decimal {
        income - expenses
    }

    var body: some View {
        VStack(spacing: 16) {
            // Balance
            VStack(spacing: 4) {
                Text("Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(balance, format: .currency(code: currencyCode))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(balance >= 0 ? .primary : .red)
                    .contentTransition(.numericText())
            }

            Divider()

            // Income & Expenses
            HStack(spacing: 24) {
                // Income
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                        Text("Income")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(income, format: .currency(code: currencyCode))
                        .font(.headline)
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)

                // Expenses
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.red)
                        Text("Expenses")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(expenses, format: .currency(code: currencyCode))
                        .font(.headline)
                        .foregroundStyle(.red)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Glass Stat Card

/// A compact stat display card
struct GlassStatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.05))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.1), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Preview

#Preview("Glass Amount Display") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {
                // Amount Display Sizes
                VStack(spacing: 16) {
                    Text("Amount Display Sizes")
                        .font(.headline)

                    GlassAmountDisplay(amount: 1250.50, isExpense: true, size: .small)
                    GlassAmountDisplay(amount: 5000.00, isExpense: false, size: .medium)
                    GlassAmountDisplay(amount: 12500.75, isExpense: true, size: .large)
                    GlassAmountDisplay(amount: 100000.00, isExpense: false, size: .hero)
                }

                // Summary Card
                GlassSummaryCard(
                    income: 50000.00,
                    expenses: 32500.50
                )

                // Stat Cards
                HStack(spacing: 12) {
                    GlassStatCard(
                        title: "This Month",
                        value: "₹32,500",
                        icon: "calendar",
                        tint: .blue
                    )

                    GlassStatCard(
                        title: "Transactions",
                        value: "47",
                        icon: "list.bullet",
                        tint: .purple
                    )
                }
            }
            .padding()
        }
    }
}
