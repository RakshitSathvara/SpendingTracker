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
    func fetchBudgets() async throws -> [BudgetDTO]

    /// Calculates spending for a budget based on transactions
    func calculateSpending(for budget: BudgetDTO, transactions: [TransactionDTO]) -> Decimal

    /// Returns an AsyncStream that emits updates when budgets change
    func observeBudgets() -> AsyncStream<[BudgetDTO]>
}

// MARK: - Budget DTO

/// Data Transfer Object for Budget (decoupled from SwiftData)
struct BudgetDTO: Identifiable, Equatable {
    let id: String
    var amount: Decimal
    var period: BudgetPeriod
    var startDate: Date
    var alertThreshold: Double // 0.8 = 80%
    var isActive: Bool
    var categoryId: String?
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: period.days, to: startDate) ?? startDate
    }

    var isExpired: Bool {
        Date() > endDate
    }

    var daysRemaining: Int {
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, remaining)
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "period": period.rawValue,
            "startDate": Timestamp(date: startDate),
            "alertThreshold": alertThreshold,
            "isActive": isActive,
            "isSynced": true,
            "lastModified": Timestamp(date: lastModified),
            "createdAt": Timestamp(date: createdAt)
        ]
        if let categoryId = categoryId {
            data["categoryId"] = categoryId
        }
        return data
    }

    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        period: BudgetPeriod = .monthly,
        startDate: Date = Date(),
        alertThreshold: Double = 0.8,
        isActive: Bool = true,
        categoryId: String? = nil,
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.period = period
        self.startDate = startDate
        self.alertThreshold = alertThreshold
        self.isActive = isActive
        self.categoryId = categoryId
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

        let periodRaw = data["period"] as? String ?? BudgetPeriod.monthly.rawValue
        self.period = BudgetPeriod(rawValue: periodRaw) ?? .monthly

        if let startDateTimestamp = data["startDate"] as? Timestamp {
            self.startDate = startDateTimestamp.dateValue()
        } else {
            self.startDate = Date()
        }

        self.alertThreshold = data["alertThreshold"] as? Double ?? 0.8
        self.isActive = data["isActive"] as? Bool ?? true
        self.categoryId = data["categoryId"] as? String
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

    /// Creates a BudgetDTO from a SwiftData Budget model
    init(from budget: Budget) {
        self.id = budget.id
        self.amount = budget.amount
        self.period = budget.period
        self.startDate = budget.startDate
        self.alertThreshold = budget.alertThreshold
        self.isActive = budget.isActive
        self.categoryId = budget.category?.id
        self.isSynced = budget.isSynced
        self.lastModified = budget.lastModified
        self.createdAt = budget.createdAt
    }

    // MARK: - Budget Calculations

    func spentAmount(transactions: [TransactionDTO]) -> Decimal {
        transactions
            .filter { transaction in
                transaction.isExpense &&
                transaction.date >= startDate &&
                transaction.date <= endDate &&
                (categoryId == nil || transaction.categoryId == categoryId)
            }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    func remainingAmount(transactions: [TransactionDTO]) -> Decimal {
        amount - spentAmount(transactions: transactions)
    }

    func progress(transactions: [TransactionDTO]) -> Double {
        let spent = spentAmount(transactions: transactions)
        guard amount > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / amount).doubleValue
    }

    func isOverThreshold(transactions: [TransactionDTO]) -> Bool {
        progress(transactions: transactions) >= alertThreshold
    }

    func isOverBudget(transactions: [TransactionDTO]) -> Bool {
        progress(transactions: transactions) >= 1.0
    }
}

// MARK: - Budget Repository Implementation

/// Firestore repository for Budget entities
@Observable
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
        let dto = BudgetDTO(from: budget)

        do {
            try await collection.document(dto.id).setDataAsync(dto.firestoreData)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateBudget(_ budget: Budget) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()
        let dto = BudgetDTO(from: budget)
        let updatedDTO = BudgetDTO(
            id: dto.id,
            amount: dto.amount,
            period: dto.period,
            startDate: dto.startDate,
            alertThreshold: dto.alertThreshold,
            isActive: dto.isActive,
            categoryId: dto.categoryId,
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

    func fetchBudgets() async throws -> [BudgetDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let snapshot = try await collection
                .order(by: "createdAt", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try BudgetDTO(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func calculateSpending(for budget: BudgetDTO, transactions: [TransactionDTO]) -> Decimal {
        budget.spentAmount(transactions: transactions)
    }

    // MARK: - Real-time Listener

    func observeBudgets() -> AsyncStream<[BudgetDTO]> {
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

                    let budgets = documents.compactMap { doc -> BudgetDTO? in
                        try? BudgetDTO(from: doc)
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
    func fetchActiveBudgets() async throws -> [BudgetDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let snapshot = try await collection
                .whereField("isActive", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try BudgetDTO(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches budgets for a specific category
    func fetchBudgetsByCategory(categoryId: String) async throws -> [BudgetDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let snapshot = try await collection
                .whereField("categoryId", isEqualTo: categoryId)
                .order(by: "createdAt", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try BudgetDTO(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches budgets by period
    func fetchBudgetsByPeriod(_ period: BudgetPeriod) async throws -> [BudgetDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let snapshot = try await collection
                .whereField("period", isEqualTo: period.rawValue)
                .order(by: "createdAt", descending: true)
                .getDocumentsAsync()

            return try snapshot.documents.map { try BudgetDTO(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches a single budget by ID
    func fetchBudget(id: String) async throws -> BudgetDTO? {
        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()

        do {
            let document = try await collection.document(id).getDocument()
            guard document.exists else { return nil }
            return try BudgetDTO(from: document)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Calculates spending for a budget directly from Firestore transactions
    func calculateSpendingFromFirestore(for budget: BudgetDTO, transactionRepository: TransactionRepository) async throws -> Decimal {
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
    func fetchAlertBudgets(transactions: [TransactionDTO]) async throws -> [BudgetDTO] {
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

    /// Batch sync multiple budgets
    func batchSyncBudgets(_ budgets: [Budget]) async throws {
        guard !budgets.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let collection = try budgetsCollection()
        let batchWriter = FirestoreBatchWriter(firestore: db)

        for budget in budgets {
            let dto = BudgetDTO(from: budget)
            let docRef = collection.document(dto.id)
            batchWriter.set(dto.firestoreData, forDocument: docRef)

            if batchWriter.isFull {
                try await batchWriter.commit()
            }
        }

        if batchWriter.count > 0 {
            try await batchWriter.commit()
        }
    }
}
