//
//  AccountViewModel.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - Account ViewModel (iOS 26 @Observable)

/// ViewModel for managing account operations
@Observable
final class AccountViewModel {

    // MARK: - Published Properties

    /// All accounts
    private(set) var accounts: [Account] = []

    /// Loading state for async operations
    private(set) var isLoading = false

    /// Error message if operation fails
    private(set) var errorMessage: String?

    /// Success state for dismissing view
    private(set) var didSaveSuccessfully = false

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let syncService: SyncService

    // MARK: - Initialization

    init(modelContext: ModelContext, syncService: SyncService = .shared) {
        self.modelContext = modelContext
        self.syncService = syncService
        loadAccounts()
    }

    // MARK: - Computed Properties

    /// Total balance across all accounts
    var totalBalance: Decimal {
        accounts.reduce(Decimal.zero) { $0 + $1.currentBalance }
    }

    /// Formatted total balance
    var formattedTotalBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: totalBalance as NSDecimalNumber) ?? "₹0"
    }

    /// Accounts grouped by type
    var accountsByType: [AccountType: [Account]] {
        Dictionary(grouping: accounts, by: { $0.accountType })
    }

    // MARK: - Data Loading

    func loadAccounts() {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.createdAt)]
        )

        do {
            accounts = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }
    }

    // MARK: - CRUD Operations

    /// Add a new account
    @MainActor
    func addAccount(
        name: String,
        accountType: AccountType,
        initialBalance: Decimal,
        icon: String?,
        colorHex: String?
    ) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Account name cannot be empty"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let account = Account(
                name: name.trimmingCharacters(in: .whitespaces),
                initialBalance: initialBalance,
                accountType: accountType,
                icon: icon ?? accountType.icon,
                colorHex: colorHex ?? accountType.defaultColor,
                isSynced: false,
                lastModified: Date(),
                createdAt: Date()
            )

            modelContext.insert(account)
            try modelContext.save()

            // Mark for sync
            syncService.markAccountForSync(account)

            didSaveSuccessfully = true
            isLoading = false

            // Reload data
            loadAccounts()

            // Trigger sync
            Task {
                try? await syncService.syncAllUnsynced(from: modelContext)
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to save account: \(error.localizedDescription)"
        }
    }

    /// Update an existing account
    @MainActor
    func updateAccount(
        _ account: Account,
        name: String,
        accountType: AccountType,
        initialBalance: Decimal,
        icon: String,
        colorHex: String
    ) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Account name cannot be empty"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            account.name = name.trimmingCharacters(in: .whitespaces)
            account.accountType = accountType
            account.initialBalance = initialBalance
            account.icon = icon
            account.colorHex = colorHex
            account.lastModified = Date()
            account.isSynced = false

            try modelContext.save()

            // Mark for sync
            syncService.markAccountForSync(account)

            didSaveSuccessfully = true
            isLoading = false

            // Reload data
            loadAccounts()

            // Trigger sync
            Task {
                try? await syncService.syncAllUnsynced(from: modelContext)
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to update account: \(error.localizedDescription)"
        }
    }

    /// Delete an account
    @MainActor
    func deleteAccount(_ account: Account) async {
        // Check if account has transactions
        if let transactions = account.transactions, !transactions.isEmpty {
            errorMessage = "Cannot delete account with existing transactions. Please delete or reassign transactions first."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let accountId = account.id

            modelContext.delete(account)
            try modelContext.save()

            // Mark for deletion sync
            syncService.markForDeletion(entityId: accountId, entityType: .account)

            isLoading = false

            // Reload data
            loadAccounts()

            // Trigger sync
            Task {
                try? await syncService.syncAllUnsynced(from: modelContext)
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }
    }

    /// Delete accounts at specified offsets (for swipe-to-delete)
    @MainActor
    func deleteAccounts(at offsets: IndexSet) async {
        for index in offsets {
            guard index < accounts.count else { continue }
            await deleteAccount(accounts[index])
        }
    }

    // MARK: - Balance Calculations

    /// Get balance for a specific account type
    func balance(for accountType: AccountType) -> Decimal {
        accounts
            .filter { $0.accountType == accountType }
            .reduce(Decimal.zero) { $0 + $1.currentBalance }
    }

    /// Get transaction count for an account
    func transactionCount(for account: Account) -> Int {
        account.transactions?.count ?? 0
    }

    // MARK: - Helpers

    func clearError() {
        errorMessage = nil
    }

    func resetState() {
        didSaveSuccessfully = false
        errorMessage = nil
    }

    func refresh() {
        loadAccounts()
    }
}

// MARK: - Account Form State

@Observable
final class AccountFormState {
    var name: String = ""
    var accountType: AccountType = .cash
    var initialBalanceString: String = ""
    var initialBalance: Decimal = 0
    var selectedIcon: String = "banknote.fill"
    var selectedColor: Color = .green

    var colorHex: String {
        selectedColor.hexString
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func updateBalance(from string: String) {
        initialBalanceString = string
        initialBalance = Decimal(string: string) ?? 0
    }

    func reset() {
        name = ""
        accountType = .cash
        initialBalanceString = ""
        initialBalance = 0
        selectedIcon = AccountType.cash.icon
        selectedColor = Color(hex: AccountType.cash.defaultColor) ?? .green
    }

    func loadAccount(_ account: Account) {
        name = account.name
        accountType = account.accountType
        initialBalance = account.initialBalance
        initialBalanceString = "\(account.initialBalance)"
        selectedIcon = account.icon
        selectedColor = account.color
    }

    func updateForAccountType(_ type: AccountType) {
        accountType = type
        selectedIcon = type.icon
        selectedColor = Color(hex: type.defaultColor) ?? .blue
    }
}
