//
//  AccountPicker.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Account Picker (iOS 26 Stable)

/// A dropdown picker for selecting accounts with glass effect
struct AccountPicker: View {
    @Binding var selection: Account?
    let accounts: [Account]

    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 10) {
                // Account Icon
                if let account = selection {
                    Image(systemName: account.icon)
                        .font(.body)
                        .foregroundStyle(account.color)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(account.color.opacity(0.15))
                        }
                } else {
                    Image(systemName: "wallet.pass")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                        }
                }

                // Account Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(selection?.name ?? "Select Account")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(selection != nil ? .primary : .secondary)

                    if let account = selection {
                        Text(account.accountType.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(pickerBackground)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selection?.id)
        .sheet(isPresented: $showPicker) {
            AccountPickerSheet(selection: $selection, accounts: accounts)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var pickerBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
    }
}

// MARK: - Account Picker Sheet

struct AccountPickerSheet: View {
    @Binding var selection: Account?
    let accounts: [Account]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    AccountRow(
                        account: account,
                        isSelected: selection?.id == account.id
                    ) {
                        selection = account
                        dismiss()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Account Row

struct AccountRow: View {
    let account: Account
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: account.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(account.color.gradient)
                    .clipShape(Circle())

                // Account Details
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(account.accountType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Account Picker

/// A more compact inline account picker
struct CompactAccountPicker: View {
    @Binding var selection: Account?
    let accounts: [Account]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(accounts) { account in
                    CompactAccountChip(
                        account: account,
                        isSelected: selection?.id == account.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = account
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .sensoryFeedback(.selection, trigger: selection?.id)
    }
}

// MARK: - Compact Account Chip

private struct CompactAccountChip: View {
    let account: Account
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: account.icon)
                    .font(.caption)
                Text(account.name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(account.color.gradient) : AnyShapeStyle(.ultraThinMaterial))
            }
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(account.color.opacity(0.3), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Account Picker") {
    struct PreviewWrapper: View {
        @State private var selectedAccount: Account?
        let sampleAccounts = Account.defaultAccounts

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Dropdown Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dropdown Style")
                            .font(.headline)
                        AccountPicker(
                            selection: $selectedAccount,
                            accounts: sampleAccounts
                        )
                    }
                    .padding()

                    // Compact Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compact Style")
                            .font(.headline)
                            .padding(.horizontal)
                        CompactAccountPicker(
                            selection: $selectedAccount,
                            accounts: sampleAccounts
                        )
                    }
                }
            }
        }
    }

    return PreviewWrapper()
}
