//
//  AuthenticationService.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore
import SwiftData

// MARK: - Authentication Service (iOS 26 @Observable)

@Observable
final class AuthenticationService {

    // MARK: - Published Properties

    private(set) var currentUser: User?
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var error: AuthError?

    // MARK: - Private Properties

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private lazy var firestore: Firestore = Firestore.firestore()

    // MARK: - Initialization

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    // MARK: - Sign Up

    /// Creates a new user account with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password (minimum 6 characters)
    ///   - displayName: User's display name
    ///   - persona: User's persona for default category setup
    /// - Throws: AuthError if sign up fails
    @MainActor
    func signUp(
        email: String,
        password: String,
        displayName: String,
        persona: UserPersona
    ) async throws {
        isLoading = true
        error = nil

        do {
            // Create user in Firebase Auth
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            // Create user profile in Firestore
            try await createUserProfile(
                userId: result.user.uid,
                email: email,
                displayName: displayName,
                persona: persona
            )

            // Create default categories based on persona
            try await createDefaultCategories(userId: result.user.uid, persona: persona)

            // Create default accounts
            try await createDefaultAccounts(userId: result.user.uid)

            isLoading = false
        } catch {
            isLoading = false
            let authError = AuthError.from(error)
            self.error = authError
            throw authError
        }
    }

    // MARK: - Sign In

    /// Signs in an existing user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Throws: AuthError if sign in fails
    @MainActor
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            isLoading = false
        } catch {
            isLoading = false
            let authError = AuthError.from(error)
            self.error = authError
            throw authError
        }
    }

    // MARK: - Sign Out

    /// Signs out the current user
    /// - Throws: AuthError if sign out fails
    @MainActor
    func signOut() throws {
        error = nil

        do {
            try Auth.auth().signOut()
            // Clear local state
            currentUser = nil
            isAuthenticated = false
        } catch {
            let authError = AuthError.from(error)
            self.error = authError
            throw authError
        }
    }

    // MARK: - Password Reset

    /// Sends a password reset email to the specified address
    /// - Parameter email: Email address to send reset link to
    /// - Throws: AuthError if sending fails
    @MainActor
    func resetPassword(email: String) async throws {
        isLoading = true
        error = nil

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            isLoading = false
        } catch {
            isLoading = false
            let authError = AuthError.from(error)
            self.error = authError
            throw authError
        }
    }

    // MARK: - Delete Account

    /// Deletes the current user's account and all associated data
    /// This is required for App Store compliance
    /// - Throws: AuthError if deletion fails
    @MainActor
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }

        isLoading = true
        error = nil

        do {
            // Delete user data from Firestore first
            try await deleteUserData(userId: user.uid)

            // Delete Firebase Auth account
            try await user.delete()

            // Clear local state
            currentUser = nil
            isAuthenticated = false
            isLoading = false
        } catch {
            isLoading = false
            let authError = AuthError.from(error)
            self.error = authError
            throw authError
        }
    }

    // MARK: - Update Profile

    /// Updates the current user's display name
    /// - Parameter name: New display name
    /// - Throws: AuthError if update fails
    @MainActor
    func updateDisplayName(_ name: String) async throws {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }

        isLoading = true
        error = nil

        do {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()

            // Update in Firestore
            try await firestore.collection("users").document(user.uid).updateData([
                "displayName": name,
                "lastModified": FieldValue.serverTimestamp()
            ])

            isLoading = false
        } catch {
            isLoading = false
            let authError = AuthError.from(error)
            self.error = authError
            throw authError
        }
    }

    /// Updates the current user's email
    /// - Parameter email: New email address
    /// - Throws: AuthError if update fails
    @MainActor
    func updateEmail(_ email: String) async throws {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }

        isLoading = true
        error = nil

        do {
            try await user.sendEmailVerification(beforeUpdatingEmail: email)
            isLoading = false
        } catch {
            isLoading = false
            let authError = AuthError.from(error)
            self.error = authError
            throw authError
        }
    }

    // MARK: - Clear Error

    /// Clears the current error state
    @MainActor
    func clearError() {
        error = nil
    }
}

// MARK: - Firestore Operations

extension AuthenticationService {

    /// Creates a user profile in Firestore
    private func createUserProfile(
        userId: String,
        email: String,
        displayName: String,
        persona: UserPersona
    ) async throws {
        let userProfile = UserProfile(
            id: userId,
            email: email,
            displayName: displayName,
            persona: persona,
            preferredTheme: .clear
        )

        try await firestore.collection("users").document(userId).setData(userProfile.firestoreData)
    }

    /// Creates default categories based on user persona
    private func createDefaultCategories(userId: String, persona: UserPersona) async throws {
        let batch = firestore.batch()
        let categoriesRef = firestore.collection("users").document(userId).collection("categories")

        let categories = Category.defaultCategories(for: persona)

        for category in categories {
            let docRef = categoriesRef.document(category.id)
            batch.setData(category.firestoreData, forDocument: docRef)
        }

        try await batch.commit()
    }

    /// Creates default accounts for a new user
    private func createDefaultAccounts(userId: String) async throws {
        let batch = firestore.batch()
        let accountsRef = firestore.collection("users").document(userId).collection("accounts")

        let accounts = Account.defaultAccounts

        for account in accounts {
            let docRef = accountsRef.document(account.id)
            batch.setData(account.firestoreData, forDocument: docRef)
        }

        try await batch.commit()
    }

    /// Deletes all user data from Firestore
    private func deleteUserData(userId: String) async throws {
        // Delete subcollections
        let collections = ["transactions", "categories", "accounts", "budgets"]

        for collectionName in collections {
            let collectionRef = firestore.collection("users").document(userId).collection(collectionName)
            let snapshot = try await collectionRef.getDocuments()

            let batch = firestore.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }

        // Delete user document
        try await firestore.collection("users").document(userId).delete()
    }
}

// MARK: - Convenience Properties

extension AuthenticationService {

    /// Current user's display name
    var displayName: String? {
        currentUser?.displayName
    }

    /// Current user's email
    var email: String? {
        currentUser?.email
    }

    /// Current user's UID
    var userId: String? {
        currentUser?.uid
    }

    /// Whether the current user's email is verified
    var isEmailVerified: Bool {
        currentUser?.isEmailVerified ?? false
    }
}
