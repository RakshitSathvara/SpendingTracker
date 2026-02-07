//
//  CategoryRepository.swift
//  SpendingTracker
//
//  Created by Claude on 2026-01-31.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Category Repository Protocol

/// Protocol defining category repository operations
protocol CategoryRepositoryProtocol {
    /// Adds a new category to Firestore
    func addCategory(_ category: Category) async throws

    /// Updates an existing category in Firestore
    func updateCategory(_ category: Category) async throws

    /// Deletes a category by its ID
    func deleteCategory(id: String) async throws

    /// Fetches all categories
    func fetchCategories() async throws -> [Category]

    /// Creates default categories based on user persona
    func createDefaultCategories(for persona: UserPersona) async throws

    /// Returns an AsyncStream that emits updates when categories change
    func observeCategories() -> AsyncStream<[Category]>
}

// MARK: - Category Repository Implementation

/// Firestore repository for Category entities
final class CategoryRepository: CategoryRepositoryProtocol {

    // MARK: - Properties

    private let db: Firestore
    private var listener: ListenerRegistration?

    var isLoading: Bool = false
    var error: RepositoryError?

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Initialization

    init(firestore: Firestore = Firestore.firestore()) {
        self.db = firestore
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Private Helpers

    private func categoriesCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }
        return db.collection(FirestorePath.categoriesCollection(userId: userId))
    }

    // MARK: - CRUD Operations

    func addCategory(_ category: Category) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            try await collection.document(category.id).setDataAsync(category.firestoreData)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateCategory(_ category: Category) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            try await collection.document(category.id).setDataAsync(category.firestoreData, merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func deleteCategory(id: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            try await collection.document(id).delete()
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchCategories() async throws -> [Category] {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            let snapshot = try await collection
                .order(by: "sortOrder")
                .getDocumentsAsync()

            return try snapshot.documents.map { try Category(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    // MARK: - Default Categories Creation

    func createDefaultCategories(for persona: UserPersona) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()
        let batchWriter = FirestoreBatchWriter(firestore: db)

        // Create expense categories based on persona
        for (index, categoryInfo) in persona.defaultCategories.enumerated() {
            let category = Category(
                name: categoryInfo.name,
                icon: categoryInfo.icon,
                colorHex: categoryInfo.colorHex,
                isExpenseCategory: true,
                sortOrder: index,
                isDefault: true
            )

            let docRef = collection.document(category.id)
            batchWriter.set(category.firestoreData, forDocument: docRef)
        }

        // Add default income categories
        let incomeCategories = Category.defaultIncomeCategories
        let expenseCount = persona.defaultCategories.count

        for (index, incomeCategory) in incomeCategories.enumerated() {
            let category = Category(
                id: incomeCategory.id,
                name: incomeCategory.name,
                icon: incomeCategory.icon,
                colorHex: incomeCategory.colorHex,
                isExpenseCategory: false,
                sortOrder: expenseCount + index,
                isDefault: true
            )

            let docRef = collection.document(category.id)
            batchWriter.set(category.firestoreData, forDocument: docRef)
        }

        do {
            try await batchWriter.commit()
        } catch {
            self.error = .batchWriteFailed(error.localizedDescription)
            throw RepositoryError.batchWriteFailed(error.localizedDescription)
        }
    }

    // MARK: - Real-time Listener

    func observeCategories() -> AsyncStream<[Category]> {
        AsyncStream { continuation in
            guard let userId = currentUserId else {
                continuation.finish()
                return
            }

            let collection = db.collection(FirestorePath.categoriesCollection(userId: userId))

            let listener = collection
                .order(by: "sortOrder")
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("CategoryRepository listener error: \(error.localizedDescription)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }

                    let categories = documents.compactMap { doc -> Category? in
                        try? Category(from: doc)
                    }

                    continuation.yield(categories)
                }

            self.listener = listener

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
}

// MARK: - Category Query Helpers

extension CategoryRepository {

    /// Fetches only expense categories
    func fetchExpenseCategories() async throws -> [Category] {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            let snapshot = try await collection
                .whereField("isExpenseCategory", isEqualTo: true)
                .order(by: "sortOrder")
                .getDocumentsAsync()

            return try snapshot.documents.map { try Category(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches only income categories
    func fetchIncomeCategories() async throws -> [Category] {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            let snapshot = try await collection
                .whereField("isExpenseCategory", isEqualTo: false)
                .order(by: "sortOrder")
                .getDocumentsAsync()

            return try snapshot.documents.map { try Category(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches a category by ID
    func fetchCategory(id: String) async throws -> Category? {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            let document = try await collection.document(id).getDocument()
            guard document.exists else { return nil }
            return try Category(from: document)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Updates the sort order of multiple categories
    func updateSortOrder(_ categories: [Category]) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()
        let batchWriter = FirestoreBatchWriter(firestore: db)

        for (index, category) in categories.enumerated() {
            let docRef = collection.document(category.id)
            batchWriter.update(["sortOrder": index, "lastModified": Timestamp(date: Date())], forDocument: docRef)
        }

        do {
            try await batchWriter.commit()
        } catch {
            self.error = .batchWriteFailed(error.localizedDescription)
            throw RepositoryError.batchWriteFailed(error.localizedDescription)
        }
    }
}
