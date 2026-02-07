//
//  CategoryQuickPicker.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI

// MARK: - Category Quick Picker (iOS 26 Stable)

/// A grid of category buttons for quick selection with glass effect
struct CategoryQuickPicker: View {
    @Binding var selection: Category?
    let categories: [Category]
    let isExpense: Bool
    let maxVisibleItems: Int
    let onShowMore: (() -> Void)?

    @State private var lastSelectedId: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(
        selection: Binding<Category?>,
        categories: [Category],
        isExpense: Bool = true,
        maxVisibleItems: Int = 7,
        onShowMore: (() -> Void)? = nil
    ) {
        self._selection = selection
        self.categories = categories
        self.isExpense = isExpense
        self.maxVisibleItems = maxVisibleItems
        self.onShowMore = onShowMore
    }

    private var filteredCategories: [Category] {
        categories.filter { $0.isExpenseCategory == isExpense }
    }

    private var visibleCategories: [Category] {
        Array(filteredCategories.prefix(maxVisibleItems))
    }

    private var hasMoreCategories: Bool {
        filteredCategories.count > maxVisibleItems
    }

    var body: some View {
        Group {
            if filteredCategories.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "tag.slash")
                        .font(.title)
                        .foregroundStyle(.secondary)

                    Text("No \(isExpense ? "expense" : "income") categories")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleCategories) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selection?.id == category.id
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selection = category
                                lastSelectedId = category.id
                            }
                        }
                    }

                    // More button if there are additional categories
                    if hasMoreCategories {
                        MoreCategoriesButton(action: onShowMore ?? {})
                    }
                }
                .sensoryFeedback(.selection, trigger: lastSelectedId)
            }
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : category.color)
                    .frame(width: 44, height: 44)
                    .background(iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Name
                Text(category.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? category.color : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

    @ViewBuilder
    private var iconBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(category.color.gradient)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(category.color.opacity(0.1))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(category.color.opacity(0.2), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - More Categories Button

struct MoreCategoriesButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                            }
                    }

                Text("More")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show more categories")
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

// MARK: - Full Category Picker Sheet

/// A full-screen category picker for when "More" is tapped
struct CategoryPickerSheet: View {
    @Binding var selection: Category?
    let categories: [Category]
    let isExpense: Bool
    @Environment(\.dismiss) private var dismiss

    private var filteredCategories: [Category] {
        categories.filter { $0.isExpenseCategory == isExpense }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if filteredCategories.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer()

                        Image(systemName: "tag.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No Categories")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("No \(isExpense ? "expense" : "income") categories available. Categories will be created automatically.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredCategories) { category in
                                CategoryButton(
                                    category: category,
                                    isSelected: selection?.id == category.id
                                ) {
                                    selection = category
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isExpense ? "Expense Categories" : "Income Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Category Quick Picker") {
    struct PreviewWrapper: View {
        @State private var selectedCategory: Category?
        @State private var showMoreCategories = false

        let sampleCategories = Category.allDefaultCategories

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Selected: \(selectedCategory?.name ?? "None")")
                        .font(.headline)

                    CategoryQuickPicker(
                        selection: $selectedCategory,
                        categories: sampleCategories,
                        isExpense: true
                    ) {
                        showMoreCategories = true
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showMoreCategories) {
                CategoryPickerSheet(
                    selection: $selectedCategory,
                    categories: sampleCategories,
                    isExpense: true
                )
            }
        }
    }

    return PreviewWrapper()
}
