//
//  ModelConversionTests.swift
//  SpendingTrackerTests
//
//  Created by Rakshit on 31/01/26.
//

import XCTest
import SwiftData
@testable import SpendingTracker

final class ModelConversionTests: XCTestCase {

    // MARK: - Transaction Tests

    func testTransactionFirestoreConversion() {
        // Given
        let transaction = Transaction(
            id: "test-transaction-123",
            amount: 150.50,
            note: "Test purchase",
            date: Date(),
            type: .expense,
            merchantName: "Test Store"
        )

        // When
        let firestoreData = transaction.firestoreData

        // Then
        XCTAssertEqual(firestoreData["id"] as? String, "test-transaction-123")
        XCTAssertEqual(firestoreData["amount"] as? Double, 150.50, accuracy: 0.01)
        XCTAssertEqual(firestoreData["note"] as? String, "Test purchase")
        XCTAssertEqual(firestoreData["type"] as? String, "Expense")
        XCTAssertEqual(firestoreData["merchantName"] as? String, "Test Store")
        XCTAssertNotNil(firestoreData["date"])
        XCTAssertNotNil(firestoreData["createdAt"])
        XCTAssertNotNil(firestoreData["lastModified"])
    }

    func testTransactionFromFirestore() {
        // Given
        let firestoreDoc: [String: Any] = [
            "id": "firestore-trans-456",
            "amount": 275.00,
            "note": "Firestore test",
            "type": "Income",
            "merchantName": "Client Payment",
            "date": Date(),
            "isSynced": true,
            "createdAt": Date(),
            "lastModified": Date()
        ]

        // When
        let transaction = Transaction(from: firestoreDoc)

        // Then
        XCTAssertEqual(transaction.id, "firestore-trans-456")
        XCTAssertEqual(transaction.amount, 275.00)
        XCTAssertEqual(transaction.note, "Firestore test")
        XCTAssertEqual(transaction.type, .income)
        XCTAssertEqual(transaction.merchantName, "Client Payment")
        XCTAssertTrue(transaction.isSynced)
    }

    func testTransactionTypeProperties() {
        // Test expense
        let expense = Transaction(amount: 100, type: .expense)
        XCTAssertTrue(expense.isExpense)
        XCTAssertFalse(expense.isIncome)

        // Test income
        let income = Transaction(amount: 100, type: .income)
        XCTAssertTrue(income.isIncome)
        XCTAssertFalse(income.isExpense)
    }

    // MARK: - Category Tests

    func testCategoryFirestoreConversion() {
        // Given
        let category = Category(
            id: "test-category-123",
            name: "Test Category",
            icon: "star.fill",
            colorHex: "#FF5733",
            isExpenseCategory: true,
            sortOrder: 5,
            isDefault: false
        )

        // When
        let firestoreData = category.firestoreData

        // Then
        XCTAssertEqual(firestoreData["id"] as? String, "test-category-123")
        XCTAssertEqual(firestoreData["name"] as? String, "Test Category")
        XCTAssertEqual(firestoreData["icon"] as? String, "star.fill")
        XCTAssertEqual(firestoreData["colorHex"] as? String, "#FF5733")
        XCTAssertEqual(firestoreData["isExpenseCategory"] as? Bool, true)
        XCTAssertEqual(firestoreData["sortOrder"] as? Int, 5)
        XCTAssertEqual(firestoreData["isDefault"] as? Bool, false)
    }

    func testCategoryFromFirestore() {
        // Given
        let firestoreDoc: [String: Any] = [
            "id": "firestore-cat-789",
            "name": "Groceries",
            "icon": "cart.fill",
            "colorHex": "#34C759",
            "isExpenseCategory": true,
            "sortOrder": 0,
            "isDefault": true,
            "isSynced": true,
            "createdAt": Date(),
            "lastModified": Date()
        ]

        // When
        let category = Category(from: firestoreDoc)

        // Then
        XCTAssertEqual(category.id, "firestore-cat-789")
        XCTAssertEqual(category.name, "Groceries")
        XCTAssertEqual(category.icon, "cart.fill")
        XCTAssertEqual(category.colorHex, "#34C759")
        XCTAssertTrue(category.isExpenseCategory)
        XCTAssertEqual(category.sortOrder, 0)
        XCTAssertTrue(category.isDefault)
    }

