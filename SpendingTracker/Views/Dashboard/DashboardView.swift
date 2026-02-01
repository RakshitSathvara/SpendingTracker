//
//  DashboardView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Dashboard View (iOS 26 Stable)

/// The main dashboard view with Liquid Glass design and Swift Charts
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var categories: [Category]

    @State private var selectedPeriod: TimePeriod = .week
    @State private var showAddTransaction = false
    @State private var addTransactionType: TransactionType = .expense
    @State private var isLoading = true
    @State private var isViewReady = false

    // MARK: - Computed Properties

    private var filteredTransactions: [Transaction] {
        let startDate = selectedPeriod.startDate
        return transactions.filter { $0.date >= startDate }
    }

    private var totalBalance: Decimal {
        let income = transactions.filter { $0.isIncome }.reduce(Decimal.zero) { $0 + $1.amount }
        let expenses = transactions.filter { $0.isExpense }.reduce(Decimal.zero) { $0 + $1.amount }
        return income - expenses
    }

    private var totalIncome: Decimal {
        filteredTransactions.filter { $0.isIncome }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var totalExpense: Decimal {
        filteredTransactions.filter { $0.isExpense }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }

    private var categorySpending: [CategorySpending] {
        let startDate = selectedPeriod.startDate
        let expenses = transactions.filter { $0.isExpense && $0.date >= startDate }

        var categoryTotals: [String: (category: Category, amount: Decimal, count: Int)] = [:]

        for transaction in expenses {
            guard let category = transaction.category else { continue }

            if let existing = categoryTotals[category.id] {
                categoryTotals[category.id] = (category, existing.amount + transaction.amount, existing.count + 1)
            } else {
                categoryTotals[category.id] = (category, transaction.amount, 1)
            }
        }

        let total = categoryTotals.values.reduce(Decimal.zero) { $0 + $1.amount }

        let spending = categoryTotals.values.map { item -> CategorySpending in
            let percentage = total > 0 ? (NSDecimalNumber(decimal: item.amount / total).doubleValue * 100) : 0

            return CategorySpending(
                id: item.category.id,
                category: SpendingCategory(from: item.category),
                amount: item.amount,
                transactionCount: item.count,
                percentage: percentage
            )
        }

        return spending.sorted { $0.amount > $1.amount }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive Background
                AdaptiveBackground(style: .primary)

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if isLoading {
                            // Loading skeleton
                            DashboardSkeleton()
                        } else {
                            // Balance Card
                            BalanceCard(
                                total: totalBalance,
                                income: totalIncome,
                                expense: totalExpense
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))

                            // Period Selector
                            periodSelector
                                .transition(.opacity)

                            // Spending Chart
                            SpendingChartCard(
                                data: Array(categorySpending.prefix(6)),
                                period: selectedPeriod
                            )
                            .transition(.opacity.combined(with: .move(edge: .leading)))

                            // Recent Transactions
                            RecentTransactionsSection(
                                transactions: recentTransactions,
                                onSeeAll: {
                                    // Navigate to all transactions
                                }
                            )
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .padding()
                    .opacity(isViewReady ? 1 : 0)
                }
                .refreshable {
                    await refresh()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        addButton
                        profileButton
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .onAppear {
                // Small delay for smooth appearance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isViewReady = true
                    }
                }

                // Simulate initial load
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isLoading = false
                    }
                }
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        GlassSegmentedControl(
            selection: $selectedPeriod,
            options: TimePeriod.allCases,
            titleForOption: { $0.rawValue },
            iconForOption: { $0.icon }
        )
        .sensoryFeedback(.selection, trigger: selectedPeriod)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            showAddTransaction = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        Button {
            // Show profile/settings
        } label: {
            if let initial = authService.displayName?.first {
                Text(String(initial).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func refresh() async {
        // Simulate refresh
        try? await Task.sleep(for: .milliseconds(500))
    }
}

// MARK: - Dashboard View with ViewModel

/// Alternative DashboardView using the DashboardViewModel
struct DashboardViewWithViewModel: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: DashboardViewModel?
    @State private var showAddTransaction = false
    @State private var addTransactionType: TransactionType = .expense
    @State private var isViewReady = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive Background
                AdaptiveBackground(style: .primary)

                if let vm = viewModel {
                    dashboardContent(viewModel: vm)
                } else {
                    DashboardSkeleton()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        addButton
                        profileButton
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = DashboardViewModel(modelContext: modelContext)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isViewReady = true
                    }
                }

                Task {
                    await viewModel?.loadIfNeeded()
                }
            }
        }
    }

    @ViewBuilder
    private func dashboardContent(viewModel: DashboardViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading && !viewModel.hasLoadedOnce {
                    DashboardSkeleton()
                } else {
                    BalanceCard(
                        total: viewModel.totalBalance,
                        income: viewModel.totalIncome,
                        expense: viewModel.totalExpense,
                        incomeTrend: viewModel.incomeTrend,
                        expenseTrend: viewModel.expenseTrend
                    )

                    GlassSegmentedControl(
                        selection: Bindable(viewModel).selectedPeriod,
                        options: TimePeriod.allCases,
                        titleForOption: { $0.rawValue },
                        iconForOption: { $0.icon }
                    )

                    SpendingChartCard(
                        data: Array(viewModel.categorySpending.prefix(6)),
                        period: viewModel.selectedPeriod
                    )

                    RecentTransactionsSection(
                        transactions: viewModel.recentTransactions,
                        onSeeAll: { }
                    )
                }
            }
            .padding()
            .opacity(isViewReady ? 1 : 0)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var addButton: some View {
        Button {
            showAddTransaction = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var profileButton: some View {
        Button {
            // Show profile/settings
        } label: {
            if let initial = authService.displayName?.first {
                Text(String(initial).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Dashboard View") {
    DashboardView()
        .environment(AuthenticationService())
        .modelContainer(.preview)
}
