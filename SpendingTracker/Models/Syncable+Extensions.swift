//
//  Syncable+Extensions.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation

// MARK: - Transaction + Syncable

extension Transaction: Syncable {
    static var firestoreCollectionPath: String { "transactions" }

    func toFirestoreData() -> [String: Any] {
        return firestoreData
    }
}

// MARK: - Category + Syncable

extension Category: Syncable {
    static var firestoreCollectionPath: String { "categories" }

    func toFirestoreData() -> [String: Any] {
        return firestoreData
    }
}

// MARK: - Account + Syncable

extension Account: Syncable {
    static var firestoreCollectionPath: String { "accounts" }

    func toFirestoreData() -> [String: Any] {
        return firestoreData
    }
}

// MARK: - Budget + Syncable

extension Budget: Syncable {
    static var firestoreCollectionPath: String { "budgets" }

    func toFirestoreData() -> [String: Any] {
        return firestoreData
    }
}

// MARK: - Syncable Helper Methods

extension Syncable {
    /// Create a firestore-ready update dictionary with server timestamp
    func toFirestoreUpdateData() -> [String: Any] {
        var data = toFirestoreData()
        data["isSynced"] = true
        // Note: lastModified will be set to server timestamp by the caller
        return data
    }

    /// Check if this entity needs to be synced
    var needsSync: Bool {
        return !isSynced
    }
}

// MARK: - Array Extensions for Syncable

extension Array where Element: Syncable {
    /// Filter to only unsynced items
    var unsynced: [Element] {
        filter { !$0.isSynced }
    }

    /// Get count of unsynced items
    var unsyncedCount: Int {
        filter { !$0.isSynced }.count
    }

    /// Mark all items as synced
    func markAllAsSynced() {
        for item in self {
            item.isSynced = true
        }
    }

    /// Mark all items for sync
    func markAllForSync() {
        let now = Date()
        for item in self {
            item.isSynced = false
            item.lastModified = now
        }
    }

    /// Get the most recently modified item
    var mostRecentlyModified: Element? {
        self.max { $0.lastModified < $1.lastModified }
    }

    /// Get items modified since a specific date
    func modifiedSince(_ date: Date) -> [Element] {
        filter { $0.lastModified > date }
    }
}

// MARK: - Date Extensions for Sync

extension Date {
    /// Check if the date is within the sync threshold (e.g., 5 minutes)
    func isWithinSyncThreshold(threshold: TimeInterval = 300) -> Bool {
        return abs(timeIntervalSinceNow) < threshold
    }

    /// Format date for sync logging
    var syncLogFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: self)
    }
}
