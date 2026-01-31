//
//  TransactionFilterSheet.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Date Range Preset

enum DateRangePreset: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .yesterday: return "arrow.uturn.backward"
        case .thisWeek: return "calendar.badge.clock"
        case .thisMonth: return "calendar"
        case .lastMonth: return "calendar.badge.minus"
        case .custom: return "calendar.badge.plus"
        }
    }

    var dateRange: ClosedRange<Date>? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
            return start...end

        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let start = calendar.startOfDay(for: yesterday)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
            return start...end

        case .thisWeek:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            let end = calendar.date(byAdding: .day, value: 1, to: endOfWeek)!.addingTimeInterval(-1)
            return startOfWeek...end

        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            let end = calendar.date(byAdding: .day, value: 1, to: endOfMonth)!.addingTimeInterval(-1)
            return startOfMonth...end

        case .lastMonth:
            let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
            let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfThisMonth)!
            let end = calendar.date(byAdding: .day, value: 1, to: endOfLastMonth)!.addingTimeInterval(-1)
            return startOfLastMonth...end

        case .custom:
            return nil
        }
    }
}

// MARK: - Transaction Filter State

@Observable
class TransactionFilterState {
    var selectedCategory: Category?
    var selectedAccount: Account?
    var dateRangePreset: DateRangePreset = .thisMonth
    var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    var customEndDate: Date = Date()
    var showExpenses: Bool = true
    var showIncome: Bool = true

    var hasActiveFilters: Bool {
        selectedCategory != nil ||
        selectedAccount != nil ||
        dateRangePreset != .thisMonth ||
        !showExpenses ||
        !showIncome
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedCategory != nil { count += 1 }
        if selectedAccount != nil { count += 1 }
        if dateRangePreset != .thisMonth { count += 1 }
        if !showExpenses || !showIncome { count += 1 }
        return count
    }

    var dateRange: ClosedRange<Date>? {
        if dateRangePreset == .custom {
            return customStartDate...customEndDate
        }
        return dateRangePreset.dateRange
    }

    func reset() {
        selectedCategory = nil
        selectedAccount = nil
        dateRangePreset = .thisMonth
        customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        customEndDate = Date()
        showExpenses = true
        showIncome = true
    }
}

// MARK: - Transaction Filter Sheet (iOS 26 Stable)

struct TransactionFilterSheet: View {
    @Bindable var filterState: TransactionFilterState
    let categories: [Category]
    let accounts: [Account]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Use provided categories or fallback to defaults
    private var displayCategories: [Category] {
        categories.isEmpty ? Category.allDefaultCategories : categories
    }

    // Use provided accounts or fallback to defaults
    private var displayAccounts: [Account] {
        accounts.isEmpty ? Account.defaultAccounts : accounts
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Transaction Type Filter
                    transactionTypeSection

                    // Date Range Filter
                    dateRangeSection

                    // Category Filter
                    categorySection

                    // Account Filter
                    accountSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Filter Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if filterState.hasActiveFilters {
                    resetButton
                }
            }
        }
    }

    // MARK: - Transaction Type Section

    private var transactionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transaction Type")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                FilterToggleButton(
                    title: "Expenses",
                    icon: "arrow.up.circle.fill",
                    isSelected: filterState.showExpenses,
                    color: .red
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        filterState.showExpenses.toggle()
                    }
                }

                FilterToggleButton(
                    title: "Income",
                    icon: "arrow.down.circle.fill",
                    isSelected: filterState.showIncome,
                    color: .green
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        filterState.showIncome.toggle()
                    }
                }
            }
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Range")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(DateRangePreset.allCases) { preset in
                    DatePresetButton(
                        preset: preset,
                        isSelected: filterState.dateRangePreset == preset
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            filterState.dateRangePreset = preset
                        }
                    }
                }
            }

            // Custom Date Pickers
            if filterState.dateRangePreset == .custom {
                VStack(spacing: 12) {
                    DatePicker(
                        "Start Date",
                        selection: $filterState.customStartDate,
                        displayedComponents: .date
                    )

                    DatePicker(
                        "End Date",
                        selection: $filterState.customEndDate,
                        in: filterState.customStartDate...,
                        displayedComponents: .date
                    )
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Category")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                if filterState.selectedCategory != nil {
                    Button("Clear") {
                        withAnimation { filterState.selectedCategory = nil }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All Categories option
                    CategoryFilterChip(
                        name: "All",
                        icon: "square.grid.2x2.fill",
                        color: .blue,
                        isSelected: filterState.selectedCategory == nil
                    ) {
                        withAnimation { filterState.selectedCategory = nil }
                    }

                    ForEach(displayCategories) { category in
                        CategoryFilterChip(
                            name: category.name,
                            icon: category.icon,
                            color: category.color,
                            isSelected: filterState.selectedCategory?.id == category.id
                        ) {
                            withAnimation { filterState.selectedCategory = category }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Account")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                if filterState.selectedAccount != nil {
                    Button("Clear") {
                        withAnimation { filterState.selectedAccount = nil }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All Accounts option
                    AccountFilterChip(
                        name: "All",
                        icon: "wallet.pass.fill",
                        color: .purple,
                        isSelected: filterState.selectedAccount == nil
                    ) {
                        withAnimation { filterState.selectedAccount = nil }
                    }

                    ForEach(displayAccounts) { account in
                        AccountFilterChip(
                            name: account.name,
                            icon: account.icon,
                            color: account.color,
                            isSelected: filterState.selectedAccount?.id == account.id
                        ) {
                            withAnimation { filterState.selectedAccount = account }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                filterState.reset()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset All Filters")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.red.gradient)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Supporting Components

struct FilterToggleButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? color : .secondary)
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? color : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DatePresetButton: View {
    let preset: DateRangePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: preset.icon)
                    .font(.title3)
                Text(preset.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
            }
        }
        .buttonStyle(.plain)
    }
}

struct CategoryFilterChip: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
            }
        }
        .buttonStyle(.plain)
    }
}

struct AccountFilterChip: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Transaction Filter Sheet") {
    struct PreviewWrapper: View {
        @State private var filterState = TransactionFilterState()

        var body: some View {
            TransactionFilterSheet(
                filterState: filterState,
                categories: Category.allDefaultCategories,
                accounts: Account.defaultAccounts,
                onApply: {}
            )
        }
    }

    return PreviewWrapper()
}
