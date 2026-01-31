//
//  DashboardModels.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftUI

// MARK: - Time Period Enum

/// Time periods for filtering dashboard data
enum TimePeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        case .year: return "calendar.badge.checkmark"
        }
    }

    /// Returns the start date for this period
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }

    /// Display title for the period
    var displayTitle: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }
}

// MARK: - Category Spending Model

/// Model representing spending data for a category (used in charts)
struct CategorySpending: Identifiable, Equatable {
    let id: String
    let category: SpendingCategory
    let amount: Decimal
    let transactionCount: Int
    let percentage: Double

    init(id: String = UUID().uuidString, category: SpendingCategory, amount: Decimal, transactionCount: Int, percentage: Double = 0) {
        self.id = id
        self.category = category
        self.amount = amount
        self.transactionCount = transactionCount
        self.percentage = percentage
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }

    var formattedPercentage: String {
        String(format: "%.1f%%", percentage)
    }

    static func == (lhs: CategorySpending, rhs: CategorySpending) -> Bool {
        lhs.id == rhs.id && lhs.amount == rhs.amount
    }
}

/// Lightweight category representation for charts
struct SpendingCategory: Equatable {
    let name: String
    let icon: String
    let colorHex: String

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    init(from category: Category) {
        self.name = category.name
        self.icon = category.icon
        self.colorHex = category.colorHex
    }
}

// MARK: - Spending Trend

/// Represents spending trend compared to previous period
enum SpendingTrend {
    case up(percentage: Double)
    case down(percentage: Double)
    case stable

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .up: return .red
        case .down: return .green
        case .stable: return .secondary
        }
    }

    var description: String {
        switch self {
        case .up(let percentage):
            return "+\(String(format: "%.1f", percentage))%"
        case .down(let percentage):
            return "-\(String(format: "%.1f", percentage))%"
        case .stable:
            return "0%"
        }
    }
}

// MARK: - Dashboard Summary

/// Summary data for the dashboard
struct DashboardSummary {
    let totalBalance: Decimal
    let totalIncome: Decimal
    let totalExpense: Decimal
    let expenseTrend: SpendingTrend
    let incomeTrend: SpendingTrend
    let topCategory: CategorySpending?

    var formattedBalance: String {
        formatCurrency(totalBalance)
    }

    var formattedIncome: String {
        formatCurrency(totalIncome)
    }

    var formattedExpense: String {
        formatCurrency(totalExpense)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }

    static var empty: DashboardSummary {
        DashboardSummary(
            totalBalance: 0,
            totalIncome: 0,
            totalExpense: 0,
            expenseTrend: .stable,
            incomeTrend: .stable,
            topCategory: nil
        )
    }
}

// MARK: - Quick Action Type

/// Quick action types for the dashboard
enum QuickActionType: String, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"
    case transfer = "Transfer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .expense: return "arrow.down.circle"
        case .income: return "arrow.up.circle"
        case .transfer: return "arrow.left.arrow.right.circle"
        }
    }

    var filledIcon: String {
        switch self {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .blue
        }
    }
}
