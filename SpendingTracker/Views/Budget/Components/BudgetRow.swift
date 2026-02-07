//
//  BudgetRow.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Budget Row (iOS 26 Stable)

/// A row displaying budget information with progress indicator
struct BudgetRow: View {

    // MARK: - Properties

    let budget: Budget
    let spent: Decimal
    let progress: Double
    let progressColor: Color
    let dailyAllowance: Decimal
    let isExpired: Bool
    let categoryName: String?
    let categoryIcon: String?
    let categoryColor: Color?

    // MARK: - Computed Properties

    private var displayCategoryIcon: String {
        categoryIcon ?? "folder.fill"
    }

    private var displayCategoryName: String {
        categoryName ?? "General"
    }

    private var displayCategoryColor: Color {
        categoryColor ?? .blue
    }

    private var remaining: Decimal {
        budget.amount - spent
    }

    private var isOverBudget: Bool {
        progress >= 1.0
    }

    // MARK: - Body

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header Row
                headerRow

                // Progress Section
                progressSection

                // Footer Row
                footerRow
            }
            .padding()
        }
        .opacity(isExpired ? 0.7 : 1.0)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(displayCategoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: displayCategoryIcon)
                    .font(.title3)
                    .foregroundStyle(displayCategoryColor)
            }

            // Category & Budget Info
            VStack(alignment: .leading, spacing: 2) {
                Text(displayCategoryName)
                    .font(.headline)
                    .lineLimit(1)

                Text(budget.period.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount Column
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(spent))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isOverBudget ? .red : .primary)

                Text("of \(formatCurrency(budget.amount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Progress Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [progressColor, progressColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: min(geometry.size.width * min(progress, 1.0), geometry.size.width), height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                    // Over-budget indicator
                    if progress > 1.0 {
                        // Show overflow pattern
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 8)
                            .overlay(
                                HStack(spacing: 4) {
                                    ForEach(0..<Int(geometry.size.width / 12), id: \.self) { _ in
                                        Rectangle()
                                            .fill(.white.opacity(0.3))
                                            .frame(width: 2)
                                    }
                                }
                            )
                    }
                }
            }
            .frame(height: 8)

            // Progress Labels
            HStack {
                // Percentage
                HStack(spacing: 4) {
                    if isOverBudget {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }

                    Text("\(Int(progress * 100))% used")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(progressColor)
                }

                Spacer()

                // Remaining
                if !isExpired {
                    if remaining >= 0 {
                        Text("\(formatCurrency(remaining)) remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(formatCurrency(abs(remaining))) over budget")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    // MARK: - Footer Row

    private var footerRow: some View {
        HStack(spacing: 16) {
            // Days Remaining
            if !isExpired {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(budget.daysRemaining) days left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Text("Expired")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Daily Allowance (only for active budgets)
            if !isExpired && dailyAllowance > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.day.timeline.left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(formatCurrency(dailyAllowance))/day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Period Icon
            Image(systemName: budget.period.icon)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }
}

// MARK: - Compact Budget Row

/// A more compact version of the budget row for use in summaries
struct CompactBudgetRow: View {
    let budget: Budget
    let spent: Decimal
    let progress: Double
    let progressColor: Color
    let categoryName: String?
    let categoryIcon: String?
    let categoryColor: Color?

    private var displayCategoryIcon: String {
        categoryIcon ?? "folder.fill"
    }

    private var displayCategoryName: String {
        categoryName ?? "General"
    }

    private var displayCategoryColor: Color {
        categoryColor ?? .blue
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: displayCategoryIcon)
                .font(.subheadline)
                .foregroundStyle(displayCategoryColor)
                .frame(width: 32, height: 32)
                .background(displayCategoryColor.opacity(0.1))
                .clipShape(Circle())

            // Name
            Text(displayCategoryName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                    .frame(width: 28, height: 28)

                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress * 100))")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Budget Alert Row

/// A row for displaying budget alerts
struct BudgetAlertRow: View {
    let budget: Budget
    let progress: Double
    let message: String

    private var alertColor: Color {
        progress >= 1.0 ? .red : .orange
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: progress >= 1.0 ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(alertColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Budget Alert")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(progress * 100))%")
                .font(.headline)
                .foregroundStyle(alertColor)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(alertColor.opacity(0.1))
        }
    }
}

// MARK: - Preview

#Preview("Budget Row") {
    VStack(spacing: 16) {
        // Normal budget
        BudgetRow(
            budget: .preview,
            spent: 3500,
            progress: 0.35,
            progressColor: .green,
            dailyAllowance: 200,
            isExpired: false,
            categoryName: "Groceries",
            categoryIcon: "cart.fill",
            categoryColor: .orange
        )

        // Warning budget
        BudgetRow(
            budget: .preview,
            spent: 8500,
            progress: 0.85,
            progressColor: .orange,
            dailyAllowance: 50,
            isExpired: false,
            categoryName: "Entertainment",
            categoryIcon: "film.fill",
            categoryColor: .purple
        )

        // Over budget
        BudgetRow(
            budget: .preview,
            spent: 12000,
            progress: 1.2,
            progressColor: .red,
            dailyAllowance: 0,
            isExpired: false,
            categoryName: "Travel",
            categoryIcon: "car.fill",
            categoryColor: .blue
        )

        // Expired
        BudgetRow(
            budget: .preview,
            spent: 7500,
            progress: 0.75,
            progressColor: .yellow,
            dailyAllowance: 0,
            isExpired: true,
            categoryName: "Dining",
            categoryIcon: "fork.knife",
            categoryColor: .red
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

// MARK: - Budget Preview Extension

extension Budget {
    static var preview: Budget {
        Budget(
            amount: 10000,
            period: .monthly,
            startDate: Date(),
            alertThreshold: 0.8,
            isActive: true,
            categoryId: nil
        )
    }
}
