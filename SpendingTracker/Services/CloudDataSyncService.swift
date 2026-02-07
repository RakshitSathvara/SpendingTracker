//
//  CloudDataSyncService.swift
//  SpendingTracker
//
//  Deprecated: App now uses cloud-only architecture.
//

import Foundation

/// Deprecated: Minimal stub for cloud-only architecture.
/// All data now lives only in Firestore - no local SwiftData needed.
@Observable
final class CloudDataSyncService {
    static let shared = CloudDataSyncService()

    private init() {}
}

/// Deprecated sync error type - kept for backwards compatibility
enum CloudSyncError: LocalizedError {
    case notAuthenticated
    case networkError(String)
    case dataError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to sync data"
        case .networkError(let message):
            return "Network error: \(message)"
        case .dataError(let message):
            return "Data error: \(message)"
        }
    }
}
