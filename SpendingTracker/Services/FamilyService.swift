//
//  FamilyService.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import FirebaseAuth
import SwiftData

// MARK: - Family Service Errors

enum FamilyServiceError: Error, LocalizedError {
    case notAuthenticated
    case familyNotFound
    case alreadyMember
    case invalidInviteCode
    case notAuthorized
    case cannotRemoveLastAdmin
    case cannotLeaveAsOnlyAdmin
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .familyNotFound:
            return "Family not found"
        case .alreadyMember:
            return "You are already a member of this family"
        case .invalidInviteCode:
            return "Invalid invite code. Please check and try again"
        case .notAuthorized:
            return "You don't have permission to perform this action"
        case .cannotRemoveLastAdmin:
            return "Cannot remove the last admin. Promote another member first"
        case .cannotLeaveAsOnlyAdmin:
            return "You cannot leave as the only admin. Transfer admin role first"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Family Service

/// Service class handling all family budget operations
@Observable
final class FamilyService {

    // MARK: - Properties

    private let repository: FamilyRepository
    private var modelContext: ModelContext?

    var isLoading: Bool = false
    var error: FamilyServiceError?

    /// Currently selected family (for active family context)
    var currentFamily: FamilyBudgetDTO?
    var currentFamilyMembers: [FamilyMemberDTO] = []

    /// All families the user belongs to
    var userFamilies: [FamilyBudgetDTO] = []

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private var currentUserEmail: String? {
        Auth.auth().currentUser?.email
    }

    private var currentUserDisplayName: String? {
        Auth.auth().currentUser?.displayName
    }

    // MARK: - Initialization

