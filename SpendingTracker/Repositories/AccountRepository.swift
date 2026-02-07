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
    func fetchAccounts() async throws -> [Account]

    /// Updates the balance of an account (adjusts initialBalance)
    func updateBalance(accountId: String, amount: Decimal) async throws

    /// Returns an AsyncStream that emits updates when accounts change
    func observeAccounts() -> AsyncStream<[Account]>

    /// Creates default accounts for a new user
    func createDefaultAccounts() async throws
}

// MARK: - Account Repository Implementation

/// Firestore repository for Account entities
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

        do {
            try await collection.document(account.id).setDataAsync(account.firestoreData)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateAccount(_ account: Account) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        do {
            try await collection.document(account.id).setDataAsync(account.firestoreData, merge: true)
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

    func fetchAccounts() async throws -> [Account] {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        do {
            let snapshot = try await collection
                .order(by: "createdAt")
                .getDocumentsAsync()

            return try snapshot.documents.map { try Account(from: $0) }
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

            let account = try Account(from: document)
            let newBalance = account.initialBalance + amount

            // Update with new balance
            try await collection.document(accountId).setDataAsync([
                "initialBalance": NSDecimalNumber(decimal: newBalance).doubleValue,
                "lastModified": FieldValue.serverTimestamp()
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

    func observeAccounts() -> AsyncStream<[Account]> {
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

                    let accounts = documents.compactMap { doc -> Account? in
                        try? Account(from: doc)
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

        for account in Account.defaultAccounts {
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
    func fetchAccountsByType(_ type: AccountType) async throws -> [Account] {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        do {
            let snapshot = try await collection
                .whereField("accountType", isEqualTo: type.rawValue)
                .order(by: "createdAt")
                .getDocumentsAsync()

            return try snapshot.documents.map { try Account(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches a single account by ID
    func fetchAccount(id: String) async throws -> Account? {
        isLoading = true
        defer { isLoading = false }

        let collection = try accountsCollection()

        do {
            let document = try await collection.document(id).getDocument()
            guard document.exists else { return nil }
            return try Account(from: document)
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

        let fromAccount = try Account(from: fromDoc)
        let toAccount = try Account(from: toDoc)

        // Use batch write for atomicity
        let batchWriter = FirestoreBatchWriter(firestore: db)

        let fromRef = collection.document(fromAccountId)
        let toRef = collection.document(toAccountId)

        batchWriter.update([
            "initialBalance": NSDecimalNumber(decimal: fromAccount.initialBalance - amount).doubleValue,
            "lastModified": FieldValue.serverTimestamp()
        ], forDocument: fromRef)

        batchWriter.update([
            "initialBalance": NSDecimalNumber(decimal: toAccount.initialBalance + amount).doubleValue,
            "lastModified": FieldValue.serverTimestamp()
        ], forDocument: toRef)

        do {
            try await batchWriter.commit()
        } catch {
            self.error = .batchWriteFailed(error.localizedDescription)
            throw RepositoryError.batchWriteFailed(error.localizedDescription)
        }
    }
}
