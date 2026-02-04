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
    func fetchFamily(familyId: String) async throws -> FamilyBudgetDTO?
    func fetchUserFamilies() async throws -> [FamilyBudgetDTO]
    func findFamilyByInviteCode(_ code: String) async throws -> FamilyBudgetDTO?

    // Member operations
    func addMember(_ member: FamilyMember, toFamily familyId: String) async throws
    func updateMember(_ member: FamilyMember, inFamily familyId: String) async throws
    func removeMember(memberId: String, fromFamily familyId: String) async throws
    func fetchMembers(familyId: String) async throws -> [FamilyMemberDTO]

    // Real-time listeners
    func observeFamily(familyId: String) -> AsyncStream<FamilyBudgetDTO?>
    func observeMembers(familyId: String) -> AsyncStream<[FamilyMemberDTO]>
}

// MARK: - Family Budget DTO

/// Data Transfer Object for FamilyBudget (decoupled from SwiftData)
struct FamilyBudgetDTO: Identifiable, Equatable {
    let id: String
    var name: String
    var iconName: String
    var monthlyIncome: Decimal
    var createdBy: String
    var inviteCode: String
    var coverImageURL: String?
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    var formattedMonthlyIncome: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: monthlyIncome as NSDecimalNumber) ?? "₹\(monthlyIncome)"
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "name": name,
            "iconName": iconName,
            "monthlyIncome": NSDecimalNumber(decimal: monthlyIncome).doubleValue,
            "createdBy": createdBy,
            "inviteCode": inviteCode,
            "isSynced": true,
            "lastModified": Timestamp(date: lastModified),
            "createdAt": Timestamp(date: createdAt)
        ]

        if let coverImageURL = coverImageURL {
            data["coverImageURL"] = coverImageURL
        }

        return data
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        iconName: String = "house.fill",
        monthlyIncome: Decimal = 0,
        createdBy: String,
        inviteCode: String? = nil,
        coverImageURL: String? = nil,
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.monthlyIncome = monthlyIncome
        self.createdBy = createdBy
        self.inviteCode = inviteCode ?? FamilyBudget.generateInviteCode()
        self.coverImageURL = coverImageURL
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.name = data["name"] as? String ?? "Family Budget"
        self.iconName = data["iconName"] as? String ?? "house.fill"
        self.monthlyIncome = Decimal((data["monthlyIncome"] as? Double) ?? 0)
        self.createdBy = data["createdBy"] as? String ?? ""
        self.inviteCode = data["inviteCode"] as? String ?? ""
        self.coverImageURL = data["coverImageURL"] as? String
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

    init(from family: FamilyBudget) {
        self.id = family.id
        self.name = family.name
        self.iconName = family.iconName
        self.monthlyIncome = family.monthlyIncome
        self.createdBy = family.createdBy
        self.inviteCode = family.inviteCode
        self.coverImageURL = family.coverImageURL
        self.isSynced = family.isSynced
        self.lastModified = family.lastModified
        self.createdAt = family.createdAt
    }
}

// MARK: - Family Member DTO

/// Data Transfer Object for FamilyMember (decoupled from SwiftData)
struct FamilyMemberDTO: Identifiable, Equatable {
    let id: String
    var userId: String
    var displayName: String
    var email: String
    var role: FamilyRole
    var avatarColorHex: String
    var avatarEmoji: String?
    var joinedAt: Date
    var isActive: Bool
    var isSynced: Bool
    var lastModified: Date

    var initials: String {
        let names = displayName.split(separator: " ")
        if names.count >= 2 {
            return String(names[0].prefix(1) + names[1].prefix(1)).uppercased()
        } else if let firstName = names.first {
            return String(firstName.prefix(2)).uppercased()
        }
        return "??"
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "userId": userId,
            "displayName": displayName,
            "email": email,
            "role": role.rawValue,
            "avatarColorHex": avatarColorHex,
            "joinedAt": Timestamp(date: joinedAt),
            "isActive": isActive,
            "isSynced": true,
            "lastModified": Timestamp(date: lastModified)
        ]

        if let avatarEmoji = avatarEmoji {
            data["avatarEmoji"] = avatarEmoji
        }

        return data
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        displayName: String,
        email: String,
        role: FamilyRole = .member,
        avatarColorHex: String? = nil,
        avatarEmoji: String? = nil,
        joinedAt: Date = Date(),
        isActive: Bool = true,
        isSynced: Bool = false,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.role = role
        self.avatarColorHex = avatarColorHex ?? FamilyMember.randomAvatarColor()
        self.avatarEmoji = avatarEmoji
        self.joinedAt = joinedAt
        self.isActive = isActive
        self.isSynced = isSynced
        self.lastModified = lastModified
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.displayName = data["displayName"] as? String ?? "Unknown"
        self.email = data["email"] as? String ?? ""

