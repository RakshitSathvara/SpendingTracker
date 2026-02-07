//
//  BudgetRepository.swift
//  SpendingTracker
//
//  Created by Claude on 2026-01-31.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Budget Repository Protocol

/// Protocol defining budget repository operations
protocol BudgetRepositoryProtocol {
    /// Adds a new budget to Firestore
    func addBudget(_ budget: Budget) async throws

    /// Updates an existing budget in Firestore
    func updateBudget(_ budget: Budget) async throws

    /// Deletes a budget by its ID
    func deleteBudget(id: String) async throws

    /// Fetches all budgets
    func fetchBudgets() async throws -> [Budget]

    /// Calculates spending for a budget based on transactions
    func calculateSpending(for budget: Budget, transactions: [Transaction]) -> Decimal

    /// Returns an AsyncStream that emits updates when budgets change
    func observeBudgets() -> AsyncStream<[Budget]>
}

// MARK: - Budget Repository Implementation

/// Firestore repository for Budget entities
final class BudgetRepository: BudgetRepositoryProtocol {

    // MARK: - Properties

    private let db: Firestore
    private var listener: ListenerRegistration?

    var isLoading: Bool = false
    var error: RepositoryError?

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Initialization

    init(firestore: Firestore = Firestore.firestore()) {
        self.db = firestore
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Private Helpers

    private func budgetsCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }
        return db.collection(FirestorePath.budgetsCollection(userId: userId))
    }

    // MARK: - CRUD Operations

    func addBudget(_ budget: Budget) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            try await collection.document(budget.id).setDataAsync(budget.firestoreData)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateBudget(_ budget: Budget) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            try await collection.document(budget.id).setDataAsync(budget.firestoreData, merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func deleteBudget(id: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            try await collection.document(id).delete()
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchBudgets() async throws -> [Budget] {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let snapshot = try await collection
                .order(by: "createdAt", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try Budget(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func calculateSpending(for budget: Budget, transactions: [Transaction]) -> Decimal {
        budget.spentAmount(transactions: transactions)
    }

    // MARK: - Real-time Listener

    func observeBudgets() -> AsyncStream<[Budget]> {
        AsyncStream { continuation in
            guard let userId = currentUserId else {
                continuation.finish()
                return
            }

            let collection = db.collection(FirestorePath.budgetsCollection(userId: userId))

            let listener = collection
                .order(by: "createdAt", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("BudgetRepository listener error: \(error.localizedDescription)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }

                    let budgets = documents.compactMap { doc -> Budget? in
                        try? Budget(from: doc)
                    }

                    continuation.yield(budgets)
                }

            self.listener = listener

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
}

// MARK: - Budget Query Helpers

extension BudgetRepository {

    /// Fetches only active budgets
    func fetchActiveBudgets() async throws -> [Budget] {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let snapshot = try await collection
                .whereField("isActive", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try Budget(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches budgets for a specific category
    func fetchBudgetsByCategory(categoryId: String) async throws -> [Budget] {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let snapshot = try await collection
                .whereField("categoryId", isEqualTo: categoryId)
                .order(by: "createdAt", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try Budget(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches budgets by period
    func fetchBudgetsByPeriod(_ period: BudgetPeriod) async throws -> [Budget] {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let snapshot = try await collection
                .whereField("period", isEqualTo: period.rawValue)
                .order(by: "createdAt", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try Budget(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches a single budget by ID
    func fetchBudget(id: String) async throws -> Budget? {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let document = try await collection.document(id).getDocument()
            guard document.exists else { return nil }
            return try Budget(from: document)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Calculates spending for a budget directly from Firestore transactions
    func calculateSpendingFromFirestore(for budget: Budget, transactionRepository: TransactionRepository) async throws -> Decimal {
        let transactions = try await transactionRepository.fetchTransactions(
            from: budget.startDate,
            to: budget.endDate
        )

        return transactions
            .filter { transaction in
                transaction.isExpense &&
                (budget.categoryId == nil || transaction.categoryId == budget.categoryId)
            }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Returns budgets that are over threshold or over budget
    func fetchAlertBudgets(transactions: [Transaction]) async throws -> [Budget] {
        let budgets = try await fetchActiveBudgets()
        return budgets.filter { $0.isOverThreshold(transactions: transactions) }
    }

    /// Deactivates a budget
    func deactivateBudget(id: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            try await collection.document(id).setDataAsync([
                "isActive": false,
                "lastModified": Timestamp(date: Date())
            ], merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Renews an expired budget with a new start date
    func renewBudget(id: String, newStartDate: Date = Date()) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            try await collection.document(id).setDataAsync([
                "startDate": Timestamp(date: newStartDate),
                "isActive": true,
                "lastModified": Timestamp(date: Date())
            ], merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }
}
