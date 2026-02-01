//
//  AddAccountView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Add Account View (iOS 26 Stable)

/// Form for creating or editing accounts
struct AddAccountView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var viewModel: AccountViewModel?
    @State private var formState = AccountFormState()
    @State private var showSuccessAnimation = false

    // MARK: - Edit Mode

    let editingAccount: Account?

    init(editingAccount: Account? = nil) {
        self.editingAccount = editingAccount
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive Background
                AdaptiveBackground(style: .secondary)

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Preview Card
                        accountPreview

                        // Name Field
                        nameSection

                        // Account Type Picker
                        accountTypeSection

                        // Initial Balance
                        balanceSection

                        // Icon Picker
                        iconPickerSection

                        // Color Picker
                        colorPickerSection

                        // Save Button
                        saveButtonSection
                    }
                    .padding()
                }
            }
            .navigationTitle(editingAccount != nil ? "Edit Account" : "New Account")
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
            .overlay {
                if showSuccessAnimation {
                    successOverlay
                }
            }
        }
        .sensoryFeedback(.success, trigger: showSuccessAnimation)
    }

    // MARK: - Setup

    private func setupViewModel() {
        viewModel = AccountViewModel(modelContext: modelContext, syncService: syncService)

        if let account = editingAccount {
            formState.loadAccount(account)
        }
    }

    // MARK: - Account Preview

    private var accountPreview: some View {
        GlassCard {
            HStack(spacing: 16) {
                // Icon Preview
                Image(systemName: formState.selectedIcon)
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(formState.selectedColor.gradient)
                    .clipShape(Circle())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: formState.selectedIcon)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: formState.selectedColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(formState.name.isEmpty ? "Account Name" : formState.name)
                        .font(.headline)
                        .foregroundStyle(formState.name.isEmpty ? .secondary : .primary)

                    Text(formState.accountType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(formState.initialBalance))
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Balance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account Name")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            GlassTextField(
                placeholder: "Enter account name",
                text: $formState.name,
                icon: "creditcard"
            )
        }
    }

    // MARK: - Account Type Section

    private var accountTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Type")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            GlassCard(padding: 0) {
                LazyVStack(spacing: 0) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        AccountTypeRow(
                            type: type,
                            isSelected: formState.accountType == type
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                formState.updateForAccountType(type)
                            }
                        }

                        if type != AccountType.allCases.last {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Balance Section

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Initial Balance")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            GlassCard {
                HStack {
                    Text("₹")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    TextField("0", text: $formState.initialBalanceString)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .keyboardType(.decimalPad)
                        .onChange(of: formState.initialBalanceString) { _, newValue in
                            formState.updateBalance(from: newValue)
                        }

                    Spacer()

                    Button {
                        formState.initialBalanceString = ""
                        formState.initialBalance = 0
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .opacity(formState.initialBalanceString.isEmpty ? 0 : 1)
                }
                .padding()
            }
        }
    }

    // MARK: - Icon Picker Section

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            GlassCard(padding: 12) {
                AccountIconPicker(selection: $formState.selectedIcon, color: formState.selectedColor)
            }
        }
    }

    // MARK: - Color Picker Section

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            GlassCard(padding: 12) {
                ColorPickerGrid(selection: $formState.selectedColor)
            }
        }
    }

    // MARK: - Save Button Section

    private var saveButtonSection: some View {
        VStack(spacing: 12) {
            if let errorMessage = viewModel?.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            GlassButton(
                title: editingAccount != nil ? "Update Account" : "Create Account",
                icon: "checkmark.circle",
                tint: formState.selectedColor,
                isLoading: viewModel?.isLoading ?? false
            ) {
                Task { await saveAccount() }
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

                Text("Account \(editingAccount != nil ? "Updated" : "Created")!")
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

    // MARK: - Save Account

    private func saveAccount() async {
        guard let viewModel = viewModel else { return }

        if let account = editingAccount {
            await viewModel.updateAccount(
                account,
                name: formState.name,
                accountType: formState.accountType,
                initialBalance: formState.initialBalance,
                icon: formState.selectedIcon,
                colorHex: formState.colorHex
            )
        } else {
            await viewModel.addAccount(
                name: formState.name,
                accountType: formState.accountType,
                initialBalance: formState.initialBalance,
                icon: formState.selectedIcon,
                colorHex: formState.colorHex
            )
        }
    }

    // MARK: - Success Animation

    private func showSuccessAndDismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSuccessAnimation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }
}

// MARK: - Account Type Row

struct AccountTypeRow: View {
    let type: AccountType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: type.defaultColor)?.gradient ?? Color.blue.gradient)
                    .clipShape(Circle())

                Text(type.rawValue)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Account Icon Picker

struct AccountIconPicker: View {
    @Binding var selection: String
    let color: Color

    private let icons = [
        "banknote.fill", "creditcard.fill", "building.columns.fill",
        "dollarsign.circle.fill", "wallet.pass.fill", "indianrupeesign.circle.fill",
        "chart.pie.fill", "chart.bar.fill", "safe.fill",
        "briefcase.fill", "bag.fill", "storefront.fill"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(icons, id: \.self) { icon in
                IconButton(
                    icon: icon,
                    isSelected: selection == icon,
                    color: color
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = icon
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Add Account") {
    AddAccountView()
        .environment(SyncService.shared)
        .modelContainer(.preview)
}

#Preview("Edit Account") {
    AddAccountView(editingAccount: nil)
        .environment(SyncService.shared)
        .modelContainer(.preview)
}
