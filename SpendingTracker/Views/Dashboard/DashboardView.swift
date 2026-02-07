//
//  DashboardView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//  Enhanced with 2026 Modern Dashboard UI Best Practices
//

import SwiftUI
import Charts

// MARK: - Dashboard View (2026 Modern UI - Firestore Only)

/// The main dashboard view with modern UI patterns:
/// - F/Z pattern information hierarchy
/// - Personalized greeting header
/// - Quick actions for frequent tasks
/// - Contextual insights
/// - Budget status alerts
/// - Smooth micro-interactions
/// - Uses DashboardViewModel for Firestore-only data management
struct DashboardView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    @State private var addTransactionType: TransactionType = .expense
    @State private var isViewReady = false

    // MARK: - Computed Properties

    private var budgetProgress: [BudgetProgress] {
        viewModel.budgets.compactMap { budget -> BudgetProgress? in
            guard let categoryId = budget.categoryId,
                  let category = viewModel.categories.first(where: { $0.id == categoryId }) else {
                return nil
            }

            let spent = viewModel.allTransactions
                .filter { $0.isExpense && $0.categoryId == categoryId && $0.date >= budget.startDate && $0.date <= budget.endDate }
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

    private var spendingInsights: [SpendingInsight] {
        InsightGenerator.generateInsights(
            categorySpending: viewModel.categorySpending,
            totalExpense: viewModel.totalExpense,
            previousPeriodExpense: 0,
            topCategory: viewModel.categorySpending.first
        )
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
                        if viewModel.isLoading && !viewModel.hasLoadedOnce {
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
                Task {
                    await viewModel.loadIfNeeded()
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
            total: viewModel.totalBalance,
            income: viewModel.totalIncome,
            expense: viewModel.totalExpense,
            incomeTrend: viewModel.incomeTrend,
            expenseTrend: viewModel.expenseTrend
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
            data: Array(viewModel.categorySpending.prefix(6)),
            period: viewModel.selectedPeriod
        )
        .transition(.opacity.combined(with: .move(edge: .leading)))

        // 8. Recent Transactions
        RecentTransactionsSection(
            transactions: viewModel.recentTransactions,
            onSeeAll: {
                // Navigate to all transactions
            }
        )
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Quick Stats

    private var quickStats: [QuickStat] {
        let avgDaily = viewModel.filteredTransactions.isEmpty ? Decimal.zero : viewModel.totalExpense / Decimal(max(viewModel.selectedPeriod.dayCount, 1))

        return [
            QuickStat(
                title: viewModel.selectedPeriod.rawValue,
                value: viewModel.formatCurrency(viewModel.totalExpense),
                icon: "calendar",
                color: .blue
            ),
            QuickStat(
                title: "Avg/Day",
                value: viewModel.formatCurrency(avgDaily),
                icon: "chart.line.uptrend.xyaxis",
                color: .purple
            ),
            QuickStat(
                title: "Txns",
                value: "\(viewModel.filteredTransactions.count)",
                icon: "list.bullet",
                color: .green
            )
        ]
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        GlassSegmentedControl(
            selection: Bindable(viewModel).selectedPeriod,
            options: TimePeriod.allCases,
            titleForOption: { $0.rawValue },
            iconForOption: { $0.icon }
        )
        .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)
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
        await viewModel.refresh()
    }
}

// MARK: - Preview

#Preview("Dashboard View") {
    DashboardView()
        .environment(AuthenticationService())
}
