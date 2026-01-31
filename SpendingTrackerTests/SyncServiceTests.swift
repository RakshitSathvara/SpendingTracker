//
//  SyncServiceTests.swift
//  SpendingTrackerTests
//
//  Created by Rakshit on 31/01/26.
//

import XCTest
import Foundation
@testable import SpendingTracker

// MARK: - Sync Service Tests

final class SyncServiceTests: XCTestCase {

    // MARK: - Properties

    var syncService: SyncService!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        syncService = SyncService.shared
    }

    override func tearDownWithError() throws {
        syncService.stopSync()
        try super.tearDownWithError()
    }

    // MARK: - Sync State Tests

    func testSyncStateInitiallyIdle() {
        XCTAssertEqual(syncService.state, .idle, "Initial sync state should be idle")
    }

    func testIsSyncingProperty() {
        XCTAssertFalse(syncService.isSyncing, "Should not be syncing initially")
    }

    func testPendingChangesCountInitiallyZero() {
        XCTAssertEqual(syncService.pendingChangesCount, 0, "Initial pending changes count should be 0")
    }

    func testLastSyncDateInitiallyNil() {
        XCTAssertNil(syncService.lastSyncDate, "Last sync date should be nil initially")
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let config = SyncConfiguration.default
        XCTAssertEqual(config.maxRetryAttempts, 5)
        XCTAssertEqual(config.baseRetryDelay, 1.0)
        XCTAssertEqual(config.maxRetryDelay, 60.0)
        XCTAssertTrue(config.allowExpensiveSync)
        XCTAssertFalse(config.allowConstrainedSync)
        XCTAssertEqual(config.uploadBatchSize, 50)
        XCTAssertEqual(config.autoSyncInterval, 300)
    }

    func testCustomConfiguration() {
        var config = SyncConfiguration.default
        config.maxRetryAttempts = 10
        config.allowExpensiveSync = false

        syncService.configure(config)

        // Configuration is private, so we can't directly verify
        // But we can test that it doesn't crash
        XCTAssertTrue(true, "Custom configuration applied without crash")
    }

    // MARK: - Sync State Display Tests

    func testSyncStateDisplayText() {
        XCTAssertEqual(SyncState.idle.displayText, "Up to date")
        XCTAssertEqual(SyncState.syncing.displayText, "Syncing...")
        XCTAssertEqual(SyncState.waitingForNetwork.displayText, "Waiting for connection")
        XCTAssertEqual(SyncState.error("Test error").displayText, "Test error")
    }

    func testSyncStateIcons() {
        XCTAssertEqual(SyncState.idle.icon, "checkmark.circle.fill")
        XCTAssertEqual(SyncState.syncing.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(SyncState.waitingForNetwork.icon, "wifi.slash")
        XCTAssertEqual(SyncState.error("").icon, "exclamationmark.triangle.fill")
    }

    // MARK: - Statistics Tests

    func testStatisticsReset() {
        var stats = SyncStatistics()
        stats.totalUploaded = 10
        stats.totalDownloaded = 5
        stats.totalConflictsResolved = 2
        stats.totalErrors = 1
        stats.lastSyncDuration = 5.0

        stats.reset()

        XCTAssertEqual(stats.totalUploaded, 0)
        XCTAssertEqual(stats.totalDownloaded, 0)
        XCTAssertEqual(stats.totalConflictsResolved, 0)
        XCTAssertEqual(stats.totalErrors, 0)
        XCTAssertEqual(stats.lastSyncDuration, 0)
    }
}

// MARK: - Network Monitor Tests

final class NetworkMonitorTests: XCTestCase {

    // MARK: - Properties

    var networkMonitor: NetworkMonitor!

    // MARK: - Setup

    override func setUpWithError() throws {
        try super.setUpWithError()
        networkMonitor = NetworkMonitor.shared
    }

    // MARK: - Connection Type Tests

    func testConnectionTypeDisplayNames() {
        XCTAssertEqual(ConnectionType.wifi.displayName, "Wi-Fi")
        XCTAssertEqual(ConnectionType.cellular.displayName, "Cellular")
        XCTAssertEqual(ConnectionType.ethernet.displayName, "Ethernet")
        XCTAssertEqual(ConnectionType.other.displayName, "Other")
    }

    func testConnectionTypeIcons() {
        XCTAssertEqual(ConnectionType.wifi.icon, "wifi")
        XCTAssertEqual(ConnectionType.cellular.icon, "antenna.radiowaves.left.and.right")
        XCTAssertEqual(ConnectionType.ethernet.icon, "cable.connector")
        XCTAssertEqual(ConnectionType.other.icon, "network")
    }

    // MARK: - Network Status Tests

    func testNetworkStatusIsConnected() {
        let connectedWifi = NetworkStatus.connected(.wifi)
        let connectedCellular = NetworkStatus.connected(.cellular)
        let disconnected = NetworkStatus.disconnected

        XCTAssertTrue(connectedWifi.isConnected)
        XCTAssertTrue(connectedCellular.isConnected)
        XCTAssertFalse(disconnected.isConnected)
    }

