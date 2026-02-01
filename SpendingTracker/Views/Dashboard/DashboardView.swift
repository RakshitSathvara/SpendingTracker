//
//  DashboardView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//  Enhanced with 2026 Modern Dashboard UI Best Practices
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Dashboard View (2026 Modern UI)

/// The main dashboard view with modern UI patterns:
/// - F/Z pattern information hierarchy
/// - Personalized greeting header
/// - Quick actions for frequent tasks
/// - Contextual insights
/// - Budget status alerts
/// - Smooth micro-interactions
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var budgets: [Budget]

    @State private var selectedPeriod: TimePeriod = .week
    @State private var showAddTransaction = false
    @State private var addTransactionType: TransactionType = .expense
    @State private var isLoading = true
    @State private var isViewReady = false
    @State private var showIncomeSheet = false
    @State private var showTransferSheet = false

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

    private var todayExpense: Decimal {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return transactions
            .filter { $0.isExpense && calendar.isDate($0.date, inSameDayAs: today) }
            .reduce(Decimal.zero) { $0 + $1.amount }
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

    // Budget progress for alerts widget
    private var budgetProgress: [BudgetProgress] {
        budgets.compactMap { budget -> BudgetProgress? in
            guard let category = budget.category else { return nil }

            // Calculate spent amount for this budget's period
            let spent = transactions
                .filter { $0.isExpense && $0.category?.id == category.id && $0.date >= budget.startDate && $0.date <= budget.endDate }
                .reduce(Decimal.zero) { $0 + $1.amount }

            return BudgetProgress(
                id: budget.id,
                categoryName: category.name,
                categoryIcon: category.icon,
                categoryColor: category.color,
                spent: spent,
                limit: budget.amount
            )
        }
    }

    // Generate insights
    private var spendingInsights: [SpendingInsight] {
        InsightGenerator.generateInsights(
            categorySpending: categorySpending,
            totalExpense: totalExpense,
            previousPeriodExpense: previousPeriodExpense,
            topCategory: categorySpending.first
        )
    }

    private var previousPeriodExpense: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let (start, end): (Date, Date)

        switch selectedPeriod {
        case .week:
            end = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            start = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        case .month:
            end = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            start = calendar.date(byAdding: .month, value: -2, to: now) ?? now
        case .year:
            end = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            start = calendar.date(byAdding: .year, value: -2, to: now) ?? now
        }

        return transactions
            .filter { $0.isExpense && $0.date >= start && $0.date < end }
            .reduce(Decimal.zero) { $0 + $1.amount }
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
                            DashboardSkeleton()
                        } else {
                            dashboardContent
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isViewReady = true
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isLoading = false
                    }
                }
            }
        }
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

    // MARK: - Dashboard Content

    @ViewBuilder
    private var dashboardContent: some View {
        // 1. Personalized Header (F-pattern: top priority)
        DashboardHeader(
            userName: authService.displayName
        )
        .transition(.opacity.combined(with: .move(edge: .top)))

        // 2. Balance Card (Primary KPI)
        BalanceCard(
            total: totalBalance,
            income: totalIncome,
            expense: totalExpense,
            savingsGoal: 100000, // From user settings
            currentSavings: max(totalBalance, 0)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))

        // 3. Period Selector
        periodSelector
            .transition(.opacity)

        // 4. Quick Stats Row
        QuickStatsRow(stats: quickStats)
            .transition(.opacity.combined(with: .move(edge: .leading)))

        // 5. Spending Insights (Contextual intelligence)
        if !spendingInsights.isEmpty {
            SpendingInsightsCard(insights: spendingInsights)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }

        // 6. Budget Alerts (Important warnings)
        if !budgetProgress.isEmpty {
            BudgetAlertsWidget(budgets: budgetProgress)
                .transition(.opacity.combined(with: .move(edge: .leading)))
        }

        // 7. Spending Chart
        SpendingChartCard(
            data: Array(categorySpending.prefix(6)),
            period: selectedPeriod
        )
        .transition(.opacity.combined(with: .move(edge: .leading)))

        // 8. Recent Transactions
        RecentTransactionsSection(
            transactions: recentTransactions,
            onSeeAll: {
                // Navigate to all transactions
            }
        )
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Quick Stats

    private var quickStats: [QuickStat] {
        let avgDaily = filteredTransactions.isEmpty ? Decimal.zero : totalExpense / Decimal(max(selectedPeriod.dayCount, 1))

        return [
            QuickStat(
                title: selectedPeriod.rawValue,
                value: formatCurrency(totalExpense),
                icon: "calendar",
                color: .blue
            ),
            QuickStat(
                title: "Avg/Day",
                value: formatCurrency(avgDaily),
                icon: "chart.line.uptrend.xyaxis",
                color: .purple
            ),
            QuickStat(
                title: "Txns",
                value: "\(filteredTransactions.count)",
                icon: "list.bullet",
                color: .green
            )
        ]
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
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

    // MARK: - Profile Button

    private var profileButton: some View {
        Button {
            // Show profile/settings
        } label: {
            if let initial = authService.displayName?.first {
                Text(String(initial).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
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
        try? await Task.sleep(for: .milliseconds(500))
    }
}

// MARK: - Dashboard View with ViewModel (2026 Modern UI)

/// Alternative DashboardView using the DashboardViewModel with modern UI patterns
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
                    // 1. Personalized Header
                    DashboardHeader(userName: authService.displayName)

                    // 2. Balance Card
                    BalanceCard(
                        total: viewModel.totalBalance,
                        income: viewModel.totalIncome,
                        expense: viewModel.totalExpense,
                        incomeTrend: viewModel.incomeTrend,
                        expenseTrend: viewModel.expenseTrend
                    )

                    // 3. Period Selector
                    GlassSegmentedControl(
                        selection: Bindable(viewModel).selectedPeriod,
                        options: TimePeriod.allCases,
                        titleForOption: { $0.rawValue },
                        iconForOption: { $0.icon }
                    )
                    .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)

                    // 4. Spending Insights
                    let insights = InsightGenerator.generateInsights(
                        categorySpending: viewModel.categorySpending,
                        totalExpense: viewModel.totalExpense,
                        previousPeriodExpense: 0,
                        topCategory: viewModel.categorySpending.first
                    )
                    if !insights.isEmpty {
                        SpendingInsightsCard(insights: insights)
                    }

                    // 5. Spending Chart
                    SpendingChartCard(
                        data: Array(viewModel.categorySpending.prefix(6)),
                        period: viewModel.selectedPeriod
                    )

                    // 6. Recent Transactions
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
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
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
