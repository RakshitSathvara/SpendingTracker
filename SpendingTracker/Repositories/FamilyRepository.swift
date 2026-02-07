//
//  FamilyRepository.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Family Repository Protocol

/// Protocol defining family repository operations
protocol FamilyRepositoryProtocol {
    // Family CRUD
    func createFamily(_ family: FamilyBudget, withMember member: FamilyMember) async throws
    func updateFamily(_ family: FamilyBudget) async throws
    func deleteFamily(familyId: String) async throws
    func fetchFamily(familyId: String) async throws -> FamilyBudget?
    func fetchUserFamilies() async throws -> [FamilyBudget]
    func findFamilyByInviteCode(_ code: String) async throws -> FamilyBudget?

    // Member operations
    func addMember(_ member: FamilyMember, toFamily familyId: String) async throws
    func updateMember(_ member: FamilyMember, inFamily familyId: String) async throws
    func removeMember(memberId: String, fromFamily familyId: String) async throws
    func fetchMembers(familyId: String) async throws -> [FamilyMember]

    // Real-time listeners
    func observeFamily(familyId: String) -> AsyncStream<FamilyBudget?>
    func observeMembers(familyId: String) -> AsyncStream<[FamilyMember]>
}

// MARK: - Family Repository Implementation

/// Firestore repository for Family entities
final class FamilyRepository: FamilyRepositoryProtocol {

    // MARK: - Properties

