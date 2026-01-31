//
//  Budget.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Budget Period Enum

enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var displayName: String {
        rawValue
    }

    var days: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .yearly: return 365
        }
    }

    var icon: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .yearly: return "calendar.circle.fill"
        }
    }
}

// MARK: - Budget Model

@Model
final class Budget {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var periodRawValue: String
    var startDate: Date
    var alertThreshold: Double // 0.8 = 80%
    var isActive: Bool
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var category: Category?

    var period: BudgetPeriod {
        get { BudgetPeriod(rawValue: periodRawValue) ?? .monthly }
        set { periodRawValue = newValue.rawValue }
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: period.days, to: startDate) ?? startDate
    }

    var isExpired: Bool {
        Date() > endDate
    }

    var daysRemaining: Int {
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, remaining)
    }

    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        period: BudgetPeriod = .monthly,
        startDate: Date = Date(),
        alertThreshold: Double = 0.8,
        isActive: Bool = true,
        category: Category? = nil,
        isSynced: Bool = false,
        lastModified: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.periodRawValue = period.rawValue
        self.startDate = startDate
        self.alertThreshold = alertThreshold
        self.isActive = isActive
        self.category = category
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    // MARK: - Budget Calculations

    func spentAmount(transactions: [Transaction]) -> Decimal {
        transactions
            .filter { transaction in
                transaction.isExpense &&
                transaction.date >= startDate &&
                transaction.date <= endDate &&
                (category == nil || transaction.category?.id == category?.id)
            }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    func remainingAmount(transactions: [Transaction]) -> Decimal {
        amount - spentAmount(transactions: transactions)
    }

    func progress(transactions: [Transaction]) -> Double {
        let spent = spentAmount(transactions: transactions)
        guard amount > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / amount).doubleValue
    }

    func isOverThreshold(transactions: [Transaction]) -> Bool {
        progress(transactions: transactions) >= alertThreshold
    }

    func isOverBudget(transactions: [Transaction]) -> Bool {
        progress(transactions: transactions) >= 1.0
    }

    func progressColor(transactions: [Transaction]) -> Color {
        let progress = progress(transactions: transactions)
        if progress >= 1.0 {
            return .red
        } else if progress >= alertThreshold {
            return .orange
        } else {
            return .green
        }
    }

    // MARK: - Firestore Conversion

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "period": periodRawValue,
            "startDate": startDate,
            "alertThreshold": alertThreshold,
            "isActive": isActive,
            "isSynced": isSynced,
            "lastModified": lastModified,
            "createdAt": createdAt
        ]
        if let categoryId = category?.id {
            data["categoryId"] = categoryId
        }
        return data
    }

    convenience init(from firestoreDoc: [String: Any]) {
        let id = firestoreDoc["id"] as? String ?? UUID().uuidString
        let amountDouble = firestoreDoc["amount"] as? Double ?? 0
        let periodRaw = firestoreDoc["period"] as? String ?? BudgetPeriod.monthly.rawValue
        let startDate = (firestoreDoc["startDate"] as? Date) ?? Date()
        let alertThreshold = firestoreDoc["alertThreshold"] as? Double ?? 0.8
        let isActive = firestoreDoc["isActive"] as? Bool ?? true
        let isSynced = firestoreDoc["isSynced"] as? Bool ?? true
        let lastModified = (firestoreDoc["lastModified"] as? Date) ?? Date()
        let createdAt = (firestoreDoc["createdAt"] as? Date) ?? Date()

        self.init(
            id: id,
            amount: Decimal(amountDouble),
            period: BudgetPeriod(rawValue: periodRaw) ?? .monthly,
            startDate: startDate,
            alertThreshold: alertThreshold,
            isActive: isActive,
            category: nil, // Category needs to be linked separately
            isSynced: isSynced,
            lastModified: lastModified,
            createdAt: createdAt
        )
    }
}
