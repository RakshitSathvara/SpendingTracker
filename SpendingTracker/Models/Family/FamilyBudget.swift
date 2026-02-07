//
//  FamilyBudget.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Family Budget Model

struct FamilyBudget: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var iconName: String
    var monthlyIncome: Decimal
    var createdBy: String
    var inviteCode: String
    var coverImageURL: String?
    var createdAt: Date

    var formattedMonthlyIncome: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: monthlyIncome as NSDecimalNumber) ?? "\u{20B9}\(monthlyIncome)"
    }

    var icon: Image {
        Image(systemName: iconName)
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        iconName: String = "house.fill",
        monthlyIncome: Decimal = 0,
        createdBy: String,
        inviteCode: String? = nil,
        coverImageURL: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.monthlyIncome = monthlyIncome
        self.createdBy = createdBy
        self.inviteCode = inviteCode ?? FamilyBudget.generateInviteCode()
        self.coverImageURL = coverImageURL
        self.createdAt = createdAt
    }

    static func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
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
            "isSynced": true,
            "lastModified": FieldValue.serverTimestamp(),
            "createdAt": Timestamp(date: createdAt)
        ]
        if let coverImageURL = coverImageURL {
            data["coverImageURL"] = coverImageURL
        }
        return data
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.name = data["name"] as? String ?? "Family Budget"
        self.iconName = data["iconName"] as? String ?? "house.fill"
        self.monthlyIncome = Decimal((data["monthlyIncome"] as? Double) ?? 0)
        self.createdBy = data["createdBy"] as? String ?? ""
        self.inviteCode = data["inviteCode"] as? String ?? FamilyBudget.generateInviteCode()
        self.coverImageURL = data["coverImageURL"] as? String

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

// MARK: - Family Icon Options

extension FamilyBudget {
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