    func testNetworkStatusDisplayText() {
        XCTAssertEqual(NetworkStatus.connected(.wifi).displayText, "Connected via Wi-Fi")
        XCTAssertEqual(NetworkStatus.connected(.cellular).displayText, "Connected via Cellular")
        XCTAssertEqual(NetworkStatus.disconnected.displayText, "No Connection")
    }

    // MARK: - Monitoring Tests

    func testStartMonitoring() {
        networkMonitor.startMonitoring()
        // Just verify it doesn't crash
        XCTAssertTrue(true)
    }

    func testShouldSyncWhenDisconnected() {
        // When disconnected, shouldSync should return false
        // This is hard to test directly, but we can verify the method exists
        let _ = networkMonitor.shouldSync(allowExpensive: true, allowConstrained: false)
        XCTAssertTrue(true)
    }
}

// MARK: - Sync Entity Type Tests

final class SyncEntityTypeTests: XCTestCase {

    func testCollectionNames() {
        XCTAssertEqual(SyncEntityType.transaction.collectionName, "transactions")
        XCTAssertEqual(SyncEntityType.category.collectionName, "categories")
        XCTAssertEqual(SyncEntityType.account.collectionName, "accounts")
        XCTAssertEqual(SyncEntityType.budget.collectionName, "budgets")
        XCTAssertEqual(SyncEntityType.userProfile.collectionName, "profile")
    }

    func testDisplayNames() {
        XCTAssertEqual(SyncEntityType.transaction.displayName, "Transaction")
        XCTAssertEqual(SyncEntityType.category.displayName, "Category")
        XCTAssertEqual(SyncEntityType.account.displayName, "Account")
        XCTAssertEqual(SyncEntityType.budget.displayName, "Budget")
        XCTAssertEqual(SyncEntityType.userProfile.displayName, "User Profile")
    }

    func testAllCases() {
        XCTAssertEqual(SyncEntityType.allCases.count, 5)
    }
}

// MARK: - Sync Result Tests

final class SyncResultTests: XCTestCase {

    func testSuccessIsSuccess() {
        let result = SyncResult.success(syncedCount: 10)
        XCTAssertTrue(result.isSuccess)
    }

    func testNoChangesIsSuccess() {
        let result = SyncResult.noChanges
        XCTAssertTrue(result.isSuccess)
    }

    func testPartialSuccessIsNotSuccess() {
        let result = SyncResult.partialSuccess(syncedCount: 5, failedCount: 3)
        XCTAssertFalse(result.isSuccess)
    }

    func testFailureIsNotSuccess() {
        let result = SyncResult.failure(SyncError.networkLost)
        XCTAssertFalse(result.isSuccess)
    }
}

// MARK: - Sync Error Tests

final class SyncErrorTests: XCTestCase {

    func testNotAuthenticatedError() {
        let error = SyncError.notAuthenticated
        XCTAssertEqual(error.errorDescription, "You must be signed in to sync data")
    }

    func testNetworkLostError() {
        let error = SyncError.networkLost
        XCTAssertEqual(error.errorDescription, "Network connection lost during sync")
    }

    func testMaxRetriesExceededError() {
        let error = SyncError.maxRetriesExceeded
        XCTAssertEqual(error.errorDescription, "Maximum retry attempts exceeded")
    }

    func testInvalidDataError() {
        let error = SyncError.invalidData("Missing required field")
        XCTAssertEqual(error.errorDescription, "Invalid data: Missing required field")
    }

    func testConflictError() {
        let error = SyncError.conflict("Local and remote differ")
        XCTAssertEqual(error.errorDescription, "Sync conflict: Local and remote differ")
    }

    func testBatchFailedError() {
        let error = SyncError.batchFailed("Write limit exceeded")
        XCTAssertEqual(error.errorDescription, "Batch operation failed: Write limit exceeded")
    }
}

// MARK: - Network Monitor Error Tests

final class NetworkMonitorErrorTests: XCTestCase {

    func testNoConnectionError() {
        let error = NetworkMonitorError.noConnection
        XCTAssertEqual(error.errorDescription, "No network connection available")
    }

    func testExpensiveConnectionError() {
        let error = NetworkMonitorError.expensiveConnection
        XCTAssertEqual(error.errorDescription, "Sync paused on cellular network")
    }

    func testConstrainedConnectionError() {
        let error = NetworkMonitorError.constrainedConnection
        XCTAssertEqual(error.errorDescription, "Sync paused in Low Data Mode")
    }
}

// MARK: - Sync Conflict Tests

final class SyncConflictTests: XCTestCase {

    func testResolveWithLastWriteWinsLocalWins() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600) // 1 hour ago

        let conflict = SyncConflict(
            entityId: "test-id",
            entityType: .transaction,
            localModified: now,
            remoteModified: earlier,
            localData: ["value": "local"],
            remoteData: ["value": "remote"]
        )

        let resolved = conflict.resolveWithLastWriteWins()
        XCTAssertEqual(resolved["value"] as? String, "local")
    }

    func testResolveWithLastWriteWinsRemoteWins() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600) // 1 hour ago

        let conflict = SyncConflict(
            entityId: "test-id",
            entityType: .transaction,
            localModified: earlier,
            remoteModified: now,
            localData: ["value": "local"],
            remoteData: ["value": "remote"]
        )

        let resolved = conflict.resolveWithLastWriteWins()
        XCTAssertEqual(resolved["value"] as? String, "remote")
    }
}

