//
//  TransactionRow.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

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
        return transaction.isExpense ? .red : .green
    }

    private var categoryIconName: String {
        return transaction.isExpense ? "arrow.up.circle" : "arrow.down.circle"
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let typeText = transaction.isExpense ? "Expense" : "Income"
        let amountText = transaction.formattedAmount
        let dateText = transaction.formattedDate

        var label = "\(typeText) of \(amountText)"

        if !transaction.note.isEmpty {
            label += ", note: \(transaction.note)"
        }

        label += ", on \(dateText)"

        return label
    }
}

// MARK: - Transaction Card (Modern Glass Design)

/// A beautiful card-style transaction display with glass morphism
struct TransactionCard: View {
    let transaction: Transaction
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Category Icon with Glow Effect
                categoryIconView

                // Transaction Details
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(transaction.displayTitle)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Note (if available)
                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Date Row
                    HStack(spacing: 6) {
                        // Date
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(formattedDate)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Amount with Badge Style
                amountView
            }
            .padding(16)
        }
        .background {
            // Glass Card Background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.5),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: transaction.isExpense
                        ? Color.red.opacity(0.08)
                        : Color.green.opacity(0.08),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            if let onEdit = onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Category Icon View

    private var categoryIconView: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 52, height: 52)
                .blur(radius: 4)

            // Main icon circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            categoryColor,
                            categoryColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: categoryIconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: categoryColor.opacity(0.4), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Amount View

    private var amountView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            // Amount with sign
            HStack(spacing: 2) {
                Text(transaction.isExpense ? "-" : "+")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))

                Text(formattedAmountWithoutSign)
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .foregroundStyle(transaction.isExpense ? .red : .green)

            // Type badge
            Text(transaction.isExpense ? "EXPENSE" : "INCOME")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(transaction.isExpense ? .red.opacity(0.7) : .green.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    Capsule()
                        .fill(transaction.isExpense ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                }
        }
    }

    // MARK: - Computed Properties

    private var categoryColor: Color {
        return transaction.isExpense ? .red : .green
    }

    private var categoryIconName: String {
        return transaction.isExpense ? "arrow.up.circle" : "arrow.down.circle"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(transaction.date) {
            formatter.dateFormat = "'Today,' h:mm a"
        } else if calendar.isDateInYesterday(transaction.date) {
            formatter.dateFormat = "'Yesterday,' h:mm a"
        } else if calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d, h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }

        return formatter.string(from: transaction.date)
    }

    private var formattedAmountWithoutSign: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: transaction.amount as NSDecimalNumber) ?? "\(transaction.amount)"
    }

    private var accessibilityLabel: String {
        let typeText = transaction.isExpense ? "Expense" : "Income"
        let amountText = transaction.formattedAmount
        let dateText = transaction.formattedDate

        var label = "\(typeText) of \(amountText)"

        if !transaction.note.isEmpty {
            label += ", note: \(transaction.note)"
        }

        label += ", on \(dateText)"

        return label
    }
}

// MARK: - Transaction Card for Firestore Data

/// A clean card-style transaction display for Transaction from Firebase
/// Matches the settings card design with column layout for full details
struct TransactionCardDTO: View {
    let transaction: Transaction
    let categoryName: String?
    let categoryIcon: String?
    let categoryColor: Color?
    let accountName: String?
    let accountIcon: String?
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var iconColor: Color {
        categoryColor ?? (transaction.isExpense ? .red : .green)
    }

