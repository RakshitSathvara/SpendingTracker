//
//  AccountRepository.swift
//  SpendingTracker
//
//  Created by Claude on 2026-01-31.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Account Repository Protocol

/// Protocol defining account repository operations
protocol AccountRepositoryProtocol {
    /// Adds a new account to Firestore
    func addAccount(_ account: Account) async throws

    /// Updates an existing account in Firestore
    func updateAccount(_ account: Account) async throws

    /// Deletes an account by its ID
    func deleteAccount(id: String) async throws

    /// Fetches all accounts
    func fetchAccounts() async throws -> [AccountDTO]

    /// Updates the balance of an account (adjusts initialBalance)
    func updateBalance(accountId: String, amount: Decimal) async throws

    /// Returns an AsyncStream that emits updates when accounts change
    func observeAccounts() -> AsyncStream<[AccountDTO]>

    /// Creates default accounts for a new user
    func createDefaultAccounts() async throws
}

// MARK: - Account DTO

/// Data Transfer Object for Account (decoupled from SwiftData)
struct AccountDTO: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var initialBalance: Decimal
    var accountType: AccountType
    var icon: String
    var colorHex: String
    var currencyCode: String
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: initialBalance as NSDecimalNumber) ?? "\(initialBalance)"
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "initialBalance": NSDecimalNumber(decimal: initialBalance).doubleValue,
            "accountType": accountType.rawValue,
            "icon": icon,
            "colorHex": colorHex,
            "currencyCode": currencyCode,
            "isSynced": true,
            "lastModified": Timestamp(date: lastModified),
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        initialBalance: Decimal = 0,
        accountType: AccountType = .cash,
        icon: String? = nil,
        colorHex: String? = nil,
        currencyCode: String = "INR",
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.initialBalance = initialBalance
        self.accountType = accountType
        self.icon = icon ?? accountType.icon
        self.colorHex = colorHex ?? accountType.defaultColor
        self.currencyCode = currencyCode
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.name = data["name"] as? String ?? "Unknown"
        self.initialBalance = Decimal((data["initialBalance"] as? Double) ?? 0)

        let accountTypeRaw = data["accountType"] as? String ?? AccountType.cash.rawValue
        self.accountType = AccountType(rawValue: accountTypeRaw) ?? .cash

        self.icon = data["icon"] as? String ?? self.accountType.icon
        self.colorHex = data["colorHex"] as? String ?? self.accountType.defaultColor
        self.currencyCode = data["currencyCode"] as? String ?? "INR"
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

    /// Creates an AccountDTO from a SwiftData Account model
    init(from account: Account) {
        self.id = account.id
        self.name = account.name
        self.initialBalance = account.initialBalance
        self.accountType = account.accountType
        self.icon = account.icon
        self.colorHex = account.colorHex
        self.currencyCode = account.currencyCode
        self.isSynced = account.isSynced
        self.lastModified = account.lastModified
        self.createdAt = account.createdAt
    }
}

// MARK: - Account Repository Implementation

/// Firestore repository for Account entities
@Observable
final class AccountRepository: AccountRepositoryProtocol {

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

