//
//  JoinFamilyView.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//
//  Join Family screen with invite code input

import SwiftUI

// MARK: - Join Family View

struct JoinFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let familyService: FamilyService
    let onFamilyJoined: (FamilyBudgetDTO) -> Void

    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var foundFamily: FamilyBudgetDTO?
    @State private var isSearching = false

    @FocusState private var isCodeFocused: Bool

    // MARK: - Computed Properties

    private var isValid: Bool {
        inviteCode.count == 6
    }

    private var formattedCode: String {
        inviteCode.uppercased()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AdaptiveBackground(style: .secondary)

                ScrollView {
                    VStack(spacing: 32) {
                        // Header Illustration
                        headerIllustration

                        // Instructions
                        instructionsCard

                        // Code Input
                        codeInputSection

                        // Found Family Preview
                        if let family = foundFamily {
                            familyPreviewCard(family: family)
                        }

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isCodeFocused = false
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: inviteCode) { _, newValue in
                // Auto-search when code is complete
                if newValue.count == 6 {
                    Task { await searchFamily() }
                } else {
                    foundFamily = nil
                }
            }
        }
    }

    // MARK: - Header Illustration

    private var headerIllustration: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .teal.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Join a Family Budget")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter the 6-character invite code shared by a family member")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 20)
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        GlassCard(tint: .green) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("How to get an invite code")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Ask the family admin to share the invite code from Family Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Code Input Section

    private var codeInputSection: some View {
        VStack(spacing: 16) {
            Text("INVITE CODE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Code Input Boxes
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    codeBox(index: index)
                }
            }

            // Hidden TextField
            TextField("", text: $inviteCode)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isCodeFocused)
                .opacity(0)
                .frame(height: 0)
                .onChange(of: inviteCode) { _, newValue in
                    // Limit to 6 characters and uppercase
                    let filtered = String(newValue.uppercased().prefix(6))
                        .filter { $0.isLetter || $0.isNumber }
                    if filtered != newValue {
                        inviteCode = filtered
                    }
                }

            // Paste Button
            Button {
                if let pasteString = UIPasteboard.general.string {
                    let cleaned = String(pasteString.uppercased().prefix(6))
                        .filter { $0.isLetter || $0.isNumber }
                    inviteCode = cleaned
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste from Clipboard")
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }

            // Status
            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if isValid && foundFamily == nil {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("No family found with this code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onTapGesture {
            isCodeFocused = true
        }
    }

    private func codeBox(index: Int) -> some View {
        let character: String = {
            let chars = Array(formattedCode)
            return index < chars.count ? String(chars[index]) : ""
        }()

        let isFilled = !character.isEmpty
        let isActive = index == formattedCode.count && isCodeFocused

        return Text(character)
            .font(.title)
            .fontWeight(.bold)
            .fontDesign(.monospaced)
            .frame(width: 45, height: 55)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? Color(.systemGray5)
                            : Color.white
                    )
                    .shadow(
                        color: isActive ? .blue.opacity(0.3) : .black.opacity(0.05),
                        radius: isActive ? 4 : 2
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.blue : (isFilled ? Color.green.opacity(0.5) : Color.gray.opacity(0.2)),
                        lineWidth: isActive ? 2 : 1
                    )
            }
            .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    // MARK: - Family Preview Card

    private func familyPreviewCard(family: FamilyBudgetDTO) -> some View {
        VStack(spacing: 16) {
            GlassCard(tint: .green) {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // Family Icon
                        Image(systemName: family.iconName)
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(family.name)
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("Monthly: \(family.formattedMonthlyIncome)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Family found!")
                                    .foregroundStyle(.green)
                            }
                            .font(.caption)
                        }

                        Spacer()
                    }

                    // Join Button
                    Button {
                        Task { await joinFamily() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "person.badge.plus")
                                Text("Join Family")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.green, .teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(isLoading)
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: foundFamily != nil)
    }

    // MARK: - Actions

    @MainActor
    private func searchFamily() async {
        guard isValid else { return }

        isSearching = true

        do {
            foundFamily = try await FamilyRepository().findFamilyByInviteCode(formattedCode)
        } catch {
            foundFamily = nil
        }

        isSearching = false
    }

    @MainActor
    private func joinFamily() async {
        guard isValid else { return }

        isLoading = true

        do {
            let family = try await familyService.joinFamily(inviteCode: formattedCode)
            dismiss()
            onFamilyJoined(family)
        } catch let error as FamilyServiceError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview("Join Family") {
    JoinFamilyView(familyService: FamilyService()) { _ in }
}
