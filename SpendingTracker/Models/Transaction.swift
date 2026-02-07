//
//  Transaction.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Transaction Type Enum

enum TransactionType: String, Codable, CaseIterable {
    case expense = "Expense"
    case income = "Income"

    var icon: String {
        switch self {
        case .expense: return "arrow.up.circle.fill"
        case .income: return "arrow.down.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .expense: return "red"
        case .income: return "green"
        }
    }
}

// MARK: - Transaction Model

struct Transaction: Identifiable, Equatable, Hashable {
    let id: String
    var amount: Decimal
    var note: String
    var date: Date
    var type: TransactionType
    var merchantName: String?
    var categoryId: String?
    var accountId: String?
    var createdAt: Date

    var isExpense: Bool { type == .expense }
    var isIncome: Bool { type == .income }

    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        note: String = "",
        date: Date = Date(),
        type: TransactionType = .expense,
        merchantName: String? = nil,
        categoryId: String? = nil,
        accountId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.date = date
        self.type = type
        self.merchantName = merchantName
        self.categoryId = categoryId
        self.accountId = accountId
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var displayTitle: String {
        if let merchant = merchantName, !merchant.isEmpty {
            return merchant
        } else {
            return type == .expense ? "Expense" : "Income"
        }
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "note": note,
            "date": Timestamp(date: date),
            "type": type.rawValue,
            "isSynced": true,
            "lastModified": FieldValue.serverTimestamp(),
            "createdAt": Timestamp(date: createdAt)
        ]

        if let merchantName = merchantName {
            data["merchantName"] = merchantName
        }
        if let categoryId = categoryId {
            data["categoryId"] = categoryId
        }
        if let accountId = accountId {
            data["accountId"] = accountId
        }

        return data
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.amount = Decimal((data["amount"] as? Double) ?? 0)
        self.note = data["note"] as? String ?? ""

        if let timestamp = data["date"] as? Timestamp {
            self.date = timestamp.dateValue()
        } else {
            self.date = Date()
        }

        let typeRaw = data["type"] as? String ?? TransactionType.expense.rawValue
        self.type = TransactionType(rawValue: typeRaw) ?? .expense
        self.merchantName = data["merchantName"] as? String
        self.categoryId = data["categoryId"] as? String
        self.accountId = data["accountId"] as? String

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}
