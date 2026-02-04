//
//  FamilyMember.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Family Role Enum

/// Defines the role of a member within a family budget
enum FamilyRole: String, Codable, CaseIterable {
    case admin = "Admin"
    case member = "Member"
    case viewer = "Viewer"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .admin: return "crown.fill"
        case .member: return "person.fill"
        case .viewer: return "eye.fill"
        }
    }

    var description: String {
        switch self {
        case .admin:
            return "Full control: manage members, budgets, and all settings"
        case .member:
            return "Can add and edit transactions, view all data"
        case .viewer:
            return "View-only access to transactions and budgets"
        }
    }

    var permissions: FamilyPermissions {
        switch self {
        case .admin:
            return FamilyPermissions(
                canAddTransactions: true,
                canEditTransactions: true,
                canDeleteTransactions: true,
                canManageBudgets: true,
                canManageCategories: true,
                canInviteMembers: true,
                canRemoveMembers: true,
                canEditFamilySettings: true,
                canDeleteFamily: true
            )
        case .member:
            return FamilyPermissions(
                canAddTransactions: true,
                canEditTransactions: true,
                canDeleteTransactions: false,
                canManageBudgets: false,
                canManageCategories: false,
                canInviteMembers: true,
                canRemoveMembers: false,
                canEditFamilySettings: false,
                canDeleteFamily: false
            )
        case .viewer:
            return FamilyPermissions(
                canAddTransactions: false,
                canEditTransactions: false,
                canDeleteTransactions: false,
                canManageBudgets: false,
                canManageCategories: false,
                canInviteMembers: false,
                canRemoveMembers: false,
                canEditFamilySettings: false,
                canDeleteFamily: false
            )
        }
    }
}

// MARK: - Family Permissions

/// Defines what actions a member can perform
struct FamilyPermissions {
    let canAddTransactions: Bool
    let canEditTransactions: Bool
    let canDeleteTransactions: Bool
    let canManageBudgets: Bool
    let canManageCategories: Bool
    let canInviteMembers: Bool
    let canRemoveMembers: Bool
    let canEditFamilySettings: Bool
    let canDeleteFamily: Bool
}

// MARK: - Family Member Model

/// Represents a member of a family budget group
@Model
final class FamilyMember {
    @Attribute(.unique) var id: String
    var userId: String // Reference to Firebase Auth user ID
    var displayName: String
    var email: String
    var roleRawValue: String
    var avatarColorHex: String
    var avatarEmoji: String?
    var joinedAt: Date
    var isActive: Bool
    var isSynced: Bool
    var lastModified: Date

    @Relationship var familyBudget: FamilyBudget?

    // MARK: - Computed Properties

    var role: FamilyRole {
        get { FamilyRole(rawValue: roleRawValue) ?? .member }
        set { roleRawValue = newValue.rawValue }
    }

    var permissions: FamilyPermissions {
        role.permissions
    }

    var avatarColor: Color {
        Color(hex: avatarColorHex) ?? .blue
    }

    var initials: String {
        let names = displayName.split(separator: " ")
        if names.count >= 2 {
            return String(names[0].prefix(1) + names[1].prefix(1)).uppercased()
        } else if let firstName = names.first {
            return String(firstName.prefix(2)).uppercased()
        }
        return "??"
    }

    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: joinedAt)
    }

    // MARK: - Initialization

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
        self.roleRawValue = role.rawValue
        self.avatarColorHex = avatarColorHex ?? FamilyMember.randomAvatarColor()
        self.avatarEmoji = avatarEmoji
        self.joinedAt = joinedAt
        self.isActive = isActive
        self.isSynced = isSynced
        self.lastModified = lastModified
    }

    // MARK: - Avatar Colors

    static let avatarColors: [String] = [
        "#FF6B6B", // Red
        "#4ECDC4", // Teal
        "#45B7D1", // Blue
        "#96CEB4", // Green
        "#FFEAA7", // Yellow
        "#DDA0DD", // Plum
        "#98D8C8", // Mint
        "#F7DC6F", // Gold
        "#BB8FCE", // Purple
        "#85C1E9", // Light Blue
        "#F8B500", // Orange
        "#58D68D"  // Lime
    ]

    static func randomAvatarColor() -> String {
        avatarColors.randomElement() ?? "#007AFF"
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "userId": userId,
            "displayName": displayName,
            "email": email,
            "role": roleRawValue,
            "avatarColorHex": avatarColorHex,
            "joinedAt": joinedAt,
            "isActive": isActive,
            "isSynced": isSynced,
            "lastModified": lastModified
        ]

        if let avatarEmoji = avatarEmoji {
            data["avatarEmoji"] = avatarEmoji
        }

        return data
    }

    convenience init(from firestoreDoc: [String: Any]) {
        let id = firestoreDoc["id"] as? String ?? UUID().uuidString
        let userId = firestoreDoc["userId"] as? String ?? ""
        let displayName = firestoreDoc["displayName"] as? String ?? "Unknown"
        let email = firestoreDoc["email"] as? String ?? ""
        let roleRaw = firestoreDoc["role"] as? String ?? FamilyRole.member.rawValue
        let avatarColorHex = firestoreDoc["avatarColorHex"] as? String ?? FamilyMember.randomAvatarColor()
        let avatarEmoji = firestoreDoc["avatarEmoji"] as? String
        let joinedAt = (firestoreDoc["joinedAt"] as? Date) ?? Date()
        let isActive = firestoreDoc["isActive"] as? Bool ?? true
        let isSynced = firestoreDoc["isSynced"] as? Bool ?? true
        let lastModified = (firestoreDoc["lastModified"] as? Date) ?? Date()

        self.init(
            id: id,
            userId: userId,
            displayName: displayName,
            email: email,
            role: FamilyRole(rawValue: roleRaw) ?? .member,
            avatarColorHex: avatarColorHex,
            avatarEmoji: avatarEmoji,
            joinedAt: joinedAt,
            isActive: isActive,
            isSynced: isSynced,
            lastModified: lastModified
        )
    }
}

// MARK: - Predicates

extension FamilyMember {
    /// Predicate for active members
    static func activeMembersPredicate() -> Predicate<FamilyMember> {
        #Predicate<FamilyMember> { member in
            member.isActive == true
        }
    }

    /// Predicate for unsynced members
    static func unsyncedPredicate() -> Predicate<FamilyMember> {
        #Predicate<FamilyMember> { member in
            member.isSynced == false
        }
    }
}
