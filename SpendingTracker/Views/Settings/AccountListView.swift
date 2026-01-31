//
//  AccountListView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Account List View (iOS 26 Stable)

/// View for managing accounts with balance display
struct AccountListView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    // MARK: - State

    @State private var viewModel: AccountViewModel?
    @State private var showAddAccount = false
    @State private var editingAccount: Account?
    @State private var isViewReady = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            AnimatedMeshGradient(colorScheme: .blue)

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    if let vm = viewModel {
                        if vm.accounts.isEmpty {
                            emptyStateView
                        } else {
                            // Total Balance Card
                            totalBalanceCard(viewModel: vm)

                            // Accounts List
                            accountsSection(viewModel: vm)
                        }
                    } else {
                        AccountListSkeleton()
                    }
                }
                .padding()
                .opacity(isViewReady ? 1 : 0)
            }
            .refreshable {
                viewModel?.refresh()
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddAccount = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountView()
                .environment(\.modelContext, modelContext)
                .environment(syncService)
                .onDisappear {
                    viewModel?.refresh()
                }
        }
        .sheet(item: $editingAccount) { account in
            AddAccountView(editingAccount: account)
                .environment(\.modelContext, modelContext)
                .environment(syncService)
                .onDisappear {
                    viewModel?.refresh()
                }
        }
        .onAppear {
            setupViewModel()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isViewReady = true
                }
            }
        }
    }

    // MARK: - Setup

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = AccountViewModel(modelContext: modelContext, syncService: syncService)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "creditcard.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("No Accounts")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Add accounts to track your balances and transactions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            GlassButton(
                title: "Add Account",
                icon: "plus.circle",
                tint: .blue
            ) {
                showAddAccount = true
            }
            .frame(maxWidth: 200)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Total Balance Card

    private func totalBalanceCard(viewModel: AccountViewModel) -> some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Balance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(viewModel.formattedTotalBalance)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(viewModel.totalBalance >= 0 ? .primary : .red)
                    }

                    Spacer()

                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue.gradient)
                }

                Divider()

                // Account type summary
                HStack(spacing: 16) {
                    ForEach(AccountType.allCases.prefix(4), id: \.self) { type in
                        let balance = viewModel.balance(for: type)
                        if viewModel.accountsByType[type] != nil {
                            VStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: type.defaultColor) ?? .blue)

                                Text(formatCompactCurrency(balance))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Accounts Section

    private func accountsSection(viewModel: AccountViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Accounts")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.accounts.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(viewModel.accounts) { account in
                    AccountRow(
                        account: account,
                        transactionCount: viewModel.transactionCount(for: account),
                        onEdit: {
                            editingAccount = account
                        },
                        onDelete: {
                            Task {
                                await viewModel.deleteAccount(account)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatCompactCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0

        let doubleValue = NSDecimalNumber(decimal: amount).doubleValue

        if abs(doubleValue) >= 100000 {
            formatter.maximumFractionDigits = 1
            return formatter.string(from: NSNumber(value: doubleValue / 100000))?.replacingOccurrences(of: "₹", with: "₹") ?? "₹0" + "L"
        } else if abs(doubleValue) >= 1000 {
            formatter.maximumFractionDigits = 1
            return formatter.string(from: NSNumber(value: doubleValue / 1000))?.replacingOccurrences(of: "₹", with: "₹") ?? "₹0" + "K"
        }

        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }
}

// MARK: - Account Row

struct AccountRow: View {
    let account: Account
    let transactionCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: account.currentBalance as NSDecimalNumber) ?? "₹0"
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: account.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(account.color.gradient)
                    .clipShape(Circle())

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text(account.accountType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if transactionCount > 0 {
                            Text("•")
                                .foregroundStyle(.tertiary)

                            Text("\(transactionCount) txns")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Balance
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedBalance)
                        .font(.headline)
                        .foregroundStyle(account.currentBalance >= 0 ? .primary : .red)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if transactionCount > 0 {
                Text("This account has \(transactionCount) transactions. Delete or reassign them before deleting this account.")
            } else {
                Text("Are you sure you want to delete \"\(account.name)\"? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Account List Skeleton

struct AccountListSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            // Balance card skeleton
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .frame(height: 140)

            // Account rows skeleton
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(height: 80)
            }
        }
        .shimmer()
    }
}

// MARK: - Preview

#Preview("Account List") {
    NavigationStack {
        AccountListView()
            .environment(SyncService.shared)
            .modelContainer(.preview)
    }
}
