//
//  BudgetListView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Budget List View (iOS 26 Stable)

/// Main view displaying all budgets with progress indicators
struct BudgetListView: View {

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var viewModel: BudgetViewModel?
    @State private var showAddBudget = false
    @State private var selectedBudget: Budget?
    @State private var showBudgetDetail = false
    @State private var isViewReady = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive Background
                AdaptiveBackground(style: .primary)

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if let vm = viewModel {
                            if vm.budgets.isEmpty {
                                emptyStateView
                            } else {
                                // Budget Summary Card
                                budgetSummaryCard(viewModel: vm)

                                // Active Budgets Section
                                if !vm.activeBudgets.isEmpty {
                                    budgetSection(
                                        title: "Active Budgets",
                                        budgets: vm.activeBudgets,
                                        viewModel: vm
                                    )
                                }

                                // Alert Budgets Section (over threshold)
                                let alertBudgets = vm.alertBudgets.filter { !vm.isOverBudget(for: $0) }
                                if !alertBudgets.isEmpty {
                                    warningBanner(count: alertBudgets.count)
                                }

                                // Expired Budgets Section
                                if !vm.expiredBudgets.isEmpty {
                                    budgetSection(
                                        title: "Expired Budgets",
                                        budgets: vm.expiredBudgets,
                                        viewModel: vm,
                                        isExpired: true
                                    )
                                }
                            }
                        } else {
                            // Loading skeleton
                            BudgetListSkeleton()
                        }
                    }
                    .padding()
                    .opacity(isViewReady ? 1 : 0)
                }
                .refreshable {
                    await viewModel?.refresh()
                }
            }
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBudget = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetView()
                    .onDisappear {
                        Task { await viewModel?.refresh() }
                    }
            }
            .sheet(item: $selectedBudget) { budget in
                BudgetDetailView(budget: budget)
                    .onDisappear {
                        Task { await viewModel?.refresh() }
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
    }

    // MARK: - Setup

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = BudgetViewModel()
            Task { await viewModel?.loadData() }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.pie.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("No Budgets Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create your first budget to start tracking your spending limits.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            GlassButton(
                title: "Create Budget",
                icon: "plus.circle",
                tint: .blue
            ) {
                showAddBudget = true
            }
            .frame(maxWidth: 200)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Budget Summary Card

    private func budgetSummaryCard(viewModel: BudgetViewModel) -> some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Budget")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(viewModel.totalBudgetedAmount))
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Spent")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(viewModel.totalSpentAmount))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(viewModel.totalSpentAmount > viewModel.totalBudgetedAmount ? .red : .primary)
                    }
                }

                // Overall Progress
                let overallProgress = viewModel.totalBudgetedAmount > 0
                    ? NSDecimalNumber(decimal: viewModel.totalSpentAmount / viewModel.totalBudgetedAmount).doubleValue
                    : 0

                VStack(spacing: 8) {
                    ProgressView(value: min(overallProgress, 1.0))
                        .tint(progressColor(for: overallProgress))

                    HStack {
                        Text("\(Int(overallProgress * 100))% used")
                            .font(.caption)
                            .foregroundStyle(progressColor(for: overallProgress))

                        Spacer()

                        Text("\(viewModel.activeBudgets.count) active budgets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Budget Section

    private func budgetSection(
        title: String,
        budgets: [Budget],
        viewModel: BudgetViewModel,
        isExpired: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(isExpired ? .secondary : .primary)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(budgets) { budget in
                    let categoryData = viewModel.categoryData(for: budget)
                    BudgetRow(
                        budget: budget,
                        spent: viewModel.spentAmount(for: budget),
                        progress: viewModel.progress(for: budget),
                        progressColor: viewModel.progressColor(for: budget),
                        dailyAllowance: viewModel.dailyAllowance(for: budget),
                        isExpired: isExpired,
                        categoryName: categoryData.name,
                        categoryIcon: categoryData.icon,
                        categoryColor: categoryData.color
                    )
                    .onTapGesture {
                        selectedBudget = budget
                    }
                    .contextMenu {
                        budgetContextMenu(for: budget, viewModel: viewModel, isExpired: isExpired)
                    }
                }
            }
        }
    }

    // MARK: - Warning Banner

    private func warningBanner(count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) budget\(count == 1 ? "" : "s") approaching limit")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Review your spending to stay on track")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func budgetContextMenu(
        for budget: Budget,
        viewModel: BudgetViewModel,
        isExpired: Bool
    ) -> some View {
        Button {
            selectedBudget = budget
        } label: {
            Label("View Details", systemImage: "eye")
        }

        if isExpired {
            Button {
                Task {
                    await viewModel.renewBudget(budget)
                }
            } label: {
                Label("Renew Budget", systemImage: "arrow.clockwise")
            }
        } else {
            Button {
                Task {
                    await viewModel.deactivateBudget(budget)
                }
            } label: {
                Label("Deactivate", systemImage: "pause.circle")
            }
        }

        Divider()

        Button(role: .destructive) {
            Task {
                await viewModel.deleteBudget(budget)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }

    private func progressColor(for progress: Double) -> Color {
        switch progress {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .yellow
        case 0.8..<1.0: return .orange
        default: return .red
        }
    }
}

// MARK: - Budget List Skeleton

struct BudgetListSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            // Summary skeleton
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .frame(height: 140)
                .shimmer()

            // Budget items skeleton
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(height: 120)
                    .shimmer()
            }
        }
    }
}

// MARK: - Preview

#Preview("Budget List") {
    BudgetListView()
}

#Preview("Empty State") {
    BudgetListView()
}
