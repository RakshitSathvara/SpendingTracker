//
//  TransactionRepository.swift
//  SpendingTracker
//
//  Created by Claude on 2026-01-31.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Transaction Repository Protocol

/// Protocol defining transaction repository operations
protocol TransactionRepositoryProtocol {
    /// Adds a new transaction to Firestore
    func addTransaction(_ transaction: Transaction) async throws

    /// Updates an existing transaction in Firestore
    func updateTransaction(_ transaction: Transaction) async throws

    /// Deletes a transaction by its ID
    func deleteTransaction(id: String) async throws

    /// Fetches transactions within a date range
    func fetchTransactions(from startDate: Date, to endDate: Date) async throws -> [Transaction]

    /// Fetches all transactions
    func fetchAllTransactions() async throws -> [Transaction]

    /// Returns an AsyncStream that emits updates when transactions change
    func observeTransactions() -> AsyncStream<[Transaction]>
}

// MARK: - Transaction Repository Implementation

/// Firestore repository for Transaction entities
final class TransactionRepository: TransactionRepositoryProtocol {

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

    private func transactionsCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }
        return db.collection(FirestorePath.transactionsCollection(userId: userId))
    }

    // MARK: - CRUD Operations

    func addTransaction(_ transaction: Transaction) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            try await collection.document(transaction.id).setDataAsync(transaction.firestoreData)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateTransaction(_ transaction: Transaction) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            try await collection.document(transaction.id).setDataAsync(transaction.firestoreData, merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func deleteTransaction(id: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            try await collection.document(id).delete()
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchTransactions(from startDate: Date, to endDate: Date) async throws -> [Transaction] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startDate))
                .whereField("date", isLessThanOrEqualTo: Timestamp(date: endDate))
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try Transaction(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchAllTransactions() async throws -> [Transaction] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try Transaction(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    // MARK: - Real-time Listener

    func observeTransactions() -> AsyncStream<[Transaction]> {
        AsyncStream { continuation in
            guard let userId = currentUserId else {
                continuation.finish()
                return
            }

            let collection = db.collection(FirestorePath.transactionsCollection(userId: userId))

            let listener = collection
                .order(by: "date", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("TransactionRepository listener error: \(error.localizedDescription)")
                        // Don't finish the stream on error, just skip this update
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }

                    let transactions = documents.compactMap { doc -> Transaction? in
                        try? Transaction(from: doc)
                    }

                    continuation.yield(transactions)
                }

            // Store the listener reference
            self.listener = listener

            // Handle cancellation
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
}

// MARK: - Transactions Query Helpers

extension TransactionRepository {

    /// Fetches transactions for a specific month
    func fetchTransactionsForMonth(year: Int, month: Int) async throws -> [Transaction] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let startDate = calendar.date(from: components),
              let endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) else {
            throw RepositoryError.invalidData("Invalid date components")
        }

        return try await fetchTransactions(from: startDate, to: endDate)
    }

    /// Fetches transactions for the current month
    func fetchCurrentMonthTransactions() async throws -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)

        guard let year = components.year, let month = components.month else {
            throw RepositoryError.invalidData("Could not get current date components")
        }

        return try await fetchTransactionsForMonth(year: year, month: month)
    }

    /// Fetches transactions by type (expense or income)
    func fetchTransactionsByType(_ type: TransactionType) async throws -> [Transaction] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .whereField("type", isEqualTo: type.rawValue)
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try Transaction(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches transactions for a specific category
    func fetchTransactionsByCategory(categoryId: String) async throws -> [Transaction] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .whereField("categoryId", isEqualTo: categoryId)
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try Transaction(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches transactions for a specific account
    func fetchTransactionsByAccount(accountId: String) async throws -> [Transaction] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .whereField("accountId", isEqualTo: accountId)
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try Transaction(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Calculates the total amount for a date range and type
    func calculateTotal(from startDate: Date, to endDate: Date, type: TransactionType) async throws -> Decimal {
        let transactions = try await fetchTransactions(from: startDate, to: endDate)
        return transactions
            .filter { $0.type == type }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
}
