//
//  TransactionViewModel.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import Observation

// MARK: - Transaction ViewModel (iOS 26 @Observable)

/// ViewModel for managing transaction operations
@Observable
final class TransactionViewModel {

    // MARK: - Published Properties

    /// Loading state for async operations
    private(set) var isLoading = false

    /// Error message if operation fails
    private(set) var errorMessage: String?

    /// Success state for dismissing view
    private(set) var didSaveSuccessfully = false

    /// Recently added transaction for undo functionality
    private(set) var lastAddedTransaction: Transaction?

    // MARK: - Dependencies

    private let transactionRepo = TransactionRepository()

    // MARK: - Initialization

    init() {}

    // MARK: - CRUD Operations

    /// Add a new transaction
    @MainActor
    func addTransaction(
        amount: Decimal,
        type: TransactionType,
        category: Category?,
        account: Account?,
        note: String,
        merchantName: String?,
        date: Date
    ) async {
        guard amount > 0 else {
            errorMessage = "Amount must be greater than zero"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let transaction = Transaction(
                amount: amount,
                note: note,
                date: date,
                type: type,
                merchantName: merchantName,
                categoryId: category?.id,
                accountId: account?.id,
                createdAt: Date()
            )

            try await transactionRepo.addTransaction(transaction)

            lastAddedTransaction = transaction
            didSaveSuccessfully = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to save transaction: \(error.localizedDescription)"
        }
    }

    /// Update an existing transaction
    @MainActor
    func updateTransaction(
        _ transaction: Transaction,
        amount: Decimal,
        type: TransactionType,
        category: Category?,
        account: Account?,
        note: String,
        merchantName: String?,
        date: Date
    ) async {
        guard amount > 0 else {
            errorMessage = "Amount must be greater than zero"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let updatedTransaction = Transaction(
                id: transaction.id,
                amount: amount,
                note: note,
                date: date,
                type: type,
                merchantName: merchantName,
                categoryId: category?.id,
                accountId: account?.id,
                createdAt: transaction.createdAt
            )

            try await transactionRepo.updateTransaction(updatedTransaction)

            didSaveSuccessfully = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to update transaction: \(error.localizedDescription)"
        }
    }

    /// Delete a transaction
    @MainActor
    func deleteTransaction(_ transaction: Transaction) async {
        isLoading = true
        errorMessage = nil

        do {
            try await transactionRepo.deleteTransaction(id: transaction.id)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to delete transaction: \(error.localizedDescription)"
        }
    }

    /// Undo the last added transaction
    @MainActor
    func undoLastTransaction() async {
        guard let transaction = lastAddedTransaction else { return }

        await deleteTransaction(transaction)
        lastAddedTransaction = nil
    }

    // MARK: - Helpers

    /// Clear error state
    func clearError() {
        errorMessage = nil
    }

    /// Reset success state (call when view appears again)
    func resetState() {
        didSaveSuccessfully = false
        errorMessage = nil
        lastAddedTransaction = nil
    }
}

// MARK: - Transaction Form State

/// State object for the transaction form
@Observable
final class TransactionFormState {
    var amountString: String = "0"
    var amount: Decimal = 0
    var isExpense: Bool = true
    var selectedCategory: Category?
    var selectedAccount: Account?
    var note: String = ""
    var merchantName: String = ""
    var date: Date = Date()

    var transactionType: TransactionType {
        isExpense ? .expense : .income
    }

    var isValid: Bool {
        amount > 0
    }

    var hasRequiredFields: Bool {
        amount > 0 && selectedCategory != nil
    }

    func updateAmount(from string: String) {
        amountString = string
        amount = Decimal(string: string) ?? 0
    }

    func reset() {
        amountString = "0"
        amount = 0
        isExpense = true
        selectedCategory = nil
        selectedAccount = nil
        note = ""
        merchantName = ""
        date = Date()
    }

    /// Initialize for editing an existing transaction
    func loadTransaction(_ transaction: Transaction) {
        amount = transaction.amount
        amountString = "\(transaction.amount)"
        isExpense = transaction.isExpense
        note = transaction.note
        merchantName = transaction.merchantName ?? ""
        date = transaction.date
    }
}

// MARK: - Transaction Summary

/// Summary statistics for transactions
struct TransactionSummary {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let transactionCount: Int
    let period: String

    var balance: Decimal {
        totalIncome - totalExpenses
    }

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: balance as NSDecimalNumber) ?? "₹0"
    }

    static var empty: TransactionSummary {
        TransactionSummary(totalIncome: 0, totalExpenses: 0, transactionCount: 0, period: "")
    }
}

// MARK: - Transaction Filter

/// Filter options for transaction list
struct TransactionFilter {
    var searchText: String = ""
    var transactionType: TransactionType?
    var categoryId: String?
    var accountId: String?
    var startDate: Date?
    var endDate: Date?

    var hasActiveFilters: Bool {
        !searchText.isEmpty ||
        transactionType != nil ||
        categoryId != nil ||
        accountId != nil ||
        startDate != nil ||
        endDate != nil
    }

    mutating func reset() {
        searchText = ""
        transactionType = nil
        categoryId = nil
        accountId = nil
        startDate = nil
        endDate = nil
    }
}
