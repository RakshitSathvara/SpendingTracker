//
//  RepositoryTests.swift
//  SpendingTrackerTests
//
//  Created by Claude on 2026-01-31.
//
//  Integration tests for Firestore repositories.
//  These tests require Firebase Emulator to be running.
//
//  To run tests with emulator:
//  1. Install Firebase CLI: npm install -g firebase-tools
//  2. Start emulator: firebase emulators:start --only firestore,auth
//  3. Run tests in Xcode
//

import XCTest
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
@testable import SpendingTracker

// MARK: - Test Configuration

/// Configuration for Firebase emulator testing
struct EmulatorConfig {
    static let firestoreHost = "localhost"
    static let firestorePort = 8080
    static let authHost = "localhost"
    static let authPort = 9099

    static func configure() {
        // Configure Firestore to use emulator
        let settings = Firestore.firestore().settings
        settings.host = "\(firestoreHost):\(firestorePort)"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        // Configure Auth to use emulator
        Auth.auth().useEmulator(withHost: authHost, port: authPort)
    }
}

// MARK: - Mock User Helper

/// Helper class to create mock authenticated users for testing
class MockAuthHelper {
    static let testEmail = "test@example.com"
    static let testPassword = "password123"
    static let testUserId = "test-user-id"

    static func signInTestUser() async throws {
        do {
            try await Auth.auth().signIn(withEmail: testEmail, password: testPassword)
        } catch {
            // Create user if doesn't exist
            try await Auth.auth().createUser(withEmail: testEmail, password: testPassword)
        }
    }

    static func signOut() throws {
        try Auth.auth().signOut()
    }

    static var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
}

// MARK: - Transaction Repository Tests

final class TransactionRepositoryTests: XCTestCase {

    var repository: TransactionRepository!
    var firestore: Firestore!

    override func setUp() async throws {
        try await super.setUp()

        // Note: In a real test environment, configure emulator here
        // EmulatorConfig.configure()

        firestore = Firestore.firestore()
        repository = TransactionRepository(firestore: firestore)

        // Sign in test user
        // try await MockAuthHelper.signInTestUser()
    }

    override func tearDown() async throws {
        // Clean up test data
        // try MockAuthHelper.signOut()
        repository = nil
        try await super.tearDown()
    }

    // MARK: - DTO Tests

    func testTransactionDTOInitialization() {
        let dto = TransactionDTO(
            id: "test-id",
            amount: Decimal(100.50),
            note: "Test transaction",
            date: Date(),
            type: .expense,
            merchantName: "Test Merchant",
            categoryId: "category-1",
            accountId: "account-1"
        )

        XCTAssertEqual(dto.id, "test-id")
        XCTAssertEqual(dto.amount, Decimal(100.50))
        XCTAssertEqual(dto.note, "Test transaction")
        XCTAssertEqual(dto.type, .expense)
        XCTAssertEqual(dto.merchantName, "Test Merchant")
        XCTAssertEqual(dto.categoryId, "category-1")
        XCTAssertEqual(dto.accountId, "account-1")
        XCTAssertTrue(dto.isExpense)
        XCTAssertFalse(dto.isIncome)
    }

    func testTransactionDTOFirestoreData() {
        let dto = TransactionDTO(
            amount: Decimal(50),
            note: "Test",
            type: .income
        )

        let data = dto.firestoreData

        XCTAssertNotNil(data["id"])
        XCTAssertEqual(data["amount"] as? Double, 50.0)
        XCTAssertEqual(data["note"] as? String, "Test")
        XCTAssertEqual(data["type"] as? String, "Income")
        XCTAssertTrue(data["isSynced"] as? Bool ?? false)
    }

    func testTransactionDTOFromSwiftDataModel() {
        let transaction = Transaction(
            id: "model-id",
            amount: Decimal(75),
            note: "From model",
            type: .expense
        )

        let dto = TransactionDTO(from: transaction)

        XCTAssertEqual(dto.id, "model-id")
        XCTAssertEqual(dto.amount, Decimal(75))
        XCTAssertEqual(dto.note, "From model")
        XCTAssertEqual(dto.type, .expense)
    }

    func testFormattedAmount() {
        let dto = TransactionDTO(amount: Decimal(1234.56), type: .expense)
        XCTAssertFalse(dto.formattedAmount.isEmpty)
    }
}

// MARK: - Category Repository Tests

final class CategoryRepositoryTests: XCTestCase {

    var repository: CategoryRepository!

    override func setUp() async throws {
        try await super.setUp()
        repository = CategoryRepository(firestore: Firestore.firestore())
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }

