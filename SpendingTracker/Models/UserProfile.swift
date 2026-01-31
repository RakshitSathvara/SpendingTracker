//
//  UserProfile.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - User Persona Enum

enum UserPersona: String, Codable, CaseIterable {
    case student = "Student"
    case professional = "Professional"
    case family = "Family"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .student: return "graduationcap.fill"
        case .professional: return "briefcase.fill"
        case .family: return "house.fill"
        }
    }

    var description: String {
        switch self {
        case .student:
            return "Budget-conscious with focus on education and entertainment"
        case .professional:
            return "Work-related expenses, investments, and lifestyle"
        case .family:
            return "Household management, groceries, and family activities"
        }
    }

    /// Default categories for each persona
    var defaultCategories: [(name: String, icon: String, colorHex: String)] {
        switch self {
        case .student:
            return [
                ("Food & Dining", "fork.knife", "#FF9500"),
                ("Transportation", "bus.fill", "#007AFF"),
                ("Education", "book.fill", "#5856D6"),
                ("Entertainment", "gamecontroller.fill", "#FF2D55"),
                ("Shopping", "bag.fill", "#AF52DE"),
                ("Subscriptions", "play.rectangle.fill", "#FF3B30"),
                ("Health", "heart.fill", "#34C759"),
                ("Other", "ellipsis.circle.fill", "#8E8E93")
            ]
        case .professional:
            return [
                ("Food & Dining", "fork.knife", "#FF9500"),
                ("Transportation", "car.fill", "#007AFF"),
                ("Work Expenses", "briefcase.fill", "#5856D6"),
                ("Entertainment", "tv.fill", "#FF2D55"),
                ("Shopping", "bag.fill", "#AF52DE"),
                ("Bills & Utilities", "bolt.fill", "#FFCC00"),
                ("Investments", "chart.line.uptrend.xyaxis", "#34C759"),
                ("Health & Fitness", "figure.run", "#FF3B30"),
                ("Travel", "airplane", "#5AC8FA"),
                ("Other", "ellipsis.circle.fill", "#8E8E93")
            ]
        case .family:
            return [
                ("Groceries", "cart.fill", "#34C759"),
                ("Food & Dining", "fork.knife", "#FF9500"),
                ("Transportation", "car.fill", "#007AFF"),
                ("Kids & Education", "figure.and.child.holdinghands", "#5856D6"),
                ("Entertainment", "tv.fill", "#FF2D55"),
                ("Shopping", "bag.fill", "#AF52DE"),
                ("Bills & Utilities", "bolt.fill", "#FFCC00"),
                ("Health & Medical", "cross.fill", "#FF3B30"),
                ("Home & Garden", "house.fill", "#00C7BE"),
                ("Other", "ellipsis.circle.fill", "#8E8E93")
            ]
        }
    }
}

// MARK: - App Theme Enum (iOS 26 Liquid Glass)

enum AppTheme: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case tinted = "Tinted"
    case clear = "Clear" // iOS 26 Liquid Glass

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .tinted: return "paintpalette.fill"
        case .clear: return "drop.fill"
        }
    }

    var description: String {
        switch self {
        case .light:
            return "Classic light appearance"
        case .dark:
            return "Easy on the eyes in low light"
        case .tinted:
            return "Subtle color tint throughout"
        case .clear:
            return "iOS 26 Liquid Glass transparency"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .tinted, .clear: return nil // System default
        }
    }
}

// MARK: - User Profile Model

@Model
final class UserProfile {
    @Attribute(.unique) var id: String
    var email: String
    var displayName: String
    var personaRawValue: String
    var preferredThemeRawValue: String
    var currencyCode: String
    var notificationsEnabled: Bool
    var budgetAlertsEnabled: Bool
    var dailyReminderTime: Date?
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    var persona: UserPersona {
        get { UserPersona(rawValue: personaRawValue) ?? .professional }
        set { personaRawValue = newValue.rawValue }
    }

    var preferredTheme: AppTheme {
        get { AppTheme(rawValue: preferredThemeRawValue) ?? .clear }
        set { preferredThemeRawValue = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String,
        persona: UserPersona = .professional,
        preferredTheme: AppTheme = .clear,
        currencyCode: String = "INR",
        notificationsEnabled: Bool = true,
        budgetAlertsEnabled: Bool = true,
        dailyReminderTime: Date? = nil,
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.personaRawValue = persona.rawValue
        self.preferredThemeRawValue = preferredTheme.rawValue
        self.currencyCode = currencyCode
        self.notificationsEnabled = notificationsEnabled
        self.budgetAlertsEnabled = budgetAlertsEnabled
        self.dailyReminderTime = dailyReminderTime
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "persona": personaRawValue,
            "preferredTheme": preferredThemeRawValue,
            "currencyCode": currencyCode,
            "notificationsEnabled": notificationsEnabled,
            "budgetAlertsEnabled": budgetAlertsEnabled,
            "isSynced": isSynced,
            "lastModified": lastModified,
            "createdAt": createdAt
        ]
        if let reminderTime = dailyReminderTime {
            data["dailyReminderTime"] = reminderTime
        }
        return data
    }

    convenience init(from firestoreDoc: [String: Any]) {
        let id = firestoreDoc["id"] as? String ?? UUID().uuidString
        let email = firestoreDoc["email"] as? String ?? ""
        let displayName = firestoreDoc["displayName"] as? String ?? ""
        let personaRaw = firestoreDoc["persona"] as? String ?? UserPersona.professional.rawValue
        let themeRaw = firestoreDoc["preferredTheme"] as? String ?? AppTheme.clear.rawValue
        let currencyCode = firestoreDoc["currencyCode"] as? String ?? "INR"
        let notificationsEnabled = firestoreDoc["notificationsEnabled"] as? Bool ?? true
        let budgetAlertsEnabled = firestoreDoc["budgetAlertsEnabled"] as? Bool ?? true
        let dailyReminderTime = firestoreDoc["dailyReminderTime"] as? Date
        let isSynced = firestoreDoc["isSynced"] as? Bool ?? true
        let lastModified = (firestoreDoc["lastModified"] as? Date) ?? Date()
        let createdAt = (firestoreDoc["createdAt"] as? Date) ?? Date()

        self.init(
            id: id,
            email: email,
            displayName: displayName,
            persona: UserPersona(rawValue: personaRaw) ?? .professional,
            preferredTheme: AppTheme(rawValue: themeRaw) ?? .clear,
            currencyCode: currencyCode,
            notificationsEnabled: notificationsEnabled,
            budgetAlertsEnabled: budgetAlertsEnabled,
            dailyReminderTime: dailyReminderTime,
            isSynced: isSynced,
            lastModified: lastModified,
            createdAt: createdAt
        )
    }
}
