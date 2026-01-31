//
//  DataInitializer.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftData

// MARK: - Data Initializer

/// Service responsible for initializing default data for new users
@MainActor
final class DataInitializer {

    // MARK: - Singleton

    static let shared = DataInitializer()

    private init() {}

    // MARK: - UserDefaults Keys

    private let hasInitializedDataKey = "hasInitializedDefaultData"

    // MARK: - Public Methods

    /// Initialize default data if not already done
    func initializeDefaultDataIfNeeded(context: ModelContext) {
        // Check if we've already initialized
        guard !UserDefaults.standard.bool(forKey: hasInitializedDataKey) else {
            // Even if initialized before, check if data exists (user might have deleted app data)
            checkAndRepairMissingData(context: context)
            return
        }

        // Create default data
        createDefaultData(context: context)

        // Mark as initialized
        UserDefaults.standard.set(true, forKey: hasInitializedDataKey)
    }

    /// Force re-initialization of default data (for testing/reset)
    func reinitializeDefaultData(context: ModelContext) {
        createDefaultData(context: context)
    }

    // MARK: - Private Methods

    private func createDefaultData(context: ModelContext) {
        createDefaultAccounts(context: context)
        createDefaultCategories(context: context)

        do {
            try context.save()
            print("✅ Default data initialized successfully")
        } catch {
            print("❌ Failed to save default data: \(error)")
        }
    }

    private func createDefaultAccounts(context: ModelContext) {
        // Check if accounts already exist
        let descriptor = FetchDescriptor<Account>()
        let existingAccounts = (try? context.fetch(descriptor)) ?? []

        guard existingAccounts.isEmpty else {
            print("ℹ️ Accounts already exist, skipping creation")
            return
        }

        // Create default accounts
        let defaultAccounts: [(name: String, type: AccountType, initialBalance: Decimal)] = [
            ("Cash", .cash, 0),
            ("Bank Account", .bank, 0),
            ("Credit Card", .credit, 0),
            ("Savings", .savings, 0)
        ]

        for accountInfo in defaultAccounts {
            let account = Account(
                name: accountInfo.name,
                initialBalance: accountInfo.initialBalance,
                accountType: accountInfo.type
            )
            context.insert(account)
        }

        print("✅ Created \(defaultAccounts.count) default accounts")
    }

    private func createDefaultCategories(context: ModelContext) {
        // Check if categories already exist
        let descriptor = FetchDescriptor<Category>()
        let existingCategories = (try? context.fetch(descriptor)) ?? []

        guard existingCategories.isEmpty else {
            print("ℹ️ Categories already exist, skipping creation")
            return
        }

        // Create default expense categories
        let expenseCategories = Category.defaultExpenseCategories
        for category in expenseCategories {
            context.insert(category)
        }

        // Create default income categories
        let incomeCategories = Category.defaultIncomeCategories
        for category in incomeCategories {
            context.insert(category)
        }

        print("✅ Created \(expenseCategories.count + incomeCategories.count) default categories")
    }

    private func checkAndRepairMissingData(context: ModelContext) {
        // Check accounts
        let accountDescriptor = FetchDescriptor<Account>()
        let accounts = (try? context.fetch(accountDescriptor)) ?? []

        if accounts.isEmpty {
            print("⚠️ No accounts found, recreating defaults")
            createDefaultAccounts(context: context)
        }

        // Check categories
        let categoryDescriptor = FetchDescriptor<Category>()
        let categories = (try? context.fetch(categoryDescriptor)) ?? []

        if categories.isEmpty {
            print("⚠️ No categories found, recreating defaults")
            createDefaultCategories(context: context)
        }

        // Save if any repairs were made
        if accounts.isEmpty || categories.isEmpty {
            try? context.save()
        }
    }
}