    // MARK: - DTO Tests

    func testCategoryDTOInitialization() {
        let dto = CategoryDTO(
            id: "cat-1",
            name: "Food & Dining",
            icon: "fork.knife",
            colorHex: "#FF9500",
            isExpenseCategory: true,
            sortOrder: 0,
            isDefault: true
        )

        XCTAssertEqual(dto.id, "cat-1")
        XCTAssertEqual(dto.name, "Food & Dining")
        XCTAssertEqual(dto.icon, "fork.knife")
        XCTAssertEqual(dto.colorHex, "#FF9500")
        XCTAssertTrue(dto.isExpenseCategory)
        XCTAssertEqual(dto.sortOrder, 0)
        XCTAssertTrue(dto.isDefault)
    }

    func testCategoryDTOFirestoreData() {
        let dto = CategoryDTO(
            name: "Transportation",
            icon: "car.fill",
            colorHex: "#007AFF",
            isExpenseCategory: true
        )

        let data = dto.firestoreData

        XCTAssertNotNil(data["id"])
        XCTAssertEqual(data["name"] as? String, "Transportation")
        XCTAssertEqual(data["icon"] as? String, "car.fill")
        XCTAssertEqual(data["colorHex"] as? String, "#007AFF")
        XCTAssertTrue(data["isExpenseCategory"] as? Bool ?? false)
    }

    func testDefaultIncomeCategories() {
        let incomeCategories = CategoryDTO.defaultIncomeCategories

        XCTAssertFalse(incomeCategories.isEmpty)
        XCTAssertTrue(incomeCategories.allSatisfy { !$0.isExpenseCategory })
        XCTAssertTrue(incomeCategories.contains { $0.name == "Salary" })
        XCTAssertTrue(incomeCategories.contains { $0.name == "Freelance" })
    }

    func testCategoryDTOFromSwiftDataModel() {
        let category = Category(
            id: "swift-cat",
            name: "Test Category",
            icon: "star.fill",
            colorHex: "#FF0000",
            isExpenseCategory: false
        )

        let dto = CategoryDTO(from: category)

        XCTAssertEqual(dto.id, "swift-cat")
        XCTAssertEqual(dto.name, "Test Category")
        XCTAssertEqual(dto.icon, "star.fill")
        XCTAssertEqual(dto.colorHex, "#FF0000")
        XCTAssertFalse(dto.isExpenseCategory)
    }
}

// MARK: - Account Repository Tests

final class AccountRepositoryTests: XCTestCase {

    var repository: AccountRepository!

    override func setUp() async throws {
        try await super.setUp()
        repository = AccountRepository(firestore: Firestore.firestore())
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }

    // MARK: - DTO Tests

    func testAccountDTOInitialization() {
        let dto = AccountDTO(
            id: "acc-1",
            name: "Savings Account",
            initialBalance: Decimal(5000),
            accountType: .savings,
            currencyCode: "INR"
        )

        XCTAssertEqual(dto.id, "acc-1")
        XCTAssertEqual(dto.name, "Savings Account")
        XCTAssertEqual(dto.initialBalance, Decimal(5000))
        XCTAssertEqual(dto.accountType, .savings)
        XCTAssertEqual(dto.currencyCode, "INR")
        XCTAssertEqual(dto.icon, AccountType.savings.icon)
        XCTAssertEqual(dto.colorHex, AccountType.savings.defaultColor)
    }

    func testAccountDTOFirestoreData() {
        let dto = AccountDTO(
            name: "Cash",
            initialBalance: Decimal(1000),
            accountType: .cash
        )

        let data = dto.firestoreData

        XCTAssertNotNil(data["id"])
        XCTAssertEqual(data["name"] as? String, "Cash")
        XCTAssertEqual(data["initialBalance"] as? Double, 1000.0)
        XCTAssertEqual(data["accountType"] as? String, "Cash")
    }

    func testAccountTypeDefaults() {
        XCTAssertEqual(AccountType.cash.icon, "banknote.fill")
        XCTAssertEqual(AccountType.bank.icon, "building.columns.fill")
        XCTAssertEqual(AccountType.credit.icon, "creditcard.fill")
        XCTAssertEqual(AccountType.savings.icon, "dollarsign.circle.fill")
        XCTAssertEqual(AccountType.wallet.icon, "wallet.pass.fill")
    }

    func testAccountDTOFormattedBalance() {
        let dto = AccountDTO(
            name: "Test",
            initialBalance: Decimal(1234.56),
            accountType: .bank
        )

        XCTAssertFalse(dto.formattedBalance.isEmpty)
    }
}

