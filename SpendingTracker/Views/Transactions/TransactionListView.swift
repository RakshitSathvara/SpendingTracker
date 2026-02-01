//
//  TransactionListView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

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
    private(set) var hasMoreTransactions = true

    let filterState = TransactionFilterState()
    var searchText: String = ""

    private let pageSize = 20
    private var currentPage = 0

    private let modelContext: ModelContext
    private let syncService: SyncService

    // MARK: - Initialization

    init(modelContext: ModelContext, syncService: SyncService = .shared) {
        self.modelContext = modelContext
        self.syncService = syncService
    }

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        filterState.hasActiveFilters || !searchText.isEmpty
    }

    // MARK: - Refresh

    @MainActor
    func refresh() async {
        isLoading = true
        currentPage = 0
        hasMoreTransactions = true

        // Trigger sync if online
        do {
            try await syncService.syncNow()
        } catch {
            // Sync failed, but we can still show local data
            print("Sync failed during refresh: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Load More (Pagination)

    @MainActor
    func loadMoreIfNeeded(currentTransaction: Transaction, allTransactions: [Transaction]) async {
        guard !isLoadingMore && hasMoreTransactions else { return }

        let thresholdIndex = allTransactions.index(allTransactions.endIndex, offsetBy: -5)
        if let currentIndex = allTransactions.firstIndex(where: { $0.id == currentTransaction.id }),
           currentIndex >= thresholdIndex {
            isLoadingMore = true
            currentPage += 1

            // Simulate loading delay for smooth UX
            try? await Task.sleep(nanoseconds: 500_000_000)

            // In a real app, you'd fetch more from the repository
            // For SwiftData with @Query, pagination is handled automatically
            hasMoreTransactions = false // For now, we load all at once
            isLoadingMore = false
        }
    }

    // MARK: - Delete Transaction

    @MainActor
    func deleteTransaction(_ transaction: Transaction) async {
        let transactionId = transaction.id

        modelContext.delete(transaction)

        do {
            try modelContext.save()

            // Mark for deletion sync
            syncService.markForDeletion(entityId: transactionId, entityType: SyncEntityType.transaction)

            // Trigger sync if online
            Task {
                try? await syncService.syncNow()
            }
        } catch {
            errorMessage = "Failed to delete transaction: \(error.localizedDescription)"
        }
    }

    // MARK: - Clear Error

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Transaction List View (iOS 26 Stable)

struct TransactionListView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - SwiftData Queries

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @Query(sort: \Category.sortOrder)
    private var categories: [Category]

    @Query(sort: \Account.createdAt)
    private var accounts: [Account]

    // MARK: - State

    @State private var viewModel: TransactionListViewModel?
    @State private var showFilterSheet = false
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: Transaction?
    @State private var selectedTransaction: Transaction?
    @State private var showEditTransaction = false

    // MARK: - Firestore Data (for when local DB is empty)

    @State private var firestoreCategories: [CategoryDTO] = []
    @State private var firestoreAccounts: [AccountDTO] = []
    @State private var categoryRepository = CategoryRepository()
    @State private var accountRepository = AccountRepository()

    // MARK: - Display Data (combines local + Firestore)

    private var displayCategories: [Category] {
        if !categories.isEmpty {
            return categories
        }
        // Convert DTOs to Category objects for display
        return firestoreCategories.map { dto in
            Category(
                id: dto.id,
                name: dto.name,
                icon: dto.icon,
                colorHex: dto.colorHex,
                isExpenseCategory: dto.isExpenseCategory,
                sortOrder: dto.sortOrder,
                isDefault: dto.isDefault
            )
        }
    }

    private var displayAccounts: [Account] {
        if !accounts.isEmpty {
            return accounts
        }
        // Convert DTOs to Account objects for display
        return firestoreAccounts.map { dto in
            Account(
                id: dto.id,
                name: dto.name,
                initialBalance: dto.initialBalance,
                accountType: dto.accountType,
                icon: dto.icon,
                colorHex: dto.colorHex,
                currencyCode: dto.currencyCode
            )
        }
    }

    // MARK: - Computed Properties

    private var filteredTransactions: [Transaction] {
        guard let viewModel = viewModel else { return allTransactions }

        var filtered = allTransactions

        // Apply search filter
        if !viewModel.searchText.isEmpty {
            let searchLower = viewModel.searchText.lowercased()
            filtered = filtered.filter { transaction in
                transaction.note.lowercased().contains(searchLower) ||
                (transaction.merchantName?.lowercased().contains(searchLower) ?? false) ||
                (transaction.category?.name.lowercased().contains(searchLower) ?? false)
            }
        }

        // Apply type filter
        if !viewModel.filterState.showExpenses {
            filtered = filtered.filter { !$0.isExpense }
        }
        if !viewModel.filterState.showIncome {
            filtered = filtered.filter { !$0.isIncome }
        }

        // Apply category filter
        if let selectedCategory = viewModel.filterState.selectedCategory {
            filtered = filtered.filter { $0.category?.id == selectedCategory.id }
        }

        // Apply account filter
        if let selectedAccount = viewModel.filterState.selectedAccount {
            filtered = filtered.filter { $0.account?.id == selectedAccount.id }
        }

        // Apply date range filter
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
                    if viewModel?.isLoading == true && allTransactions.isEmpty {
                        loadingView
                    } else if filteredTransactions.isEmpty {
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
                        categories: displayCategories,
                        accounts: displayAccounts,
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
            .onAppear {
                setupViewModel()
                loadFirestoreDataIfNeeded()
            }
        }
    }

    // MARK: - Load Firestore Data

    private func loadFirestoreDataIfNeeded() {
        // Fetch from Firestore if local SwiftData is empty
        Task {
            if categories.isEmpty && firestoreCategories.isEmpty {
                do {
                    firestoreCategories = try await categoryRepository.fetchCategories()
                } catch {
                    print("Failed to fetch categories from Firestore: \(error)")
                }
            }

            if accounts.isEmpty && firestoreAccounts.isEmpty {
                do {
                    firestoreAccounts = try await accountRepository.fetchAccounts()
                } catch {
                    print("Failed to fetch accounts from Firestore: \(error)")
                }
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
        List {
            ForEach(groupedTransactions) { group in
                Section {
                    ForEach(group.transactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    selectedTransaction = transaction
                                    showEditTransaction = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .onAppear {
                                Task {
                                    await viewModel?.loadMoreIfNeeded(
                                        currentTransaction: transaction,
                                        allTransactions: filteredTransactions
                                    )
                                }
                            }
                    }
                } header: {
                    TransactionSectionHeader(
                        title: group.title,
                        total: group.formattedTotal,
                        isPositive: group.totalAmount >= 0
                    )
                }
            }

            // Loading more indicator
            if viewModel?.isLoadingMore == true {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel?.refresh()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                TransactionRowSkeleton()
                    .padding(.horizontal)
            }
        }
        .padding(.top, 20)
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
            viewModel = TransactionListViewModel(modelContext: modelContext, syncService: syncService)
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
        .modelContainer(.preview)
        .environment(SyncService.shared)
}

#Preview("Empty State") {
    TransactionEmptyStateView(hasFilters: false, onClearFilters: {})
}

#Preview("Empty State with Filters") {
    TransactionEmptyStateView(hasFilters: true, onClearFilters: {})
}
