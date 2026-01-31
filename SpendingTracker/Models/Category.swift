//
//  Category.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Category Model

@Model
final class Category {
    @Attribute(.unique) var id: String
    var name: String
    var icon: String // SF Symbol name
    var colorHex: String
    var isExpenseCategory: Bool
    var sortOrder: Int
    var isDefault: Bool
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget]?

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        icon: String = "tag.fill",
        colorHex: String = "#007AFF",
        isExpenseCategory: Bool = true,
        sortOrder: Int = 0,
        isDefault: Bool = false,
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isExpenseCategory = isExpenseCategory
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.isSynced = isSynced
        self.lastModified = lastModified
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
            "sortOrder": sortOrder,
            "isDefault": isDefault,
            "isSynced": isSynced,
            "lastModified": lastModified,
            "createdAt": createdAt
        ]
    }

    convenience init(from firestoreDoc: [String: Any]) {
        let id = firestoreDoc["id"] as? String ?? UUID().uuidString
        let name = firestoreDoc["name"] as? String ?? "Unknown"
        let icon = firestoreDoc["icon"] as? String ?? "tag.fill"
        let colorHex = firestoreDoc["colorHex"] as? String ?? "#007AFF"
        let isExpenseCategory = firestoreDoc["isExpenseCategory"] as? Bool ?? true
        let sortOrder = firestoreDoc["sortOrder"] as? Int ?? 0
        let isDefault = firestoreDoc["isDefault"] as? Bool ?? false
        let isSynced = firestoreDoc["isSynced"] as? Bool ?? true
        let lastModified = (firestoreDoc["lastModified"] as? Date) ?? Date()
        let createdAt = (firestoreDoc["createdAt"] as? Date) ?? Date()

        self.init(
            id: id,
            name: name,
            icon: icon,
            colorHex: colorHex,
            isExpenseCategory: isExpenseCategory,
            sortOrder: sortOrder,
            isDefault: isDefault,
            isSynced: isSynced,
            lastModified: lastModified,
            createdAt: createdAt
        )
    }

    // MARK: - Default Categories

    static var defaultExpenseCategories: [Category] {
        [
            Category(name: "Food & Dining", icon: "fork.knife", colorHex: "#FF9500", isExpenseCategory: true, sortOrder: 0, isDefault: true),
            Category(name: "Transportation", icon: "car.fill", colorHex: "#007AFF", isExpenseCategory: true, sortOrder: 1, isDefault: true),
            Category(name: "Shopping", icon: "bag.fill", colorHex: "#FF2D55", isExpenseCategory: true, sortOrder: 2, isDefault: true),
            Category(name: "Entertainment", icon: "tv.fill", colorHex: "#AF52DE", isExpenseCategory: true, sortOrder: 3, isDefault: true),
            Category(name: "Bills & Utilities", icon: "bolt.fill", colorHex: "#FFCC00", isExpenseCategory: true, sortOrder: 4, isDefault: true),
            Category(name: "Health", icon: "heart.fill", colorHex: "#FF3B30", isExpenseCategory: true, sortOrder: 5, isDefault: true),
            Category(name: "Travel", icon: "airplane", colorHex: "#5AC8FA", isExpenseCategory: true, sortOrder: 6, isDefault: true),
            Category(name: "Other", icon: "ellipsis.circle.fill", colorHex: "#8E8E93", isExpenseCategory: true, sortOrder: 7, isDefault: true)
        ]
    }

    static var defaultIncomeCategories: [Category] {
        [
            Category(name: "Salary", icon: "briefcase.fill", colorHex: "#34C759", isExpenseCategory: false, sortOrder: 0, isDefault: true),
            Category(name: "Freelance", icon: "laptopcomputer", colorHex: "#007AFF", isExpenseCategory: false, sortOrder: 1, isDefault: true),
            Category(name: "Investments", icon: "chart.line.uptrend.xyaxis", colorHex: "#5856D6", isExpenseCategory: false, sortOrder: 2, isDefault: true),
            Category(name: "Gifts", icon: "gift.fill", colorHex: "#FF2D55", isExpenseCategory: false, sortOrder: 3, isDefault: true),
            Category(name: "Other Income", icon: "ellipsis.circle.fill", colorHex: "#8E8E93", isExpenseCategory: false, sortOrder: 4, isDefault: true)
        ]
    }

    static var allDefaultCategories: [Category] {
        defaultExpenseCategories + defaultIncomeCategories
    }

    /// Creates default categories based on user persona
    static func defaultCategories(for persona: UserPersona) -> [Category] {
        var categories: [Category] = []

        for (index, categoryInfo) in persona.defaultCategories.enumerated() {
            let category = Category(
                name: categoryInfo.name,
                icon: categoryInfo.icon,
                colorHex: categoryInfo.colorHex,
                isExpenseCategory: true,
                sortOrder: index,
                isDefault: true
            )
            categories.append(category)
        }

        // Add default income categories
        categories.append(contentsOf: defaultIncomeCategories)

        return categories
    }
}

// MARK: - Category Predicates

extension Category {
    static func expenseCategoriesPredicate() -> Predicate<Category> {
        #Predicate<Category> { category in
            category.isExpenseCategory == true
        }
    }

    static func incomeCategoriesPredicate() -> Predicate<Category> {
        #Predicate<Category> { category in
            category.isExpenseCategory == false
        }
    }

    static func unsyncedPredicate() -> Predicate<Category> {
        #Predicate<Category> { category in
            category.isSynced == false
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
