//
//  Account.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Account Type Enum

enum AccountType: String, Codable, CaseIterable {
    case cash = "Cash"
    case bank = "Bank"
    case credit = "Credit"
    case savings = "Savings"
    case wallet = "Wallet"

    var icon: String {
        switch self {
        case .cash: return "banknote.fill"
        case .bank: return "building.columns.fill"
        case .credit: return "creditcard.fill"
        case .savings: return "dollarsign.circle.fill"
        case .wallet: return "wallet.pass.fill"
        }
    }

    var defaultColor: String {
        switch self {
        case .cash: return "#34C759"
        case .bank: return "#007AFF"
        case .credit: return "#FF9500"
        case .savings: return "#5856D6"
        case .wallet: return "#FF2D55"
        }
    }
}

// MARK: - Account Model

struct Account: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var initialBalance: Decimal
    var accountType: AccountType
    var icon: String
    var colorHex: String
    var currencyCode: String
    var createdAt: Date

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        initialBalance: Decimal = 0,
        accountType: AccountType = .cash,
        icon: String? = nil,
        colorHex: String? = nil,
        currencyCode: String = "INR",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.initialBalance = initialBalance
        self.accountType = accountType
        self.icon = icon ?? accountType.icon
        self.colorHex = colorHex ?? accountType.defaultColor
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "initialBalance": NSDecimalNumber(decimal: initialBalance).doubleValue,
            "accountType": accountType.rawValue,
            "icon": icon,
            "colorHex": colorHex,
            "currencyCode": currencyCode,
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
        let initialBalanceDouble = data["initialBalance"] as? Double ?? 0
        self.initialBalance = Decimal(initialBalanceDouble)
        let accountTypeRaw = data["accountType"] as? String ?? AccountType.cash.rawValue
        self.accountType = AccountType(rawValue: accountTypeRaw) ?? .cash
        self.icon = data["icon"] as? String ?? self.accountType.icon
        self.colorHex = data["colorHex"] as? String ?? self.accountType.defaultColor
        self.currencyCode = data["currencyCode"] as? String ?? "INR"

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }

    // MARK: - Default Accounts

    static var defaultAccounts: [Account] {
        [
            Account(name: "Cash", accountType: .cash),
            Account(name: "Bank Account", accountType: .bank),
            Account(name: "Credit Card", accountType: .credit),
            Account(name: "Savings", accountType: .savings)
        ]
    }
}
