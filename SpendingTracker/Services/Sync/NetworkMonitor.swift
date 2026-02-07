//
//  NetworkMonitor.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import Network
import Observation

// MARK: - Network Status

/// Represents the current network connection status
enum NetworkStatus: Equatable {
    case connected(ConnectionType)
    case disconnected

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .connected(let type):
            return "Connected via \(type.displayName)"
        case .disconnected:
            return "No Connection"
        }
    }
}

// MARK: - Connection Type

/// Type of network connection
enum ConnectionType: Equatable {
    case wifi
    case cellular
    case ethernet
    case other

    var displayName: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .ethernet: return "Ethernet"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .other: return "network"
        }
    }
}

// MARK: - Network Monitor

/// Monitors network connectivity status using NWPathMonitor
@Observable
final class NetworkMonitor {

    // MARK: - Singleton

    static let shared = NetworkMonitor()

    // MARK: - Published Properties

    /// Current network status
    private(set) var status: NetworkStatus = .disconnected

    /// Whether the network is currently reachable
    var isConnected: Bool { status.isConnected }

    /// Current connection type (if connected)
    var connectionType: ConnectionType? {
        if case .connected(let type) = status {
            return type
        }
        return nil
    }

    /// Whether the connection is expensive (e.g., cellular)
    private(set) var isExpensive: Bool = false

    /// Whether the connection is constrained (e.g., Low Data Mode)
    private(set) var isConstrained: Bool = false

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.spendingtracker.networkmonitor", qos: .utility)
    private var isMonitoring = false

    /// Continuation for connectivity change notifications
    private var connectivityContinuations: [UUID: AsyncStream<NetworkStatus>.Continuation] = [:]

    // MARK: - Initialization

    private init() {
        monitor = NWPathMonitor()
        setupMonitor()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Setup

    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let newStatus = self.determineStatus(from: path)
            let wasConnected = self.status.isConnected
            let isNowConnected = newStatus.isConnected

            // Update properties on main thread
            DispatchQueue.main.async {
                self.status = newStatus
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained

                // Notify all continuations
                for continuation in self.connectivityContinuations.values {
                    continuation.yield(newStatus)
                }

                // Post notification for connectivity restoration
                if !wasConnected && isNowConnected {
                    NotificationCenter.default.post(
                        name: .networkConnectivityRestored,
                        object: nil,
                        userInfo: ["connectionType": newStatus]
                    )
                } else if wasConnected && !isNowConnected {
                    NotificationCenter.default.post(
                        name: .networkConnectivityLost,
                        object: nil
                    )
                }
            }
        }
    }

    private func determineStatus(from path: NWPath) -> NetworkStatus {
        guard path.status == .satisfied else {
            return .disconnected
        }

        if path.usesInterfaceType(.wifi) {
            return .connected(.wifi)
        } else if path.usesInterfaceType(.cellular) {
            return .connected(.cellular)
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .connected(.ethernet)
        } else {
            return .connected(.other)
        }
    }

    // MARK: - Public Methods

    /// Start monitoring network connectivity
    func startMonitoring() {
        guard !isMonitoring else { return }
        monitor.start(queue: monitorQueue)
        isMonitoring = true
    }

    /// Stop monitoring network connectivity
    func stopMonitoring() {
        guard isMonitoring else { return }
        monitor.cancel()
        isMonitoring = false

        // Finish all continuations
        for continuation in connectivityContinuations.values {
            continuation.finish()
        }
        connectivityContinuations.removeAll()
    }

    /// Returns an AsyncStream that emits network status changes
    func observeConnectivity() -> AsyncStream<NetworkStatus> {
        AsyncStream { continuation in
            let id = UUID()
            self.connectivityContinuations[id] = continuation

            // Emit current status immediately
            continuation.yield(self.status)

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.connectivityContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    /// Wait for connectivity to be restored
    func waitForConnectivity() async {
        guard !isConnected else { return }

        for await status in observeConnectivity() {
            if status.isConnected {
                return
            }
        }
    }

    /// Check if sync should proceed based on network conditions
    func shouldSync(allowExpensive: Bool = true, allowConstrained: Bool = false) -> Bool {
        guard isConnected else { return false }

        if isExpensive && !allowExpensive {
            return false
        }

        if isConstrained && !allowConstrained {
            return false
        }

        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when network connectivity is restored
    static let networkConnectivityRestored = Notification.Name("networkConnectivityRestored")

    /// Posted when network connectivity is lost
    static let networkConnectivityLost = Notification.Name("networkConnectivityLost")
}

// MARK: - Network Monitor Error

enum NetworkMonitorError: LocalizedError {
    case noConnection
    case expensiveConnection
    case constrainedConnection

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No network connection available"
        case .expensiveConnection:
            return "Sync paused on cellular network"
        case .constrainedConnection:
            return "Sync paused in Low Data Mode"
        }
    }
}
