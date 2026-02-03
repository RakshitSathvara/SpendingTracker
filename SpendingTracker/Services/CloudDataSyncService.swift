//
//  CloudDataSyncService.swift
//  SpendingTracker
//
//  Created by Claude on 2026-02-03.
//

import Foundation
import Observation
import SwiftData
import FirebaseFirestore
import FirebaseAuth

// MARK: - Cloud Data Sync Service

/// Service responsible for downloading data from Firestore and syncing to local SwiftData
/// This enables cross-device sync by pulling cloud data on login/startup
@Observable
@MainActor
final class CloudDataSyncService {

    // MARK: - Singleton

    static let shared = CloudDataSyncService()

    // MARK: - Observable Properties

    /// Current sync state
    private(set) var isSyncing: Bool = false

    /// Whether initial sync has completed
    private(set) var hasCompletedInitialSync: Bool = false

    /// Last sync error
    private(set) var lastError: Error?

    /// Progress message for UI
    private(set) var progressMessage: String = ""

    // MARK: - Private Properties

    private var firestore: Firestore { Firestore.firestore() }

    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Download all user data from Firestore and sync to SwiftData
    /// This should be called on login or when app starts with an authenticated user
    func downloadAndSyncAllData(to modelContext: ModelContext) async throws {
        guard let userId = currentUserId else {
            throw CloudSyncError.notAuthenticated
        }

        guard !isSyncing else { return }

        isSyncing = true
        lastError = nil
        progressMessage = "Syncing your data..."

        do {
            // Download and sync categories first (transactions depend on them)
            progressMessage = "Syncing categories..."
            try await downloadAndSyncCategories(userId: userId, context: modelContext)

            // Download and sync accounts (transactions depend on them)
            progressMessage = "Syncing accounts..."
            try await downloadAndSyncAccounts(userId: userId, context: modelContext)

            // Download and sync budgets
            progressMessage = "Syncing budgets..."
            try await downloadAndSyncBudgets(userId: userId, context: modelContext)

            // Download and sync transactions (depends on categories and accounts)
            progressMessage = "Syncing transactions..."
            try await downloadAndSyncTransactions(userId: userId, context: modelContext)

            // Save all changes
            try modelContext.save()

            hasCompletedInitialSync = true
            isSyncing = false
            progressMessage = "Sync complete!"

            print("✅ Cloud data sync completed successfully")

        } catch {
            isSyncing = false
            lastError = error
            progressMessage = "Sync failed: \(error.localizedDescription)"
            print("❌ Cloud data sync failed: \(error)")
            throw error
        }
    }

    /// Force refresh - re-download all data from cloud
    func forceRefresh(to modelContext: ModelContext) async throws {
        hasCompletedInitialSync = false
        try await downloadAndSyncAllData(to: modelContext)
    }

    // MARK: - Private Sync Methods

    private func downloadAndSyncCategories(userId: String, context: ModelContext) async throws {
        let collection = firestore.collection("users").document(userId).collection("categories")
        let snapshot = try await collection.getDocuments()

        // Fetch existing local categories
        let existingDescriptor = FetchDescriptor<Category>()
        let existingCategories = (try? context.fetch(existingDescriptor)) ?? []
        let existingIds = Set(existingCategories.map { $0.id })

        var syncedCount = 0

        for document in snapshot.documents {
            let data = convertTimestamps(in: document.data())
            let remoteId = data["id"] as? String ?? document.documentID

            if existingIds.contains(remoteId) {
                // Update existing category if remote is newer
                if let existingCategory = existingCategories.first(where: { $0.id == remoteId }) {
                    let remoteModified = (data["lastModified"] as? Date) ?? Date.distantPast
                    if remoteModified > existingCategory.lastModified {
                        updateCategory(existingCategory, with: data)
                        syncedCount += 1
                    }
                }
            } else {
                // Insert new category from cloud
                let newCategory = Category(from: data)
                newCategory.isSynced = true
                context.insert(newCategory)
                syncedCount += 1
            }
        }

        print("📦 Synced \(syncedCount) categories from cloud")
    }

