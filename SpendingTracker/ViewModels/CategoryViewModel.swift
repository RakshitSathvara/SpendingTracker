//
//  CategoryViewModel.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - Category ViewModel (iOS 26 @Observable)

/// ViewModel for managing category operations
@Observable
final class CategoryViewModel {

    // MARK: - Published Properties

    /// All categories
    private(set) var categories: [Category] = []

    /// Loading state for async operations
    private(set) var isLoading = false

    /// Error message if operation fails
    private(set) var errorMessage: String?

    /// Success state for dismissing view
    private(set) var didSaveSuccessfully = false

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let syncService: SyncService

    // MARK: - Initialization

    init(modelContext: ModelContext, syncService: SyncService = .shared) {
        self.modelContext = modelContext
        self.syncService = syncService
        loadCategories()
    }

    // MARK: - Computed Properties

    /// Expense categories only
    var expenseCategories: [Category] {
        categories
            .filter { $0.isExpenseCategory }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Income categories only
    var incomeCategories: [Category] {
        categories
            .filter { !$0.isExpenseCategory }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Data Loading

    func loadCategories() {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        do {
            categories = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
    }

    // MARK: - CRUD Operations

    /// Add a new category
    @MainActor
    func addCategory(
        name: String,
        icon: String,
        colorHex: String,
        isExpenseCategory: Bool
    ) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Category name cannot be empty"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Calculate sort order (add at end)
            let existingCategories = isExpenseCategory ? expenseCategories : incomeCategories
            let maxSortOrder = existingCategories.map(\.sortOrder).max() ?? -1

            let category = Category(
                name: name.trimmingCharacters(in: .whitespaces),
                icon: icon,
                colorHex: colorHex,
                isExpenseCategory: isExpenseCategory,
                sortOrder: maxSortOrder + 1,
                isDefault: false,
                isSynced: false,
                lastModified: Date(),
                createdAt: Date()
            )

            modelContext.insert(category)
            try modelContext.save()

            // Mark for sync
            syncService.markCategoryForSync(category)

            didSaveSuccessfully = true
            isLoading = false

            // Reload data
            loadCategories()

            // Trigger sync
            Task {
                try? await syncService.syncNow()
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to save category: \(error.localizedDescription)"
        }
    }

    /// Update an existing category
    @MainActor
    func updateCategory(
        _ category: Category,
        name: String,
        icon: String,
        colorHex: String,
        isExpenseCategory: Bool
    ) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Category name cannot be empty"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            category.name = name.trimmingCharacters(in: .whitespaces)
            category.icon = icon
            category.colorHex = colorHex
            category.isExpenseCategory = isExpenseCategory
            category.lastModified = Date()
            category.isSynced = false

            try modelContext.save()

            // Mark for sync
            syncService.markCategoryForSync(category)

            didSaveSuccessfully = true
            isLoading = false

            // Reload data
            loadCategories()

            // Trigger sync
            Task {
                try? await syncService.syncNow()
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to update category: \(error.localizedDescription)"
        }
    }

    /// Delete a category
    @MainActor
    func deleteCategory(_ category: Category) async {
        // Prevent deletion of default categories
        guard !category.isDefault else {
            errorMessage = "Cannot delete default categories"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let categoryId = category.id

            modelContext.delete(category)
            try modelContext.save()

            // Mark for deletion sync
            syncService.markForDeletion(entityId: categoryId, entityType: .category)

            isLoading = false

            // Reload data
            loadCategories()

            // Trigger sync
            Task {
                try? await syncService.syncNow()
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to delete category: \(error.localizedDescription)"
        }
    }

    /// Delete categories at specified offsets (for swipe-to-delete)
    @MainActor
    func deleteCategories(at offsets: IndexSet, isExpense: Bool) async {
        let categoriesToDelete = isExpense ? expenseCategories : incomeCategories

        for index in offsets {
            guard index < categoriesToDelete.count else { continue }
            let category = categoriesToDelete[index]

            // Skip default categories
            if !category.isDefault {
                await deleteCategory(category)
            }
        }
    }

    /// Move category (reorder)
    @MainActor
    func moveCategory(from source: IndexSet, to destination: Int, isExpense: Bool) {
        var categoriesToReorder = isExpense ? expenseCategories : incomeCategories
        categoriesToReorder.move(fromOffsets: source, toOffset: destination)

        // Update sort orders
        for (index, category) in categoriesToReorder.enumerated() {
            category.sortOrder = index
            category.lastModified = Date()
            category.isSynced = false
            syncService.markCategoryForSync(category)
        }

        do {
            try modelContext.save()
            loadCategories()

            // Trigger sync
            Task {
                try? await syncService.syncNow()
            }
        } catch {
            errorMessage = "Failed to reorder categories: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    func clearError() {
        errorMessage = nil
    }

    func resetState() {
        didSaveSuccessfully = false
        errorMessage = nil
    }

    func refresh() {
        loadCategories()
    }
}

// MARK: - Category Form State

@Observable
final class CategoryFormState {
    var name: String = ""
    var selectedIcon: String = "folder.fill"
    var selectedColor: Color = .blue
    var isExpenseCategory: Bool = true

    var colorHex: String {
        selectedColor.hexString
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func reset() {
        name = ""
        selectedIcon = "folder.fill"
        selectedColor = .blue
        isExpenseCategory = true
    }

    func loadCategory(_ category: Category) {
        name = category.name
        selectedIcon = category.icon
        selectedColor = category.color
        isExpenseCategory = category.isExpenseCategory
    }
}
