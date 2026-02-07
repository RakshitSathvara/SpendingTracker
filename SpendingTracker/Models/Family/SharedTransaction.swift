//
//  SharedTransaction.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Shared Transaction Model

struct SharedTransaction: Identifiable, Equatable, Hashable {
    let id: String
    var amount: Decimal
    var note: String
    var date: Date
    var type: TransactionType
    var merchantName: String?
    var addedBy: String
    var addedByName: String
    var receiptImageURL: String?
    var categoryId: String?
    var createdAt: Date

    // MARK: - Computed Properties

    var isExpense: Bool {
        type == .expense
    }

    var isIncome: Bool {
        type == .income
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: amount as NSDecimalNumber) ?? "\u{20B9}\(amount)"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: date)
    }

    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        note: String = "",
        date: Date = Date(),
        type: TransactionType = .expense,
        merchantName: String? = nil,
        addedBy: String,
        addedByName: String,
        receiptImageURL: String? = nil,
        categoryId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.date = date
        self.type = type
        self.merchantName = merchantName
        self.addedBy = addedBy
        self.addedByName = addedByName
        self.receiptImageURL = receiptImageURL
        self.categoryId = categoryId
        self.createdAt = createdAt
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "note": note,
            "date": Timestamp(date: date),
            "type": type.rawValue,
            "addedBy": addedBy,
            "addedByName": addedByName,
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
        if let receiptImageURL = receiptImageURL {
            data["receiptImageURL"] = receiptImageURL
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

        if let dateTimestamp = data["date"] as? Timestamp {
            self.date = dateTimestamp.dateValue()
        } else {
            self.date = Date()
        }

        let typeRaw = data["type"] as? String ?? TransactionType.expense.rawValue
        self.type = TransactionType(rawValue: typeRaw) ?? .expense
        self.merchantName = data["merchantName"] as? String
        self.addedBy = data["addedBy"] as? String ?? ""
        self.addedByName = data["addedByName"] as? String ?? "Unknown"
        self.receiptImageURL = data["receiptImageURL"] as? String
        self.categoryId = data["categoryId"] as? String

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

// MARK: - Grouping Helpers

extension Array where Element == SharedTransaction {
    /// Groups transactions by date
    func groupedByDate() -> [(date: Date, transactions: [SharedTransaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: self) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .map { (date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// Groups transactions by member
    func groupedByMember() -> [(memberId: String, memberName: String, transactions: [SharedTransaction])] {
        let grouped = Dictionary(grouping: self) { $0.addedBy }
        return grouped
            .map { (memberId: $0.key, memberName: $0.value.first?.addedByName ?? "Unknown", transactions: $0.value) }
            .sorted { $0.memberName < $1.memberName }
    }

    /// Groups transactions by category ID
    func groupedByCategoryId() -> [(categoryId: String?, transactions: [SharedTransaction])] {
        let grouped = Dictionary(grouping: self) { $0.categoryId ?? "uncategorized" }
        return grouped
            .map { (categoryId: $0.key == "uncategorized" ? nil : $0.key, transactions: $0.value) }
            .sorted { ($0.categoryId ?? "") < ($1.categoryId ?? "") }
    }

    /// Total amount for expenses
    var totalExpenses: Decimal {
        filter { $0.isExpense }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Total amount for income
    var totalIncome: Decimal {
        filter { $0.isIncome }.reduce(Decimal.zero) { $0 + $1.amount }
    }
}
