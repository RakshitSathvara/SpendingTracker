//
//  AddCategoryView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Add Category View (iOS 26 Stable)

/// Form for creating or editing categories
struct AddCategoryView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var viewModel: CategoryViewModel?
    @State private var formState = CategoryFormState()
    @State private var showSuccessAnimation = false

    // MARK: - Edit Mode

    let editingCategory: Category?

    init(editingCategory: Category? = nil) {
        self.editingCategory = editingCategory
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
                        // Preview
                        categoryPreview

                        // Name Field
                        nameSection

                        // Category Type Toggle
                        typeToggleSection

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
            .navigationTitle(editingCategory != nil ? "Edit Category" : "New Category")
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
        viewModel = CategoryViewModel(modelContext: modelContext, syncService: syncService)

        if let category = editingCategory {
            formState.loadCategory(category)
        }
    }

    // MARK: - Category Preview

    private var categoryPreview: some View {
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
                    Text(formState.name.isEmpty ? "Category Name" : formState.name)
                        .font(.headline)
                        .foregroundStyle(formState.name.isEmpty ? .secondary : .primary)

                    Text(formState.isExpenseCategory ? "Expense Category" : "Income Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            GlassTextField(
                placeholder: "Enter category name",
                text: $formState.name,
                icon: "tag"
            )
        }
    }

    // MARK: - Type Toggle Section

    private var typeToggleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category Type")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            GlassSegmentedControl(
                selection: $formState.isExpenseCategory,
                options: [true, false],
                titleForOption: { $0 ? "Expense" : "Income" },
                iconForOption: { $0 ? "arrow.up.circle" : "arrow.down.circle" }
            )
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
                IconPicker(selection: $formState.selectedIcon, color: formState.selectedColor)
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
                title: editingCategory != nil ? "Update Category" : "Create Category",
                icon: "checkmark.circle",
                tint: formState.selectedColor,
                isLoading: viewModel?.isLoading ?? false
            ) {
                Task { await saveCategory() }
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

                Text("Category \(editingCategory != nil ? "Updated" : "Created")!")
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

    // MARK: - Save Category

    private func saveCategory() async {
        guard let viewModel = viewModel else { return }

        if let category = editingCategory {
            await viewModel.updateCategory(
                category,
                name: formState.name,
                icon: formState.selectedIcon,
                colorHex: formState.colorHex,
                isExpenseCategory: formState.isExpenseCategory
            )
        } else {
            await viewModel.addCategory(
                name: formState.name,
                icon: formState.selectedIcon,
                colorHex: formState.colorHex,
                isExpenseCategory: formState.isExpenseCategory
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
}

// MARK: - Icon Picker

struct IconPicker: View {
    @Binding var selection: String
    let color: Color

    private let icons = [
        // Food & Dining
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        // Transportation
        "car.fill", "bus.fill", "tram.fill", "airplane", "fuelpump.fill",
        // Shopping
        "bag.fill", "cart.fill", "gift.fill", "tshirt.fill",
        // Entertainment
        "tv.fill", "film.fill", "gamecontroller.fill", "music.note",
        // Bills & Utilities
        "bolt.fill", "drop.fill", "wifi", "phone.fill",
        // Health
        "heart.fill", "cross.case.fill", "pills.fill", "figure.run",
        // Education
        "book.fill", "graduationcap.fill", "pencil", "backpack.fill",
        // Home
        "house.fill", "bed.double.fill", "sofa.fill", "washer.fill",
        // Personal
        "person.fill", "person.2.fill", "figure.child", "pawprint.fill",
        // Finance
        "creditcard.fill", "banknote.fill", "chart.line.uptrend.xyaxis", "dollarsign.circle.fill",
        // Travel
        "suitcase.fill", "map.fill", "camera.fill", "binoculars.fill",
        // Other
        "star.fill", "tag.fill", "folder.fill", "ellipsis.circle.fill"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

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

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : color)
                .frame(width: 44, height: 44)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(color.gradient)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(color.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
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

// MARK: - Color Picker Grid

struct ColorPickerGrid: View {
    @Binding var selection: Color

    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(colors, id: \.self) { color in
                ColorButton(
                    color: color,
                    isSelected: selection == color
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = color
                    }
                }
            }
        }
    }
}

// MARK: - Color Button

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 44, height: 44)

                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
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

// MARK: - Preview

#Preview("Add Category") {
    AddCategoryView()
        .environment(SyncService.shared)
        .modelContainer(.preview)
}

#Preview("Edit Category") {
    AddCategoryView(editingCategory: nil)
        .environment(SyncService.shared)
        .modelContainer(.preview)
}
