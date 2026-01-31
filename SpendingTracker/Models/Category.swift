//
//  Category.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    var name: String
    var icon: String
    var colorHex: String
    var isDefault: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

    init(
        name: String,
        icon: String = "tag.fill",
        colorHex: String = "#007AFF",
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    static var defaultCategories: [Category] {
        [
            Category(name: "Food & Dining", icon: "fork.knife", colorHex: "#FF9500", isDefault: true),
            Category(name: "Transportation", icon: "car.fill", colorHex: "#007AFF", isDefault: true),
            Category(name: "Shopping", icon: "bag.fill", colorHex: "#FF2D55", isDefault: true),
            Category(name: "Entertainment", icon: "tv.fill", colorHex: "#AF52DE", isDefault: true),
            Category(name: "Bills & Utilities", icon: "bolt.fill", colorHex: "#FFCC00", isDefault: true),
            Category(name: "Health", icon: "heart.fill", colorHex: "#FF3B30", isDefault: true),
            Category(name: "Travel", icon: "airplane", colorHex: "#5AC8FA", isDefault: true),
            Category(name: "Other", icon: "ellipsis.circle.fill", colorHex: "#8E8E93", isDefault: true)
        ]
    }
}

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
}
