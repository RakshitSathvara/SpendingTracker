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
    func fetchTransactions(from startDate: Date, to endDate: Date) async throws -> [TransactionDTO]

    /// Fetches all transactions
    func fetchAllTransactions() async throws -> [TransactionDTO]

    /// Returns an AsyncStream that emits updates when transactions change
    func observeTransactions() -> AsyncStream<[TransactionDTO]>

    /// Syncs multiple unsynced transactions in a batch
    func batchSyncTransactions(_ transactions: [Transaction]) async throws
}

// MARK: - Transaction DTO

/// Data Transfer Object for Transaction (decoupled from SwiftData)
struct TransactionDTO: Identifiable, Equatable {
    let id: String
    var amount: Decimal
    var note: String
    var date: Date
    var type: TransactionType
    var merchantName: String?
    var categoryId: String?
    var accountId: String?
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    var isExpense: Bool { type == .expense }
    var isIncome: Bool { type == .income }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "note": note,
            "date": Timestamp(date: date),
            "type": type.rawValue,
            "isSynced": true,
            "lastModified": Timestamp(date: lastModified),
            "createdAt": Timestamp(date: createdAt)
        ]

        if let merchantName = merchantName {
            data["merchantName"] = merchantName
        }
        if let categoryId = categoryId {
            data["categoryId"] = categoryId
        }
        if let accountId = accountId {
            data["accountId"] = accountId
        }

        return data
    }

    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        note: String = "",
        date: Date = Date(),
        type: TransactionType = .expense,
        merchantName: String? = nil,
        categoryId: String? = nil,
        accountId: String? = nil,
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.date = date
        self.type = type
        self.merchantName = merchantName
        self.categoryId = categoryId
        self.accountId = accountId
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.amount = Decimal((data["amount"] as? Double) ?? 0)
        self.note = data["note"] as? String ?? ""

        if let timestamp = data["date"] as? Timestamp {
            self.date = timestamp.dateValue()
        } else {
            self.date = Date()
        }

        let typeRaw = data["type"] as? String ?? TransactionType.expense.rawValue
        self.type = TransactionType(rawValue: typeRaw) ?? .expense
        self.merchantName = data["merchantName"] as? String
        self.categoryId = data["categoryId"] as? String
        self.accountId = data["accountId"] as? String
        self.isSynced = data["isSynced"] as? Bool ?? true

        if let lastModifiedTimestamp = data["lastModified"] as? Timestamp {
            self.lastModified = lastModifiedTimestamp.dateValue()
        } else {
            self.lastModified = Date()
        }

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }

    /// Creates a TransactionDTO from a SwiftData Transaction model
    init(from transaction: Transaction) {
        self.id = transaction.id
        self.amount = transaction.amount
        self.note = transaction.note
        self.date = transaction.date
        self.type = transaction.type
        self.merchantName = transaction.merchantName
        self.categoryId = transaction.category?.id
        self.accountId = transaction.account?.id
        self.isSynced = transaction.isSynced
        self.lastModified = transaction.lastModified
        self.createdAt = transaction.createdAt
    }
}

// MARK: - Transaction Repository Implementation

/// Firestore repository for Transaction entities
@Observable
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
        let dto = TransactionDTO(from: transaction)

        do {
            try await collection.document(dto.id).setDataAsync(dto.firestoreData)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateTransaction(_ transaction: Transaction) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()
        var dto = TransactionDTO(from: transaction)
        // Update lastModified timestamp
        let updatedDTO = TransactionDTO(
            id: dto.id,
            amount: dto.amount,
            note: dto.note,
            date: dto.date,
            type: dto.type,
            merchantName: dto.merchantName,
            categoryId: dto.categoryId,
            accountId: dto.accountId,
            isSynced: true,
            lastModified: Date(),
            createdAt: dto.createdAt
        )

        do {
            try await collection.document(updatedDTO.id).setDataAsync(updatedDTO.firestoreData, merge: true)
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

    func fetchTransactions(from startDate: Date, to endDate: Date) async throws -> [TransactionDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startDate))
                .whereField("date", isLessThanOrEqualTo: Timestamp(date: endDate))
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try TransactionDTO(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchAllTransactions() async throws -> [TransactionDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try TransactionDTO(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    // MARK: - Real-time Listener

    func observeTransactions() -> AsyncStream<[TransactionDTO]> {
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

                    let transactions = documents.compactMap { doc -> TransactionDTO? in
                        try? TransactionDTO(from: doc)
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

    // MARK: - Batch Operations

    func batchSyncTransactions(_ transactions: [Transaction]) async throws {
        guard !transactions.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()
        let batchWriter = FirestoreBatchWriter(firestore: db)

        for transaction in transactions {
            let dto = TransactionDTO(from: transaction)
            let docRef = collection.document(dto.id)
            batchWriter.set(dto.firestoreData, forDocument: docRef)

            // Commit in batches of 500 (Firestore limit)
            if batchWriter.isFull {
                try await batchWriter.commit()
            }
        }

        // Commit any remaining operations
        if batchWriter.count > 0 {
            try await batchWriter.commit()
        }
    }
}

// MARK: - Transactions Query Helpers

extension TransactionRepository {

    /// Fetches transactions for a specific month
    func fetchTransactionsForMonth(year: Int, month: Int) async throws -> [TransactionDTO] {
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
    func fetchCurrentMonthTransactions() async throws -> [TransactionDTO] {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)

        guard let year = components.year, let month = components.month else {
            throw RepositoryError.invalidData("Could not get current date components")
        }

        return try await fetchTransactionsForMonth(year: year, month: month)
    }

    /// Fetches transactions by type (expense or income)
    func fetchTransactionsByType(_ type: TransactionType) async throws -> [TransactionDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .whereField("type", isEqualTo: type.rawValue)
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try TransactionDTO(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches transactions for a specific category
    func fetchTransactionsByCategory(categoryId: String) async throws -> [TransactionDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .whereField("categoryId", isEqualTo: categoryId)
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try TransactionDTO(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches transactions for a specific account
    func fetchTransactionsByAccount(accountId: String) async throws -> [TransactionDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try transactionsCollection()

        do {
            let snapshot = try await collection
                .whereField("accountId", isEqualTo: accountId)
                .order(by: "date", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try TransactionDTO(from: $0) }
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