    func testDefaultCategories() {
        // Test expense categories
        let expenseCategories = Category.defaultExpenseCategories
        XCTAssertFalse(expenseCategories.isEmpty)
        XCTAssertTrue(expenseCategories.allSatisfy { $0.isExpenseCategory })
        XCTAssertTrue(expenseCategories.allSatisfy { $0.isDefault })

        // Test income categories
        let incomeCategories = Category.defaultIncomeCategories
        XCTAssertFalse(incomeCategories.isEmpty)
        XCTAssertTrue(incomeCategories.allSatisfy { !$0.isExpenseCategory })
        XCTAssertTrue(incomeCategories.allSatisfy { $0.isDefault })
    }

    // MARK: - Account Tests

    func testAccountFirestoreConversion() {
        // Given
        let account = Account(
            id: "test-account-123",
            name: "Main Bank",
            initialBalance: 5000.00,
            accountType: .bank,
            currencyCode: "INR"
        )

        // When
        let firestoreData = account.firestoreData

        // Then
        XCTAssertEqual(firestoreData["id"] as? String, "test-account-123")
        XCTAssertEqual(firestoreData["name"] as? String, "Main Bank")
        XCTAssertEqual(firestoreData["initialBalance"] as? Double, 5000.00, accuracy: 0.01)
        XCTAssertEqual(firestoreData["accountType"] as? String, "Bank")
        XCTAssertEqual(firestoreData["currencyCode"] as? String, "INR")
    }

    func testAccountFromFirestore() {
        // Given
        let firestoreDoc: [String: Any] = [
            "id": "firestore-acc-456",
            "name": "Credit Card",
            "initialBalance": -1000.00,
            "accountType": "Credit",
            "icon": "creditcard.fill",
            "colorHex": "#FF9500",
            "currencyCode": "INR",
            "isSynced": true,
            "createdAt": Date(),
            "lastModified": Date()
        ]

        // When
        let account = Account(from: firestoreDoc)

        // Then
        XCTAssertEqual(account.id, "firestore-acc-456")
        XCTAssertEqual(account.name, "Credit Card")
        XCTAssertEqual(account.initialBalance, -1000.00)
        XCTAssertEqual(account.accountType, .credit)
        XCTAssertEqual(account.currencyCode, "INR")
    }

    func testAccountTypeEnum() {
        // Test all account types
        XCTAssertEqual(AccountType.allCases.count, 5)
        XCTAssertTrue(AccountType.allCases.contains(.cash))
        XCTAssertTrue(AccountType.allCases.contains(.bank))
        XCTAssertTrue(AccountType.allCases.contains(.credit))
        XCTAssertTrue(AccountType.allCases.contains(.savings))
        XCTAssertTrue(AccountType.allCases.contains(.wallet))

        // Test icons
        XCTAssertFalse(AccountType.cash.icon.isEmpty)
        XCTAssertFalse(AccountType.bank.icon.isEmpty)
    }

    func testDefaultAccounts() {
        let defaultAccounts = Account.defaultAccounts
        XCTAssertFalse(defaultAccounts.isEmpty)
        XCTAssertEqual(defaultAccounts.count, 4)
    }

    // MARK: - Budget Tests

    func testBudgetFirestoreConversion() {
        // Given
        let budget = Budget(
            id: "test-budget-123",
            amount: 10000.00,
            period: .monthly,
            startDate: Date(),
            alertThreshold: 0.75
        )

        // When
        let firestoreData = budget.firestoreData

        // Then
        XCTAssertEqual(firestoreData["id"] as? String, "test-budget-123")
        XCTAssertEqual(firestoreData["amount"] as? Double, 10000.00, accuracy: 0.01)
        XCTAssertEqual(firestoreData["period"] as? String, "Monthly")
        XCTAssertEqual(firestoreData["alertThreshold"] as? Double, 0.75, accuracy: 0.01)
    }

    func testBudgetFromFirestore() {
        // Given
        let firestoreDoc: [String: Any] = [
            "id": "firestore-budget-789",
            "amount": 5000.00,
            "period": "Weekly",
            "startDate": Date(),
            "alertThreshold": 0.80,
            "isActive": true,
            "isSynced": true,
            "createdAt": Date(),
            "lastModified": Date()
        ]

        // When
        let budget = Budget(from: firestoreDoc)

        // Then
        XCTAssertEqual(budget.id, "firestore-budget-789")
        XCTAssertEqual(budget.amount, 5000.00)
        XCTAssertEqual(budget.period, .weekly)
        XCTAssertEqual(budget.alertThreshold, 0.80, accuracy: 0.01)
        XCTAssertTrue(budget.isActive)
    }

