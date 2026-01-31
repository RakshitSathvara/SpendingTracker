//
//  Syncable.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Syncable Protocol

/// Protocol for entities that can be synchronized between SwiftData and Firestore
protocol Syncable: AnyObject {
    /// Unique identifier for the entity
    var id: String { get }

    /// Whether the entity has been synced to Firestore
    var isSynced: Bool { get set }

    /// Last modification timestamp for conflict resolution
    var lastModified: Date { get set }

    /// Creation timestamp
    var createdAt: Date { get }

    /// Convert entity to Firestore document data
    func toFirestoreData() -> [String: Any]

    /// The Firestore collection path for this entity type
    static var firestoreCollectionPath: String { get }
}

// MARK: - Syncable Default Implementation

extension Syncable {
    /// Mark entity as needing sync
    func markForSync() {
        isSynced = false
        lastModified = Date()
    }

    /// Mark entity as synced
    func markAsSynced() {
        isSynced = true
    }
}

// MARK: - Sync Metadata

/// Metadata about sync operations
struct SyncMetadata: Codable {
    let entityId: String
    let entityType: String
    let operation: SyncOperation
    let timestamp: Date
    let retryCount: Int

    enum SyncOperation: String, Codable {
        case create
        case update
        case delete
    }
}

// MARK: - Pending Sync Item

/// Represents a pending sync operation
struct PendingSyncItem: Identifiable {
    let id: String
    let entityType: SyncEntityType
    let operation: SyncMetadata.SyncOperation
    var retryCount: Int
    let createdAt: Date

    init(entityId: String, entityType: SyncEntityType, operation: SyncMetadata.SyncOperation) {
        self.id = entityId
        self.entityType = entityType
        self.operation = operation
        self.retryCount = 0
        self.createdAt = Date()
    }
}

// MARK: - Sync Entity Type

/// Types of entities that can be synced
enum SyncEntityType: String, CaseIterable, Codable {
    case transaction
    case category
    case account
    case budget
    case userProfile

    var collectionName: String {
        switch self {
        case .transaction: return "transactions"
        case .category: return "categories"
        case .account: return "accounts"
        case .budget: return "budgets"
        case .userProfile: return "profile"
        }
    }

    var displayName: String {
        switch self {
        case .transaction: return "Transaction"
        case .category: return "Category"
        case .account: return "Account"
        case .budget: return "Budget"
        case .userProfile: return "User Profile"
        }
    }
}

// MARK: - Sync Result

/// Result of a sync operation
enum SyncResult {
    case success(syncedCount: Int)
    case partialSuccess(syncedCount: Int, failedCount: Int)
    case failure(Error)
    case noChanges

    var isSuccess: Bool {
        switch self {
        case .success, .noChanges: return true
        case .partialSuccess, .failure: return false
        }
    }
}

// MARK: - Sync Conflict

/// Represents a sync conflict between local and remote data
struct SyncConflict {
    let entityId: String
    let entityType: SyncEntityType
    let localModified: Date
    let remoteModified: Date
    let localData: [String: Any]
    let remoteData: [String: Any]

    /// Resolve conflict using last-write-wins strategy
    func resolveWithLastWriteWins() -> [String: Any] {
        if localModified > remoteModified {
            return localData
        } else {
            return remoteData
        }
    }
}

// MARK: - Sync Statistics

/// Statistics about sync operations
struct SyncStatistics {
    var totalUploaded: Int = 0
    var totalDownloaded: Int = 0
    var totalConflictsResolved: Int = 0
    var totalErrors: Int = 0
    var lastSyncDuration: TimeInterval = 0

    mutating func reset() {
        totalUploaded = 0
        totalDownloaded = 0
        totalConflictsResolved = 0
        totalErrors = 0
        lastSyncDuration = 0
    }
}
