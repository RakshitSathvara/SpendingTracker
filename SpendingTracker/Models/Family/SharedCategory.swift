//
//  SharedCategory.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Budget Type Enum (50/30/20 Rule)

/// Categorizes expenses according to the 50/30/20 budgeting rule
enum BudgetType: String, Codable, CaseIterable {
    case needs = "Needs"
    case wants = "Wants"
    case savings = "Savings"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .needs: return "house.fill"
        case .wants: return "sparkles"
        case .savings: return "banknote.fill"
        }
    }

    var description: String {
        switch self {
        case .needs:
            return "Essential expenses like housing, food, utilities, healthcare"
        case .wants:
            return "Lifestyle expenses like entertainment, dining out, shopping"
        case .savings:
            return "Savings, investments, emergency fund, debt repayment"
        }
    }

    /// Recommended percentage allocation (can be adjusted for Indian families)
    var recommendedPercentage: Int {
        switch self {
        case .needs: return 50
        case .wants: return 30
        case .savings: return 20
        }
    }

    var color: Color {
        switch self {
        case .needs: return Color(hex: "#4A90A4") ?? .blue
        case .wants: return Color(hex: "#FF6B6B") ?? .red
        case .savings: return Color(hex: "#2E8B57") ?? .green
        }
    }
}

// MARK: - Shared Category Model

struct SharedCategory: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var icon: String
    var colorHex: String
    var isExpenseCategory: Bool
    var budgetType: BudgetType
    var sortOrder: Int
    var isDefault: Bool
    var createdAt: Date

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        icon: String = "tag.fill",
        colorHex: String = "#007AFF",
        isExpenseCategory: Bool = true,
        budgetType: BudgetType = .needs,
        sortOrder: Int = 0,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isExpenseCategory = isExpenseCategory
        self.budgetType = budgetType
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "icon": icon,
            "colorHex": colorHex,
            "isExpenseCategory": isExpenseCategory,
            "budgetType": budgetType.rawValue,
            "sortOrder": sortOrder,
            "isDefault": isDefault,
            "isSynced": true,
            "lastModified": FieldValue.serverTimestamp(),
            "createdAt": Timestamp(date: createdAt)
        ]
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
        let budgetTypeRaw = data["budgetType"] as? String ?? BudgetType.needs.rawValue
        self.budgetType = BudgetType(rawValue: budgetTypeRaw) ?? .needs
        self.sortOrder = data["sortOrder"] as? Int ?? 0
        self.isDefault = data["isDefault"] as? Bool ?? false

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

// MARK: - Default Indian Family Categories

extension SharedCategory {

    // MARK: - Needs (Essential Expenses)

    static var defaultNeedsCategories: [SharedCategory] {
        [
            SharedCategory(name: "Housing/Rent", icon: "house.fill", colorHex: "#4A90A4", budgetType: .needs, sortOrder: 0, isDefault: true),
            SharedCategory(name: "Groceries", icon: "cart.fill", colorHex: "#6B8E23", budgetType: .needs, sortOrder: 1, isDefault: true),
            SharedCategory(name: "Utilities", icon: "bolt.fill", colorHex: "#FFD700", budgetType: .needs, sortOrder: 2, isDefault: true),
            SharedCategory(name: "Education", icon: "book.fill", colorHex: "#8B4513", budgetType: .needs, sortOrder: 3, isDefault: true),
            SharedCategory(name: "Healthcare", icon: "cross.case.fill", colorHex: "#DC143C", budgetType: .needs, sortOrder: 4, isDefault: true),
            SharedCategory(name: "Transportation", icon: "car.fill", colorHex: "#4169E1", budgetType: .needs, sortOrder: 5, isDefault: true),
            SharedCategory(name: "Insurance", icon: "shield.fill", colorHex: "#2E8B57", budgetType: .needs, sortOrder: 6, isDefault: true),
            SharedCategory(name: "Family Support", icon: "person.2.fill", colorHex: "#9370DB", budgetType: .needs, sortOrder: 7, isDefault: true),
            SharedCategory(name: "EMI/Loans", icon: "indianrupeesign.circle.fill", colorHex: "#CD853F", budgetType: .needs, sortOrder: 8, isDefault: true)
        ]
    }

