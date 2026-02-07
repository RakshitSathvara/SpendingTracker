//
//  DataInitializer.swift
//  SpendingTracker
//

import Foundation

// MARK: - Data Initializer

/// Service responsible for initializing default data for new users
/// Cloud-only mode: Creates defaults directly in Firestore
@MainActor
final class DataInitializer {

    // MARK: - Singleton

    static let shared = DataInitializer()

    // MARK: - Private Properties

    private let categoryRepository: CategoryRepository
    private let accountRepository: AccountRepository

    // MARK: - Initialization

    private init() {
        self.categoryRepository = CategoryRepository()
        self.accountRepository = AccountRepository()
    }

    // MARK: - Public Methods

    /// Initialize default data for a new user with the given persona
    /// - Parameter persona: The user's persona for category selection
    func initializeDefaults(for persona: UserPersona) async {
        // Create default categories
        do {
            let existingCategories = try await categoryRepository.fetchCategories()
            if existingCategories.isEmpty {
                try await categoryRepository.createDefaultCategories(for: persona)
                print("✅ Default categories created in Firestore")
            }
        } catch {
            print("Failed to initialize default categories: \(error)")
        }

        // Create default accounts
        do {
            let existingAccounts = try await accountRepository.fetchAccounts()
            if existingAccounts.isEmpty {
                try await accountRepository.createDefaultAccounts()
                print("✅ Default accounts created in Firestore")
            }
        } catch {
            print("Failed to initialize default accounts: \(error)")
        }
    }

    /// Quick initialization check — creates default data if none exists
    /// Uses a default persona (.professional) for first-time setup
    func initializeDefaultDataIfNeeded() async {
        await initializeDefaults(for: .professional)
    }

    /// Repair missing default data by checking and recreating if needed
    func repairIfNeeded() async {
        do {
            // Check for missing categories
            let categories = try await categoryRepository.fetchCategories()
            if categories.isEmpty {
                print("⚠️ No categories found, recreating defaults")
                try await categoryRepository.createDefaultCategories(for: .professional)
            }

            // Check for missing accounts
            let accounts = try await accountRepository.fetchAccounts()
            if accounts.isEmpty {
                print("⚠️ No accounts found, recreating defaults")
                try await accountRepository.createDefaultAccounts()
            }
        } catch {
            print("Failed to repair missing data: \(error)")
        }
    }
}

// Note: CategoryRepository, AccountRepository, and their protocols
// are defined in Repositories/CategoryRepository.swift and Repositories/AccountRepository.swift
