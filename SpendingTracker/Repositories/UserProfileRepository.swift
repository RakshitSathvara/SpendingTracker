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
    func fetchProfile() async throws -> UserProfileDTO?

    /// Deletes the user's profile
    func deleteProfile() async throws

    /// Returns an AsyncStream that emits updates when the profile changes
    func observeProfile() -> AsyncStream<UserProfileDTO?>

    /// Updates specific profile fields
    func updateProfileFields(_ fields: [String: Any]) async throws
}

// MARK: - User Profile DTO

/// Data Transfer Object for UserProfile (decoupled from SwiftData)
struct UserProfileDTO: Identifiable, Equatable {
    let id: String
    var email: String
    var displayName: String
    var persona: UserPersona
    var preferredTheme: AppTheme
    var currencyCode: String
    var notificationsEnabled: Bool
    var budgetAlertsEnabled: Bool
    var dailyReminderTime: Date?
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "persona": persona.rawValue,
            "preferredTheme": preferredTheme.rawValue,
            "currencyCode": currencyCode,
            "notificationsEnabled": notificationsEnabled,
            "budgetAlertsEnabled": budgetAlertsEnabled,
            "isSynced": true,
            "lastModified": Timestamp(date: lastModified),
            "createdAt": Timestamp(date: createdAt)
        ]
        if let reminderTime = dailyReminderTime {
            data["dailyReminderTime"] = Timestamp(date: reminderTime)
        }
        return data
    }

    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String,
        persona: UserPersona = .professional,
        preferredTheme: AppTheme = .clear,
        currencyCode: String = "INR",
        notificationsEnabled: Bool = true,
        budgetAlertsEnabled: Bool = true,
        dailyReminderTime: Date? = nil,
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.persona = persona
        self.preferredTheme = preferredTheme
        self.currencyCode = currencyCode
        self.notificationsEnabled = notificationsEnabled
        self.budgetAlertsEnabled = budgetAlertsEnabled
        self.dailyReminderTime = dailyReminderTime
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.email = data["email"] as? String ?? ""
        self.displayName = data["displayName"] as? String ?? ""

        let personaRaw = data["persona"] as? String ?? UserPersona.professional.rawValue
        self.persona = UserPersona(rawValue: personaRaw) ?? .professional

        let themeRaw = data["preferredTheme"] as? String ?? AppTheme.clear.rawValue
        self.preferredTheme = AppTheme(rawValue: themeRaw) ?? .clear

        self.currencyCode = data["currencyCode"] as? String ?? "INR"
        self.notificationsEnabled = data["notificationsEnabled"] as? Bool ?? true
        self.budgetAlertsEnabled = data["budgetAlertsEnabled"] as? Bool ?? true

        if let reminderTimestamp = data["dailyReminderTime"] as? Timestamp {
            self.dailyReminderTime = reminderTimestamp.dateValue()
        } else {
            self.dailyReminderTime = nil
        }

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

    /// Creates a UserProfileDTO from a SwiftData UserProfile model
    init(from profile: UserProfile) {
        self.id = profile.id
        self.email = profile.email
        self.displayName = profile.displayName
        self.persona = profile.persona
        self.preferredTheme = profile.preferredTheme
        self.currencyCode = profile.currencyCode
        self.notificationsEnabled = profile.notificationsEnabled
        self.budgetAlertsEnabled = profile.budgetAlertsEnabled
        self.dailyReminderTime = profile.dailyReminderTime
        self.isSynced = profile.isSynced
        self.lastModified = profile.lastModified
        self.createdAt = profile.createdAt
    }
}

// MARK: - User Profile Repository Implementation

/// Firestore repository for UserProfile entities
@Observable
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

        let dto = UserProfileDTO(from: profile)
        var data = dto.firestoreData
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
        let dto = UserProfileDTO(from: profile)
        var data = dto.firestoreData
        data["lastModified"] = Timestamp(date: Date())

        do {
            try await document.setDataAsync(data, merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchProfile() async throws -> UserProfileDTO? {
        isLoading = true
        defer { isLoading = false }

        let document = try profileDocument()

        do {
            let snapshot = try await document.getDocument()
            guard snapshot.exists else { return nil }
            return try UserProfileDTO(from: snapshot)
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

    func observeProfile() -> AsyncStream<UserProfileDTO?> {
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

                if let profile = try? UserProfileDTO(from: snapshot) {
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

        let dto = UserProfileDTO(
            id: userId,
            email: email,
            displayName: displayName,
            persona: persona
        )

        do {
            try await db.collection(FirestorePath.users).document(userId).setDataAsync(dto.firestoreData)
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
