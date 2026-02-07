//
//  FamilyMember.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Family Role Enum

enum FamilyRole: String, Codable, CaseIterable {
    case admin = "Admin"
    case member = "Member"
    case viewer = "Viewer"

    var displayName: String { rawValue }

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
                canAddTransactions: true, canEditTransactions: true, canDeleteTransactions: true,
                canManageBudgets: true, canManageCategories: true, canInviteMembers: true,
                canRemoveMembers: true, canEditFamilySettings: true, canDeleteFamily: true
            )
        case .member:
            return FamilyPermissions(
                canAddTransactions: true, canEditTransactions: true, canDeleteTransactions: false,
                canManageBudgets: false, canManageCategories: false, canInviteMembers: true,
                canRemoveMembers: false, canEditFamilySettings: false, canDeleteFamily: false
            )
        case .viewer:
            return FamilyPermissions(
                canAddTransactions: false, canEditTransactions: false, canDeleteTransactions: false,
                canManageBudgets: false, canManageCategories: false, canInviteMembers: false,
                canRemoveMembers: false, canEditFamilySettings: false, canDeleteFamily: false
            )
        }
    }
}

// MARK: - Family Permissions

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

struct FamilyMember: Identifiable, Equatable, Hashable {
    let id: String
    var userId: String
    var displayName: String
    var email: String
    var role: FamilyRole
    var avatarColorHex: String
    var avatarEmoji: String?
    var joinedAt: Date
    var isActive: Bool

    var permissions: FamilyPermissions { role.permissions }

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

    init(
        id: String = UUID().uuidString,
        userId: String,
        displayName: String,
        email: String,
        role: FamilyRole = .member,
        avatarColorHex: String? = nil,
        avatarEmoji: String? = nil,
        joinedAt: Date = Date(),
        isActive: Bool = true
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
    }

    static let avatarColors: [String] = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD",
        "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9", "#F8B500", "#58D68D"
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
            "role": role.rawValue,
            "avatarColorHex": avatarColorHex,
            "joinedAt": Timestamp(date: joinedAt),
            "isActive": isActive,
            "isSynced": true,
            "lastModified": FieldValue.serverTimestamp()
        ]
        if let avatarEmoji = avatarEmoji {
            data["avatarEmoji"] = avatarEmoji
        }
        return data
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

        if let joinedAtTimestamp = data["joinedAt"] as? Timestamp {
            self.joinedAt = joinedAtTimestamp.dateValue()
        } else {
            self.joinedAt = Date()
        }

        self.isActive = data["isActive"] as? Bool ?? true
    }
}
