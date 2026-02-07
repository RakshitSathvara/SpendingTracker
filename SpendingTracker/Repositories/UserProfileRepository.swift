//
//  UserProfileRepository.swift
//  SpendingTracker
//
//  Created by Claude on 2026-01-31.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Profile Repository Protocol

/// Protocol defining user profile repository operations
protocol UserProfileRepositoryProtocol {
    /// Creates a new user profile in Firestore
    func createProfile(_ profile: UserProfile) async throws

    /// Updates an existing user profile in Firestore
    func updateProfile(_ profile: UserProfile) async throws

    /// Fetches the current user's profile
    func fetchProfile() async throws -> UserProfile?

    /// Deletes the user's profile
    func deleteProfile() async throws

    /// Returns an AsyncStream that emits updates when the profile changes
    func observeProfile() -> AsyncStream<UserProfile?>

    /// Updates specific profile fields
    func updateProfileFields(_ fields: [String: Any]) async throws
}

// MARK: - User Profile Repository Implementation

/// Firestore repository for UserProfile entities
final class UserProfileRepository: UserProfileRepositoryProtocol {

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

    private func profileDocument() throws -> DocumentReference {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }
        return db.collection(FirestorePath.users).document(userId)
    }

    // MARK: - CRUD Operations

    func createProfile(_ profile: UserProfile) async throws {
        isLoading = true
        defer { isLoading = false }

        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }

        var data = profile.firestoreData
        data["id"] = userId // Ensure ID matches user ID

        do {
            try await db.collection(FirestorePath.users).document(userId).setDataAsync(data)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateProfile(_ profile: UserProfile) async throws {
        isLoading = true
        defer { isLoading = false }

        let document = try profileDocument()
        let data = profile.firestoreData

        do {
            try await document.setDataAsync(data, merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchProfile() async throws -> UserProfile? {
        isLoading = true
        defer { isLoading = false }

        let document = try profileDocument()

        do {
            let snapshot = try await document.getDocument()
            guard snapshot.exists else { return nil }
            return try UserProfile(from: snapshot)
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func deleteProfile() async throws {
        isLoading = true
        defer { isLoading = false }

        let document = try profileDocument()

        do {
            try await document.delete()
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    // MARK: - Real-time Listener

    func observeProfile() -> AsyncStream<UserProfile?> {
        AsyncStream { continuation in
            guard let userId = currentUserId else {
                continuation.yield(nil)
                continuation.finish()
                return
            }

            let document = db.collection(FirestorePath.users).document(userId)

            let listener = document.addSnapshotListener { snapshot, error in
                if let error = error {
                    print("UserProfileRepository listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot, snapshot.exists else {
                    continuation.yield(nil)
                    return
                }

                if let profile = try? UserProfile(from: snapshot) {
                    continuation.yield(profile)
                } else {
                    continuation.yield(nil)
                }
            }

            self.listener = listener

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }

    // MARK: - Partial Updates

    func updateProfileFields(_ fields: [String: Any]) async throws {
        isLoading = true
        defer { isLoading = false }

        let document = try profileDocument()
        var updatedFields = fields
        updatedFields["lastModified"] = Timestamp(date: Date())

        do {
            try await document.setDataAsync(updatedFields, merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }
}

// MARK: - User Profile Update Helpers

extension UserProfileRepository {

    /// Updates the user's display name
    func updateDisplayName(_ displayName: String) async throws {
        try await updateProfileFields(["displayName": displayName])
    }

    /// Updates the user's persona
    func updatePersona(_ persona: UserPersona) async throws {
        try await updateProfileFields(["persona": persona.rawValue])
    }

    /// Updates the user's preferred theme
    func updateTheme(_ theme: AppTheme) async throws {
        try await updateProfileFields(["preferredTheme": theme.rawValue])
    }

    /// Updates the user's currency code
    func updateCurrency(_ currencyCode: String) async throws {
        try await updateProfileFields(["currencyCode": currencyCode])
    }

    /// Updates notification settings
    func updateNotificationSettings(enabled: Bool, budgetAlerts: Bool) async throws {
        try await updateProfileFields([
            "notificationsEnabled": enabled,
            "budgetAlertsEnabled": budgetAlerts
        ])
    }

    /// Updates the daily reminder time
    func updateDailyReminderTime(_ time: Date?) async throws {
        if let time = time {
            try await updateProfileFields(["dailyReminderTime": Timestamp(date: time)])
        } else {
            try await updateProfileFields(["dailyReminderTime": FieldValue.delete()])
        }
    }

    /// Checks if a profile exists for the current user
    func profileExists() async throws -> Bool {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }

        let document = db.collection(FirestorePath.users).document(userId)
        let snapshot = try await document.getDocument()
        return snapshot.exists
    }

    /// Creates a new profile with default values
    func createDefaultProfile(email: String, displayName: String, persona: UserPersona) async throws {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }

        let profile = UserProfile(
            id: userId,
            email: email,
            displayName: displayName,
            persona: persona
        )

        do {
            try await db.collection(FirestorePath.users).document(userId).setDataAsync(profile.firestoreData)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }
}

// MARK: - User Data Deletion

extension UserProfileRepository {

    /// Deletes all user data (profile, transactions, categories, accounts, budgets)
    /// This is required for App Store compliance
    func deleteAllUserData() async throws {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        // Delete subcollections first
        let collections = [
            FirestorePath.transactionsCollection(userId: userId),
            FirestorePath.categoriesCollection(userId: userId),
            FirestorePath.accountsCollection(userId: userId),
            FirestorePath.budgetsCollection(userId: userId)
        ]

        for collectionPath in collections {
            try await deleteCollection(path: collectionPath)
        }

        // Delete the user document
        try await db.collection(FirestorePath.users).document(userId).delete()
    }

    /// Helper to delete all documents in a collection
    private func deleteCollection(path: String) async throws {
        let collection = db.collection(path)
        let batchWriter = FirestoreBatchWriter(firestore: db)

        do {
            let snapshot = try await collection.getDocumentsAsync()

            for document in snapshot.documents {
                batchWriter.delete(document.reference)

                if batchWriter.isFull {
                    try await batchWriter.commit()
                }
            }

            if batchWriter.count > 0 {
                try await batchWriter.commit()
            }
        } catch {
            throw RepositoryError.syncFailed("Failed to delete collection: \(path)")
        }
    }
}
