//
//  TransactionListView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Transaction Group

/// Represents a group of transactions by date
struct TransactionGroup: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let transactions: [Transaction]

    var totalAmount: Decimal {
        transactions.reduce(Decimal.zero) { result, transaction in
            if transaction.isExpense {
                return result - transaction.amount
            } else {
                return result + transaction.amount
            }
        }
    }

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        let absAmount = abs(NSDecimalNumber(decimal: totalAmount).doubleValue)
        return formatter.string(from: NSNumber(value: absAmount)) ?? "\(totalAmount)"
    }
}

// MARK: - Transaction List ViewModel

@Observable
class TransactionListViewModel {
    // MARK: - Properties

    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    let filterState = TransactionFilterState()
    var searchText: String = ""

    private(set) var transactions: [Transaction] = []
    private(set) var categories: [Category] = []
    private(set) var accounts: [Account] = []

    private let transactionRepo = TransactionRepository()
    private let categoryRepo = CategoryRepository()
    private let accountRepo = AccountRepository()

    // MARK: - Initialization

    init() {}

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        filterState.hasActiveFilters || !searchText.isEmpty
    }

    // MARK: - Load Data

    @MainActor
    func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let t = transactionRepo.fetchAllTransactions()
            async let c = categoryRepo.fetchCategories()
            async let a = accountRepo.fetchAccounts()
            transactions = try await t
            categories = try await c
            accounts = try await a
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
    }

    // MARK: - Refresh

    @MainActor
    func refresh() async {
        await loadData()
    }

    // MARK: - Delete Transaction

    @MainActor
    func deleteTransaction(_ transaction: Transaction) async {
        do {
            try await transactionRepo.deleteTransaction(id: transaction.id)
            transactions.removeAll { $0.id == transaction.id }
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    // MARK: - Clear Error

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Helper Methods for Category/Account Lookups

    func getCategoryName(for categoryId: String?) -> String? {
        guard let id = categoryId else { return nil }
        return categories.first { $0.id == id }?.name
    }

    func getCategoryIcon(for categoryId: String?) -> String? {
        guard let id = categoryId else { return nil }
        return categories.first { $0.id == id }?.icon
    }

    func getCategoryColor(for categoryId: String?) -> Color? {
        guard let id = categoryId else { return nil }
        return categories.first { $0.id == id }?.color
    }

    func getAccountName(for accountId: String?) -> String? {
        guard let id = accountId else { return nil }
        return accounts.first { $0.id == id }?.name
    }
}

// MARK: - Transaction List View (Firestore-Only)

struct TransactionListView: View {

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var viewModel: TransactionListViewModel?
    @State private var showFilterSheet = false
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: Transaction?
    @State private var selectedTransaction: Transaction?
    @State private var showEditTransaction = false

    // MARK: - Computed Properties

    private var filteredTransactions: [Transaction] {
        guard let viewModel = viewModel else { return [] }
        var filtered = viewModel.transactions

        if !viewModel.searchText.isEmpty {
            let searchLower = viewModel.searchText.lowercased()
            filtered = filtered.filter { transaction in
                transaction.note.lowercased().contains(searchLower) ||
                (transaction.merchantName?.lowercased().contains(searchLower) ?? false) ||
                (viewModel.getCategoryName(for: transaction.categoryId)?.lowercased().contains(searchLower) ?? false)
            }
        }

        if !viewModel.filterState.showExpenses {
            filtered = filtered.filter { !$0.isExpense }
        }
        if !viewModel.filterState.showIncome {
            filtered = filtered.filter { !$0.isIncome }
        }

        if let selectedCategory = viewModel.filterState.selectedCategory {
            filtered = filtered.filter { $0.categoryId == selectedCategory.id }
        }
        if let selectedAccount = viewModel.filterState.selectedAccount {
            filtered = filtered.filter { $0.accountId == selectedAccount.id }
        }
        if let dateRange = viewModel.filterState.dateRange {
            filtered = filtered.filter { dateRange.contains($0.date) }
        }
        return filtered
    }

    private var groupedTransactions: [TransactionGroup] {
        let calendar = Calendar.current
        let now = Date()

        let grouped = Dictionary(grouping: filteredTransactions) { transaction -> String in
            if calendar.isDateInToday(transaction.date) {
                return "Today"
            } else if calendar.isDateInYesterday(transaction.date) {
                return "Yesterday"
            } else if calendar.isDate(transaction.date, equalTo: now, toGranularity: .weekOfYear) {
                return "This Week"
            } else if calendar.isDate(transaction.date, equalTo: now, toGranularity: .month) {
                return "This Month"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: transaction.date)
            }
        }

        // Sort groups by priority and date
        let sortOrder = ["Today": 0, "Yesterday": 1, "This Week": 2, "This Month": 3]

        return grouped.map { key, transactions in
            TransactionGroup(
                title: key,
                date: transactions.first?.date ?? Date(),
                transactions: transactions.sorted { $0.date > $1.date }
            )
        }
        .sorted { group1, group2 in
            let order1 = sortOrder[group1.title] ?? 4
            let order2 = sortOrder[group2.title] ?? 4

            if order1 != order2 {
                return order1 < order2
            }
            return group1.date > group2.date
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive Background
                AdaptiveBackground(style: .primary)

                // Content
                Group {
                    if viewModel?.isLoading == true {
                        loadingView
                    } else if (viewModel?.transactions.isEmpty ?? true) {
                        emptyStateView
                    } else {
                        transactionListContent
                    }
                }
            }
            .navigationTitle("Transactions")
            .searchable(
                text: Binding(
                    get: { viewModel?.searchText ?? "" },
                    set: { viewModel?.searchText = $0 }
                ),
                prompt: "Search by note, merchant, or category"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterButton
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                if let viewModel = viewModel {
                    TransactionFilterSheet(
                        filterState: viewModel.filterState,
                        categories: viewModel.categories,
                        accounts: viewModel.accounts,
                        onApply: {}
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showEditTransaction) {
                if let transaction = selectedTransaction {
                    AddTransactionView(editingTransaction: transaction)
                }
            }
            .confirmationDialog(
                "Delete Transaction",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let transaction = transactionToDelete {
                        Task {
                            await viewModel?.deleteTransaction(transaction)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    transactionToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
            .refreshable {
                await viewModel?.refresh()
            }
            .onAppear {
                setupViewModel()
            }
        }
    }

    // MARK: - Filter Button

    private var filterButton: some View {
        Button {
            showFilterSheet = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)

                if viewModel?.hasActiveFilters == true {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }
    }

    // MARK: - Transaction List Content

    private var transactionListContent: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedTransactions) { group in
                    Section {
                        VStack(spacing: 12) {
                            ForEach(group.transactions) { transaction in
                                TransactionCard(
                                    transaction: transaction,
                                    onEdit: {
                                        selectedTransaction = transaction
                                        showEditTransaction = true
                                    },
                                    onDelete: {
                                        transactionToDelete = transaction
                                        showDeleteConfirmation = true
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(.horizontal, 16)
                    } header: {
                        TransactionCardSectionHeader(
                            title: group.title,
                            total: group.formattedTotal,
                            isPositive: group.totalAmount >= 0,
                            transactionCount: group.transactions.count
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea(edges: .horizontal)
                        }
                    }
                }

                // Bottom padding for FAB
                Color.clear.frame(height: 80)
            }
            .padding(.top, 8)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredTransactions.count)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    TransactionCardSkeleton()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        TransactionEmptyStateView(
            hasFilters: viewModel?.hasActiveFilters ?? false,
            onClearFilters: {
                viewModel?.filterState.reset()
                viewModel?.searchText = ""
            }
        )
    }

    // MARK: - Setup

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = TransactionListViewModel()
            Task { await viewModel?.loadData() }
        }
    }
}

// MARK: - Transaction Section Header

struct TransactionSectionHeader: View {
    let title: String
    let total: String
    let isPositive: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Spacer()

            Text(isPositive ? "+\(total)" : "-\(total)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isPositive ? .green : .red)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
    }
}

// MARK: - Transaction Card Section Header

/// Modern section header for card-based transaction list
struct TransactionCardSectionHeader: View {
    let title: String
    let total: String
    let isPositive: Bool
    let transactionCount: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Title with count badge
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                // Transaction count badge
                Text("\(transactionCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                    }
            }

            Spacer()

            // Net amount badge
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))

                Text(isPositive ? "+\(total)" : "-\(total)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            .foregroundStyle(isPositive ? .green : .red)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(isPositive ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State View

struct TransactionEmptyStateView: View {
    let hasFilters: Bool
    let onClearFilters: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            Image(systemName: hasFilters ? "magnifyingglass" : "tray")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)

            // Title
            Text(hasFilters ? "No Matching Transactions" : "No Transactions Yet")
                .font(.title2)
                .fontWeight(.semibold)

            // Description
            Text(hasFilters
                 ? "Try adjusting your filters or search terms to find what you're looking for."
                 : "Start tracking your spending by adding your first transaction.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Action Button
            if hasFilters {
                Button {
                    onClearFilters()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Clear Filters")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background {
                        Capsule()
                            .fill(Color.blue.gradient)
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasFilters
            ? "No matching transactions. Clear filters to see all transactions."
            : "No transactions yet. Add your first transaction to get started.")
    }
}

// MARK: - Preview

#Preview("Transaction List") {
    TransactionListView()
}

#Preview("Empty State") {
    TransactionEmptyStateView(hasFilters: false, onClearFilters: {})
}

#Preview("Empty State with Filters") {
    TransactionEmptyStateView(hasFilters: true, onClearFilters: {})
}