    private func downloadAndSyncAccounts(userId: String, context: ModelContext) async throws {
        let collection = firestore.collection("users").document(userId).collection("accounts")
        let snapshot = try await collection.getDocuments()

        // Fetch existing local accounts
        let existingDescriptor = FetchDescriptor<Account>()
        let existingAccounts = (try? context.fetch(existingDescriptor)) ?? []
        let existingIds = Set(existingAccounts.map { $0.id })

        var syncedCount = 0

        for document in snapshot.documents {
            let data = convertTimestamps(in: document.data())
            let remoteId = data["id"] as? String ?? document.documentID

            if existingIds.contains(remoteId) {
                // Update existing account if remote is newer
                if let existingAccount = existingAccounts.first(where: { $0.id == remoteId }) {
                    let remoteModified = (data["lastModified"] as? Date) ?? Date.distantPast
                    if remoteModified > existingAccount.lastModified {
                        updateAccount(existingAccount, with: data)
                        syncedCount += 1
                    }
                }
            } else {
                // Insert new account from cloud
                let newAccount = Account(from: data)
                newAccount.isSynced = true
                context.insert(newAccount)
                syncedCount += 1
            }
        }

        print("📦 Synced \(syncedCount) accounts from cloud")
    }

    private func downloadAndSyncBudgets(userId: String, context: ModelContext) async throws {
        let collection = firestore.collection("users").document(userId).collection("budgets")
        let snapshot = try await collection.getDocuments()

        // Fetch existing local budgets and categories for linking
        let existingBudgetDescriptor = FetchDescriptor<Budget>()
        let existingBudgets = (try? context.fetch(existingBudgetDescriptor)) ?? []
        let existingIds = Set(existingBudgets.map { $0.id })

        let categoryDescriptor = FetchDescriptor<Category>()
        let categories = (try? context.fetch(categoryDescriptor)) ?? []
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        var syncedCount = 0

        for document in snapshot.documents {
            let data = convertTimestamps(in: document.data())
            let remoteId = data["id"] as? String ?? document.documentID

            if existingIds.contains(remoteId) {
                // Update existing budget if remote is newer
                if let existingBudget = existingBudgets.first(where: { $0.id == remoteId }) {
                    let remoteModified = (data["lastModified"] as? Date) ?? Date.distantPast
                    if remoteModified > existingBudget.lastModified {
                        updateBudget(existingBudget, with: data, categoryMap: categoryMap)
                        syncedCount += 1
                    }
                }
            } else {
                // Insert new budget from cloud
                let newBudget = Budget(from: data)
                newBudget.isSynced = true

                // Link category if available
                if let categoryId = data["categoryId"] as? String,
                   let category = categoryMap[categoryId] {
                    newBudget.category = category
                }

                context.insert(newBudget)
                syncedCount += 1
            }
        }

        print("📦 Synced \(syncedCount) budgets from cloud")
    }

