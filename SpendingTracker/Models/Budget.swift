//
//  Budget.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Budget Period Enum

enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var displayName: String { rawValue }

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

struct Budget: Identifiable, Equatable, Hashable {
    let id: String
    var amount: Decimal
    var period: BudgetPeriod
    var startDate: Date
    var alertThreshold: Double
    var isActive: Bool
    var categoryId: String?
    var createdAt: Date

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: period.days, to: startDate) ?? startDate
    }

    var isExpired: Bool { Date() > endDate }

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
        categoryId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.period = period
        self.startDate = startDate
        self.alertThreshold = alertThreshold
        self.isActive = isActive
        self.categoryId = categoryId
        self.createdAt = createdAt
    }

    // MARK: - Budget Calculations

    func spentAmount(transactions: [Transaction]) -> Decimal {
        transactions
            .filter { transaction in
                transaction.isExpense &&
                transaction.date >= startDate &&
                transaction.date <= endDate &&
                (categoryId == nil || transaction.categoryId == categoryId)
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
            "period": period.rawValue,
            "startDate": Timestamp(date: startDate),
            "alertThreshold": alertThreshold,
            "isActive": isActive,
            "isSynced": true,
            "lastModified": FieldValue.serverTimestamp(),
            "createdAt": Timestamp(date: createdAt)
        ]
        if let categoryId = categoryId {
            data["categoryId"] = categoryId
        }
        return data
    }

    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw RepositoryError.invalidData("Document has no data")
        }

        self.id = data["id"] as? String ?? document.documentID
        self.amount = Decimal((data["amount"] as? Double) ?? 0)
        let periodRaw = data["period"] as? String ?? BudgetPeriod.monthly.rawValue
        self.period = BudgetPeriod(rawValue: periodRaw) ?? .monthly

        if let startTimestamp = data["startDate"] as? Timestamp {
            self.startDate = startTimestamp.dateValue()
        } else {
            self.startDate = Date()
        }

        self.alertThreshold = data["alertThreshold"] as? Double ?? 0.8
        self.isActive = data["isActive"] as? Bool ?? true
        self.categoryId = data["categoryId"] as? String

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}
