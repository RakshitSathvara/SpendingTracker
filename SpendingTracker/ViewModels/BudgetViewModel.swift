//
//  BudgetViewModel.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - Budget ViewModel (iOS 26 @Observable)

/// ViewModel for managing budget operations and calculations
@Observable
final class BudgetViewModel {

    // MARK: - Published Properties

    /// All budgets
    private(set) var budgets: [Budget] = []

    /// All transactions (for spending calculations)
    private(set) var transactions: [Transaction] = []

    /// Loading state for async operations
    private(set) var isLoading = false

    /// Error message if operation fails
    private(set) var errorMessage: String?

    /// Success state for dismissing view
    private(set) var didSaveSuccessfully = false

    /// Recently added budget for undo functionality
    private(set) var lastAddedBudget: Budget?

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let syncService: SyncService

    // MARK: - Initialization

    init(modelContext: ModelContext, syncService: SyncService = .shared) {
        self.modelContext = modelContext
        self.syncService = syncService
        loadData()
    }

    // MARK: - Data Loading

    /// Load budgets and transactions from SwiftData
    func loadData() {
        loadBudgets()
        loadTransactions()
    }

    private func loadBudgets() {
        let descriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            budgets = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load budgets: \(error.localizedDescription)"
        }
    }

    private func loadTransactions() {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            transactions = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load transactions: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Properties

    /// Active budgets only
    var activeBudgets: [Budget] {
        budgets.filter { $0.isActive && !$0.isExpired }
    }

    /// Expired budgets
    var expiredBudgets: [Budget] {
        budgets.filter { $0.isExpired }
    }

    /// Budgets that are over threshold
    var alertBudgets: [Budget] {
        activeBudgets.filter { isOverThreshold(for: $0) }
    }

    /// Total budgeted amount across all active budgets
    var totalBudgetedAmount: Decimal {
        activeBudgets.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Total spent across all active budgets
    var totalSpentAmount: Decimal {
        activeBudgets.reduce(Decimal.zero) { $0 + spentAmount(for: $1) }
    }

    // MARK: - Spending Calculations

    /// Calculate spent amount for a specific budget
    func spentAmount(for budget: Budget) -> Decimal {
        transactions
            .filter { transaction in
                transaction.isExpense &&
                transaction.date >= budget.startDate &&
                transaction.date <= budget.endDate &&
                (budget.category == nil || transaction.category?.id == budget.category?.id)
            }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Calculate remaining amount for a budget
    func remainingAmount(for budget: Budget) -> Decimal {
        budget.amount - spentAmount(for: budget)
    }

    /// Calculate progress (0.0 to 1.0+) for a budget
    func progress(for budget: Budget) -> Double {
        let spent = spentAmount(for: budget)
        guard budget.amount > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / budget.amount).doubleValue
    }

    /// Check if budget is over threshold
    func isOverThreshold(for budget: Budget) -> Bool {
        progress(for: budget) >= budget.alertThreshold
    }

    /// Check if budget is exceeded
    func isOverBudget(for budget: Budget) -> Bool {
        progress(for: budget) >= 1.0
    }

    /// Get progress color for a budget
    func progressColor(for budget: Budget) -> Color {
        let prog = progress(for: budget)
        switch prog {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .yellow
        case 0.8..<1.0:
            return .orange
        default:
            return .red
        }
    }

    /// Calculate daily allowance for a budget
    func dailyAllowance(for budget: Budget) -> Decimal {
        guard budget.daysRemaining > 0 else { return 0 }
        let remaining = remainingAmount(for: budget)
        return remaining / Decimal(budget.daysRemaining)
    }

    /// Get transactions for a specific budget
    func transactions(for budget: Budget) -> [Transaction] {
        transactions
            .filter { transaction in
                transaction.isExpense &&
                transaction.date >= budget.startDate &&
                transaction.date <= budget.endDate &&
                (budget.category == nil || transaction.category?.id == budget.category?.id)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - CRUD Operations

    /// Add a new budget
    @MainActor
    func addBudget(
        amount: Decimal,
        period: BudgetPeriod,
        startDate: Date,
        alertThreshold: Double,
        category: Category?
    ) async {
        guard amount > 0 else {
            errorMessage = "Budget amount must be greater than zero"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let budget = Budget(
                amount: amount,
                period: period,
                startDate: startDate,
                alertThreshold: alertThreshold,
                isActive: true,
                category: category,
                isSynced: false,
                lastModified: Date(),
                createdAt: Date()
            )

            modelContext.insert(budget)
            try modelContext.save()

            // Mark for sync
            syncService.markBudgetForSync(budget)

            lastAddedBudget = budget
            didSaveSuccessfully = true
            isLoading = false

            // Reload data
            loadData()

            // Trigger sync if online
            Task {
                try? await syncService.syncNow()
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to save budget: \(error.localizedDescription)"
        }
    }

    /// Update an existing budget
    @MainActor
    func updateBudget(
        _ budget: Budget,
        amount: Decimal,
        period: BudgetPeriod,
        startDate: Date,
        alertThreshold: Double,
        category: Category?,
        isActive: Bool
    ) async {
        guard amount > 0 else {
            errorMessage = "Budget amount must be greater than zero"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            budget.amount = amount
            budget.period = period
            budget.startDate = startDate
            budget.alertThreshold = alertThreshold
            budget.category = category
            budget.isActive = isActive
            budget.lastModified = Date()
            budget.isSynced = false

            try modelContext.save()

            // Mark for sync
            syncService.markBudgetForSync(budget)

            didSaveSuccessfully = true
            isLoading = false

            // Reload data
            loadData()

            // Trigger sync if online
            Task {
                try? await syncService.syncNow()
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to update budget: \(error.localizedDescription)"
        }
    }

    /// Delete a budget
    @MainActor
    func deleteBudget(_ budget: Budget) async {
        isLoading = true
        errorMessage = nil

        do {
            let budgetId = budget.id

            modelContext.delete(budget)
            try modelContext.save()

            // Mark for deletion sync
            syncService.markForDeletion(entityId: budgetId, entityType: .budget)

            isLoading = false

            // Reload data
            loadData()

            // Trigger sync if online
            Task {
                try? await syncService.syncNow()
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to delete budget: \(error.localizedDescription)"
        }
    }

    /// Renew an expired budget
    @MainActor
    func renewBudget(_ budget: Budget) async {
        await updateBudget(
            budget,
            amount: budget.amount,
            period: budget.period,
            startDate: Date(),
            alertThreshold: budget.alertThreshold,
            category: budget.category,
            isActive: true
        )
    }

    /// Deactivate a budget
    @MainActor
    func deactivateBudget(_ budget: Budget) async {
        await updateBudget(
            budget,
            amount: budget.amount,
            period: budget.period,
            startDate: budget.startDate,
            alertThreshold: budget.alertThreshold,
            category: budget.category,
            isActive: false
        )
    }

    // MARK: - Helpers

    /// Clear error state
    func clearError() {
        errorMessage = nil
    }

    /// Reset success state
    func resetState() {
        didSaveSuccessfully = false
        errorMessage = nil
        lastAddedBudget = nil
    }

    /// Refresh data
    func refresh() {
        loadData()
    }
}

// MARK: - Budget Form State

/// State object for the budget form
@Observable
final class BudgetFormState {
    var amountString: String = ""
    var amount: Decimal = 0
    var period: BudgetPeriod = .monthly
    var startDate: Date = Date()
    var alertThreshold: Double = 0.8
    var selectedCategory: Category?
    var isActive: Bool = true

    var isValid: Bool {
        amount > 0
    }

    var thresholdPercentage: Int {
        Int(alertThreshold * 100)
    }

    func updateAmount(from string: String) {
        amountString = string
        amount = Decimal(string: string) ?? 0
    }

    func reset() {
        amountString = ""
        amount = 0
        period = .monthly
        startDate = Date()
        alertThreshold = 0.8
        selectedCategory = nil
        isActive = true
    }

    /// Initialize for editing an existing budget
    func loadBudget(_ budget: Budget) {
        amount = budget.amount
        amountString = "\(budget.amount)"
        period = budget.period
        startDate = budget.startDate
        alertThreshold = budget.alertThreshold
        selectedCategory = budget.category
        isActive = budget.isActive
    }
}

// MARK: - Budget Summary

/// Summary statistics for budgets
struct BudgetSummary {
    let totalBudgeted: Decimal
    let totalSpent: Decimal
    let activeBudgetCount: Int
    let alertCount: Int

    var remaining: Decimal {
        totalBudgeted - totalSpent
    }

    var overallProgress: Double {
        guard totalBudgeted > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalSpent / totalBudgeted).doubleValue
    }

    var formattedRemaining: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: remaining as NSDecimalNumber) ?? "₹0"
    }

    static var empty: BudgetSummary {
        BudgetSummary(totalBudgeted: 0, totalSpent: 0, activeBudgetCount: 0, alertCount: 0)
    }
}