    init(repository: FamilyRepository = FamilyRepository()) {
        self.repository = repository
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Family CRUD Operations

    /// Creates a new family budget with the current user as admin
    @MainActor
    func createFamily(
        name: String,
        iconName: String = "house.fill",
        monthlyIncome: Decimal = 0
    ) async throws -> FamilyBudgetDTO {
        guard let userId = currentUserId,
              let email = currentUserEmail else {
            throw FamilyServiceError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let displayName = currentUserDisplayName ?? email.components(separatedBy: "@").first ?? "User"

        // Create family model
        let family = FamilyBudget(
            name: name,
            iconName: iconName,
            monthlyIncome: monthlyIncome,
            createdBy: userId
        )

        // Create admin member for the creator
        let adminMember = FamilyMember(
            userId: userId,
            displayName: displayName,
            email: email,
            role: .admin
        )

        do {
            try await repository.createFamily(family, withMember: adminMember)

            // Save to local SwiftData if context is available
            if let context = modelContext {
                context.insert(family)
                context.insert(adminMember)
                adminMember.familyBudget = family

                // Create default categories for the family
                let defaultCategories = SharedCategory.allDefaultCategories
                for category in defaultCategories {
                    let newCategory = SharedCategory(
                        name: category.name,
                        icon: category.icon,
                        colorHex: category.colorHex,
                        isExpenseCategory: category.isExpenseCategory,
                        budgetType: category.budgetType,
                        sortOrder: category.sortOrder,
                        isDefault: true
                    )
                    newCategory.familyBudget = family
                    context.insert(newCategory)
                }

                try context.save()
            }

            let familyDTO = FamilyBudgetDTO(from: family)
            userFamilies.append(familyDTO)

            return familyDTO
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    /// Fetches all families the current user belongs to
    @MainActor
    func fetchUserFamilies() async throws {
        guard currentUserId != nil else {
            throw FamilyServiceError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        do {
            userFamilies = try await repository.fetchUserFamilies()
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    /// Updates family settings (admin only)
    @MainActor
    func updateFamily(
        familyId: String,
        name: String? = nil,
        iconName: String? = nil,
        monthlyIncome: Decimal? = nil
    ) async throws {
        guard let userId = currentUserId else {
            throw FamilyServiceError.notAuthenticated
        }

        // Check if user is admin
        guard let role = try await repository.getUserRole(familyId: familyId, userId: userId),
              role == .admin else {
            throw FamilyServiceError.notAuthorized
        }

        isLoading = true
        defer { isLoading = false }

        guard var familyDTO = try await repository.fetchFamily(familyId: familyId) else {
            throw FamilyServiceError.familyNotFound
        }

        // Update only provided fields
        if let name = name { familyDTO = FamilyBudgetDTO(
            id: familyDTO.id,
            name: name,
            iconName: familyDTO.iconName,
            monthlyIncome: familyDTO.monthlyIncome,
            createdBy: familyDTO.createdBy,
            inviteCode: familyDTO.inviteCode,
            coverImageURL: familyDTO.coverImageURL,
            lastModified: Date(),
            createdAt: familyDTO.createdAt
        )}

        // Create a FamilyBudget model for the repository
        let family = FamilyBudget(
            id: familyDTO.id,
            name: name ?? familyDTO.name,
            iconName: iconName ?? familyDTO.iconName,
            monthlyIncome: monthlyIncome ?? familyDTO.monthlyIncome,
            createdBy: familyDTO.createdBy,
            inviteCode: familyDTO.inviteCode,
            coverImageURL: familyDTO.coverImageURL,
            lastModified: Date(),
            createdAt: familyDTO.createdAt
        )

        do {
            try await repository.updateFamily(family)

            // Update local state
            if let index = userFamilies.firstIndex(where: { $0.id == familyId }) {
                userFamilies[index] = FamilyBudgetDTO(from: family)
            }
            if currentFamily?.id == familyId {
                currentFamily = FamilyBudgetDTO(from: family)
            }
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    /// Deletes a family (admin only)
    @MainActor
    func deleteFamily(familyId: String) async throws {
        guard let userId = currentUserId else {
            throw FamilyServiceError.notAuthenticated
        }

        // Check if user is admin
        guard let role = try await repository.getUserRole(familyId: familyId, userId: userId),
              role == .admin else {
            throw FamilyServiceError.notAuthorized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.deleteFamily(familyId: familyId)

            // Update local state
            userFamilies.removeAll { $0.id == familyId }
            if currentFamily?.id == familyId {
                currentFamily = nil
                currentFamilyMembers = []
            }
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    // MARK: - Join Family

    /// Joins a family using an invite code
    @MainActor
    func joinFamily(inviteCode: String) async throws -> FamilyBudgetDTO {
        guard let userId = currentUserId,
              let email = currentUserEmail else {
            throw FamilyServiceError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        // Find family by invite code
        guard let familyDTO = try await repository.findFamilyByInviteCode(inviteCode.uppercased()) else {
            throw FamilyServiceError.invalidInviteCode
        }

        // Check if already a member
        if try await repository.isUserMemberOf(familyId: familyDTO.id, userId: userId) {
            throw FamilyServiceError.alreadyMember
        }

        let displayName = currentUserDisplayName ?? email.components(separatedBy: "@").first ?? "User"

        // Create member
        let member = FamilyMember(
            userId: userId,
            displayName: displayName,
            email: email,
            role: .member
        )

        do {
            try await repository.addMember(member, toFamily: familyDTO.id)

            // Save to local SwiftData if context is available
            if let context = modelContext {
                context.insert(member)
                try context.save()
            }

            userFamilies.append(familyDTO)
            return familyDTO
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    // MARK: - Member Management

    /// Fetches members for a family
    @MainActor
    func fetchMembers(familyId: String) async throws -> [FamilyMemberDTO] {
        isLoading = true
        defer { isLoading = false }

        do {
            let members = try await repository.fetchMembers(familyId: familyId)
            if currentFamily?.id == familyId {
                currentFamilyMembers = members
            }
            return members
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    /// Updates a member's role (admin only)
    @MainActor
    func updateMemberRole(
        familyId: String,
        memberId: String,
        newRole: FamilyRole
    ) async throws {
        guard let userId = currentUserId else {
            throw FamilyServiceError.notAuthenticated
        }

        // Check if user is admin
        guard let role = try await repository.getUserRole(familyId: familyId, userId: userId),
              role == .admin else {
            throw FamilyServiceError.notAuthorized
        }

        isLoading = true
        defer { isLoading = false }

        // If demoting from admin, ensure there's another admin
        let members = try await repository.fetchMembers(familyId: familyId)
        if let currentMember = members.first(where: { $0.id == memberId }),
           currentMember.role == .admin && newRole != .admin {
            let adminCount = members.filter { $0.role == .admin }.count
            if adminCount <= 1 {
                throw FamilyServiceError.cannotRemoveLastAdmin
            }
        }

        // Create updated member model
        guard let existingMember = members.first(where: { $0.id == memberId }) else {
            throw FamilyServiceError.familyNotFound
        }

        let updatedMember = FamilyMember(
            id: existingMember.id,
            userId: existingMember.userId,
            displayName: existingMember.displayName,
            email: existingMember.email,
            role: newRole,
            avatarColorHex: existingMember.avatarColorHex,
            avatarEmoji: existingMember.avatarEmoji,
            joinedAt: existingMember.joinedAt,
            isActive: existingMember.isActive,
            lastModified: Date()
        )

        do {
            try await repository.updateMember(updatedMember, inFamily: familyId)

            // Update local state
            if let index = currentFamilyMembers.firstIndex(where: { $0.id == memberId }) {
                currentFamilyMembers[index] = FamilyMemberDTO(from: updatedMember)
            }
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    /// Removes a member from the family (admin only)
    @MainActor
    func removeMember(familyId: String, memberId: String) async throws {
        guard let userId = currentUserId else {
            throw FamilyServiceError.notAuthenticated
        }

        // Check if user is admin
        guard let role = try await repository.getUserRole(familyId: familyId, userId: userId),
              role == .admin else {
            throw FamilyServiceError.notAuthorized
        }

        isLoading = true
        defer { isLoading = false }

        // If removing an admin, ensure there's another admin
        let members = try await repository.fetchMembers(familyId: familyId)
        if let memberToRemove = members.first(where: { $0.id == memberId }),
           memberToRemove.role == .admin {
            let adminCount = members.filter { $0.role == .admin }.count
            if adminCount <= 1 {
                throw FamilyServiceError.cannotRemoveLastAdmin
            }
        }

        do {
            try await repository.removeMember(memberId: memberId, fromFamily: familyId)

            // Update local state
            currentFamilyMembers.removeAll { $0.id == memberId }
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    /// Leaves a family (current user)
    @MainActor
    func leaveFamily(familyId: String) async throws {
        guard let userId = currentUserId else {
            throw FamilyServiceError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        let members = try await repository.fetchMembers(familyId: familyId)
        guard let currentMember = members.first(where: { $0.userId == userId }) else {
            throw FamilyServiceError.familyNotFound
        }

        // If user is admin, ensure there's another admin
        if currentMember.role == .admin {
            let adminCount = members.filter { $0.role == .admin }.count
            if adminCount <= 1 {
                throw FamilyServiceError.cannotLeaveAsOnlyAdmin
            }
        }

        do {
            try await repository.removeMember(memberId: currentMember.id, fromFamily: familyId)

            // Update local state
            userFamilies.removeAll { $0.id == familyId }
            if currentFamily?.id == familyId {
                currentFamily = nil
                currentFamilyMembers = []
            }
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    // MARK: - Invite Code Management

    /// Regenerates the invite code for a family (admin only)
    @MainActor
    func regenerateInviteCode(familyId: String) async throws -> String {
        guard let userId = currentUserId else {
            throw FamilyServiceError.notAuthenticated
        }

        // Check if user is admin
        guard let role = try await repository.getUserRole(familyId: familyId, userId: userId),
              role == .admin else {
            throw FamilyServiceError.notAuthorized
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let newCode = try await repository.regenerateInviteCode(familyId: familyId)

            // Update local state
            if let index = userFamilies.firstIndex(where: { $0.id == familyId }) {
                var family = userFamilies[index]
                family = FamilyBudgetDTO(
                    id: family.id,
                    name: family.name,
                    iconName: family.iconName,
                    monthlyIncome: family.monthlyIncome,
                    createdBy: family.createdBy,
                    inviteCode: newCode,
                    coverImageURL: family.coverImageURL,
                    lastModified: Date(),
                    createdAt: family.createdAt
                )
                userFamilies[index] = family
            }

            return newCode
        } catch {
            self.error = .unknown(error)
            throw FamilyServiceError.unknown(error)
        }
    }

    // MARK: - Active Family Management

    /// Sets the currently active family
    @MainActor
    func setCurrentFamily(_ family: FamilyBudgetDTO?) async {
        currentFamily = family

        if let familyId = family?.id {
            do {
                currentFamilyMembers = try await fetchMembers(familyId: familyId)
            } catch {
                print("Failed to fetch members: \(error)")
                currentFamilyMembers = []
            }
        } else {
            currentFamilyMembers = []
        }
    }

    /// Gets the current user's role in the active family
    func currentUserRole() -> FamilyRole? {
        guard let userId = currentUserId else { return nil }
        return currentFamilyMembers.first(where: { $0.userId == userId })?.role
    }

    /// Checks if current user is admin of the active family
    func isCurrentUserAdmin() -> Bool {
        currentUserRole() == .admin
    }
}
