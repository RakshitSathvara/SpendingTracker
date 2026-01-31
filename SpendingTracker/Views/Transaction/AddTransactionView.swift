//
//  AddTransactionView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Add Transaction View (iOS 26 Stable)

/// Full-screen modal for adding transactions with quick 3-tap logging
struct AddTransactionView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    // MARK: - SwiftData Queries

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    // MARK: - State

    @State private var viewModel: TransactionViewModel?
    @State private var formState = TransactionFormState()
    @State private var showCategoryPicker = false
    @State private var showSuccessAnimation = false

    // MARK: - Edit Mode (optional)

    let editingTransaction: Transaction?

    init(editingTransaction: Transaction? = nil) {
        self.editingTransaction = editingTransaction
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AnimatedMeshGradient()
                    .ignoresSafeArea()

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Amount Display
                        amountDisplaySection

                        // Type Toggle
                        typeToggleSection

                        // Category Grid
                        categorySection

                        // Account & Date Row
                        accountDateSection

                        // Note Field
                        noteSection

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
                CategoryPickerSheet(
                    selection: $formState.selectedCategory,
                    categories: categories,
                    isExpense: formState.isExpense
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
        if editingTransaction != nil {
            return "Edit Transaction"
        }
        return formState.isExpense ? "Add Expense" : "Add Income"
    }

    // MARK: - Amount Display Section

    private var amountDisplaySection: some View {
        GlassAmountDisplay(
            amount: formState.amount,
            isExpense: formState.isExpense,
            showSign: false,
            size: .hero
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: formState.amount)
    }

    // MARK: - Type Toggle Section

    private var typeToggleSection: some View {
        GlassSegmentedControl(
            selection: $formState.isExpense,
            options: [true, false],
            titleForOption: { $0 ? "Expense" : "Income" },
            iconForOption: { $0 ? "arrow.up.circle" : "arrow.down.circle" }
        )
        .onChange(of: formState.isExpense) { _, _ in
            // Reset category when type changes
            formState.selectedCategory = nil
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            CategoryQuickPicker(
                selection: $formState.selectedCategory,
                categories: categories,
                isExpense: formState.isExpense
            ) {
                showCategoryPicker = true
            }
        }
    }

    // MARK: - Account & Date Section

    private var accountDateSection: some View {
        HStack(spacing: 12) {
            AccountPicker(
                selection: $formState.selectedAccount,
                accounts: accounts
            )
            .frame(maxWidth: .infinity)

            DateQuickPicker(selection: $formState.date)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        GlassTextField(
            placeholder: "Add note (optional)",
            text: $formState.note,
            icon: "note.text"
        )
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
        GlassButton(
            title: editingTransaction != nil ? "Update Transaction" : "Save Transaction",
            icon: "checkmark.circle",
            tint: formState.isExpense ? .red : .green,
            isLoading: viewModel?.isLoading ?? false
        ) {
            Task { await saveTransaction() }
        }
        .disabled(!formState.isValid || viewModel?.isLoading == true)
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

                Text("Transaction Saved!")
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
        viewModel = TransactionViewModel(modelContext: modelContext, syncService: syncService)

        // Load existing transaction if editing
        if let transaction = editingTransaction {
            formState.loadTransaction(transaction)
        }

        // Set default account if none selected
        if formState.selectedAccount == nil {
            formState.selectedAccount = accounts.first
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
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
        .modelContainer(.preview)
        .environment(SyncService.shared)
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
    .modelContainer(.preview)
    .environment(SyncService.shared)
}