    private let db: Firestore
    private var familyListener: ListenerRegistration?
    private var membersListener: ListenerRegistration?

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
        familyListener?.remove()
        membersListener?.remove()
    }

    // MARK: - Collection References

    private func familiesCollection() -> CollectionReference {
        db.collection(FirestorePath.families)
    }

    private func membersCollection(familyId: String) -> CollectionReference {
        db.collection(FirestorePath.familyMembersCollection(familyId: familyId))
    }

    private func userFamiliesCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }
        return db.collection(FirestorePath.userFamiliesCollection(userId: userId))
    }

    // MARK: - Family CRUD Operations

    func createFamily(_ family: FamilyBudget, withMember member: FamilyMember) async throws {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let batch = db.batch()

        // 1. Create family document
        let familyRef = familiesCollection().document(family.id)
        batch.setData(family.firestoreData, forDocument: familyRef)

        // 2. Add creator as member (use userId as document ID for security rules)
        let memberRef = membersCollection(familyId: family.id).document(member.userId)
        batch.setData(member.firestoreData, forDocument: memberRef)

        // 3. Add family reference to user's families collection
        let userFamilyRef = db.collection(FirestorePath.userFamiliesCollection(userId: userId)).document(family.id)
        batch.setData([
            "familyId": family.id,
            "joinedAt": Timestamp(date: Date()),
            "role": FamilyRole.admin.rawValue
        ], forDocument: userFamilyRef)

        do {
            try await batch.commit()
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateFamily(_ family: FamilyBudget) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await familiesCollection().document(family.id).setDataAsync(family.firestoreData, merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func deleteFamily(familyId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        // Note: In production, you'd want to use Cloud Functions to handle
        // cascading deletes of subcollections (members, transactions, etc.)

        do {
            try await familiesCollection().document(familyId).delete()
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchFamily(familyId: String) async throws -> FamilyBudget? {
        isLoading = true
        defer { isLoading = false }

        do {
            let document = try await familiesCollection().document(familyId).getDocument()
            guard document.exists else { return nil }
            return try FamilyBudget(from: document)
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchUserFamilies() async throws -> [FamilyBudget] {
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // First, get family IDs from user's families collection
            let userFamiliesSnapshot = try await db
                .collection(FirestorePath.userFamiliesCollection(userId: userId))
                .getDocuments()

            let familyIds = userFamiliesSnapshot.documents.compactMap { doc -> String? in
                doc.data()["familyId"] as? String
            }

            guard !familyIds.isEmpty else { return [] }

            // Then fetch each family document
            var families: [FamilyBudget] = []
            for familyId in familyIds {
                if let family = try await fetchFamily(familyId: familyId) {
                    families.append(family)
                }
            }

            return families.sorted { $0.createdAt > $1.createdAt }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func findFamilyByInviteCode(_ code: String) async throws -> FamilyBudget? {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await familiesCollection()
                .whereField("inviteCode", isEqualTo: code.uppercased())
                .limit(to: 1)
                .getDocuments()

            guard let document = snapshot.documents.first else { return nil }
            return try FamilyBudget(from: document)
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    // MARK: - Member Operations

    func addMember(_ member: FamilyMember, toFamily familyId: String) async throws {
        guard currentUserId != nil else {
            throw RepositoryError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let batch = db.batch()

        // 1. Add member to family's members collection (use userId as document ID)
        let memberRef = membersCollection(familyId: familyId).document(member.userId)
        batch.setData(member.firestoreData, forDocument: memberRef)

        // 2. Add family reference to user's families collection
        let userFamilyRef = db.collection(FirestorePath.userFamiliesCollection(userId: member.userId)).document(familyId)
        batch.setData([
            "familyId": familyId,
            "joinedAt": Timestamp(date: Date()),
            "role": member.role.rawValue
        ], forDocument: userFamilyRef)

        do {
            try await batch.commit()
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func updateMember(_ member: FamilyMember, inFamily familyId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await membersCollection(familyId: familyId).document(member.userId).setDataAsync(member.firestoreData, merge: true)
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func removeMember(memberId: String, fromFamily familyId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        // Get member to find their userId
        let memberDoc = try await membersCollection(familyId: familyId).document(memberId).getDocument()
        guard let memberData = memberDoc.data(),
              let userId = memberData["userId"] as? String else {
            throw RepositoryError.documentNotFound(memberId)
        }

        let batch = db.batch()

        // 1. Remove member from family
        let memberRef = membersCollection(familyId: familyId).document(memberId)
        batch.deleteDocument(memberRef)

        // 2. Remove family from user's families collection
        let userFamilyRef = db.collection(FirestorePath.userFamiliesCollection(userId: userId)).document(familyId)
        batch.deleteDocument(userFamilyRef)

        do {
            try await batch.commit()
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchMembers(familyId: String) async throws -> [FamilyMember] {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await membersCollection(familyId: familyId)
                .whereField("isActive", isEqualTo: true)
                .order(by: "joinedAt", descending: false)
                .getDocuments()

            return try snapshot.documents.map { try FamilyMember(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    // MARK: - Real-time Listeners

    func observeFamily(familyId: String) -> AsyncStream<FamilyBudget?> {
        AsyncStream { continuation in
            let listener = familiesCollection().document(familyId)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("FamilyRepository listener error: \(error.localizedDescription)")
                        return
                    }

                    guard let document = snapshot, document.exists else {
                        continuation.yield(nil)
                        return
                    }

                    if let family = try? FamilyBudget(from: document) {
                        continuation.yield(family)
                    }
                }

            self.familyListener = listener

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }

    func observeMembers(familyId: String) -> AsyncStream<[FamilyMember]> {
        AsyncStream { continuation in
            let listener = membersCollection(familyId: familyId)
                .whereField("isActive", isEqualTo: true)
                .order(by: "joinedAt", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("FamilyRepository members listener error: \(error.localizedDescription)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }

                    let members = documents.compactMap { doc -> FamilyMember? in
                        try? FamilyMember(from: doc)
                    }

                    continuation.yield(members)
                }

            self.membersListener = listener

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
}

// MARK: - Additional Helper Methods

extension FamilyRepository {

    /// Checks if a user is already a member of a family
    func isUserMemberOf(familyId: String, userId: String) async throws -> Bool {
        let snapshot = try await membersCollection(familyId: familyId)
            .whereField("userId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        return !snapshot.documents.isEmpty
    }

    /// Gets the role of a user in a family
    func getUserRole(familyId: String, userId: String) async throws -> FamilyRole? {
        let snapshot = try await membersCollection(familyId: familyId)
            .whereField("userId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              let roleRaw = doc.data()["role"] as? String else {
            return nil
        }

        return FamilyRole(rawValue: roleRaw)
    }

    /// Regenerates the invite code for a family
    func regenerateInviteCode(familyId: String) async throws -> String {
        let newCode = FamilyBudget.generateInviteCode()

        try await familiesCollection().document(familyId).updateData([
            "inviteCode": newCode,
            "lastModified": Timestamp(date: Date())
        ])

        return newCode
    }
}
