//
//  Transaction.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftData

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

@Model
final class Transaction {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var note: String
    var date: Date
    var typeRawValue: String
    var merchantName: String?
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var category: Category?

    @Relationship(deleteRule: .nullify)
    var account: Account?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var isExpense: Bool {
        type == .expense
    }

    var isIncome: Bool {
        type == .income
    }

    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        note: String = "",
        date: Date = Date(),
        type: TransactionType = .expense,
        merchantName: String? = nil,
        category: Category? = nil,
        account: Account? = nil,
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.date = date
        self.typeRawValue = type.rawValue
        self.merchantName = merchantName
        self.category = category
        self.account = account
        self.isSynced = isSynced
        self.lastModified = lastModified
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
        } else if let categoryName = category?.name {
            return categoryName
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
            "date": date,
            "type": typeRawValue,
            "isSynced": isSynced,
            "lastModified": lastModified,
            "createdAt": createdAt
        ]

        if let merchantName = merchantName {
            data["merchantName"] = merchantName
        }
        if let categoryId = category?.id {
            data["categoryId"] = categoryId
        }
        if let accountId = account?.id {
            data["accountId"] = accountId
        }

        return data
    }

    convenience init(from firestoreDoc: [String: Any]) {
        let id = firestoreDoc["id"] as? String ?? UUID().uuidString
        let amountDouble = firestoreDoc["amount"] as? Double ?? 0
        let note = firestoreDoc["note"] as? String ?? ""
        let date = (firestoreDoc["date"] as? Date) ?? Date()
        let typeRaw = firestoreDoc["type"] as? String ?? TransactionType.expense.rawValue
        let merchantName = firestoreDoc["merchantName"] as? String
        let isSynced = firestoreDoc["isSynced"] as? Bool ?? true
        let lastModified = (firestoreDoc["lastModified"] as? Date) ?? Date()
        let createdAt = (firestoreDoc["createdAt"] as? Date) ?? Date()

        self.init(
            id: id,
            amount: Decimal(amountDouble),
            note: note,
            date: date,
            type: TransactionType(rawValue: typeRaw) ?? .expense,
            merchantName: merchantName,
            category: nil, // Category needs to be linked separately
            account: nil,  // Account needs to be linked separately
            isSynced: isSynced,
            lastModified: lastModified,
            createdAt: createdAt
        )
    }
}

// MARK: - Transaction Predicates

extension Transaction {
    static func predicate(
        searchText: String = "",
        type: TransactionType? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            (searchText.isEmpty || transaction.note.localizedStandardContains(searchText) ||
             (transaction.merchantName?.localizedStandardContains(searchText) ?? false)) &&
            (type == nil || transaction.typeRawValue == type?.rawValue) &&
            (startDate == nil || transaction.date >= startDate!) &&
            (endDate == nil || transaction.date <= endDate!)
        }
    }

    static func expensesPredicate() -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.typeRawValue == TransactionType.expense.rawValue
        }
    }

    static func incomePredicate() -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.typeRawValue == TransactionType.income.rawValue
        }
    }

    static func thisMonthPredicate() -> Predicate<Transaction> {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        return #Predicate<Transaction> { transaction in
            transaction.date >= startOfMonth && transaction.date <= endOfMonth
        }
    }

    static func unsyncedPredicate() -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.isSynced == false
        }
    }
}
