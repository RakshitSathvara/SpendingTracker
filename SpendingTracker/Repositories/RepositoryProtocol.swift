//
//  RepositoryProtocol.swift
//  SpendingTracker
//
//  Created by Claude on 2026-01-31.
//

import Foundation
import FirebaseFirestore

// MARK: - Repository Errors

/// Errors that can occur during repository operations
enum RepositoryError: Error, LocalizedError {
    case notAuthenticated
    case documentNotFound(String)
    case invalidData(String)
    case syncFailed(String)
    case batchWriteFailed(String)
    case networkError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .documentNotFound(let id):
            return "Document not found: \(id)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        case .batchWriteFailed(let reason):
            return "Batch write failed: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Base Repository Protocol

/// Base protocol that all repositories conform to
protocol RepositoryProtocol {
    associatedtype Entity

    /// Adds a new entity to Firestore
    func add(_ entity: Entity) async throws

    /// Updates an existing entity in Firestore
    func update(_ entity: Entity) async throws

    /// Deletes an entity by its ID
    func delete(id: String) async throws

    /// Fetches all entities
    func fetchAll() async throws -> [Entity]
}

// MARK: - Observable Repository Protocol

/// Protocol for repositories that support real-time listeners
protocol ObservableRepositoryProtocol: RepositoryProtocol {
    /// Returns an AsyncStream that emits updates when data changes
    func observe() -> AsyncStream<[Entity]>
}

// MARK: - Firestore Helper Extensions

extension DocumentReference {
    /// Sets data with merge option and returns when complete
    func setDataAsync(_ data: [String: Any], merge: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.setData(data, merge: merge) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

extension CollectionReference {
    /// Adds a document and returns when complete
    func addDocumentAsync(data: [String: Any]) async throws -> DocumentReference {
        try await withCheckedThrowingContinuation { continuation in
            var ref: DocumentReference?
            ref = self.addDocument(data: data) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let ref = ref {
                    continuation.resume(returning: ref)
                } else {
                    continuation.resume(throwing: RepositoryError.unknown(NSError(domain: "Firestore", code: -1)))
                }
            }
        }
    }
}

extension Query {
    /// Executes the query and returns documents
    func getDocumentsAsync() async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            self.getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: RepositoryError.unknown(NSError(domain: "Firestore", code: -1)))
                }
            }
        }
    }
}

// MARK: - Batch Write Helper

/// Helper class for performing atomic batch writes to Firestore
final class FirestoreBatchWriter {
    private let db: Firestore
    private var batch: WriteBatch
    private var operationCount: Int = 0
    private let maxOperationsPerBatch = 500 // Firestore limit

    init(firestore: Firestore = Firestore.firestore()) {
        self.db = firestore
        self.batch = firestore.batch()
    }

    /// Adds a set operation to the batch
    func set(_ data: [String: Any], forDocument ref: DocumentReference, merge: Bool = false) {
        if merge {
            batch.setData(data, forDocument: ref, merge: true)
        } else {
            batch.setData(data, forDocument: ref)
        }
        operationCount += 1
    }

    /// Adds an update operation to the batch
    func update(_ data: [String: Any], forDocument ref: DocumentReference) {
        batch.updateData(data, forDocument: ref)
        operationCount += 1
    }

    /// Adds a delete operation to the batch
    func delete(_ ref: DocumentReference) {
        batch.deleteDocument(ref)
        operationCount += 1
    }

    /// Returns whether the batch has reached its limit
    var isFull: Bool {
        operationCount >= maxOperationsPerBatch
    }

    /// Returns the number of operations in the batch
    var count: Int {
        operationCount
    }

    /// Commits the batch and returns when complete
    func commit() async throws {
        guard operationCount > 0 else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error = error {
                    continuation.resume(throwing: RepositoryError.batchWriteFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }

        // Reset for potential reuse
        batch = db.batch()
        operationCount = 0
    }
}

// MARK: - Firestore Path Constants

/// Constants for Firestore collection paths
enum FirestorePath {
    // User collections
    static let users = "users"
    static let transactions = "transactions"
    static let categories = "categories"
    static let accounts = "accounts"
    static let budgets = "budgets"
    static let profile = "profile"

    // Family collections
    static let families = "families"
    static let members = "members"
    static let sharedTransactions = "transactions"
    static let sharedBudgets = "budgets"
    static let sharedCategories = "categories"
    static let userFamilies = "families" // Subcollection under users

    /// Returns the user document reference for the given user ID
    static func userDocument(userId: String) -> String {
        "\(users)/\(userId)"
    }

    /// Returns the transactions collection path for the given user
    static func transactionsCollection(userId: String) -> String {
        "\(users)/\(userId)/\(transactions)"
    }

    /// Returns the categories collection path for the given user
    static func categoriesCollection(userId: String) -> String {
        "\(users)/\(userId)/\(categories)"
    }

    /// Returns the accounts collection path for the given user
    static func accountsCollection(userId: String) -> String {
        "\(users)/\(userId)/\(accounts)"
    }

    /// Returns the budgets collection path for the given user
    static func budgetsCollection(userId: String) -> String {
        "\(users)/\(userId)/\(budgets)"
    }

    // MARK: - Family Paths

    /// Returns the family document path for the given family ID
    static func familyDocument(familyId: String) -> String {
        "\(families)/\(familyId)"
    }

    /// Returns the members collection path for the given family
    static func familyMembersCollection(familyId: String) -> String {
        "\(families)/\(familyId)/\(members)"
    }

    /// Returns the shared transactions collection path for the given family
    static func familyTransactionsCollection(familyId: String) -> String {
        "\(families)/\(familyId)/\(sharedTransactions)"
    }

    /// Returns the shared budgets collection path for the given family
    static func familyBudgetsCollection(familyId: String) -> String {
        "\(families)/\(familyId)/\(sharedBudgets)"
    }

    /// Returns the shared categories collection path for the given family
    static func familyCategoriesCollection(familyId: String) -> String {
        "\(families)/\(familyId)/\(sharedCategories)"
    }

    /// Returns the user's families collection path (list of families user belongs to)
    static func userFamiliesCollection(userId: String) -> String {
        "\(users)/\(userId)/\(userFamilies)"
    }
}
