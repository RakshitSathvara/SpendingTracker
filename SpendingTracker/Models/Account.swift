//
//  Account.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftData
import SwiftUI

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

@Model
final class Account {
    @Attribute(.unique) var id: String
    var name: String
    var initialBalance: Decimal
    var accountTypeRawValue: String
    var icon: String
    var colorHex: String
    var currencyCode: String
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]?

    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRawValue) ?? .cash }
        set { accountTypeRawValue = newValue.rawValue }
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var currentBalance: Decimal {
        let transactionTotal = transactions?.reduce(Decimal.zero) { result, transaction in
            if transaction.isExpense {
                return result - transaction.amount
            } else {
                return result + transaction.amount
            }
        } ?? Decimal.zero
        return initialBalance + transactionTotal
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        initialBalance: Decimal = 0,
        accountType: AccountType = .cash,
        icon: String? = nil,
        colorHex: String? = nil,
        currencyCode: String = "INR",
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.initialBalance = initialBalance
        self.accountTypeRawValue = accountType.rawValue
        self.icon = icon ?? accountType.icon
        self.colorHex = colorHex ?? accountType.defaultColor
        self.currencyCode = currencyCode
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "initialBalance": NSDecimalNumber(decimal: initialBalance).doubleValue,
            "accountType": accountTypeRawValue,
            "icon": icon,
            "colorHex": colorHex,
            "currencyCode": currencyCode,
            "isSynced": isSynced,
            "lastModified": lastModified,
            "createdAt": createdAt
        ]
    }

    convenience init(from firestoreDoc: [String: Any]) {
        let id = firestoreDoc["id"] as? String ?? UUID().uuidString
        let name = firestoreDoc["name"] as? String ?? "Unknown"
        let initialBalanceDouble = firestoreDoc["initialBalance"] as? Double ?? 0
        let accountTypeRaw = firestoreDoc["accountType"] as? String ?? AccountType.cash.rawValue
        let icon = firestoreDoc["icon"] as? String ?? AccountType.cash.icon
        let colorHex = firestoreDoc["colorHex"] as? String ?? AccountType.cash.defaultColor
        let currencyCode = firestoreDoc["currencyCode"] as? String ?? "INR"
        let isSynced = firestoreDoc["isSynced"] as? Bool ?? true
        let lastModified = (firestoreDoc["lastModified"] as? Date) ?? Date()
        let createdAt = (firestoreDoc["createdAt"] as? Date) ?? Date()

        self.init(
            id: id,
            name: name,
            initialBalance: Decimal(initialBalanceDouble),
            accountType: AccountType(rawValue: accountTypeRaw) ?? .cash,
            icon: icon,
            colorHex: colorHex,
            currencyCode: currencyCode,
            isSynced: isSynced,
            lastModified: lastModified,
            createdAt: createdAt
        )
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
