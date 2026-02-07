//
//  SharedBudget.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Shared Budget Model

struct SharedBudget: Identifiable, Equatable, Hashable {
    let id: String
    var amount: Decimal
    var period: BudgetPeriod
    var startDate: Date
    var alertThreshold: Double
    var isActive: Bool
    var createdBy: String
    var categoryId: String?
    var createdAt: Date

    // MARK: - Computed Properties

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

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: amount as NSDecimalNumber) ?? "\u{20B9}\(amount)"
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        period: BudgetPeriod = .monthly,
        startDate: Date = Date(),
        alertThreshold: Double = 0.8,
        isActive: Bool = true,
        createdBy: String,
        categoryId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.period = period
        self.startDate = startDate
        self.alertThreshold = alertThreshold
        self.isActive = isActive
        self.createdBy = createdBy
        self.categoryId = categoryId
        self.createdAt = createdAt
    }

    // MARK: - Budget Calculations

    func spentAmount(transactions: [SharedTransaction]) -> Decimal {
        transactions
            .filter { transaction in
                transaction.isExpense &&
                transaction.date >= startDate &&
                transaction.date <= endDate &&
                (categoryId == nil || transaction.categoryId == categoryId)
            }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    func remainingAmount(transactions: [SharedTransaction]) -> Decimal {
        amount - spentAmount(transactions: transactions)
    }

    func progress(transactions: [SharedTransaction]) -> Double {
        let spent = spentAmount(transactions: transactions)
        guard amount > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / amount).doubleValue
    }

    func isOverThreshold(transactions: [SharedTransaction]) -> Bool {
        progress(transactions: transactions) >= alertThreshold
    }

    func isOverBudget(transactions: [SharedTransaction]) -> Bool {
        progress(transactions: transactions) >= 1.0
    }

    func progressColor(transactions: [SharedTransaction]) -> Color {
        let progress = progress(transactions: transactions)
        if progress >= 1.0 {
            return .red
        } else if progress >= alertThreshold {
            return .orange
        } else {
            return .green
        }
    }

    func dailyAllowance(transactions: [SharedTransaction]) -> Decimal {
        let remaining = remainingAmount(transactions: transactions)
        let days = max(1, daysRemaining)
        return remaining / Decimal(days)
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
            "createdBy": createdBy,
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
        self.createdBy = data["createdBy"] as? String ?? ""
        self.categoryId = data["categoryId"] as? String

        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

// MARK: - Budget Template

/// Pre-defined budget templates based on 50/30/20 rule
struct BudgetTemplate {
    let name: String
    let description: String
    let allocation: BudgetAllocation

    struct BudgetAllocation {
        let needsPercentage: Int
        let wantsPercentage: Int
        let savingsPercentage: Int
    }

    static let standard5030_20 = BudgetTemplate(
        name: "Standard 50/30/20",
        description: "Classic budgeting rule: 50% Needs, 30% Wants, 20% Savings",
        allocation: BudgetAllocation(needsPercentage: 50, wantsPercentage: 30, savingsPercentage: 20)
    )

    static let indian60_20_20 = BudgetTemplate(
        name: "Indian Family (60/20/20)",
        description: "Adapted for Indian families: 60% Needs, 20% Wants, 20% Savings",
        allocation: BudgetAllocation(needsPercentage: 60, wantsPercentage: 20, savingsPercentage: 20)
    )

    static let aggressive70_10_20 = BudgetTemplate(
        name: "Aggressive Savings (70/10/20)",
        description: "For high-expense periods: 70% Needs, 10% Wants, 20% Savings",
        allocation: BudgetAllocation(needsPercentage: 70, wantsPercentage: 10, savingsPercentage: 20)
    )

    static let allTemplates: [BudgetTemplate] = [standard5030_20, indian60_20_20, aggressive70_10_20]
}
