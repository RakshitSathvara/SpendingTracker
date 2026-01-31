//
//  FirestoreService.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import Observation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Firestore Service (iOS 26 @Observable)

@Observable
final class FirestoreService {

    // MARK: - Properties

    private(set) var isLoading = false
    private(set) var error: Error?

    private let firestore = Firestore.firestore()

    // MARK: - User ID Helper

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private func requireUserId() throws -> String {
        guard let userId = currentUserId else {
            throw FirestoreError.notAuthenticated
        }
        return userId
    }

    // MARK: - Collection References

    private func userDocument() throws -> DocumentReference {
        let userId = try requireUserId()
        return firestore.collection("users").document(userId)
    }

    private func transactionsCollection() throws -> CollectionReference {
        try userDocument().collection("transactions")
    }

    private func categoriesCollection() throws -> CollectionReference {
        try userDocument().collection("categories")
    }

    private func accountsCollection() throws -> CollectionReference {
        try userDocument().collection("accounts")
    }

    private func budgetsCollection() throws -> CollectionReference {
        try userDocument().collection("budgets")
    }

    // MARK: - User Profile

    @MainActor
    func fetchUserProfile() async throws -> UserProfile? {
        let userId = try requireUserId()
        let document = try await firestore.collection("users").document(userId).getDocument()

        guard let data = document.data() else { return nil }
        return UserProfile(from: data)
    }

    @MainActor
    func updateUserProfile(_ profile: UserProfile) async throws {
        let userId = try requireUserId()
        var data = profile.firestoreData
        data["lastModified"] = FieldValue.serverTimestamp()

        try await firestore.collection("users").document(userId).updateData(data)
    }

    // MARK: - Transactions

    @MainActor
    func saveTransaction(_ transaction: Transaction) async throws {
        let collection = try transactionsCollection()
        var data = transaction.firestoreData
        data["lastModified"] = FieldValue.serverTimestamp()

        try await collection.document(transaction.id).setData(data)
    }

    @MainActor
    func fetchTransactions(limit: Int = 50) async throws -> [[String: Any]] {
        let collection = try transactionsCollection()
        let snapshot = try await collection
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.map { $0.data() }
    }

    @MainActor
    func deleteTransaction(_ transactionId: String) async throws {
        let collection = try transactionsCollection()
        try await collection.document(transactionId).delete()
    }

    // MARK: - Categories

    @MainActor
    func saveCategory(_ category: Category) async throws {
        let collection = try categoriesCollection()
        var data = category.firestoreData
        data["lastModified"] = FieldValue.serverTimestamp()

        try await collection.document(category.id).setData(data)
    }

    @MainActor
    func fetchCategories() async throws -> [[String: Any]] {
        let collection = try categoriesCollection()
        let snapshot = try await collection
            .order(by: "sortOrder")
            .getDocuments()

        return snapshot.documents.map { $0.data() }
    }

    @MainActor
    func deleteCategory(_ categoryId: String) async throws {
        let collection = try categoriesCollection()
        try await collection.document(categoryId).delete()
    }

    // MARK: - Accounts

    @MainActor
    func saveAccount(_ account: Account) async throws {
        let collection = try accountsCollection()
        var data = account.firestoreData
        data["lastModified"] = FieldValue.serverTimestamp()

        try await collection.document(account.id).setData(data)
    }

    @MainActor
    func fetchAccounts() async throws -> [[String: Any]] {
        let collection = try accountsCollection()
        let snapshot = try await collection
            .order(by: "createdAt")
            .getDocuments()

        return snapshot.documents.map { $0.data() }
    }

    @MainActor
    func deleteAccount(_ accountId: String) async throws {
        let collection = try accountsCollection()
        try await collection.document(accountId).delete()
    }

    // MARK: - Budgets

    @MainActor
    func saveBudget(_ budget: Budget) async throws {
        let collection = try budgetsCollection()
        var data = budget.firestoreData
        data["lastModified"] = FieldValue.serverTimestamp()

        try await collection.document(budget.id).setData(data)
    }

    @MainActor
    func fetchBudgets() async throws -> [[String: Any]] {
        let collection = try budgetsCollection()
        let snapshot = try await collection
            .order(by: "startDate", descending: true)
            .getDocuments()

        return snapshot.documents.map { $0.data() }
    }

    @MainActor
    func deleteBudget(_ budgetId: String) async throws {
        let collection = try budgetsCollection()
        try await collection.document(budgetId).delete()
    }

    // MARK: - Sync Operations

    @MainActor
    func syncUnsyncedData(
        transactions: [Transaction],
        categories: [Category],
        accounts: [Account],
        budgets: [Budget]
    ) async throws {
        isLoading = true
        error = nil

        do {
            let batch = firestore.batch()

            // Sync transactions
            let transactionsCol = try transactionsCollection()
            for transaction in transactions where !transaction.isSynced {
                var data = transaction.firestoreData
                data["isSynced"] = true
                data["lastModified"] = FieldValue.serverTimestamp()
                batch.setData(data, forDocument: transactionsCol.document(transaction.id))
            }

            // Sync categories
            let categoriesCol = try categoriesCollection()
            for category in categories where !category.isSynced {
                var data = category.firestoreData
                data["isSynced"] = true
                data["lastModified"] = FieldValue.serverTimestamp()
                batch.setData(data, forDocument: categoriesCol.document(category.id))
            }

            // Sync accounts
            let accountsCol = try accountsCollection()
            for account in accounts where !account.isSynced {
                var data = account.firestoreData
                data["isSynced"] = true
                data["lastModified"] = FieldValue.serverTimestamp()
                batch.setData(data, forDocument: accountsCol.document(account.id))
            }

            // Sync budgets
            let budgetsCol = try budgetsCollection()
            for budget in budgets where !budget.isSynced {
                var data = budget.firestoreData
                data["isSynced"] = true
                data["lastModified"] = FieldValue.serverTimestamp()
                batch.setData(data, forDocument: budgetsCol.document(budget.id))
            }

            try await batch.commit()
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }

    // MARK: - Clear Error

    @MainActor
    func clearError() {
        error = nil
    }
}

// MARK: - Firestore Error

enum FirestoreError: LocalizedError {
    case notAuthenticated
    case documentNotFound
    case syncFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .documentNotFound:
            return "The requested document was not found."
        case .syncFailed:
            return "Failed to sync data with the server."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
