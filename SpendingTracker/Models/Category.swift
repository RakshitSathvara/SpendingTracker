//
//  Category.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Category Model

struct Category: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var icon: String
    var colorHex: String
    var isExpenseCategory: Bool
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
        sortOrder: Int = 0,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isExpenseCategory = isExpenseCategory
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
        self.sortOrder = data["sortOrder"] as? Int ?? 0
        self.isDefault = data["isDefault"] as? Bool ?? false

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
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

        categories.append(contentsOf: defaultIncomeCategories)

        return categories
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
