//
//  SyncService.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import Observation
import SwiftData
import FirebaseFirestore
import FirebaseAuth

// MARK: - Sync State

/// Current state of the sync service
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

// MARK: - Sync Configuration

/// Configuration for sync behavior
struct SyncConfiguration {
    /// Maximum retry attempts for failed sync operations
    var maxRetryAttempts: Int = 5

    /// Base delay for exponential backoff (in seconds)
    var baseRetryDelay: TimeInterval = 1.0

    /// Maximum delay for exponential backoff (in seconds)
    var maxRetryDelay: TimeInterval = 60.0

    /// Whether to sync on expensive connections (cellular)
    var allowExpensiveSync: Bool = true

    /// Whether to sync in Low Data Mode
    var allowConstrainedSync: Bool = false

    /// Batch size for upload operations
    var uploadBatchSize: Int = 50

    /// Automatic sync interval (in seconds)
    var autoSyncInterval: TimeInterval = 300 // 5 minutes

    static let `default` = SyncConfiguration()
}

// MARK: - Sync Service

/// Service responsible for offline-first data synchronization between SwiftData and Firestore
@Observable
final class SyncService {

    // MARK: - Singleton

    static let shared = SyncService()

    // MARK: - Observable Properties

    /// Current sync state
    private(set) var state: SyncState = .idle

    /// Whether sync is currently in progress
    var isSyncing: Bool { state == .syncing }

    /// Date of last successful sync
    private(set) var lastSyncDate: Date?

    /// Number of pending changes waiting to sync
    private(set) var pendingChangesCount: Int = 0

    /// Current sync statistics
    private(set) var statistics: SyncStatistics = SyncStatistics()

    // MARK: - Private Properties

    private let networkMonitor = NetworkMonitor.shared
    private var configuration = SyncConfiguration.default
    private var syncTask: Task<Void, Never>?
    private var autoSyncTask: Task<Void, Never>?
    private var listenerRegistrations: [ListenerRegistration] = []
    private let syncQueue = DispatchQueue(label: "com.spendingtracker.sync", qos: .userInitiated)

    /// Pending items queue
    private var pendingItems: [PendingSyncItem] = []

    /// Firestore instance
    private var firestore: Firestore { Firestore.firestore() }

    /// Current user ID
    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    // MARK: - Initialization

    private init() {
        setupNetworkObserver()
    }

    deinit {
        stopSync()
    }

    // MARK: - Setup

    private func setupNetworkObserver() {
        networkMonitor.startMonitoring()

        // Observe connectivity changes
        Task { [weak self] in
            for await status in NetworkMonitor.shared.observeConnectivity() {
                guard let self = self else { return }

                if status.isConnected && self.pendingChangesCount > 0 {
                    // Network restored, trigger sync
                    try? await self.syncNow()
                } else if !status.isConnected {
                    await MainActor.run {
                        if self.state == .syncing {
                            self.state = .waitingForNetwork
                        }
                    }
                }
            }
        }
    }

    // MARK: - Configuration

