//
//  TransactionRow.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Transaction Row (iOS 26 Stable)

/// A single transaction row with category icon, details, and amount
struct TransactionRow: View {
    let transaction: Transaction

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            categoryIcon

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Time stamp
                Text(transaction.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Amount
            Text(transaction.formattedAmount)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(transaction.isExpense ? .red : .green)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view details")
    }

    // MARK: - Category Icon

    private var categoryIcon: some View {
        Circle()
            .fill(categoryColor.gradient)
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: categoryIconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: categoryColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private var categoryColor: Color {
        if let category = transaction.category {
            return category.color
        }
        return transaction.isExpense ? .red : .green
    }

    private var categoryIconName: String {
        if let category = transaction.category {
            return category.icon
        }
        return transaction.isExpense ? "arrow.up.circle" : "arrow.down.circle"
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let typeText = transaction.isExpense ? "Expense" : "Income"
        let categoryText = transaction.category?.name ?? "Uncategorized"
        let amountText = transaction.formattedAmount
        let dateText = transaction.formattedDate

        var label = "\(typeText) of \(amountText) for \(categoryText)"

        if !transaction.note.isEmpty {
            label += ", note: \(transaction.note)"
        }

        label += ", on \(dateText)"

        return label
    }
}

// MARK: - Transaction Row with Glass Background

/// Transaction row wrapped in a glass card for standalone use
struct GlassTransactionRow: View {
    let transaction: Transaction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TransactionRow(transaction: transaction)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    GlassBackground(cornerRadius: 12)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transaction Skeleton Row

/// Loading skeleton for transaction row
struct TransactionRowSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon skeleton
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 44)

            // Content skeleton
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 12)
            }

            Spacer()

            // Amount skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 70, height: 18)
        }
        .padding(.vertical, 4)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview("Transaction Row") {
    List {
        // Sample expense transaction
        TransactionRow(
            transaction: Transaction(
                amount: 45.99,
                note: "Lunch with team",
                date: Date(),
                type: .expense,
                merchantName: "Restaurant",
                category: Category(
                    name: "Food & Dining",
                    icon: "fork.knife",
                    colorHex: "#FF9500"
                )
            )
        )

        // Sample income transaction
        TransactionRow(
            transaction: Transaction(
                amount: 3500.00,
                note: "Monthly salary",
                date: Date(),
                type: .income,
                category: Category(
                    name: "Salary",
                    icon: "briefcase.fill",
                    colorHex: "#34C759",
                    isExpenseCategory: false
                )
            )
        )

        // Transaction without note
        TransactionRow(
            transaction: Transaction(
                amount: 25.00,
                date: Date(),
                type: .expense,
                category: Category(
                    name: "Transportation",
                    icon: "car.fill",
                    colorHex: "#007AFF"
                )
            )
        )

        // Skeleton
        TransactionRowSkeleton()
    }
}

#Preview("Glass Transaction Row") {
    ZStack {
        AdaptiveBackground(style: .primary)

        VStack(spacing: 12) {
            GlassTransactionRow(
                transaction: Transaction(
                    amount: 45.99,
                    note: "Lunch with team",
                    date: Date(),
                    type: .expense,
                    category: Category(
                        name: "Food & Dining",
                        icon: "fork.knife",
                        colorHex: "#FF9500"
                    )
                )
            ) {
                print("Tapped")
            }

            GlassTransactionRow(
                transaction: Transaction(
                    amount: 3500.00,
                    note: "Monthly salary",
                    date: Date(),
                    type: .income,
                    category: Category(
                        name: "Salary",
                        icon: "briefcase.fill",
                        colorHex: "#34C759",
                        isExpenseCategory: false
                    )
                )
            ) {
                print("Tapped")
            }
        }
        .padding()
    }
}