    var body: some View {
        GlassCard(cornerRadius: 16, padding: 0) {
            HStack(spacing: 12) {
                // Category Icon (Settings style - solid gradient circle)
                Image(systemName: categoryIcon ?? (transaction.isExpense ? "arrow.up.circle" : "arrow.down.circle"))
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(iconColor.gradient)
                    .clipShape(Circle())

                // Transaction Details (Column layout for full visibility)
                VStack(alignment: .leading, spacing: 6) {
                    // Title - Category or Note
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    // Note (if different from title and not empty)
                    if !transaction.note.isEmpty && transaction.note != displayTitle {
                        Text(transaction.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    // Details in column format
                    VStack(alignment: .leading, spacing: 4) {
                        // Date Row
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formattedDateFull)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Category Row
                        if let categoryName = categoryName, !categoryName.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .font(.caption2)
                                    .foregroundStyle(iconColor.opacity(0.7))
                                Text(categoryName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Account Row
                        if let accountName = accountName, !accountName.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: accountIcon ?? "building.columns.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(accountName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                // Amount (Right side)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.formattedAmount)
                        .font(.headline)
                        .foregroundColor(transaction.isExpense ? .red : .green)

                    Text(transaction.isExpense ? "Expense" : "Income")
                        .font(.caption2)
                        .foregroundStyle(transaction.isExpense ? .red.opacity(0.7) : .green.opacity(0.7))
                }
            }
            .padding()
        }
        .contentShape(Rectangle())
        .contextMenu {
            if let onEdit = onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var displayTitle: String {
        // Prefer note if it's meaningful, otherwise use category name
        if !transaction.note.isEmpty {
            return transaction.note
        }
        if let name = categoryName, !name.isEmpty {
            return name
        }
        return transaction.isExpense ? "Expense" : "Income"
    }

    private var formattedDateFull: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(transaction.date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInYesterday(transaction.date) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else if calendar.isDate(transaction.date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        } else {
            formatter.dateFormat = "EEEE, MMM d, yyyy 'at' h:mm a"
        }

        return formatter.string(from: transaction.date)
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

// MARK: - Transaction Card Skeleton

/// Modern loading skeleton for transaction card
struct TransactionCardSkeleton: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            // Icon skeleton with glow effect
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .blur(radius: 4)

                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 48, height: 48)
            }

            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 140, height: 18)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 14)

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 12)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 50, height: 12)
                }
            }

            Spacer()

            // Amount skeleton
            VStack(alignment: .trailing, spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 85, height: 22)

                Capsule()
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 60, height: 16)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                }
        }
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
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
                categoryId: "food-dining"
            )
        )

        // Sample income transaction
        TransactionRow(
            transaction: Transaction(
                amount: 3500.00,
                note: "Monthly salary",
                date: Date(),
                type: .income,
                categoryId: "salary"
            )
        )

        // Transaction without note
        TransactionRow(
            transaction: Transaction(
                amount: 25.00,
                date: Date(),
                type: .expense,
                categoryId: "transportation"
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
                    categoryId: "food-dining"
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
                    categoryId: "salary"
                )
            ) {
                print("Tapped")
            }
        }
        .padding()
    }
}

#Preview("Transaction Cards") {
    ZStack {
        AdaptiveBackground(style: .primary)

        ScrollView {
            VStack(spacing: 12) {
                // Expense card
                TransactionCard(
                    transaction: Transaction(
                        amount: 45.99,
                        note: "Lunch with team at downtown restaurant",
                        date: Date(),
                        type: .expense,
                        merchantName: "Restaurant",
                        categoryId: "food-dining",
                        accountId: "chase-bank"
                    ),
                    onEdit: { print("Edit") },
                    onDelete: { print("Delete") }
                )

                // Income card
                TransactionCard(
                    transaction: Transaction(
                        amount: 3500.00,
                        note: "Monthly salary deposit",
                        date: Date().addingTimeInterval(-86400),
                        type: .income,
                        categoryId: "salary",
                        accountId: "savings"
                    ),
                    onEdit: { print("Edit") },
                    onDelete: { print("Delete") }
                )

                // Card without note
                TransactionCard(
                    transaction: Transaction(
                        amount: 25.00,
                        date: Date().addingTimeInterval(-172800),
                        type: .expense,
                        categoryId: "transportation"
                    )
                )

                // Card skeleton
                TransactionCardSkeleton()
            }
            .padding()
        }
    }
}
