//
//  FamilyBudget.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Family Budget Model

/// Represents a shared family budget group where multiple members can track expenses together
@Model
final class FamilyBudget {
    @Attribute(.unique) var id: String
    var name: String
    var iconName: String
    var monthlyIncome: Decimal
    var createdBy: String // userId of the creator
    var inviteCode: String
    var coverImageURL: String?
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \FamilyMember.familyBudget)
    var members: [FamilyMember]?

    @Relationship(deleteRule: .cascade, inverse: \SharedBudget.familyBudget)
    var sharedBudgets: [SharedBudget]?

    @Relationship(deleteRule: .cascade, inverse: \SharedTransaction.familyBudget)
    var sharedTransactions: [SharedTransaction]?

    @Relationship(deleteRule: .cascade, inverse: \SharedCategory.familyBudget)
    var sharedCategories: [SharedCategory]?

    // MARK: - Computed Properties

    var memberCount: Int {
        members?.count ?? 0
    }

    var activeMembers: [FamilyMember] {
        members?.filter { $0.isActive } ?? []
    }

    var adminMembers: [FamilyMember] {
        members?.filter { $0.role == .admin } ?? []
    }

    var formattedMonthlyIncome: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: monthlyIncome as NSDecimalNumber) ?? "₹\(monthlyIncome)"
    }

    var icon: Image {
        Image(systemName: iconName)
    }

    // MARK: - Initialization

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

    // MARK: - Invite Code Generation

    /// Generates a 6-character alphanumeric invite code
    static func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed ambiguous chars (I, O, 0, 1)
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    /// Regenerates the invite code for this family
    func regenerateInviteCode() {
        inviteCode = FamilyBudget.generateInviteCode()
        lastModified = Date()
        isSynced = false
    }

    // MARK: - Member Management

    /// Checks if a user is a member of this family
    func isMember(userId: String) -> Bool {
        members?.contains { $0.userId == userId && $0.isActive } ?? false
    }

    /// Checks if a user is an admin of this family
    func isAdmin(userId: String) -> Bool {
        members?.contains { $0.userId == userId && $0.role == .admin && $0.isActive } ?? false
    }

    /// Gets the member for a specific user ID
    func getMember(userId: String) -> FamilyMember? {
        members?.first { $0.userId == userId }
    }

    // MARK: - Budget Calculations

    /// Total spent this month across all categories
    func totalSpentThisMonth() -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        return sharedTransactions?
            .filter { $0.type == .expense && $0.date >= startOfMonth }
            .reduce(Decimal.zero) { $0 + $1.amount } ?? Decimal.zero
    }

    /// Total income this month
    func totalIncomeThisMonth() -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        return sharedTransactions?
            .filter { $0.type == .income && $0.date >= startOfMonth }
            .reduce(Decimal.zero) { $0 + $1.amount } ?? Decimal.zero
    }

    /// Balance (income - expenses) for this month
    func balanceThisMonth() -> Decimal {
        totalIncomeThisMonth() - totalSpentThisMonth()
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
            "isSynced": isSynced,
            "lastModified": lastModified,
            "createdAt": createdAt
        ]

        if let coverImageURL = coverImageURL {
            data["coverImageURL"] = coverImageURL
        }

        return data
    }

    convenience init(from firestoreDoc: [String: Any]) {
        let id = firestoreDoc["id"] as? String ?? UUID().uuidString
        let name = firestoreDoc["name"] as? String ?? "Family Budget"
        let iconName = firestoreDoc["iconName"] as? String ?? "house.fill"
        let monthlyIncomeDouble = firestoreDoc["monthlyIncome"] as? Double ?? 0
        let createdBy = firestoreDoc["createdBy"] as? String ?? ""
        let inviteCode = firestoreDoc["inviteCode"] as? String ?? FamilyBudget.generateInviteCode()
        let coverImageURL = firestoreDoc["coverImageURL"] as? String
        let isSynced = firestoreDoc["isSynced"] as? Bool ?? true
        let lastModified = (firestoreDoc["lastModified"] as? Date) ?? Date()
        let createdAt = (firestoreDoc["createdAt"] as? Date) ?? Date()

        self.init(
            id: id,
            name: name,
            iconName: iconName,
            monthlyIncome: Decimal(monthlyIncomeDouble),
            createdBy: createdBy,
            inviteCode: inviteCode,
            coverImageURL: coverImageURL,
            isSynced: isSynced,
            lastModified: lastModified,
            createdAt: createdAt
        )
    }
}

// MARK: - Family Icon Options

extension FamilyBudget {
    /// Available icons for family budget groups
    static let availableIcons: [(name: String, symbol: String)] = [
        ("Home", "house.fill"),
        ("Family", "figure.2.and.child.holdinghands"),
        ("Heart", "heart.fill"),
        ("Star", "star.fill"),
        ("Wallet", "wallet.pass.fill"),
        ("Piggy Bank", "banknote.fill"),
        ("Couple", "person.2.fill"),
        ("Group", "person.3.fill"),
        ("Building", "building.2.fill"),
        ("Tree", "tree.fill"),
        ("Sun", "sun.max.fill"),
        ("Moon", "moon.fill")
    ]
}

// MARK: - Predicates

extension FamilyBudget {
    /// Predicate to find families by invite code
    static func inviteCodePredicate(code: String) -> Predicate<FamilyBudget> {
        #Predicate<FamilyBudget> { family in
            family.inviteCode == code
        }
    }

    /// Predicate for unsynced families
    static func unsyncedPredicate() -> Predicate<FamilyBudget> {
        #Predicate<FamilyBudget> { family in
            family.isSynced == false
        }
    }
}