    func testBudgetPeriodEnum() {
        XCTAssertEqual(BudgetPeriod.allCases.count, 3)
        XCTAssertEqual(BudgetPeriod.weekly.days, 7)
        XCTAssertEqual(BudgetPeriod.monthly.days, 30)
        XCTAssertEqual(BudgetPeriod.yearly.days, 365)
    }

    func testBudgetProgress() {
        // Given
        let budget = Budget(amount: 1000.00, period: .monthly)
        let transactions = [
            Transaction(amount: 200, type: .expense),
            Transaction(amount: 300, type: .expense)
        ]

        // When
        let spent = budget.spentAmount(transactions: transactions)
        let remaining = budget.remainingAmount(transactions: transactions)
        let progress = budget.progress(transactions: transactions)

        // Then
        XCTAssertEqual(spent, 500.00)
        XCTAssertEqual(remaining, 500.00)
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }

    // MARK: - UserProfile Tests

    func testUserProfileFirestoreConversion() {
        // Given
        let profile = UserProfile(
            id: "test-user-123",
            email: "test@example.com",
            displayName: "Test User",
            persona: .professional,
            preferredTheme: .clear,
            currencyCode: "INR"
        )

        // When
        let firestoreData = profile.firestoreData

        // Then
        XCTAssertEqual(firestoreData["id"] as? String, "test-user-123")
        XCTAssertEqual(firestoreData["email"] as? String, "test@example.com")
        XCTAssertEqual(firestoreData["displayName"] as? String, "Test User")
        XCTAssertEqual(firestoreData["persona"] as? String, "Professional")
        XCTAssertEqual(firestoreData["preferredTheme"] as? String, "Clear")
        XCTAssertEqual(firestoreData["currencyCode"] as? String, "INR")
    }

    func testUserProfileFromFirestore() {
        // Given
        let firestoreDoc: [String: Any] = [
            "id": "firestore-user-456",
            "email": "student@example.com",
            "displayName": "Student User",
            "persona": "Student",
            "preferredTheme": "Dark",
            "currencyCode": "INR",
            "notificationsEnabled": true,
            "budgetAlertsEnabled": false,
            "isSynced": true,
            "createdAt": Date(),
            "lastModified": Date()
        ]

        // When
        let profile = UserProfile(from: firestoreDoc)

        // Then
        XCTAssertEqual(profile.id, "firestore-user-456")
        XCTAssertEqual(profile.email, "student@example.com")
        XCTAssertEqual(profile.displayName, "Student User")
        XCTAssertEqual(profile.persona, .student)
        XCTAssertEqual(profile.preferredTheme, .dark)
        XCTAssertTrue(profile.notificationsEnabled)
        XCTAssertFalse(profile.budgetAlertsEnabled)
    }

    func testUserPersonaEnum() {
        XCTAssertEqual(UserPersona.allCases.count, 3)
        XCTAssertTrue(UserPersona.allCases.contains(.student))
        XCTAssertTrue(UserPersona.allCases.contains(.professional))
        XCTAssertTrue(UserPersona.allCases.contains(.family))

        // Test default categories exist for each persona
        for persona in UserPersona.allCases {
            XCTAssertFalse(persona.defaultCategories.isEmpty)
        }
    }

    func testAppThemeEnum() {
        XCTAssertEqual(AppTheme.allCases.count, 4)
        XCTAssertTrue(AppTheme.allCases.contains(.light))
        XCTAssertTrue(AppTheme.allCases.contains(.dark))
        XCTAssertTrue(AppTheme.allCases.contains(.tinted))
        XCTAssertTrue(AppTheme.allCases.contains(.clear))

        // Test iOS 26 Clear theme
        XCTAssertEqual(AppTheme.clear.displayName, "Clear")
    }

    // MARK: - Color Extension Tests

    func testColorFromHex() {
        // Test valid hex colors
        let red = Color(hex: "#FF0000")
        XCTAssertNotNil(red)

        let green = Color(hex: "00FF00")
        XCTAssertNotNil(green)

        let blue = Color(hex: "#0000FF")
        XCTAssertNotNil(blue)

        // Test invalid hex
        let invalid = Color(hex: "invalid")
        XCTAssertNil(invalid)
    }
}