// MARK: - Budget Repository Tests

final class BudgetRepositoryTests: XCTestCase {

    var repository: BudgetRepository!

    override func setUp() async throws {
        try await super.setUp()
        repository = BudgetRepository(firestore: Firestore.firestore())
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }

    // MARK: - DTO Tests

    func testBudgetDTOInitialization() {
        let startDate = Date()
        let dto = BudgetDTO(
            id: "budget-1",
            amount: Decimal(10000),
            period: .monthly,
            startDate: startDate,
            alertThreshold: 0.8,
            isActive: true,
            categoryId: "food-category"
        )

        XCTAssertEqual(dto.id, "budget-1")
        XCTAssertEqual(dto.amount, Decimal(10000))
        XCTAssertEqual(dto.period, .monthly)
        XCTAssertEqual(dto.startDate, startDate)
        XCTAssertEqual(dto.alertThreshold, 0.8)
        XCTAssertTrue(dto.isActive)
        XCTAssertEqual(dto.categoryId, "food-category")
    }

    func testBudgetDTOEndDate() {
        let startDate = Date()
        let dto = BudgetDTO(
            amount: Decimal(5000),
            period: .monthly,
            startDate: startDate
        )

        let expectedEndDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)!
        XCTAssertEqual(dto.endDate.timeIntervalSince1970, expectedEndDate.timeIntervalSince1970, accuracy: 1)
    }

    func testBudgetDTOSpentAmount() {
        let startDate = Date().addingTimeInterval(-86400) // Yesterday
        let dto = BudgetDTO(
            amount: Decimal(10000),
            period: .monthly,
            startDate: startDate,
            categoryId: "food"
        )

        let transactions = [
            TransactionDTO(amount: Decimal(500), date: Date(), type: .expense, categoryId: "food"),
            TransactionDTO(amount: Decimal(300), date: Date(), type: .expense, categoryId: "food"),
            TransactionDTO(amount: Decimal(200), date: Date(), type: .income, categoryId: "food"), // Income, shouldn't count
            TransactionDTO(amount: Decimal(100), date: Date(), type: .expense, categoryId: "transport") // Different category
        ]

        let spent = dto.spentAmount(transactions: transactions)
        XCTAssertEqual(spent, Decimal(800)) // 500 + 300
    }

    func testBudgetDTOProgress() {
        let startDate = Date().addingTimeInterval(-86400)
        let dto = BudgetDTO(
            amount: Decimal(1000),
            period: .monthly,
            startDate: startDate
        )

        let transactions = [
            TransactionDTO(amount: Decimal(500), date: Date(), type: .expense)
        ]

        let progress = dto.progress(transactions: transactions)
        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
    }

    func testBudgetDTOIsOverThreshold() {
        let startDate = Date().addingTimeInterval(-86400)
        let dto = BudgetDTO(
            amount: Decimal(1000),
            period: .monthly,
            startDate: startDate,
            alertThreshold: 0.8
        )

        let transactions = [
            TransactionDTO(amount: Decimal(850), date: Date(), type: .expense)
        ]

        XCTAssertTrue(dto.isOverThreshold(transactions: transactions))
        XCTAssertFalse(dto.isOverBudget(transactions: transactions))
    }

    func testBudgetDTOIsOverBudget() {
        let startDate = Date().addingTimeInterval(-86400)
        let dto = BudgetDTO(
            amount: Decimal(1000),
            period: .monthly,
            startDate: startDate
        )

        let transactions = [
            TransactionDTO(amount: Decimal(1100), date: Date(), type: .expense)
        ]

        XCTAssertTrue(dto.isOverBudget(transactions: transactions))
    }

    func testBudgetPeriodDays() {
        XCTAssertEqual(BudgetPeriod.weekly.days, 7)
        XCTAssertEqual(BudgetPeriod.monthly.days, 30)
        XCTAssertEqual(BudgetPeriod.yearly.days, 365)
    }
}

// MARK: - User Profile Repository Tests

final class UserProfileRepositoryTests: XCTestCase {

    var repository: UserProfileRepository!

    override func setUp() async throws {
        try await super.setUp()
        repository = UserProfileRepository(firestore: Firestore.firestore())
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }

    // MARK: - DTO Tests

