//
//  RecentTransactionsSection.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Recent Transactions Section (iOS 26 Stable)

/// A section displaying recent transactions with glass styling
struct RecentTransactionsSection: View {
    let transactions: [Transaction]
    let maxCount: Int
    let onSeeAll: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    init(
        transactions: [Transaction],
        maxCount: Int = 5,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.transactions = transactions
        self.maxCount = maxCount
        self.onSeeAll = onSeeAll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView

            // Content
            if transactions.isEmpty {
                emptyStateView
            } else {
                transactionsList
            }
        }
        .padding(20)
        .background {
            glassBackground
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("Recent Transactions")
                .font(.headline)

            Spacer()

            if let onSeeAll = onSeeAll, !transactions.isEmpty {
                Button("See All") {
                    onSeeAll()
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(transactions.prefix(maxCount).enumerated()), id: \.element.id) { index, transaction in
                DashboardTransactionRow(transaction: transaction)

                if index < min(transactions.count, maxCount) - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("No transactions yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Add your first transaction to start tracking")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ThemeColors.cardBackground)
                    .shadow(color: ThemeColors.cardShadow(for: colorScheme), radius: 2, x: 0, y: 1)
            }
        }
    }
}

// MARK: - Dashboard Transaction Row

/// A transaction row optimized for the dashboard
struct DashboardTransactionRow: View {
    let transaction: Transaction

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            categoryIcon

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(transaction.note.isEmpty ? formattedDate : transaction.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 0) {
                    Text(transaction.isExpense ? "-" : "+")
                        .font(.subheadline.bold())
                        .foregroundStyle(transaction.isExpense ? .red : .green)

                    Text(transaction.amount, format: .currency(code: "INR"))
                        .font(.subheadline.bold())
                        .foregroundStyle(transaction.isExpense ? .red : .green)
                        .contentTransition(.numericText())
                }

                if !transaction.note.isEmpty {
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .onTapGesture {
            // Could navigate to detail view
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    // MARK: - Category Icon

    private var categoryIcon: some View {
        Image(systemName: transaction.isExpense ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
            .font(.body)
            .foregroundStyle(transaction.isExpense ? .red : .green)
            .frame(width: 40, height: 40)
            .background((transaction.isExpense ? Color.red : Color.green).opacity(0.15))
            .clipShape(Circle())
            .symbolEffect(.bounce, value: isPressed)
    }

    // MARK: - Formatted Date

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: transaction.date, relativeTo: Date())
    }
}

// MARK: - Compact Transaction Card

/// A compact card showing a single transaction
struct CompactTransactionCard: View {
    let transaction: Transaction

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: transaction.isExpense ? "arrow.up.circle" : "arrow.down.circle")
                .font(.title3)
                .foregroundStyle(transaction.isExpense ? .red : .green)

            // Title
            Text(transaction.displayTitle)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            // Amount
            Text(transaction.amount, format: .currency(code: "INR"))
                .font(.subheadline.bold())
                .foregroundStyle(transaction.isExpense ? .red : .green)
        }
        .padding(12)
        .background {
            GlassBackground(cornerRadius: 12)
        }
    }
}

// MARK: - Transaction Summary Row

/// A row showing transaction summary for a category
struct TransactionSummaryRow: View {
    let title: String
    let count: Int
    let amount: Decimal
    let icon: String
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Text("\(count) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount
            Text(amount, format: .currency(code: "INR"))
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .padding(12)
        .background {
            GlassBackground(cornerRadius: 12)
        }
    }
}

// MARK: - Preview

#Preview("Recent Transactions") {
    ZStack {
        AdaptiveBackground(style: .primary)

        ScrollView {
            VStack(spacing: 20) {
                // With transactions
                RecentTransactionsSection(
                    transactions: [],
                    onSeeAll: { print("See all") }
                )

                // Empty state
                RecentTransactionsSection(
                    transactions: []
                )
            }
            .padding()
        }
    }
}
