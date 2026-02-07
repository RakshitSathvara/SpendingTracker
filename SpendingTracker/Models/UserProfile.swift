//
//  UserProfile.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - User Persona Enum

enum UserPersona: String, Codable, CaseIterable {
    case student = "Student"
    case professional = "Professional"
    case family = "Family"

    var displayName: String { rawValue }

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

// MARK: - App Theme Enum

enum AppTheme: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case tinted = "Tinted"
    case clear = "Clear"

    var displayName: String { rawValue }

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
        case .light: return "Classic light appearance"
        case .dark: return "Easy on the eyes in low light"
        case .tinted: return "Subtle color tint throughout"
        case .clear: return "iOS 26 Liquid Glass transparency"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .tinted, .clear: return nil
        }
    }
}

// MARK: - User Profile Model

struct UserProfile: Identifiable, Equatable, Hashable {
    let id: String
    var email: String
    var displayName: String
    var persona: UserPersona
    var preferredTheme: AppTheme
    var currencyCode: String
    var notificationsEnabled: Bool
    var budgetAlertsEnabled: Bool
    var dailyReminderTime: Date?
    var createdAt: Date

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
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.persona = persona
        self.preferredTheme = preferredTheme
        self.currencyCode = currencyCode
        self.notificationsEnabled = notificationsEnabled
        self.budgetAlertsEnabled = budgetAlertsEnabled
        self.dailyReminderTime = dailyReminderTime
        self.createdAt = createdAt
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "persona": persona.rawValue,
            "preferredTheme": preferredTheme.rawValue,
            "currencyCode": currencyCode,
            "notificationsEnabled": notificationsEnabled,
            "budgetAlertsEnabled": budgetAlertsEnabled,
            "isSynced": true,
            "lastModified": FieldValue.serverTimestamp(),
            "createdAt": Timestamp(date: createdAt)
        ]
        if let reminderTime = dailyReminderTime {
            data["dailyReminderTime"] = Timestamp(date: reminderTime)
        }
        return data
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.email = data["email"] as? String ?? ""
        self.displayName = data["displayName"] as? String ?? ""
        let personaRaw = data["persona"] as? String ?? UserPersona.professional.rawValue
        self.persona = UserPersona(rawValue: personaRaw) ?? .professional
        let themeRaw = data["preferredTheme"] as? String ?? AppTheme.clear.rawValue
        self.preferredTheme = AppTheme(rawValue: themeRaw) ?? .clear
        self.currencyCode = data["currencyCode"] as? String ?? "INR"
        self.notificationsEnabled = data["notificationsEnabled"] as? Bool ?? true
        self.budgetAlertsEnabled = data["budgetAlertsEnabled"] as? Bool ?? true

        if let reminderTimestamp = data["dailyReminderTime"] as? Timestamp {
            self.dailyReminderTime = reminderTimestamp.dateValue()
        } else {
            self.dailyReminderTime = nil
        }

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}
