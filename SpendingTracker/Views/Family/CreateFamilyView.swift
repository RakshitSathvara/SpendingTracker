//
//  CreateFamilyView.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//
//  Create Family screen with name, icon selection, and monthly income

import SwiftUI

// MARK: - Create Family View

struct CreateFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let familyService: FamilyService
    let onFamilyCreated: (FamilyBudgetDTO) -> Void

    @State private var familyName = ""
    @State private var selectedIcon = "house.fill"
    @State private var monthlyIncome = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showIconPicker = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case income
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var incomeDecimal: Decimal {
        let cleanedString = monthlyIncome.replacingOccurrences(of: ",", with: "")
        return Decimal(string: cleanedString) ?? 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AdaptiveBackground(style: .secondary)

                ScrollView {
                    VStack(spacing: 24) {
                        // Preview Card
                        familyPreviewCard

                        // Form Fields
                        formSection

                        // Tips
                        tipsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await createFamily() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValid || isLoading)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selectedIcon: $selectedIcon)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Family Preview Card

    private var familyPreviewCard: some View {
        VStack(spacing: 0) {
            // Gradient Header
            ZStack {
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)

                VStack(spacing: 12) {
                    Button {
                        showIconPicker = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 70, height: 70)

                            Image(systemName: selectedIcon)
                                .font(.system(size: 30))
                                .foregroundStyle(.white)

                            // Edit Badge
                            Circle()
                                .fill(.white)
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Image(systemName: "pencil")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.blue)
                                }
                                .offset(x: 25, y: 25)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 20,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 20
                )
            )

            // Name Preview
            VStack(spacing: 8) {
                Text(familyName.isEmpty ? "Family Name" : familyName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(familyName.isEmpty ? .secondary : .primary)

                if incomeDecimal > 0 {
                    Text("Monthly Income: \(formatCurrency(incomeDecimal))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                colorScheme == .dark
                    ? Color(.systemGray6)
                    : Color.white
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 20,
                    bottomTrailingRadius: 20,
                    topTrailingRadius: 0
                )
            )
        }
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // Family Name
            GlassCard(cornerRadius: 16, padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("FAMILY NAME")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    TextField("e.g., Sathvara Family", text: $familyName)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .income
                        }
                }
            }

            // Monthly Income
            GlassCard(cornerRadius: 16, padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("COMBINED MONTHLY INCOME (OPTIONAL)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    HStack {
                        Text("₹")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        TextField("0", text: $monthlyIncome)
                            .font(.title2)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .income)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            // Icon Picker Button
            Button {
                showIconPicker = true
            } label: {
                GlassCard(cornerRadius: 16, padding: 16) {
                    HStack {
                        Image(systemName: selectedIcon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 40, height: 40)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Family Icon")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text("Tap to change")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                tipRow(
                    icon: "person.2.fill",
                    text: "Invite family members after creating"
                )
                tipRow(
                    icon: "chart.pie.fill",
                    text: "Set up budgets using 50/30/20 rule"
                )
                tipRow(
                    icon: "bell.fill",
                    text: "Get alerts when budgets are exceeded"
                )
            }
        }
        .padding(.top, 8)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Actions

    @MainActor
    private func createFamily() async {
        guard isValid else { return }

        isLoading = true

        do {
            let family = try await familyService.createFamily(
                name: familyName.trimmingCharacters(in: .whitespacesAndNewlines),
                iconName: selectedIcon,
                monthlyIncome: incomeDecimal
            )

            dismiss()
            onFamilyCreated(family)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹0"
    }
}

// MARK: - Icon Picker View

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    private let icons = FamilyBudget.availableIcons

    private let columns = [
        GridItem(.adaptive(minimum: 70), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(icons, id: \.symbol) { icon in
                        iconButton(icon: icon)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func iconButton(icon: (name: String, symbol: String)) -> some View {
        Button {
            selectedIcon = icon.symbol
            dismiss()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon.symbol)
                    .font(.title2)
                    .foregroundStyle(selectedIcon == icon.symbol ? .white : .blue)
                    .frame(width: 50, height: 50)
                    .background(
                        selectedIcon == icon.symbol
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.blue.opacity(0.1))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(icon.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Create Family") {
    CreateFamilyView(familyService: FamilyService()) { _ in }
}
