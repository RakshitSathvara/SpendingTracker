//
//  Transaction.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case expense = "Expense"
    case income = "Income"
}

@Model
final class Transaction {
    var amount: Decimal
    var title: String
    var notes: String?
    var date: Date
    var typeRawValue: String
    var createdAt: Date
    var updatedAt: Date

    var category: Category?
    var paymentMethod: PaymentMethod?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        amount: Decimal,
        title: String,
        notes: String? = nil,
        date: Date = Date(),
        type: TransactionType = .expense,
        category: Category? = nil,
        paymentMethod: PaymentMethod? = nil
    ) {
        self.amount = amount
        self.title = title
        self.notes = notes
        self.date = date
        self.typeRawValue = type.rawValue
        self.category = category
        self.paymentMethod = paymentMethod
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    var isExpense: Bool {
        type == .expense
    }

    var isIncome: Bool {
        type == .income
    }
}