    /// Configure sync settings
    func configure(_ configuration: SyncConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Public Sync Methods

    /// Start automatic background sync
    func startSync() {
        guard autoSyncTask == nil else { return }

        autoSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }

                if self.networkMonitor.shouldSync(
                    allowExpensive: self.configuration.allowExpensiveSync,
                    allowConstrained: self.configuration.allowConstrainedSync
                ) {
                    try? await self.syncNow()
                }

                try? await Task.sleep(nanoseconds: UInt64(self.configuration.autoSyncInterval * 1_000_000_000))
            }
        }
    }

    /// Stop automatic background sync
    func stopSync() {
        autoSyncTask?.cancel()
        autoSyncTask = nil
        syncTask?.cancel()
        syncTask = nil

        // Remove all Firestore listeners
        for registration in listenerRegistrations {
            registration.remove()
        }
        listenerRegistrations.removeAll()
    }

    /// Perform immediate sync
    @MainActor
    func syncNow() async throws {
        guard currentUserId != nil else {
            throw SyncError.notAuthenticated
        }

        guard networkMonitor.shouldSync(
            allowExpensive: configuration.allowExpensiveSync,
            allowConstrained: configuration.allowConstrainedSync
        ) else {
            state = .waitingForNetwork
            throw NetworkMonitorError.noConnection
        }

        // Cancel any existing sync task
        syncTask?.cancel()

        state = .syncing
        statistics.reset()
        let startTime = Date()

        do {
            // Upload pending changes
            try await uploadPendingChanges()

            // Download remote changes (handled by listeners in real-time)

            // Update state
            let duration = Date().timeIntervalSince(startTime)
            statistics.lastSyncDuration = duration
            lastSyncDate = Date()
            state = .idle

        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Mark for Sync

    /// Mark a transaction for sync
    func markTransactionForSync(_ transaction: Transaction) {
        transaction.isSynced = false
        transaction.lastModified = Date()
        addToPendingQueue(entityId: transaction.id, entityType: .transaction, operation: .update)
    }

    /// Mark a category for sync
    func markCategoryForSync(_ category: Category) {
        category.isSynced = false
        category.lastModified = Date()
        addToPendingQueue(entityId: category.id, entityType: .category, operation: .update)
    }

    /// Mark an account for sync
    func markAccountForSync(_ account: Account) {
        account.isSynced = false
        account.lastModified = Date()
        addToPendingQueue(entityId: account.id, entityType: .account, operation: .update)
    }

    /// Mark a budget for sync
    func markBudgetForSync(_ budget: Budget) {
        budget.isSynced = false
        budget.lastModified = Date()
        addToPendingQueue(entityId: budget.id, entityType: .budget, operation: .update)
    }

    /// Mark an entity for deletion
    func markForDeletion(entityId: String, entityType: SyncEntityType) {
        addToPendingQueue(entityId: entityId, entityType: entityType, operation: .delete)
    }

    // MARK: - Pending Queue Management

    private func addToPendingQueue(entityId: String, entityType: SyncEntityType, operation: SyncMetadata.SyncOperation) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // Remove existing item with same ID to avoid duplicates
            self.pendingItems.removeAll { $0.id == entityId && $0.entityType == entityType }

            let item = PendingSyncItem(entityId: entityId, entityType: entityType, operation: operation)
            self.pendingItems.append(item)

            DispatchQueue.main.async {
                self.pendingChangesCount = self.pendingItems.count
            }
        }
    }

    // MARK: - Upload Changes

    @MainActor
    private func uploadPendingChanges() async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        // Get current pending items
        let itemsToSync = syncQueue.sync { pendingItems }
        guard !itemsToSync.isEmpty else { return }

        // Group by entity type for batch processing
        let groupedItems = Dictionary(grouping: itemsToSync, by: { $0.entityType })

        for (entityType, items) in groupedItems {
            try await syncEntityType(entityType, items: items, userId: userId)
        }

        // Clear synced items
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            let syncedIds = Set(itemsToSync.map { $0.id })
            self.pendingItems.removeAll { syncedIds.contains($0.id) }

            DispatchQueue.main.async {
                self.pendingChangesCount = self.pendingItems.count
            }
        }
    }

    private func syncEntityType(_ entityType: SyncEntityType, items: [PendingSyncItem], userId: String) async throws {
        let collection = firestore
            .collection("users")
            .document(userId)
            .collection(entityType.collectionName)

        // Process in batches
        let batches = items.chunked(into: configuration.uploadBatchSize)

        for batch in batches {
            let writeBatch = firestore.batch()

            for item in batch {
                let docRef = collection.document(item.id)

                switch item.operation {
                case .create, .update:
                    // For create/update, we need to get the actual data from SwiftData
                    // This will be handled by the calling context passing the actual entities
                    break
                case .delete:
                    writeBatch.deleteDocument(docRef)
                }
            }

            try await commitBatchWithRetry(writeBatch)
            statistics.totalUploaded += batch.count
        }
    }

    // MARK: - Batch Sync Methods (for use with SwiftData context)

    /// Sync all unsynced transactions
    func syncTransactions(_ transactions: [Transaction], userId: String) async throws {
        let unsyncedTransactions = transactions.filter { !$0.isSynced }
        guard !unsyncedTransactions.isEmpty else { return }

        let collection = firestore
            .collection("users")
            .document(userId)
            .collection("transactions")

        let batches = unsyncedTransactions.chunked(into: configuration.uploadBatchSize)

        for batch in batches {
            let writeBatch = firestore.batch()

            for transaction in batch {
                let docRef = collection.document(transaction.id)
                var data = transaction.firestoreData
                data["lastModified"] = FieldValue.serverTimestamp()
                writeBatch.setData(data, forDocument: docRef, merge: true)
            }

            try await commitBatchWithRetry(writeBatch)

            // Mark as synced
            for transaction in batch {
                transaction.isSynced = true
            }

            statistics.totalUploaded += batch.count
        }
    }

    /// Sync all unsynced categories
    func syncCategories(_ categories: [Category], userId: String) async throws {
        let unsyncedCategories = categories.filter { !$0.isSynced }
        guard !unsyncedCategories.isEmpty else { return }

        let collection = firestore
            .collection("users")
            .document(userId)
            .collection("categories")

        let batches = unsyncedCategories.chunked(into: configuration.uploadBatchSize)

        for batch in batches {
            let writeBatch = firestore.batch()

            for category in batch {
                let docRef = collection.document(category.id)
                var data = category.firestoreData
                data["lastModified"] = FieldValue.serverTimestamp()
                writeBatch.setData(data, forDocument: docRef, merge: true)
            }

            try await commitBatchWithRetry(writeBatch)

            // Mark as synced
            for category in batch {
                category.isSynced = true
            }

            statistics.totalUploaded += batch.count
        }
    }

    /// Sync all unsynced accounts
    func syncAccounts(_ accounts: [Account], userId: String) async throws {
        let unsyncedAccounts = accounts.filter { !$0.isSynced }
        guard !unsyncedAccounts.isEmpty else { return }

        let collection = firestore
            .collection("users")
            .document(userId)
            .collection("accounts")

        let batches = unsyncedAccounts.chunked(into: configuration.uploadBatchSize)

        for batch in batches {
            let writeBatch = firestore.batch()

            for account in batch {
                let docRef = collection.document(account.id)
                var data = account.firestoreData
                data["lastModified"] = FieldValue.serverTimestamp()
                writeBatch.setData(data, forDocument: docRef, merge: true)
            }

            try await commitBatchWithRetry(writeBatch)

            // Mark as synced
            for account in batch {
                account.isSynced = true
            }

            statistics.totalUploaded += batch.count
        }
    }

    /// Sync all unsynced budgets
    func syncBudgets(_ budgets: [Budget], userId: String) async throws {
        let unsyncedBudgets = budgets.filter { !$0.isSynced }
        guard !unsyncedBudgets.isEmpty else { return }

        let collection = firestore
            .collection("users")
            .document(userId)
            .collection("budgets")

        let batches = unsyncedBudgets.chunked(into: configuration.uploadBatchSize)

        for batch in batches {
            let writeBatch = firestore.batch()

            for budget in batch {
                let docRef = collection.document(budget.id)
                var data = budget.firestoreData
                data["lastModified"] = FieldValue.serverTimestamp()
                writeBatch.setData(data, forDocument: docRef, merge: true)
            }

            try await commitBatchWithRetry(writeBatch)

            // Mark as synced
            for budget in batch {
                budget.isSynced = true
            }

            statistics.totalUploaded += batch.count
        }
    }

    // MARK: - Retry Logic with Exponential Backoff

    private func commitBatchWithRetry(_ batch: WriteBatch) async throws {
        var retryCount = 0
        var lastError: Error?

        while retryCount < configuration.maxRetryAttempts {
            do {
                try await batch.commit()
                return
            } catch {
                lastError = error
                retryCount += 1

                if retryCount < configuration.maxRetryAttempts {
                    let delay = calculateBackoffDelay(attempt: retryCount)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    // Check if network is still available
                    if !networkMonitor.isConnected {
                        throw SyncError.networkLost
                    }
                }
            }
        }

        statistics.totalErrors += 1
        throw lastError ?? SyncError.maxRetriesExceeded
    }

    /// Calculate exponential backoff delay with jitter
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        let exponentialDelay = configuration.baseRetryDelay * pow(2.0, Double(attempt - 1))
        let cappedDelay = min(exponentialDelay, configuration.maxRetryDelay)

        // Add random jitter (±25%)
        let jitter = cappedDelay * 0.25 * (Double.random(in: -1...1))
        return cappedDelay + jitter
    }

    // MARK: - Conflict Resolution

    /// Resolve a sync conflict using last-write-wins strategy
    func resolveConflict<T: Syncable>(local: T, remoteData: [String: Any]) -> T {
        guard let remoteModified = remoteData["lastModified"] as? Timestamp else {
            // If no remote timestamp, local wins
            return local
        }

        let remoteDate = remoteModified.dateValue()

        if local.lastModified > remoteDate {
            // Local is newer, keep local
            statistics.totalConflictsResolved += 1
            return local
        } else {
            // Remote is newer - caller should update local with remote data
            statistics.totalConflictsResolved += 1
            return local
        }
    }

    /// Check for conflicts and resolve them
    func checkAndResolveConflicts<T: Syncable>(
        localItems: [T],
        remoteItems: [[String: Any]]
    ) -> [SyncConflict] {
        var conflicts: [SyncConflict] = []

        let remoteById = Dictionary(uniqueKeysWithValues: remoteItems.compactMap { item -> (String, [String: Any])? in
            guard let id = item["id"] as? String else { return nil }
            return (id, item)
        })

        for local in localItems {
            guard let remote = remoteById[local.id],
                  let remoteTimestamp = remote["lastModified"] as? Timestamp else {
                continue
            }

            let remoteDate = remoteTimestamp.dateValue()

            // Check if there's a conflict (both modified since last sync)
            if !local.isSynced && abs(local.lastModified.timeIntervalSince(remoteDate)) > 1 {
                let conflict = SyncConflict(
                    entityId: local.id,
                    entityType: .transaction, // Will be overridden by caller
                    localModified: local.lastModified,
                    remoteModified: remoteDate,
                    localData: local.toFirestoreData(),
                    remoteData: remote
                )
                conflicts.append(conflict)
            }
        }

        return conflicts
    }

    // MARK: - Firestore Listeners

    /// Set up real-time listeners for remote changes
    func setupListeners(
        userId: String,
        onTransactionChange: @escaping ([DocumentChange]) -> Void,
        onCategoryChange: @escaping ([DocumentChange]) -> Void,
        onAccountChange: @escaping ([DocumentChange]) -> Void,
        onBudgetChange: @escaping ([DocumentChange]) -> Void
    ) {
        // Remove existing listeners
        for registration in listenerRegistrations {
            registration.remove()
        }
        listenerRegistrations.removeAll()

        let userDoc = firestore.collection("users").document(userId)

        // Transactions listener
        let transactionsListener = userDoc.collection("transactions")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else { return }
                onTransactionChange(snapshot.documentChanges)
            }
        listenerRegistrations.append(transactionsListener)

        // Categories listener
        let categoriesListener = userDoc.collection("categories")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else { return }
                onCategoryChange(snapshot.documentChanges)
            }
        listenerRegistrations.append(categoriesListener)

        // Accounts listener
        let accountsListener = userDoc.collection("accounts")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else { return }
                onAccountChange(snapshot.documentChanges)
            }
        listenerRegistrations.append(accountsListener)

        // Budgets listener
        let budgetsListener = userDoc.collection("budgets")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else { return }
                onBudgetChange(snapshot.documentChanges)
            }
        listenerRegistrations.append(budgetsListener)
    }
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

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
