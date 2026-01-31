//
//  BackgroundSyncManager.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import BackgroundTasks
import UIKit
import Observation
import SwiftData
import FirebaseAuth

// MARK: - Background Task Identifiers

/// Identifiers for background tasks
enum BackgroundTaskIdentifier {
    /// Periodic sync refresh task
    static let refresh = "com.spendingtracker.sync.refresh"

    /// Heavy processing sync task (runs during charging)
    static let processing = "com.spendingtracker.sync.processing"
}

// MARK: - Background Sync Manager

/// Manages background sync operations using BGTaskScheduler
@Observable
final class BackgroundSyncManager {

    // MARK: - Singleton

    static let shared = BackgroundSyncManager()

    // MARK: - Observable Properties

    /// Whether background sync is enabled
    private(set) var isBackgroundSyncEnabled: Bool = true

    /// Last background sync date
    private(set) var lastBackgroundSyncDate: Date?

    /// Next scheduled sync date
    private(set) var nextScheduledSyncDate: Date?

    /// Number of background syncs completed
    private(set) var backgroundSyncCount: Int = 0

    // MARK: - Private Properties

    private let syncService = SyncService.shared
    private let networkMonitor = NetworkMonitor.shared

    /// Minimum interval between refresh tasks (15 minutes - iOS minimum)
    private let minimumRefreshInterval: TimeInterval = 15 * 60

    /// Preferred processing time (e.g., overnight)
    private let preferredProcessingHour: Int = 3 // 3 AM

    // MARK: - User Defaults Keys

    private enum UserDefaultsKey {
        static let backgroundSyncEnabled = "backgroundSyncEnabled"
        static let lastBackgroundSync = "lastBackgroundSync"
        static let backgroundSyncCount = "backgroundSyncCount"
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    // MARK: - Settings

    private func loadSettings() {
        isBackgroundSyncEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKey.backgroundSyncEnabled)
        lastBackgroundSyncDate = UserDefaults.standard.object(forKey: UserDefaultsKey.lastBackgroundSync) as? Date
        backgroundSyncCount = UserDefaults.standard.integer(forKey: UserDefaultsKey.backgroundSyncCount)

        // Default to enabled if not set
        if !UserDefaults.standard.bool(forKey: "hasSetBackgroundSync") {
            isBackgroundSyncEnabled = true
            UserDefaults.standard.set(true, forKey: "hasSetBackgroundSync")
            UserDefaults.standard.set(true, forKey: UserDefaultsKey.backgroundSyncEnabled)
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(isBackgroundSyncEnabled, forKey: UserDefaultsKey.backgroundSyncEnabled)
        UserDefaults.standard.set(lastBackgroundSyncDate, forKey: UserDefaultsKey.lastBackgroundSync)
        UserDefaults.standard.set(backgroundSyncCount, forKey: UserDefaultsKey.backgroundSyncCount)
    }

    // MARK: - Enable/Disable

    /// Enable or disable background sync
    func setBackgroundSyncEnabled(_ enabled: Bool) {
        isBackgroundSyncEnabled = enabled
        saveSettings()

        if enabled {
            scheduleRefreshTask()
            scheduleProcessingTask()
        } else {
            cancelAllTasks()
        }
    }

    // MARK: - Task Registration

    /// Register background tasks with the system. Call from AppDelegate or App init.
    func registerBackgroundTasks() {
        // Register refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.refresh,
            using: nil
        ) { [weak self] task in
            self?.handleRefreshTask(task as! BGAppRefreshTask)
        }