    private func accountsCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }
        return db.collection(FirestorePath.accountsCollection(userId: userId))
    }

    // MARK: - CRUD Operations

    func addAccount(_ account: Account) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()
        let dto = AccountDTO(from: account)

        do {
            try await collection.document(dto.id).setDataAsync(dto.firestoreData)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateAccount(_ account: Account) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()
        let dto = AccountDTO(from: account)
        let updatedDTO = AccountDTO(
            id: dto.id,
            name: dto.name,
            initialBalance: dto.initialBalance,
            accountType: dto.accountType,
            icon: dto.icon,
            colorHex: dto.colorHex,
            currencyCode: dto.currencyCode,
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

    func deleteAccount(id: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        do {
            try await collection.document(id).delete()
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchAccounts() async throws -> [AccountDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        do {
            let snapshot = try await collection
                .order(by: "createdAt")
                .getDocumentsAsync()

            return try snapshot.documents.map { try AccountDTO(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateBalance(accountId: String, amount: Decimal) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        do {
            // First fetch the current account
            let document = try await collection.document(accountId).getDocument()
            guard document.exists else {
                throw RepositoryError.documentNotFound(accountId)
            }

            var account = try AccountDTO(from: document)
            let newBalance = account.initialBalance + amount

            // Update with new balance
            try await collection.document(accountId).setDataAsync([
                "initialBalance": NSDecimalNumber(decimal: newBalance).doubleValue,
                "lastModified": Timestamp(date: Date())
            ], merge: true)
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    // MARK: - Real-time Listener

    func observeAccounts() -> AsyncStream<[AccountDTO]> {
        AsyncStream { continuation in
            guard let userId = currentUserId else {
                continuation.finish()
                return
            }

            let collection = db.collection(FirestorePath.accountsCollection(userId: userId))

            let listener = collection
                .order(by: "createdAt")
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("AccountRepository listener error: \(error.localizedDescription)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }

                    let accounts = documents.compactMap { doc -> AccountDTO? in
                        try? AccountDTO(from: doc)
                    }

                    continuation.yield(accounts)
                }

            self.listener = listener

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }

    // MARK: - Default Accounts

    func createDefaultAccounts() async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()
        let batchWriter = FirestoreBatchWriter(firestore: db)

        let defaultAccounts: [AccountDTO] = [
            AccountDTO(name: "Cash", accountType: .cash),
            AccountDTO(name: "Bank Account", accountType: .bank),
            AccountDTO(name: "Credit Card", accountType: .credit),
            AccountDTO(name: "Savings", accountType: .savings)
        ]

        for account in defaultAccounts {
            let docRef = collection.document(account.id)
            batchWriter.set(account.firestoreData, forDocument: docRef)
        }

        do {
            try await batchWriter.commit()
        } catch {
            self.error = .batchWriteFailed(error.localizedDescription)
            throw RepositoryError.batchWriteFailed(error.localizedDescription)
        }
    }
}

// MARK: - Account Query Helpers

extension AccountRepository {

    /// Fetches accounts by type
    func fetchAccountsByType(_ type: AccountType) async throws -> [AccountDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        do {
            let snapshot = try await collection
                .whereField("accountType", isEqualTo: type.rawValue)
                .order(by: "createdAt")
                .getDocumentsAsync()

            return try snapshot.documents.map { try AccountDTO(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches a single account by ID
    func fetchAccount(id: String) async throws -> AccountDTO? {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        do {
            let document = try await collection.document(id).getDocument()
            guard document.exists else { return nil }
            return try AccountDTO(from: document)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Calculates total balance across all accounts
    func calculateTotalBalance() async throws -> Decimal {
        let accounts = try await fetchAccounts()
        return accounts.reduce(Decimal(0)) { $0 + $1.initialBalance }
    }

    /// Batch sync multiple accounts
    func batchSyncAccounts(_ accounts: [Account]) async throws {
        guard !accounts.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()
        let batchWriter = FirestoreBatchWriter(firestore: db)

        for account in accounts {
            let dto = AccountDTO(from: account)
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

    /// Transfers balance between two accounts
    func transferBalance(fromAccountId: String, toAccountId: String, amount: Decimal) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        // Fetch both accounts
        let fromDoc = try await collection.document(fromAccountId).getDocument()
        let toDoc = try await collection.document(toAccountId).getDocument()

        guard fromDoc.exists else {
            throw RepositoryError.documentNotFound(fromAccountId)
        }
        guard toDoc.exists else {
            throw RepositoryError.documentNotFound(toAccountId)
        }

        let fromAccount = try AccountDTO(from: fromDoc)
        let toAccount = try AccountDTO(from: toDoc)

        // Use batch write for atomicity
        let batchWriter = FirestoreBatchWriter(firestore: db)
        let now = Date()

        let fromRef = collection.document(fromAccountId)
        let toRef = collection.document(toAccountId)

        batchWriter.update([
            "initialBalance": NSDecimalNumber(decimal: fromAccount.initialBalance - amount).doubleValue,
            "lastModified": Timestamp(date: now)
        ], forDocument: fromRef)

        batchWriter.update([
            "initialBalance": NSDecimalNumber(decimal: toAccount.initialBalance + amount).doubleValue,
            "lastModified": Timestamp(date: now)
        ], forDocument: toRef)

        do {
            try await batchWriter.commit()
        } catch {
            self.error = .batchWriteFailed(error.localizedDescription)
            throw RepositoryError.batchWriteFailed(error.localizedDescription)
        }
    }
}
