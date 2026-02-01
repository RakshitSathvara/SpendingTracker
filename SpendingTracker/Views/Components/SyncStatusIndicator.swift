//
//  SyncStatusIndicator.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Sync Status Indicator

/// A compact indicator showing the current sync status
struct SyncStatusIndicator: View {

    // MARK: - Environment

    @Environment(SyncService.self) private var syncService
    @Environment(NetworkMonitor.self) private var networkMonitor

    // MARK: - State

    @State private var isAnimating = false
    @State private var showDetails = false

    // MARK: - Body

    var body: some View {
        Button {
            showDetails = true
        } label: {
            HStack(spacing: 6) {
                statusIcon
                    .font(.system(size: 14, weight: .medium))

                if syncService.pendingChangesCount > 0 && !syncService.isSyncing {
                    Text("\(syncService.pendingChangesCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetails) {
            SyncStatusDetailView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch syncService.state {
        case .idle:
            if !networkMonitor.isConnected {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.orange)
            } else if syncService.pendingChangesCount > 0 {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear { isAnimating = true }
                .onDisappear { isAnimating = false }

        case .waitingForNetwork:
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.orange)

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Sync Status Detail View

struct SyncStatusDetailView: View {

    // MARK: - Environment

    @Environment(SyncService.self) private var syncService
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Status Section
                Section {
                    HStack {
                        statusIndicator
                        VStack(alignment: .leading, spacing: 4) {
                            Text(syncService.state.displayText)
                                .font(.headline)
                            if let lastSync = syncService.lastSyncDate {
                                Text("Last synced \(lastSync, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Sync Status")
                }

                // Network Section
                Section {
                    HStack {
                        Image(systemName: networkMonitor.connectionType?.icon ?? "wifi.slash")
                            .foregroundStyle(networkMonitor.isConnected ? .green : .red)
                            .frame(width: 30)
                        Text(networkMonitor.status.displayText)
                        Spacer()
                    }

                    if networkMonitor.isExpensive {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.orange)
                                .frame(width: 30)
                            Text("Using cellular data")
                            Spacer()
                        }
                    }

                    if networkMonitor.isConstrained {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.0percent")
                                .foregroundStyle(.orange)
                                .frame(width: 30)
                            Text("Low Data Mode enabled")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Network")
                }

                // Pending Changes Section
                if syncService.pendingChangesCount > 0 {
                    Section {
                        HStack {
                            Image(systemName: "tray.full.fill")
                                .foregroundStyle(.orange)
                                .frame(width: 30)
                            Text("\(syncService.pendingChangesCount) changes waiting to sync")
                            Spacer()
                        }
                    } header: {
                        Text("Pending Changes")
                    }
                }

                // Statistics Section
                Section {
                    StatRow(icon: "arrow.up.circle.fill", color: .blue, label: "Uploaded", value: "\(syncService.statistics.totalUploaded)")
                    StatRow(icon: "arrow.down.circle.fill", color: .green, label: "Downloaded", value: "\(syncService.statistics.totalDownloaded)")
                    StatRow(icon: "arrow.left.arrow.right", color: .purple, label: "Conflicts Resolved", value: "\(syncService.statistics.totalConflictsResolved)")
                    if syncService.statistics.totalErrors > 0 {
                        StatRow(icon: "exclamationmark.circle.fill", color: .red, label: "Errors", value: "\(syncService.statistics.totalErrors)")
                    }
                } header: {
                    Text("Session Statistics")
                }

                // Sync Now Button
                Section {
                    Button {
                        Task {
                            try? await syncService.syncAllUnsynced(from: modelContext)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if syncService.isSyncing {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(syncService.isSyncing ? "Syncing..." : "Sync Now")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(syncService.isSyncing || !networkMonitor.isConnected)
                }
            }
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 44, height: 44)

            Image(systemName: syncService.state.icon)
                .font(.title2)
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        switch syncService.state {
        case .idle: return .green
        case .syncing: return .blue
        case .waitingForNetwork: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 30)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Compact Sync Badge

/// A minimal sync indicator for toolbars and navigation bars
struct CompactSyncBadge: View {

    @Environment(SyncService.self) private var syncService

    var body: some View {
        Group {
            if syncService.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
            } else if syncService.pendingChangesCount > 0 {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                    .font(.caption)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Offline Banner

/// A banner shown when the app is offline
struct OfflineBanner: View {

    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(SyncService.self) private var syncService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if !networkMonitor.isConnected || syncService.pendingChangesCount > 0 {
            HStack(spacing: 8) {
                Image(systemName: networkMonitor.isConnected ? "arrow.triangle.2.circlepath" : "wifi.slash")
                    .font(.caption)

                Text(bannerText)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                if networkMonitor.isConnected && syncService.pendingChangesCount > 0 {
                    Button("Sync") {
                        Task { try? await syncService.syncAllUnsynced(from: modelContext) }
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(bannerColor)
            .foregroundStyle(.white)
        }
    }

    private var bannerText: String {
        if !networkMonitor.isConnected {
            return "You're offline. Changes will sync when connected."
        } else if syncService.pendingChangesCount > 0 {
            return "\(syncService.pendingChangesCount) changes waiting to sync"
        }
        return ""
    }

    private var bannerColor: Color {
        if !networkMonitor.isConnected {
            return .gray
        } else {
            return .orange
        }
    }
}

// MARK: - Preview

#Preview("Sync Status Indicator") {
    SyncStatusIndicator()
        .environment(SyncService.shared)
        .environment(NetworkMonitor.shared)
        .padding()
}

#Preview("Sync Status Detail") {
    SyncStatusDetailView()
        .environment(SyncService.shared)
        .environment(NetworkMonitor.shared)
}
