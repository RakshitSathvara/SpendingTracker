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
    func fetchCategories() async throws -> [CategoryDTO]

    /// Creates default categories based on user persona
    func createDefaultCategories(for persona: UserPersona) async throws

    /// Returns an AsyncStream that emits updates when categories change
    func observeCategories() -> AsyncStream<[CategoryDTO]>
}

// MARK: - Category DTO

/// Data Transfer Object for Category (decoupled from SwiftData)
struct CategoryDTO: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var icon: String
    var colorHex: String
    var isExpenseCategory: Bool
    var sortOrder: Int
    var isDefault: Bool
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "icon": icon,
            "colorHex": colorHex,
            "isExpenseCategory": isExpenseCategory,
            "sortOrder": sortOrder,
            "isDefault": isDefault,
            "isSynced": true,
            "lastModified": Timestamp(date: lastModified),
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        icon: String = "tag.fill",
        colorHex: String = "#007AFF",
        isExpenseCategory: Bool = true,
        sortOrder: Int = 0,
        isDefault: Bool = false,
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isExpenseCategory = isExpenseCategory
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.name = data["name"] as? String ?? "Unknown"
        self.icon = data["icon"] as? String ?? "tag.fill"
        self.colorHex = data["colorHex"] as? String ?? "#007AFF"
        self.isExpenseCategory = data["isExpenseCategory"] as? Bool ?? true
        self.sortOrder = data["sortOrder"] as? Int ?? 0
        self.isDefault = data["isDefault"] as? Bool ?? false
        self.isSynced = data["isSynced"] as? Bool ?? true

        if let lastModifiedTimestamp = data["lastModified"] as? Timestamp {
            self.lastModified = lastModifiedTimestamp.dateValue()
        } else {
            self.lastModified = Date()
        }

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }

    /// Creates a CategoryDTO from a SwiftData Category model
    init(from category: Category) {
        self.id = category.id
        self.name = category.name
        self.icon = category.icon
        self.colorHex = category.colorHex
        self.isExpenseCategory = category.isExpenseCategory
        self.sortOrder = category.sortOrder
        self.isDefault = category.isDefault
        self.isSynced = category.isSynced
        self.lastModified = category.lastModified
        self.createdAt = category.createdAt
    }
}

// MARK: - Category Repository Implementation

/// Firestore repository for Category entities
@Observable
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
        let dto = CategoryDTO(from: category)

        do {
            try await collection.document(dto.id).setDataAsync(dto.firestoreData)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateCategory(_ category: Category) async throws {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()
        let dto = CategoryDTO(from: category)
        let updatedDTO = CategoryDTO(
            id: dto.id,
            name: dto.name,
            icon: dto.icon,
            colorHex: dto.colorHex,
            isExpenseCategory: dto.isExpenseCategory,
            sortOrder: dto.sortOrder,
            isDefault: dto.isDefault,
            isSynced: true,
            lastModified: Date(),
            createdAt: dto.createdAt
        )

        do {
            try await collection.document(updatedDTO.id).setDataAsync(updatedDTO.firestoreData, merge: true)
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

    func fetchCategories() async throws -> [CategoryDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            let snapshot = try await collection
                .order(by: "sortOrder")
                .getDocumentsAsync()

            return try snapshot.documents.map { try CategoryDTO(from: $0) }
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
            let dto = CategoryDTO(
                name: categoryInfo.name,
                icon: categoryInfo.icon,
                colorHex: categoryInfo.colorHex,
                isExpenseCategory: true,
                sortOrder: index,
                isDefault: true,
                isSynced: true
            )

            let docRef = collection.document(dto.id)
            batchWriter.set(dto.firestoreData, forDocument: docRef)
        }

        // Add default income categories
        let incomeCategories = CategoryDTO.defaultIncomeCategories
        let expenseCount = persona.defaultCategories.count

        for (index, incomeCategory) in incomeCategories.enumerated() {
            var dto = incomeCategory
            dto = CategoryDTO(
                id: incomeCategory.id,
                name: incomeCategory.name,
                icon: incomeCategory.icon,
                colorHex: incomeCategory.colorHex,
                isExpenseCategory: false,
                sortOrder: expenseCount + index,
                isDefault: true,
                isSynced: true
            )

            let docRef = collection.document(dto.id)
            batchWriter.set(dto.firestoreData, forDocument: docRef)
        }

        do {
            try await batchWriter.commit()
        } catch {
            self.error = .batchWriteFailed(error.localizedDescription)
            throw RepositoryError.batchWriteFailed(error.localizedDescription)
        }
    }

    // MARK: - Real-time Listener

    func observeCategories() -> AsyncStream<[CategoryDTO]> {
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

                    let categories = documents.compactMap { doc -> CategoryDTO? in
                        try? CategoryDTO(from: doc)
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
    func fetchExpenseCategories() async throws -> [CategoryDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            let snapshot = try await collection
                .whereField("isExpenseCategory", isEqualTo: true)
                .order(by: "sortOrder")
                .getDocumentsAsync()

            return try snapshot.documents.map { try CategoryDTO(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches only income categories
    func fetchIncomeCategories() async throws -> [CategoryDTO] {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            let snapshot = try await collection
                .whereField("isExpenseCategory", isEqualTo: false)
                .order(by: "sortOrder")
                .getDocumentsAsync()

            return try snapshot.documents.map { try CategoryDTO(from: $0) }
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetches a category by ID
    func fetchCategory(id: String) async throws -> CategoryDTO? {
        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()

        do {
            let document = try await collection.document(id).getDocument()
            guard document.exists else { return nil }
            return try CategoryDTO(from: document)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    /// Updates the sort order of multiple categories
    func updateSortOrder(_ categories: [CategoryDTO]) async throws {
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

    /// Batch sync multiple categories
    func batchSyncCategories(_ categories: [Category]) async throws {
        guard !categories.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let collection = try categoriesCollection()
        let batchWriter = FirestoreBatchWriter(firestore: db)

        for category in categories {
            let dto = CategoryDTO(from: category)
            let docRef = collection.document(dto.id)
            batchWriter.set(dto.firestoreData, forDocument: docRef)

            if batchWriter.isFull {
                try await batchWriter.commit()
            }
        }

        if batchWriter.count > 0 {
            try await batchWriter.commit()
        }
    }
}

// MARK: - Default Income Categories

extension CategoryDTO {
    /// Default income categories
    static var defaultIncomeCategories: [CategoryDTO] {
        [
            CategoryDTO(name: "Salary", icon: "briefcase.fill", colorHex: "#34C759", isExpenseCategory: false, sortOrder: 0, isDefault: true),
            CategoryDTO(name: "Freelance", icon: "laptopcomputer", colorHex: "#007AFF", isExpenseCategory: false, sortOrder: 1, isDefault: true),
            CategoryDTO(name: "Investments", icon: "chart.line.uptrend.xyaxis", colorHex: "#5856D6", isExpenseCategory: false, sortOrder: 2, isDefault: true),
            CategoryDTO(name: "Gifts", icon: "gift.fill", colorHex: "#FF2D55", isExpenseCategory: false, sortOrder: 3, isDefault: true),
            CategoryDTO(name: "Other Income", icon: "ellipsis.circle.fill", colorHex: "#8E8E93", isExpenseCategory: false, sortOrder: 4, isDefault: true)
        ]
    }
}
