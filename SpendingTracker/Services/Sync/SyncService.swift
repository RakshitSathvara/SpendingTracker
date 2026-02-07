//
//  SyncService.swift
//  SpendingTracker
//
//  Deprecated: App now uses cloud-only architecture.
//  This file kept as a minimal stub to prevent build errors.
//

import Foundation

// MARK: - Sync Entity Type

enum SyncEntityType: String {
    case transaction
    case category
    case account
    case budget

    var collectionName: String {
        self.rawValue
    }
}

// MARK: - Sync State

enum SyncState: Equatable {
    case idle
    case syncing
    case waitingForNetwork
    case error(String)

    var displayText: String {
        switch self {
        case .idle: return "Up to date"
        case .syncing: return "Syncing..."
        case .waitingForNetwork: return "Waiting for connection"
        case .error(let message): return message
        }
    }

    var icon: String {
        switch self {
        case .idle: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .waitingForNetwork: return "wifi.slash"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Sync Service

/// Deprecated: Minimal stub for cloud-only architecture.
/// All data operations now go directly to Firestore.
@Observable
final class SyncService {
    static let shared = SyncService()

    var syncState: SyncState = .idle
    var lastSyncDate: Date?
    var isSyncing: Bool { syncState == .syncing }
    var pendingChangesCount: Int = 0
    var statistics = SyncStatistics()

    /// Alias so views can use `state` instead of `syncState`
    var state: SyncState { syncState }

    private init() {}

    /// No-op: Sync is handled automatically by Firestore
    func startSync() {}

    /// No-op: Sync is handled automatically by Firestore
    func stopSync() {}

    /// No-op: Sync is handled automatically by Firestore
    func syncNow() async throws {}
}

// MARK: - Supporting Types (for backwards compatibility)

struct PendingSyncItem {
    let id: String
    let entityType: SyncEntityType
    let operation: SyncMetadata.SyncOperation
}

struct SyncMetadata {
    enum SyncOperation {
        case create
        case update
        case delete
    }
}

struct SyncStatistics {
    var totalUploaded = 0
    var totalDownloaded = 0
    var totalErrors = 0
    var totalConflictsResolved = 0
    var lastSyncDuration: TimeInterval = 0

    mutating func reset() {
        totalUploaded = 0
        totalDownloaded = 0
        totalErrors = 0
        totalConflictsResolved = 0
        lastSyncDuration = 0
    }
}

struct SyncConflict {
    let entityId: String
    let entityType: SyncEntityType
    let localModified: Date
    let remoteModified: Date
    let localData: [String: Any]
    let remoteData: [String: Any]
}

protocol Syncable {
    var id: String { get }
    var isSynced: Bool { get set }
    var lastModified: Date { get set }
    func toFirestoreData() -> [String: Any]
}

// MARK: - Sync Error

enum SyncError: LocalizedError {
    case notAuthenticated
    case networkLost
    case maxRetriesExceeded
    case invalidData(String)
    case conflict(String)
    case batchFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to sync data"
        case .networkLost:
            return "Network connection lost during sync"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .conflict(let details):
            return "Sync conflict: \(details)"
        case .batchFailed(let reason):
            return "Batch operation failed: \(reason)"
        }
    }
}
