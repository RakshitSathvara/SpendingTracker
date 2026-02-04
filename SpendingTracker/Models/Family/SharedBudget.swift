//
//  SharedBudget.swift
//  SpendingTracker
//
//  Created by Rakshit on 04/02/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Shared Budget Model

/// Represents a budget shared within a family budget group
@Model
final class SharedBudget {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var periodRawValue: String
    var startDate: Date
    var alertThreshold: Double // 0.8 = 80%
    var isActive: Bool
    var createdBy: String // memberId who created this budget
    var isSynced: Bool
    var lastModified: Date
    var createdAt: Date

    @Relationship var category: SharedCategory?
    @Relationship var familyBudget: FamilyBudget?

    // MARK: - Computed Properties

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

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: amount as NSDecimalNumber) ?? "₹\(amount)"
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
        category: SharedCategory? = nil,
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
        self.createdBy = createdBy
        self.category = category
        self.isSynced = isSynced
        self.lastModified = lastModified
        self.createdAt = createdAt
    }

    // MARK: - Budget Calculations

    func spentAmount(transactions: [SharedTransaction]) -> Decimal {
        transactions
            .filter { transaction in
                transaction.isExpense &&
                transaction.date >= startDate &&
                transaction.date <= endDate &&
                (category == nil || transaction.category?.id == category?.id)
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
            "period": periodRawValue,
            "startDate": startDate,
            "alertThreshold": alertThreshold,
            "isActive": isActive,
            "createdBy": createdBy,
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
        let createdBy = firestoreDoc["createdBy"] as? String ?? ""
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
            createdBy: createdBy,
            category: nil, // Category needs to be linked separately
            isSynced: isSynced,
            lastModified: lastModified,
            createdAt: createdAt
        )
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

// MARK: - Predicates

extension SharedBudget {
    /// Predicate for active budgets
    static func activeBudgetsPredicate() -> Predicate<SharedBudget> {
        #Predicate<SharedBudget> { budget in
            budget.isActive == true
        }
    }

    /// Predicate for unsynced budgets
    static func unsyncedPredicate() -> Predicate<SharedBudget> {
        #Predicate<SharedBudget> { budget in
            budget.isSynced == false
        }
    }
}