    private func downloadAndSyncTransactions(userId: String, context: ModelContext) async throws {
        let collection = firestore.collection("users").document(userId).collection("transactions")
        let snapshot = try await collection.order(by: "date", descending: true).getDocuments()

        // Fetch existing local data for linking
        let existingTransactionDescriptor = FetchDescriptor<Transaction>()
        let existingTransactions = (try? context.fetch(existingTransactionDescriptor)) ?? []
        let existingIds = Set(existingTransactions.map { $0.id })

        let categoryDescriptor = FetchDescriptor<Category>()
        let categories = (try? context.fetch(categoryDescriptor)) ?? []
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let accountDescriptor = FetchDescriptor<Account>()
        let accounts = (try? context.fetch(accountDescriptor)) ?? []
        let accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })

        var syncedCount = 0

        for document in snapshot.documents {
            let data = convertTimestamps(in: document.data())
            let remoteId = data["id"] as? String ?? document.documentID

            if existingIds.contains(remoteId) {
                // Update existing transaction if remote is newer
                if let existingTransaction = existingTransactions.first(where: { $0.id == remoteId }) {
                    let remoteModified = (data["lastModified"] as? Date) ?? Date.distantPast
                    if remoteModified > existingTransaction.lastModified {
                        updateTransaction(existingTransaction, with: data, categoryMap: categoryMap, accountMap: accountMap)
                        syncedCount += 1
                    }
                }
            } else {
                // Insert new transaction from cloud
                let newTransaction = Transaction(from: data)
                newTransaction.isSynced = true

                // Link category if available
                if let categoryId = data["categoryId"] as? String,
                   let category = categoryMap[categoryId] {
                    newTransaction.category = category
                }

                // Link account if available
                if let accountId = data["accountId"] as? String,
                   let account = accountMap[accountId] {
                    newTransaction.account = account
                }

                context.insert(newTransaction)
                syncedCount += 1
            }
        }

        print("📦 Synced \(syncedCount) transactions from cloud")
    }

    // MARK: - Update Helpers

    private func updateCategory(_ category: Category, with data: [String: Any]) {
        category.name = data["name"] as? String ?? category.name
        category.icon = data["icon"] as? String ?? category.icon
        category.colorHex = data["colorHex"] as? String ?? category.colorHex
        category.isExpenseCategory = data["isExpenseCategory"] as? Bool ?? category.isExpenseCategory
        category.sortOrder = data["sortOrder"] as? Int ?? category.sortOrder
        category.isDefault = data["isDefault"] as? Bool ?? category.isDefault
        category.lastModified = (data["lastModified"] as? Date) ?? Date()
        category.isSynced = true
    }

    private func updateAccount(_ account: Account, with data: [String: Any]) {
        account.name = data["name"] as? String ?? account.name
        if let balanceDouble = data["initialBalance"] as? Double {
            account.initialBalance = Decimal(balanceDouble)
        }
        account.accountTypeRawValue = data["accountType"] as? String ?? account.accountTypeRawValue
        account.icon = data["icon"] as? String ?? account.icon
        account.colorHex = data["colorHex"] as? String ?? account.colorHex
        account.currencyCode = data["currencyCode"] as? String ?? account.currencyCode
        account.lastModified = (data["lastModified"] as? Date) ?? Date()
        account.isSynced = true
    }

    private func updateBudget(_ budget: Budget, with data: [String: Any], categoryMap: [String: Category]) {
        if let amountDouble = data["amount"] as? Double {
            budget.amount = Decimal(amountDouble)
        }
        budget.periodRawValue = data["period"] as? String ?? budget.periodRawValue
        budget.startDate = (data["startDate"] as? Date) ?? budget.startDate
        budget.alertThreshold = data["alertThreshold"] as? Double ?? budget.alertThreshold
        budget.isActive = data["isActive"] as? Bool ?? budget.isActive
        budget.lastModified = (data["lastModified"] as? Date) ?? Date()
        budget.isSynced = true

        // Update category link
        if let categoryId = data["categoryId"] as? String {
            budget.category = categoryMap[categoryId]
        }
    }

    private func updateTransaction(_ transaction: Transaction, with data: [String: Any], categoryMap: [String: Category], accountMap: [String: Account]) {
        if let amountDouble = data["amount"] as? Double {
            transaction.amount = Decimal(amountDouble)
        }
        transaction.note = data["note"] as? String ?? transaction.note
        transaction.date = (data["date"] as? Date) ?? transaction.date
        transaction.typeRawValue = data["type"] as? String ?? transaction.typeRawValue
        transaction.merchantName = data["merchantName"] as? String
        transaction.lastModified = (data["lastModified"] as? Date) ?? Date()
        transaction.isSynced = true

        // Update category link
        if let categoryId = data["categoryId"] as? String {
            transaction.category = categoryMap[categoryId]
        }

        // Update account link
        if let accountId = data["accountId"] as? String {
            transaction.account = accountMap[accountId]
        }
    }

    // MARK: - Timestamp Conversion Helper

    /// Convert Firestore Timestamps to Date objects in a dictionary
    private func convertTimestamps(in data: [String: Any]) -> [String: Any] {
        var result = data
        for (key, value) in data {
            if let timestamp = value as? Timestamp {
                result[key] = timestamp.dateValue()
            }
        }
        return result
    }
}

// MARK: - Cloud Sync Error

enum CloudSyncError: LocalizedError {
    case notAuthenticated
    case networkError(String)
    case dataError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to sync data"
        case .networkError(let message):
            return "Network error: \(message)"
        case .dataError(let message):
            return "Data error: \(message)"
        }
    }
}
