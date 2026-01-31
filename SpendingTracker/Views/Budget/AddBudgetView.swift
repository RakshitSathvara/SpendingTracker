//
//  AddBudgetView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Add Budget View (iOS 26 Stable)

/// Full-screen modal for adding or editing budgets
struct AddBudgetView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    // MARK: - SwiftData Queries

    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // MARK: - State

    @State private var viewModel: BudgetViewModel?
    @State private var formState = BudgetFormState()
    @State private var showCategoryPicker = false
    @State private var showSuccessAnimation = false

    // MARK: - Edit Mode (optional)

    let editingBudget: Budget?

    init(editingBudget: Budget? = nil) {
        self.editingBudget = editingBudget
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AnimatedMeshGradient(colorScheme: .blue)
                    .ignoresSafeArea()

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Amount Display
                        amountDisplaySection

                        // Category Selection
                        categorySection

                        // Period Selection
                        periodSection

                        // Start Date Selection
                        startDateSection

                        // Alert Threshold
                        alertThresholdSection

                        // Number Pad
                        numberPadSection

                        // Save Button
                        saveButtonSection
                    }
                    .padding()
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                setupViewModel()
            }
            .onChange(of: viewModel?.didSaveSuccessfully ?? false) { _, success in
                if success {
                    showSuccessAndDismiss()
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                BudgetCategoryPickerSheet(
                    selection: $formState.selectedCategory,
                    categories: categories
                )
            }
            .overlay {
                if showSuccessAnimation {
                    successOverlay
                }
            }
        }
        .sensoryFeedback(.success, trigger: showSuccessAnimation)
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        editingBudget != nil ? "Edit Budget" : "New Budget"
    }

    // MARK: - Amount Display Section

    private var amountDisplaySection: some View {
        VStack(spacing: 8) {
            Text("Budget Amount")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            GlassAmountDisplay(
                amount: formState.amount,
                isExpense: false,
                showSign: false,
                size: .hero
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: formState.amount)
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

                if formState.selectedCategory != nil {
                    Button("Clear") {
                        formState.selectedCategory = nil
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Category Picker
            BudgetCategoryPicker(
                selection: $formState.selectedCategory,
                categories: categories.filter { $0.isExpenseCategory }
            ) {
                showCategoryPicker = true
            }
        }
    }

    // MARK: - Period Section

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Period")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            GlassSegmentedControl(
                selection: $formState.period,
                options: BudgetPeriod.allCases,
                titleForOption: { $0.displayName },
                iconForOption: { $0.icon }
            )
        }
    }

    // MARK: - Start Date Section

    private var startDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Date")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            GlassCard {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "",
                        selection: $formState.startDate,
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
                .padding()
            }
        }
    }

    // MARK: - Alert Threshold Section

    private var alertThresholdSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Alert Threshold")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(formState.thresholdPercentage)%")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            GlassCard {
                VStack(spacing: 16) {
                    Slider(
                        value: $formState.alertThreshold,
                        in: 0.5...0.95,
                        step: 0.05
                    ) {
                        Text("Alert at \(formState.thresholdPercentage)%")
                    }
                    .tint(.blue)

                    HStack {
                        Text("50%")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("95%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("You'll be alerted when spending reaches \(formState.thresholdPercentage)% of your budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }

    // MARK: - Number Pad Section

    private var numberPadSection: some View {
        NumberPad(
            value: $formState.amountString,
            onValueChange: { decimal in
                formState.amount = decimal
            }
        )
    }

    // MARK: - Save Button Section

    private var saveButtonSection: some View {
        VStack(spacing: 12) {
            // Error message
            if let errorMessage = viewModel?.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            GlassButton(
                title: editingBudget != nil ? "Update Budget" : "Create Budget",
                icon: "checkmark.circle",
                tint: .blue,
                isLoading: viewModel?.isLoading ?? false
            ) {
                Task { await saveBudget() }
            }
            .disabled(!formState.isValid || viewModel?.isLoading == true)
        }
        .padding(.top, 8)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showSuccessAnimation)

                Text("Budget \(editingBudget != nil ? "Updated" : "Created")!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(40)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Setup

    private func setupViewModel() {
        viewModel = BudgetViewModel(modelContext: modelContext, syncService: syncService)

        // Load existing budget if editing
        if let budget = editingBudget {
            formState.loadBudget(budget)
        }
    }

    // MARK: - Save Budget

    private func saveBudget() async {
        guard let viewModel = viewModel else { return }

        if let budget = editingBudget {
            await viewModel.updateBudget(
                budget,
                amount: formState.amount,
                period: formState.period,
                startDate: formState.startDate,
                alertThreshold: formState.alertThreshold,
                category: formState.selectedCategory,
                isActive: formState.isActive
            )
        } else {
            await viewModel.addBudget(
                amount: formState.amount,
                period: formState.period,
                startDate: formState.startDate,
                alertThreshold: formState.alertThreshold,
                category: formState.selectedCategory
            )
        }
    }

    // MARK: - Success Animation

    private func showSuccessAndDismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSuccessAnimation = true
        }

        // Dismiss after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}

// MARK: - Budget Category Picker

/// A horizontal scrolling category picker for budgets
struct BudgetCategoryPicker: View {
    @Binding var selection: Category?
    let categories: [Category]
    let onShowMore: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "All Categories" option
                CategoryChip(
                    name: "All Categories",
                    icon: "square.grid.2x2.fill",
                    color: .blue,
                    isSelected: selection == nil
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = nil
                    }
                }

                // Category chips
                ForEach(Array(categories.prefix(6))) { category in
                    CategoryChip(
                        name: category.name,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selection?.id == category.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = category
                        }
                    }
                }

                // More button if needed
                if categories.count > 6 {
                    CategoryChip(
                        name: "More",
                        icon: "ellipsis",
                        color: .secondary,
                        isSelected: false
                    ) {
                        onShowMore()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : color)

                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(color.gradient)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(color.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}

// MARK: - Budget Category Picker Sheet

/// Full-screen category picker for budgets
struct BudgetCategoryPickerSheet: View {
    @Binding var selection: Category?
    let categories: [Category]
    @Environment(\.dismiss) private var dismiss

    private var expenseCategories: [Category] {
        categories.filter { $0.isExpenseCategory }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // All Categories option
                    Button {
                        selection = nil
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .frame(width: 44, height: 44)
                                .background(.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("All Categories")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("Track spending across all categories")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selection == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selection == nil ? .blue.opacity(0.1) : Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(selection == nil ? .blue.opacity(0.3) : .clear, lineWidth: 1)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Category Grid
                    Text("Expense Categories")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(expenseCategories) { category in
                            CategoryGridItem(
                                category: category,
                                isSelected: selection?.id == category.id
                            ) {
                                selection = category
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Category Grid Item

struct CategoryGridItem: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : category.color)
                    .frame(width: 56, height: 56)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(category.color.gradient)
                        } else {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(category.color.opacity(0.1))
                        }
                    }

                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? category.color : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Add Budget") {
    AddBudgetView()
        .modelContainer(.preview)
        .environment(SyncService.shared)
}

#Preview("Edit Budget") {
    AddBudgetView(editingBudget: .preview)
        .modelContainer(.preview)
        .environment(SyncService.shared)
}