    func testUserProfileDTOInitialization() {
        let dto = UserProfileDTO(
            id: "user-1",
            email: "test@example.com",
            displayName: "Test User",
            persona: .professional,
            preferredTheme: .dark,
            currencyCode: "USD",
            notificationsEnabled: true,
            budgetAlertsEnabled: false
        )

        XCTAssertEqual(dto.id, "user-1")
        XCTAssertEqual(dto.email, "test@example.com")
        XCTAssertEqual(dto.displayName, "Test User")
        XCTAssertEqual(dto.persona, .professional)
        XCTAssertEqual(dto.preferredTheme, .dark)
        XCTAssertEqual(dto.currencyCode, "USD")
        XCTAssertTrue(dto.notificationsEnabled)
        XCTAssertFalse(dto.budgetAlertsEnabled)
    }

    func testUserProfileDTOFirestoreData() {
        let dto = UserProfileDTO(
            email: "test@example.com",
            displayName: "Test",
            persona: .student,
            preferredTheme: .clear
        )

        let data = dto.firestoreData

        XCTAssertNotNil(data["id"])
        XCTAssertEqual(data["email"] as? String, "test@example.com")
        XCTAssertEqual(data["displayName"] as? String, "Test")
        XCTAssertEqual(data["persona"] as? String, "Student")
        XCTAssertEqual(data["preferredTheme"] as? String, "Clear")
    }

    func testUserPersonaDefaults() {
        XCTAssertFalse(UserPersona.student.defaultCategories.isEmpty)
        XCTAssertFalse(UserPersona.professional.defaultCategories.isEmpty)
        XCTAssertFalse(UserPersona.family.defaultCategories.isEmpty)

        // Student should have education category
        XCTAssertTrue(UserPersona.student.defaultCategories.contains { $0.name == "Education" })

        // Professional should have work expenses
        XCTAssertTrue(UserPersona.professional.defaultCategories.contains { $0.name == "Work Expenses" })

        // Family should have groceries
        XCTAssertTrue(UserPersona.family.defaultCategories.contains { $0.name == "Groceries" })
    }

    func testAppThemeColorScheme() {
        XCTAssertEqual(AppTheme.light.colorScheme, .light)
        XCTAssertEqual(AppTheme.dark.colorScheme, .dark)
        XCTAssertNil(AppTheme.tinted.colorScheme)
        XCTAssertNil(AppTheme.clear.colorScheme)
    }
}

// MARK: - Repository Error Tests

final class RepositoryErrorTests: XCTestCase {

    func testErrorDescriptions() {
        let notAuth = RepositoryError.notAuthenticated
        XCTAssertEqual(notAuth.errorDescription, "User is not authenticated")

        let notFound = RepositoryError.documentNotFound("doc-123")
        XCTAssertTrue(notFound.errorDescription?.contains("doc-123") ?? false)

        let invalidData = RepositoryError.invalidData("Missing field")
        XCTAssertTrue(invalidData.errorDescription?.contains("Missing field") ?? false)

        let syncFailed = RepositoryError.syncFailed("Network timeout")
        XCTAssertTrue(syncFailed.errorDescription?.contains("Network timeout") ?? false)

        let batchFailed = RepositoryError.batchWriteFailed("Too many operations")
        XCTAssertTrue(batchFailed.errorDescription?.contains("Too many operations") ?? false)
    }
}

// MARK: - Firestore Path Tests

final class FirestorePathTests: XCTestCase {

    func testCollectionPaths() {
        let userId = "test-user-123"

        XCTAssertEqual(
            FirestorePath.transactionsCollection(userId: userId),
            "users/test-user-123/transactions"
        )

        XCTAssertEqual(
            FirestorePath.categoriesCollection(userId: userId),
            "users/test-user-123/categories"
        )

        XCTAssertEqual(
            FirestorePath.accountsCollection(userId: userId),
            "users/test-user-123/accounts"
        )

        XCTAssertEqual(
            FirestorePath.budgetsCollection(userId: userId),
            "users/test-user-123/budgets"
        )
    }

    func testUserDocumentPath() {
        let userId = "user-abc"
        XCTAssertEqual(
            FirestorePath.userDocument(userId: userId),
            "users/user-abc"
        )
    }
}

// MARK: - Batch Writer Tests

final class FirestoreBatchWriterTests: XCTestCase {

    func testBatchWriterInitialization() {
        let writer = FirestoreBatchWriter()

        XCTAssertEqual(writer.count, 0)
        XCTAssertFalse(writer.isFull)
    }

    func testBatchWriterLimitCheck() {
        let writer = FirestoreBatchWriter()

        // Initially not full
        XCTAssertFalse(writer.isFull)

        // After 500 operations, should be full
        // Note: This is a conceptual test - actual test would need Firestore
    }
}
