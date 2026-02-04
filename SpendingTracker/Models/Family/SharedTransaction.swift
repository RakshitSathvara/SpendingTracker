//
//  SharedTransaction.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Shared Transaction Model

/// Represents a transaction shared within a family budget
@Model
final class SharedTransaction {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var note: String
    var date: Date
    var typeRawValue: String
    var merchantName: String?
    var addedBy: String // memberId who added this transaction
    var addedByName: String // Display name of the member (cached for quick display)
    var receiptImageURL: String?
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    @Relationship var category: SharedCategory?
    @Relationship var familyBudget: FamilyBudget?

    // MARK: - Computed Properties

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

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹\(amount)"
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

    var displayTitle: String {
        if let merchant = merchantName, !merchant.isEmpty {
            return merchant
        } else if let categoryName = category?.name {
            return categoryName
        } else {
            return type == .expense ? "Expense" : "Income"
        }
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
        category: SharedCategory? = nil,
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
        self.addedBy = addedBy
        self.addedByName = addedByName
        self.receiptImageURL = receiptImageURL
        self.category = category
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "note": note,
            "date": date,
            "type": typeRawValue,
            "addedBy": addedBy,
            "addedByName": addedByName,
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
        if let receiptImageURL = receiptImageURL {
            data["receiptImageURL"] = receiptImageURL
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
        let addedBy = firestoreDoc["addedBy"] as? String ?? ""
        let addedByName = firestoreDoc["addedByName"] as? String ?? "Unknown"
        let receiptImageURL = firestoreDoc["receiptImageURL"] as? String
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
            addedBy: addedBy,
            addedByName: addedByName,
            receiptImageURL: receiptImageURL,
            category: nil, // Category needs to be linked separately
            isSynced: isSynced,
            lastModified: lastModified,
            createdAt: createdAt
        )
    }
}

// MARK: - Predicates

extension SharedTransaction {
    private static let expenseTypeRaw = "Expense"
    private static let incomeTypeRaw = "Income"

    /// Predicate for expense transactions
    static func expensesPredicate() -> Predicate<SharedTransaction> {
        let expenseRaw = expenseTypeRaw
        return #Predicate<SharedTransaction> { transaction in
            transaction.typeRawValue == expenseRaw
        }
    }

    /// Predicate for income transactions
    static func incomePredicate() -> Predicate<SharedTransaction> {
        let incomeRaw = incomeTypeRaw
        return #Predicate<SharedTransaction> { transaction in
            transaction.typeRawValue == incomeRaw
        }
    }

    /// Predicate for filtering by date range
    static func dateRangePredicate(startDate: Date, endDate: Date) -> Predicate<SharedTransaction> {
        #Predicate<SharedTransaction> { transaction in
            transaction.date >= startDate && transaction.date <= endDate
        }
    }

    /// Predicate for transactions added by a specific member
    static func addedByPredicate(memberId: String) -> Predicate<SharedTransaction> {
        #Predicate<SharedTransaction> { transaction in
            transaction.addedBy == memberId
        }
    }

    /// Predicate for this month's transactions
    static func thisMonthPredicate() -> Predicate<SharedTransaction> {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        return #Predicate<SharedTransaction> { transaction in
            transaction.date >= startOfMonth && transaction.date <= endOfMonth
        }
    }

    /// Predicate for unsynced transactions
    static func unsyncedPredicate() -> Predicate<SharedTransaction> {
        #Predicate<SharedTransaction> { transaction in
            transaction.isSynced == false
        }
    }

    /// Simple predicate for searching by note text
    static func searchPredicate(searchText: String) -> Predicate<SharedTransaction> {
        #Predicate<SharedTransaction> { transaction in
            transaction.note.localizedStandardContains(searchText)
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

    /// Groups transactions by category
    func groupedByCategory() -> [(category: SharedCategory?, transactions: [SharedTransaction])] {
        let grouped = Dictionary(grouping: self) { $0.category?.id ?? "uncategorized" }
        return grouped
            .map { (category: self.first { $0.category?.id == $0.category?.id }?.category, transactions: $0.value) }
            .sorted { ($0.category?.sortOrder ?? 999) < ($1.category?.sortOrder ?? 999) }
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