        let roleRaw = data["role"] as? String ?? FamilyRole.member.rawValue
        self.role = FamilyRole(rawValue: roleRaw) ?? .member

        self.avatarColorHex = data["avatarColorHex"] as? String ?? FamilyMember.randomAvatarColor()
        self.avatarEmoji = data["avatarEmoji"] as? String
        self.isActive = data["isActive"] as? Bool ?? true
        self.isSynced = data["isSynced"] as? Bool ?? true

        if let joinedAtTimestamp = data["joinedAt"] as? Timestamp {
            self.joinedAt = joinedAtTimestamp.dateValue()
        } else {
            self.joinedAt = Date()
        }

        if let lastModifiedTimestamp = data["lastModified"] as? Timestamp {
            self.lastModified = lastModifiedTimestamp.dateValue()
        } else {
            self.lastModified = Date()
        }
    }

    init(from member: FamilyMember) {
        self.id = member.id
        self.userId = member.userId
        self.displayName = member.displayName
        self.email = member.email
        self.role = member.role
        self.avatarColorHex = member.avatarColorHex
        self.avatarEmoji = member.avatarEmoji
        self.joinedAt = member.joinedAt
        self.isActive = member.isActive
        self.isSynced = member.isSynced
        self.lastModified = member.lastModified
    }
}

// MARK: - Family Repository Implementation

/// Firestore repository for Family entities
@Observable
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

        let familyDTO = FamilyBudgetDTO(from: family)
        let memberDTO = FamilyMemberDTO(from: member)

        let batch = db.batch()

        // 1. Create family document
        let familyRef = familiesCollection().document(familyDTO.id)
        batch.setData(familyDTO.firestoreData, forDocument: familyRef)

        // 2. Add creator as member
        let memberRef = membersCollection(familyId: familyDTO.id).document(memberDTO.id)
        batch.setData(memberDTO.firestoreData, forDocument: memberRef)

        // 3. Add family reference to user's families collection
        let userFamilyRef = db.collection(FirestorePath.userFamiliesCollection(userId: userId)).document(familyDTO.id)
        batch.setData([
            "familyId": familyDTO.id,
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

        let dto = FamilyBudgetDTO(from: family)

        do {
            try await familiesCollection().document(dto.id).setDataAsync(dto.firestoreData, merge: true)
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

    func fetchFamily(familyId: String) async throws -> FamilyBudgetDTO? {
        isLoading = true
        defer { isLoading = false }

        do {
            let document = try await familiesCollection().document(familyId).getDocument()
            guard document.exists else { return nil }
            return try FamilyBudgetDTO(from: document)
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    func fetchUserFamilies() async throws -> [FamilyBudgetDTO] {
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
            var families: [FamilyBudgetDTO] = []
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

    func findFamilyByInviteCode(_ code: String) async throws -> FamilyBudgetDTO? {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await familiesCollection()
                .whereField("inviteCode", isEqualTo: code.uppercased())
                .limit(to: 1)
                .getDocuments()

            guard let document = snapshot.documents.first else { return nil }
            return try FamilyBudgetDTO(from: document)
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
        guard let userId = currentUserId else {
            throw RepositoryError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let memberDTO = FamilyMemberDTO(from: member)
        let batch = db.batch()

        // 1. Add member to family's members collection
        let memberRef = membersCollection(familyId: familyId).document(memberDTO.id)
        batch.setData(memberDTO.firestoreData, forDocument: memberRef)

        // 2. Add family reference to user's families collection
        let userFamilyRef = db.collection(FirestorePath.userFamiliesCollection(userId: memberDTO.userId)).document(familyId)
        batch.setData([
            "familyId": familyId,
            "joinedAt": Timestamp(date: Date()),
            "role": memberDTO.role.rawValue
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

        let dto = FamilyMemberDTO(from: member)

        do {
            try await membersCollection(familyId: familyId).document(dto.id).setDataAsync(dto.firestoreData, merge: true)
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

    func fetchMembers(familyId: String) async throws -> [FamilyMemberDTO] {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await membersCollection(familyId: familyId)
                .whereField("isActive", isEqualTo: true)
                .order(by: "joinedAt", descending: false)
                .getDocuments()

            return try snapshot.documents.map { try FamilyMemberDTO(from: $0) }
        } catch let repoError as RepositoryError {
            self.error = repoError
            throw repoError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }

    // MARK: - Real-time Listeners

    func observeFamily(familyId: String) -> AsyncStream<FamilyBudgetDTO?> {
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

                    if let family = try? FamilyBudgetDTO(from: document) {
                        continuation.yield(family)
                    }
                }

            self.familyListener = listener

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }

    func observeMembers(familyId: String) -> AsyncStream<[FamilyMemberDTO]> {
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

                    let members = documents.compactMap { doc -> FamilyMemberDTO? in
                        try? FamilyMemberDTO(from: doc)
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