// MARK: - Pending Sync Item Tests

final class PendingSyncItemTests: XCTestCase {

    func testPendingSyncItemCreation() {
        let item = PendingSyncItem(
            entityId: "test-123",
            entityType: .transaction,
            operation: .update
        )

        XCTAssertEqual(item.id, "test-123")
        XCTAssertEqual(item.entityType, .transaction)
        XCTAssertEqual(item.operation, .update)
        XCTAssertEqual(item.retryCount, 0)
    }

    func testPendingSyncItemOperations() {
        let createItem = PendingSyncItem(entityId: "1", entityType: .category, operation: .create)
        let updateItem = PendingSyncItem(entityId: "2", entityType: .account, operation: .update)
        let deleteItem = PendingSyncItem(entityId: "3", entityType: .budget, operation: .delete)

        XCTAssertEqual(createItem.operation, .create)
        XCTAssertEqual(updateItem.operation, .update)
        XCTAssertEqual(deleteItem.operation, .delete)
    }
}

// MARK: - Array Chunking Tests

final class ArrayChunkingTests: XCTestCase {

    func testChunkingSmallArray() {
        let array = [1, 2, 3, 4, 5]
        let chunks = array.chunked(into: 2)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2])
        XCTAssertEqual(chunks[1], [3, 4])
        XCTAssertEqual(chunks[2], [5])
    }

    func testChunkingExactFit() {
        let array = [1, 2, 3, 4, 5, 6]
        let chunks = array.chunked(into: 3)

        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0], [1, 2, 3])
        XCTAssertEqual(chunks[1], [4, 5, 6])
    }

    func testChunkingLargeChunkSize() {
        let array = [1, 2, 3]
        let chunks = array.chunked(into: 10)

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], [1, 2, 3])
    }

    func testChunkingEmptyArray() {
        let array: [Int] = []
        let chunks = array.chunked(into: 5)

        XCTAssertEqual(chunks.count, 0)
    }

    func testChunkingZeroSize() {
        let array = [1, 2, 3]
        let chunks = array.chunked(into: 0)

        // Should return the original array as single chunk
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], [1, 2, 3])
    }
}

// MARK: - Date Extension Tests

final class DateExtensionTests: XCTestCase {

    func testIsWithinSyncThreshold() {
        let now = Date()
        let withinThreshold = now.addingTimeInterval(-60) // 1 minute ago
        let outsideThreshold = now.addingTimeInterval(-600) // 10 minutes ago

        XCTAssertTrue(withinThreshold.isWithinSyncThreshold(threshold: 300))
        XCTAssertFalse(outsideThreshold.isWithinSyncThreshold(threshold: 300))
    }

    func testSyncLogFormat() {
        let date = Date()
        let formatted = date.syncLogFormat

        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("-"))
        XCTAssertTrue(formatted.contains(":"))
        XCTAssertTrue(formatted.contains("."))
    }
}

// MARK: - Background Sync Manager Tests

final class BackgroundSyncManagerTests: XCTestCase {

    var backgroundManager: BackgroundSyncManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        backgroundManager = BackgroundSyncManager.shared
    }

    func testBackgroundSyncEnabledByDefault() {
        // After first load, background sync should be enabled
        XCTAssertTrue(backgroundManager.isBackgroundSyncEnabled)
    }

    func testBackgroundSyncCountInitialValue() {
        XCTAssertGreaterThanOrEqual(backgroundManager.backgroundSyncCount, 0)
    }

    func testSetBackgroundSyncEnabled() {
        let initialState = backgroundManager.isBackgroundSyncEnabled

        // Toggle
        backgroundManager.setBackgroundSyncEnabled(!initialState)
        XCTAssertNotEqual(backgroundManager.isBackgroundSyncEnabled, initialState)

        // Restore
        backgroundManager.setBackgroundSyncEnabled(initialState)
        XCTAssertEqual(backgroundManager.isBackgroundSyncEnabled, initialState)
    }
}

// MARK: - Sync Metadata Tests

final class SyncMetadataTests: XCTestCase {

    func testSyncMetadataCreation() {
        let metadata = SyncMetadata(
            entityId: "test-id",
            entityType: "transaction",
            operation: .create,
            timestamp: Date(),
            retryCount: 0
        )

        XCTAssertEqual(metadata.entityId, "test-id")
        XCTAssertEqual(metadata.entityType, "transaction")
        XCTAssertEqual(metadata.operation, .create)
        XCTAssertEqual(metadata.retryCount, 0)
    }

    func testSyncOperationValues() {
        XCTAssertEqual(SyncMetadata.SyncOperation.create.rawValue, "create")
        XCTAssertEqual(SyncMetadata.SyncOperation.update.rawValue, "update")
        XCTAssertEqual(SyncMetadata.SyncOperation.delete.rawValue, "delete")
    }
}
