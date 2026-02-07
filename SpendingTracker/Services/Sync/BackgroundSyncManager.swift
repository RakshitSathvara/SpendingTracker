//
//  BackgroundSyncManager.swift
//  SpendingTracker
//
//  Deprecated: App now uses cloud-only architecture.
//

import Foundation

/// Deprecated: Minimal stub for cloud-only architecture.
/// Background sync is no longer needed - Firestore handles all syncing.
@Observable
final class BackgroundSyncManager {
    static let shared = BackgroundSyncManager()

    private init() {}

    /// No-op: Background tasks not needed in cloud-only mode
    func registerBackgroundTasks() {}

    /// No-op: Background tasks not needed in cloud-only mode
    func sceneDidBecomeActive() {}

    /// No-op: Background tasks not needed in cloud-only mode
    func sceneWillResignActive() {}

    /// No-op: Background tasks not needed in cloud-only mode
    func sceneDidEnterBackground() {}
}
