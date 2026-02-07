//
//  DashboardViewModel.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import Observation
import SwiftUI

// MARK: - Dashboard ViewModel (iOS 26 @Observable)

/// ViewModel for managing dashboard data and computations
@Observable
final class DashboardViewModel {

    // MARK: - Published Properties

    /// Currently selected time period
    var selectedPeriod: TimePeriod = .week

    /// Loading state for async operations
    private(set) var isLoading = false

    /// Whether data has been loaded at least once
    private(set) var hasLoadedOnce = false

    /// Error message if operation fails
    private(set) var errorMessage: String?

    /// All transactions (cached for computations)
    private(set) var allTransactions: [Transaction] = []

    /// All categories (cached for lookups)
    private(set) var categories: [Category] = []

    /// All budgets (cached for computations)
    private(set) var budgets: [Budget] = []

    // MARK: - Dependencies

    private let transactionRepo = TransactionRepository()
    private let categoryRepo = CategoryRepository()
    private let budgetRepo = BudgetRepository()

    // MARK: - Initialization

    init() {
        // Don't call loadIfNeeded here as it's async
    }

    // MARK: - Computed Properties for Transactions

    /// Transactions filtered by the selected time period
    var filteredTransactions: [Transaction] {
        let startDate = selectedPeriod.startDate
        return allTransactions.filter { $0.date >= startDate }
    }

    /// Recent transactions (last 5)
    var recentTransactions: [Transaction] {
        Array(allTransactions.prefix(5))
    }

    // MARK: - Balance Calculations

    /// Total balance (all time income - expenses)
    var totalBalance: Decimal {
        let income = allTransactions
            .filter { $0.isIncome }
            .reduce(Decimal.zero) { $0 + $1.amount }

        let expenses = allTransactions
            .filter { $0.isExpense }
            .reduce(Decimal.zero) { $0 + $1.amount }

        return income - expenses
    }

    /// Total income for the selected period
    var totalIncome: Decimal {
        filteredTransactions
            .filter { $0.isIncome }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Total expense for the selected period
    var totalExpense: Decimal {
        filteredTransactions
            .filter { $0.isExpense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Net for the selected period
    var periodNet: Decimal {
        totalIncome - totalExpense
    }

    // MARK: - Category Spending

    /// Spending by category for the selected period
    var categorySpending: [CategorySpending] {
        categorySpending(for: selectedPeriod)
    }

    /// Get spending breakdown by category for a specific period
    func categorySpending(for period: TimePeriod) -> [CategorySpending] {
        let startDate = period.startDate

        // Get expense transactions in the period
        let expenses = allTransactions.filter {
            $0.isExpense && $0.date >= startDate
        }

        // Group by category
        var categoryTotals: [String: (categoryId: String, category: Category?, amount: Decimal, count: Int)] = [:]

        for transaction in expenses {
            guard let categoryId = transaction.categoryId else { continue }

            let category = categories.first { $0.id == categoryId }

            if let existing = categoryTotals[categoryId] {
                categoryTotals[categoryId] = (categoryId, category, existing.amount + transaction.amount, existing.count + 1)
            } else {
                categoryTotals[categoryId] = (categoryId, category, transaction.amount, 1)
            }
        }

        // Calculate total for percentages
        let total = categoryTotals.values.reduce(Decimal.zero) { $0 + $1.amount }

        // Convert to CategorySpending array
        let spending = categoryTotals.values.compactMap { item -> CategorySpending? in
            guard let category = item.category else { return nil }

            let percentage = total > 0 ? (NSDecimalNumber(decimal: item.amount / total).doubleValue * 100) : 0

            return CategorySpending(
                id: item.categoryId,
                category: SpendingCategory(from: category),
                amount: item.amount,
                transactionCount: item.count,
                percentage: percentage
            )
        }

        // Sort by amount (highest first)
        return spending.sorted { $0.amount > $1.amount }
    }

    /// Top 5 spending categories
    var topSpendingCategories: [CategorySpending] {
        Array(categorySpending.prefix(5))
    }

    // MARK: - Trend Calculations

    /// Calculate expense trend compared to previous period
    var expenseTrend: SpendingTrend {
        let currentExpense = totalExpense
        let previousExpense = previousPeriodExpense

        guard previousExpense > 0 else { return .stable }

        let change = ((currentExpense - previousExpense) / previousExpense) * 100
        let changeValue = NSDecimalNumber(decimal: change).doubleValue

        if abs(changeValue) < 1 {
            return .stable
        } else if changeValue > 0 {
            return .up(percentage: changeValue)
        } else {
            return .down(percentage: abs(changeValue))
        }
    }

    /// Calculate income trend compared to previous period
    var incomeTrend: SpendingTrend {
        let currentIncome = totalIncome
        let previousIncome = previousPeriodIncome

        guard previousIncome > 0 else { return .stable }

        let change = ((currentIncome - previousIncome) / previousIncome) * 100
        let changeValue = NSDecimalNumber(decimal: change).doubleValue

        if abs(changeValue) < 1 {
            return .stable
        } else if changeValue > 0 {
            return .up(percentage: changeValue)
        } else {
            return .down(percentage: abs(changeValue))
        }
    }

    /// Previous period expense (for trend calculation)
    private var previousPeriodExpense: Decimal {
        let (start, end) = previousPeriodDates
        return allTransactions
            .filter { $0.isExpense && $0.date >= start && $0.date < end }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Previous period income (for trend calculation)
    private var previousPeriodIncome: Decimal {
        let (start, end) = previousPeriodDates
        return allTransactions
            .filter { $0.isIncome && $0.date >= start && $0.date < end }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Get the date range for the previous period
    private var previousPeriodDates: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .week:
            let end = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            let start = calendar.date(byAdding: .day, value: -14, to: now) ?? now
            return (start, end)
        case .month:
            let end = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let start = calendar.date(byAdding: .month, value: -2, to: now) ?? now
            return (start, end)
        case .year:
            let end = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            let start = calendar.date(byAdding: .year, value: -2, to: now) ?? now
            return (start, end)
        }
    }

    // MARK: - Summary

    /// Complete dashboard summary
    var summary: DashboardSummary {
        DashboardSummary(
            totalBalance: totalBalance,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            expenseTrend: expenseTrend,
            incomeTrend: incomeTrend,
            topCategory: categorySpending.first
        )
    }

    // MARK: - Actions

    /// Refresh dashboard data from Firestore
    @MainActor
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            async let transactionsTask = transactionRepo.fetchAllTransactions()
            async let categoriesTask = categoryRepo.fetchCategories()
            async let budgetsTask = budgetRepo.fetchBudgets()

            allTransactions = try await transactionsTask
            categories = try await categoriesTask
            budgets = try await budgetsTask

            isLoading = false
            hasLoadedOnce = true
        } catch {
            isLoading = false
            errorMessage = "Failed to refresh data: \(error.localizedDescription)"
        }
    }

    /// Initial load
    @MainActor
    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await refresh()
    }

    // MARK: - Formatting Helpers

    /// Format currency amount
    func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }

    /// Format currency amount without decimals
    func formatCurrencyCompact(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }
}
