//
//  CategoryListView.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import SwiftUI
import SwiftData

// MARK: - Category List View (iOS 26 Stable)

/// View for managing expense and income categories
struct CategoryListView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var viewModel: CategoryViewModel?
    @State private var showAddCategory = false
    @State private var editingCategory: Category?
    @State private var isViewReady = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Adaptive Background
            AdaptiveBackground(style: .primary)

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    if let vm = viewModel {
                        if vm.categories.isEmpty {
                            emptyStateView
                        } else {
                            // Expense Categories Section
                            if !vm.expenseCategories.isEmpty {
                                categorySection(
                                    title: "Expense Categories",
                                    categories: vm.expenseCategories,
                                    isExpense: true,
                                    viewModel: vm
                                )
                            }

                            // Income Categories Section
                            if !vm.incomeCategories.isEmpty {
                                categorySection(
                                    title: "Income Categories",
                                    categories: vm.incomeCategories,
                                    isExpense: false,
                                    viewModel: vm
                                )
                            }
                        }
                    } else {
                        CategoryListSkeleton()
                    }
                }
                .padding()
                .opacity(isViewReady ? 1 : 0)
            }
            .refreshable {
                viewModel?.refresh()
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategoryView()
                .environment(\.modelContext, modelContext)
                .environment(syncService)
                .onDisappear {
                    viewModel?.refresh()
                }
        }
        .sheet(item: $editingCategory) { category in
            AddCategoryView(editingCategory: category)
                .environment(\.modelContext, modelContext)
                .environment(syncService)
                .onDisappear {
                    viewModel?.refresh()
                }
        }
        .onAppear {
            setupViewModel()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isViewReady = true
                }
            }
        }
    }

    // MARK: - Setup

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = CategoryViewModel(modelContext: modelContext, syncService: syncService)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "tag.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("No Categories")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create categories to organize your transactions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            GlassButton(
                title: "Add Category",
                icon: "plus.circle",
                tint: .purple
            ) {
                showAddCategory = true
            }
            .frame(maxWidth: 200)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Category Section

    private func categorySection(
        title: String,
        categories: [Category],
        isExpense: Bool,
        viewModel: CategoryViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text("\(categories.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)

            GlassCard(padding: 0) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        CategoryRow(
                            category: category,
                            onEdit: {
                                editingCategory = category
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteCategory(category)
                                }
                            }
                        )

                        if index < categories.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: Category
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(category.color.gradient)
                .clipShape(Circle())

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                    .fontWeight(.medium)

                if category.isDefault {
                    Text("Default")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            if !category.isDefault {
                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete Category",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(category.name)\"? This action cannot be undone.")
        }
    }
}

// MARK: - Category List Skeleton

struct CategoryListSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.ultraThinMaterial)
                        .frame(width: 150, height: 20)

                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .frame(height: 200)
                }
            }
        }
        .shimmer()
    }
}

// MARK: - Preview

#Preview("Category List") {
    NavigationStack {
        CategoryListView()
            .environment(SyncService.shared)
            .modelContainer(.preview)
    }
}
