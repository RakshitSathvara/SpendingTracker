//
//  BudgetDetailView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Budget Detail View (iOS 26 Stable)

/// Detailed view for a single budget with transaction history
struct BudgetDetailView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Properties

    let budget: Budget

    // MARK: - State

    @State private var viewModel: BudgetViewModel?
    @State private var showEditBudget = false
    @State private var showDeleteConfirmation = false
    @State private var isViewReady = false

    // MARK: - Computed Properties

    private var spent: Decimal {
        viewModel?.spentAmount(for: budget) ?? 0
    }

    private var remaining: Decimal {
        viewModel?.remainingAmount(for: budget) ?? budget.amount
    }

    private var progress: Double {
        viewModel?.progress(for: budget) ?? 0
    }

    private var progressColor: Color {
        viewModel?.progressColor(for: budget) ?? .green
    }

    private var dailyAllowance: Decimal {
        viewModel?.dailyAllowance(for: budget) ?? 0
    }

    private var budgetTransactions: [Transaction] {
        viewModel?.transactions(for: budget) ?? []
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive Background
                AdaptiveBackground(style: .primary)

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Progress Card
                        progressCard

                        // Stats Grid
                        statsGrid

                        // Daily Allowance Card
                        if budget.isActive && !budget.isExpired && dailyAllowance > 0 {
                            dailyAllowanceCard
                        }

                        // Spending Chart
                        if !budgetTransactions.isEmpty {
                            spendingChartCard
                        }

                        // Transactions Section
                        transactionsSection

                        // Action Buttons
                        actionButtons
                    }
                    .padding()
                    .opacity(isViewReady ? 1 : 0)
                }
            }
            .navigationTitle("Budget Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditBudget = true
                        } label: {
                            Label("Edit Budget", systemImage: "pencil")
                        }

                        if budget.isExpired {
                            Button {
                                Task {
                                    await viewModel?.renewBudget(budget)
                                }
                            } label: {
                                Label("Renew Budget", systemImage: "arrow.clockwise")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Budget", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showEditBudget) {
                AddBudgetView(editingBudget: budget)
                    .environment(\.modelContext, modelContext)
                    .environment(syncService)
                    .onDisappear {
                        viewModel?.refresh()
                    }
            }
            .confirmationDialog(
                "Delete Budget",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel?.deleteBudget(budget)
                        dismiss()
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this budget? This action cannot be undone.")
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
    }

    // MARK: - Setup

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = BudgetViewModel(modelContext: modelContext, syncService: syncService)
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        GlassCard {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    if let category = budget.category {
                        Image(systemName: category.icon)
                            .font(.title2)
                            .foregroundStyle(category.color)
                            .frame(width: 48, height: 48)
                            .background(category.color.opacity(0.2))
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 48, height: 48)
                            .background(.blue.opacity(0.2))
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(budget.category?.name ?? "All Categories")
                            .font(.title3)
                            .fontWeight(.bold)

                        HStack(spacing: 8) {
                            Text(budget.period.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if budget.isExpired {
                                Text("• Expired")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else if !budget.isActive {
                                Text("• Inactive")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()
                }

                // Progress Ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 140, height: 140)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: min(progress, 1.0))
                        .stroke(
                            progressColor.gradient,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                    // Center content
                    VStack(spacing: 4) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(progressColor)

                        Text("used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Amount labels
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(spent))
                            .font(.headline)
                            .foregroundStyle(progress >= 1.0 ? .red : .primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Budget")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(budget.amount))
                            .font(.headline)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // Remaining
            StatCard(
                title: "Remaining",
                value: formatCurrency(remaining),
                icon: "indianrupeesign.circle.fill",
                color: remaining >= 0 ? .green : .red,
                isNegative: remaining < 0
            )

            // Days Left
            StatCard(
                title: "Days Left",
                value: budget.isExpired ? "0" : "\(budget.daysRemaining)",
                icon: "clock.fill",
                color: budget.daysRemaining <= 3 ? .orange : .blue
            )

            // Transactions
            StatCard(
                title: "Transactions",
                value: "\(budgetTransactions.count)",
                icon: "list.bullet.rectangle.fill",
                color: .purple
            )

            // Alert Threshold
            StatCard(
                title: "Alert At",
                value: "\(Int(budget.alertThreshold * 100))%",
                icon: "bell.fill",
                color: progress >= budget.alertThreshold ? .orange : .secondary
            )
        }
    }

    // MARK: - Daily Allowance Card

    private var dailyAllowanceCard: some View {
        GlassCard {
            HStack(spacing: 16) {
                Image(systemName: "calendar.day.timeline.left")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.blue.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Allowance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(formatCurrency(dailyAllowance))
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("to stay on track")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(budget.daysRemaining) days")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .padding()
        }
    }

    // MARK: - Spending Chart Card

    private var spendingChartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Spending Over Time")
                    .font(.headline)

                // Daily spending chart
                Chart {
                    ForEach(dailySpendingData, id: \.date) { data in
                        BarMark(
                            x: .value("Date", data.date, unit: .day),
                            y: .value("Amount", NSDecimalNumber(decimal: data.amount).doubleValue)
                        )
                        .foregroundStyle(progressColor.gradient)
                        .cornerRadius(4)
                    }

                    // Budget line
                    let dailyBudget = NSDecimalNumber(decimal: budget.amount / Decimal(budget.period.days)).doubleValue
                    RuleMark(y: .value("Daily Budget", dailyBudget))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Daily avg")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("₹\(Int(amount))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var dailySpendingData: [(date: Date, amount: Decimal)] {
        let calendar = Calendar.current
        var dataByDate: [Date: Decimal] = [:]

        // Initialize all dates in the budget period
        var currentDate = budget.startDate
        while currentDate <= min(Date(), budget.endDate) {
            let normalizedDate = calendar.startOfDay(for: currentDate)
            dataByDate[normalizedDate] = 0
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Sum transactions by date
        for transaction in budgetTransactions {
            let normalizedDate = calendar.startOfDay(for: transaction.date)
            dataByDate[normalizedDate, default: 0] += transaction.amount
        }

        return dataByDate.map { (date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Transactions Section

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.headline)

                Spacer()

                if !budgetTransactions.isEmpty {
                    Text("\(budgetTransactions.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if budgetTransactions.isEmpty {
                GlassCard {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("No transactions yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Expenses in this category will appear here")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                GlassCard {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(budgetTransactions.prefix(10).enumerated()), id: \.element.id) { index, transaction in
                            BudgetTransactionRow(transaction: transaction)

                            if index < min(budgetTransactions.count - 1, 9) {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }

                        if budgetTransactions.count > 10 {
                            Divider()

                            HStack {
                                Text("+ \(budgetTransactions.count - 10) more transactions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if budget.isExpired {
                GlassButton(
                    title: "Renew Budget",
                    icon: "arrow.clockwise",
                    tint: .blue
                ) {
                    Task {
                        await viewModel?.renewBudget(budget)
                    }
                }
            }

            GlassButton(
                title: "Edit Budget",
                icon: "pencil",
                tint: .secondary
            ) {
                showEditBudget = true
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isNegative: Bool = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(isNegative ? .red : .primary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Budget Transaction Row

struct BudgetTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            if let category = transaction.category {
                Image(systemName: category.icon)
                    .font(.subheadline)
                    .foregroundStyle(category.color)
                    .frame(width: 36, height: 36)
                    .background(category.color.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .background(.red.opacity(0.1))
                    .clipShape(Circle())
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayTitle)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(transaction.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount
            Text(transaction.formattedAmount)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.red)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Budget Detail") {
    BudgetDetailView(budget: .preview)
        .environment(SyncService.shared)
        .modelContainer(.preview)
}