        // Register processing task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.processing,
            using: nil
        ) { [weak self] task in
            self?.handleProcessingTask(task as! BGProcessingTask)
        }
    }

    // MARK: - Task Scheduling

    /// Schedule periodic refresh task
    func scheduleRefreshTask() {
        guard isBackgroundSyncEnabled else { return }

        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifier.refresh)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumRefreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            nextScheduledSyncDate = request.earliestBeginDate
        } catch {
            print("Failed to schedule refresh task: \(error)")
        }
    }

    /// Schedule heavy processing task (runs during optimal conditions)
    func scheduleProcessingTask() {
        guard isBackgroundSyncEnabled else { return }

        let request = BGProcessingTaskRequest(identifier: BackgroundTaskIdentifier.processing)

        // Schedule for next optimal time (overnight)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = preferredProcessingHour
        components.minute = 0

        var scheduledDate = calendar.date(from: components) ?? Date()

        // If the time has passed today, schedule for tomorrow
        if scheduledDate < Date() {
            scheduledDate = calendar.date(byAdding: .day, value: 1, to: scheduledDate) ?? Date()
        }

        request.earliestBeginDate = scheduledDate
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false // Optional: set to true for battery savings

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule processing task: \(error)")
        }
    }

    /// Schedule sync when app enters background
    func scheduleOnEnterBackground() {
        guard isBackgroundSyncEnabled else { return }
        scheduleRefreshTask()
    }

    /// Cancel all scheduled tasks
    func cancelAllTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundTaskIdentifier.refresh)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundTaskIdentifier.processing)
        nextScheduledSyncDate = nil
    }

    // MARK: - Task Handlers

    /// Handle refresh task
    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        // Schedule next refresh
        scheduleRefreshTask()

        // Create task to perform sync
        let syncOperation = Task { [weak self] in
            guard let self = self else { return }

            // Check if user is authenticated
            guard Auth.auth().currentUser != nil else {
                task.setTaskCompleted(success: true)
                return
            }

            // Check network
            guard self.networkMonitor.isConnected else {
                task.setTaskCompleted(success: false)
                return
            }

            do {
                try await self.performBackgroundSync()
                self.recordSuccessfulSync()
                task.setTaskCompleted(success: true)
            } catch {
                print("Background refresh sync failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        // Handle task expiration
        task.expirationHandler = {
            syncOperation.cancel()
        }
    }

    /// Handle processing task
    private func handleProcessingTask(_ task: BGProcessingTask) {
        // Schedule next processing
        scheduleProcessingTask()

        // Create task to perform full sync
        let syncOperation = Task { [weak self] in
            guard let self = self else { return }

            // Check if user is authenticated
            guard Auth.auth().currentUser != nil else {
                task.setTaskCompleted(success: true)
                return
            }

            // Check network
            guard self.networkMonitor.isConnected else {
                task.setTaskCompleted(success: false)
                return
            }

            do {
                // Perform more comprehensive sync during processing window
                try await self.performFullBackgroundSync()
                self.recordSuccessfulSync()
                task.setTaskCompleted(success: true)
            } catch {
                print("Background processing sync failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        // Handle task expiration
        task.expirationHandler = {
            syncOperation.cancel()
        }
    }

    // MARK: - Sync Operations

    /// Perform lightweight background sync
    private func performBackgroundSync() async throws {
        // Quick sync of pending changes only
        try await syncService.syncNow()
    }

    /// Perform comprehensive background sync
    private func performFullBackgroundSync() async throws {
        // Full sync including downloading all remote data
        try await syncService.syncNow()

        // Additional cleanup operations could go here
        // e.g., resolving old conflicts, cleaning up deleted items, etc.
    }

    /// Record successful sync
    @MainActor
    private func recordSuccessfulSync() {
        lastBackgroundSyncDate = Date()
        backgroundSyncCount += 1
        saveSettings()
    }

    // MARK: - Testing Support

    /// Trigger background task manually for testing (only works in debug)
    #if DEBUG
    func triggerBackgroundTaskForTesting() {
        Task {
            do {
                try await performBackgroundSync()
                await recordSuccessfulSync()
                print("Manual background sync completed successfully")
            } catch {
                print("Manual background sync failed: \(error)")
            }
        }
    }
    #endif
}

// MARK: - App Lifecycle Integration

extension BackgroundSyncManager {
    /// Call when scene becomes active
    func sceneDidBecomeActive() {
        // Check if we need to sync
        if let lastSync = lastBackgroundSyncDate {
            let timeSinceSync = Date().timeIntervalSince(lastSync)
            if timeSinceSync > minimumRefreshInterval {
                Task {
                    try? await syncService.syncNow()
                }
            }
        }
    }

    /// Call when scene will resign active
    func sceneWillResignActive() {
        // No action needed
    }

    /// Call when scene did enter background
    func sceneDidEnterBackground() {
        scheduleOnEnterBackground()
    }
}

// MARK: - Info.plist Configuration Note

/*
 Add the following to your Info.plist to enable background tasks:

 <key>BGTaskSchedulerPermittedIdentifiers</key>
 <array>
     <string>com.spendingtracker.sync.refresh</string>
     <string>com.spendingtracker.sync.processing</string>
 </array>

 <key>UIBackgroundModes</key>
 <array>
     <string>fetch</string>
     <string>processing</string>
 </array>
 */

// MARK: - Debug Commands for Testing

/*
 To test background tasks in the simulator, pause execution in the debugger and run:

 For refresh task:
 e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.spendingtracker.sync.refresh"]

 For processing task:
 e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.spendingtracker.sync.processing"]
 */