    // MARK: - Wants (Lifestyle Expenses)

    static var defaultWantsCategories: [SharedCategory] {
        [
            SharedCategory(name: "Dining Out", icon: "fork.knife", colorHex: "#FF6347", budgetType: .wants, sortOrder: 10, isDefault: true),
            SharedCategory(name: "Entertainment", icon: "tv.fill", colorHex: "#9932CC", budgetType: .wants, sortOrder: 11, isDefault: true),
            SharedCategory(name: "Shopping", icon: "bag.fill", colorHex: "#FF69B4", budgetType: .wants, sortOrder: 12, isDefault: true),
            SharedCategory(name: "Personal Care", icon: "sparkles", colorHex: "#FFB6C1", budgetType: .wants, sortOrder: 13, isDefault: true),
            SharedCategory(name: "Travel", icon: "airplane", colorHex: "#00CED1", budgetType: .wants, sortOrder: 14, isDefault: true),
            SharedCategory(name: "Subscriptions", icon: "play.rectangle.fill", colorHex: "#FF4500", budgetType: .wants, sortOrder: 15, isDefault: true),
            SharedCategory(name: "Gifts & Donations", icon: "gift.fill", colorHex: "#DAA520", budgetType: .wants, sortOrder: 16, isDefault: true),
            SharedCategory(name: "Festivals", icon: "sparkler", colorHex: "#FF8C00", budgetType: .wants, sortOrder: 17, isDefault: true)
        ]
    }

    // MARK: - Savings & Investments

    static var defaultSavingsCategories: [SharedCategory] {
        [
            SharedCategory(name: "Emergency Fund", icon: "banknote.fill", colorHex: "#228B22", isExpenseCategory: false, budgetType: .savings, sortOrder: 20, isDefault: true),
            SharedCategory(name: "Investments", icon: "chart.line.uptrend.xyaxis", colorHex: "#008B8B", isExpenseCategory: false, budgetType: .savings, sortOrder: 21, isDefault: true),
            SharedCategory(name: "Retirement", icon: "clock.fill", colorHex: "#4682B4", isExpenseCategory: false, budgetType: .savings, sortOrder: 22, isDefault: true),
            SharedCategory(name: "Goal Savings", icon: "target", colorHex: "#32CD32", isExpenseCategory: false, budgetType: .savings, sortOrder: 23, isDefault: true),
            SharedCategory(name: "Gold/Jewelry", icon: "seal.fill", colorHex: "#FFD700", isExpenseCategory: false, budgetType: .savings, sortOrder: 24, isDefault: true)
        ]
    }

    // MARK: - Income Categories

    static var defaultIncomeCategories: [SharedCategory] {
        [
            SharedCategory(name: "Salary", icon: "briefcase.fill", colorHex: "#34C759", isExpenseCategory: false, budgetType: .savings, sortOrder: 30, isDefault: true),
            SharedCategory(name: "Business", icon: "building.2.fill", colorHex: "#007AFF", isExpenseCategory: false, budgetType: .savings, sortOrder: 31, isDefault: true),
            SharedCategory(name: "Freelance", icon: "laptopcomputer", colorHex: "#5856D6", isExpenseCategory: false, budgetType: .savings, sortOrder: 32, isDefault: true),
            SharedCategory(name: "Rental Income", icon: "house.lodge.fill", colorHex: "#FF9500", isExpenseCategory: false, budgetType: .savings, sortOrder: 33, isDefault: true),
            SharedCategory(name: "Interest", icon: "percent", colorHex: "#00C7BE", isExpenseCategory: false, budgetType: .savings, sortOrder: 34, isDefault: true),
            SharedCategory(name: "Other Income", icon: "ellipsis.circle.fill", colorHex: "#8E8E93", isExpenseCategory: false, budgetType: .savings, sortOrder: 35, isDefault: true)
        ]
    }

    // MARK: - All Default Categories

    static var allDefaultCategories: [SharedCategory] {
        defaultNeedsCategories + defaultWantsCategories + defaultSavingsCategories + defaultIncomeCategories
    }

    static var defaultExpenseCategories: [SharedCategory] {
        defaultNeedsCategories + defaultWantsCategories
    }
}
