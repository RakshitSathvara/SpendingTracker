//
//  AddTransactionView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Add Transaction View (Simplified 3-Tap Design)

/// Simplified modal for adding transactions with quick 3-tap logging
/// Design: Amount → Category → Save
struct AddTransactionView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Firestore Data

    @State private var categories: [Category] = []
    @State private var accounts: [Account] = []

    // MARK: - State

    @State private var viewModel: TransactionViewModel?
    @State private var formState = TransactionFormState()
    @State private var showMoreOptions = false
    @State private var showCategoryPicker = false
    @State private var showSuccessAnimation = false

    // MARK: - Edit Mode (optional)

    let editingTransaction: Transaction?

    init(editingTransaction: Transaction? = nil) {
        self.editingTransaction = editingTransaction
    }

    // MARK: - Filtered Categories

    private var filteredCategories: [Category] {
        categories.filter { $0.isExpenseCategory == formState.isExpense }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundGradient

                // Main Content
                VStack(spacing: 0) {
                    // Top Section: Amount + Type Toggle
                    amountSection
                        .padding(.top, 8)

                    Spacer(minLength: 16)

                    // Middle Section: Category Picker
                    categoryScrollSection

                    Spacer(minLength: 16)

                    // Optional: More Options (collapsed by default)
                    if showMoreOptions {
                        moreOptionsSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Bottom Section: Number Pad + Save
                    VStack(spacing: 16) {
                        numberPadSection

                        saveButton
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showMoreOptions.toggle()
                        }
                    } label: {
                        Image(systemName: showMoreOptions ? "chevron.up.circle.fill" : "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(showMoreOptions ? .blue : .secondary)
                    }
                }
            }
            .onAppear {
                setupViewModel()
            }
            .onChange(of: accounts) { _, newAccounts in
                if formState.selectedAccount == nil {
                    formState.selectedAccount = newAccounts.first
                }
            }
            .onChange(of: viewModel?.didSaveSuccessfully ?? false) { _, success in
                if success {
                    showSuccessAndDismiss()
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(
                    selection: $formState.selectedCategory,
                    categories: categories,
                    isExpense: formState.isExpense
                )
                .presentationDetents([.medium, .large])
            }
            .overlay {
                if showSuccessAnimation {
                    successOverlay
                }
            }
        }
        .sensoryFeedback(.success, trigger: showSuccessAnimation)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        AdaptiveBackground(style: .secondary)
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        if editingTransaction != nil {
            return "Edit Transaction"
        }
        return formState.isExpense ? "Add Expense" : "Add Income"
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: 12) {
            // Type Toggle (small pill)
            typeTogglePill

            // Large Amount Display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹")
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(formState.amountString == "0" ? "0" : formState.amountString)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(formState.isExpense ? Color.primary : Color.green)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: formState.amountString)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

    // MARK: - Type Toggle Pill

    private var typeTogglePill: some View {
        HStack(spacing: 0) {
            ForEach([true, false], id: \.self) { isExpense in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        formState.isExpense = isExpense
                        formState.selectedCategory = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpense ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.caption)
                        Text(isExpense ? "Expense" : "Income")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        if formState.isExpense == isExpense {
                            Capsule()
                                .fill(isExpense ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                        }
                    }
                    .foregroundStyle(formState.isExpense == isExpense ? (isExpense ? .red : .green) : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
        .sensoryFeedback(.selection, trigger: formState.isExpense)
    }

    // MARK: - Category Scroll Section

    private var categoryScrollSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Category")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if formState.selectedCategory != nil {
                    Button("Clear") {
                        withAnimation {
                            formState.selectedCategory = nil
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Horizontal Scrolling Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filteredCategories) { category in
                        CategoryChip(
                            category: category,
                            isSelected: formState.selectedCategory?.id == category.id
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                formState.selectedCategory = category
                            }
                        }
                    }

                    // More button
                    Button {
                        showCategoryPicker = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "ellipsis")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 48, height: 48)
                                .background {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                }

                            Text("More")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            .frame(height: 80)
            .sensoryFeedback(.selection, trigger: formState.selectedCategory?.id)
        }
    }

    // MARK: - More Options Section

    private var moreOptionsSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            // Account & Date Row
            HStack(spacing: 12) {
                // Account Picker
                Menu {
                    ForEach(accounts) { account in
                        Button {
                            formState.selectedAccount = account
                        } label: {
                            Label(account.name, systemImage: account.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: formState.selectedAccount?.icon ?? "creditcard")
                            .foregroundStyle(formState.selectedAccount?.color ?? .blue)
                        Text(formState.selectedAccount?.name ?? "Account")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .buttonStyle(.plain)

                // Date Picker
                DatePicker(
                    "",
                    selection: $formState.date,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .padding(.horizontal)

            // Note Field
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
                TextField("Add a note (optional)", text: $formState.note)
                    .font(.subheadline)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Number Pad Section

    private var numberPadSection: some View {
        CompactNumberPad(value: $formState.amountString) { decimal in
            formState.amount = decimal
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await saveTransaction() }
        } label: {
            HStack(spacing: 8) {
                if viewModel?.isLoading == true {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text(editingTransaction != nil ? "Update" : "Save")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        formState.isValid
                            ? (formState.isExpense ? Color.red : Color.green)
                            : Color.gray.opacity(0.3)
                    )
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!formState.isValid || viewModel?.isLoading == true)
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel?.didSaveSuccessfully ?? false)
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

                Text("Saved!")
                    .font(.title2.weight(.semibold))
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
        viewModel = TransactionViewModel()

        // Load categories and accounts from Firestore
        Task {
            do {
                categories = try await CategoryRepository().fetchCategories()
                accounts = try await AccountRepository().fetchAccounts()
            } catch {
                print("Failed to load data: \(error)")
            }
        }

        // Load existing transaction if editing
        if let transaction = editingTransaction {
            formState.loadTransaction(transaction)
            showMoreOptions = true
        }

        // Set default account if none selected
        // (will be set after async load completes)
    }

    // MARK: - Save Transaction

    private func saveTransaction() async {
        guard let viewModel = viewModel else { return }

        if let transaction = editingTransaction {
            await viewModel.updateTransaction(
                transaction,
                amount: formState.amount,
                type: formState.transactionType,
                category: formState.selectedCategory,
                account: formState.selectedAccount,
                note: formState.note,
                merchantName: formState.merchantName.isEmpty ? nil : formState.merchantName,
                date: formState.date
            )
        } else {
            await viewModel.addTransaction(
                amount: formState.amount,
                type: formState.transactionType,
                category: formState.selectedCategory,
                account: formState.selectedAccount,
                note: formState.note,
                merchantName: formState.merchantName.isEmpty ? nil : formState.merchantName,
                date: formState.date
            )
        }
    }

    // MARK: - Success Animation

    private func showSuccessAndDismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSuccessAnimation = true
        }

        // Dismiss after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismiss()
        }
    }
}

// MARK: - Category Chip

/// Compact horizontal category chip for quick selection
struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Icon
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : category.color)
                    .frame(width: 48, height: 48)
                    .background {
                        Circle()
                            .fill(isSelected ? category.color : category.color.opacity(0.15))
                    }

                // Name
                Text(category.name)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? category.color : .secondary)
                    .lineLimit(1)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
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

// MARK: - Quick Add Transaction Button

/// Floating action button for quick transaction entry
struct QuickAddTransactionButton: View {
    @State private var showAddTransaction = false
    @State private var isPressed = false

    var body: some View {
        Button {
            showAddTransaction = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
        .fullScreenCover(isPresented: $showAddTransaction) {
            AddTransactionView()
        }
    }
}

// MARK: - Preview

#Preview("Add Transaction") {
    AddTransactionView()
}

#Preview("Quick Add Button") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                QuickAddTransactionButton()
                    .padding()
            }
        }
    }
}
