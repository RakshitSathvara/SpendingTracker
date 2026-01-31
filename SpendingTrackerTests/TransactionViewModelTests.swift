//
//  TransactionViewModelTests.swift
//  SpendingTrackerTests
//
//  Created by Rakshit on 31/01/26.
//

import XCTest
import SwiftData
@testable import SpendingTracker

// MARK: - Transaction Form State Tests

final class TransactionFormStateTests: XCTestCase {

    var formState: TransactionFormState!

    override func setUpWithError() throws {
        try super.setUpWithError()
        formState = TransactionFormState()
    }

    override func tearDownWithError() throws {
        formState = nil
        try super.tearDownWithError()
    }

    // MARK: - Initial State Tests

    func testInitialAmountIsZero() {
        XCTAssertEqual(formState.amount, 0)
        XCTAssertEqual(formState.amountString, "0")
    }

    func testInitialTypeIsExpense() {
        XCTAssertTrue(formState.isExpense)
        XCTAssertEqual(formState.transactionType, .expense)
    }

    func testInitialCategoryIsNil() {
        XCTAssertNil(formState.selectedCategory)
    }

    func testInitialAccountIsNil() {
        XCTAssertNil(formState.selectedAccount)
    }

    func testInitialNoteIsEmpty() {
        XCTAssertEqual(formState.note, "")
    }

    func testInitialDateIsToday() {
        XCTAssertTrue(Calendar.current.isDateInToday(formState.date))
    }

    // MARK: - Amount Update Tests

    func testUpdateAmountFromString() {
        formState.updateAmount(from: "123.45")
        XCTAssertEqual(formState.amount, 123.45)
        XCTAssertEqual(formState.amountString, "123.45")
    }

    func testUpdateAmountFromInvalidString() {
        formState.updateAmount(from: "invalid")
        XCTAssertEqual(formState.amount, 0)
    }

    func testUpdateAmountFromEmptyString() {
        formState.updateAmount(from: "")
        XCTAssertEqual(formState.amount, 0)
    }

    // MARK: - Validation Tests

    func testIsValidWithZeroAmount() {
        formState.amount = 0
        XCTAssertFalse(formState.isValid)
    }

    func testIsValidWithPositiveAmount() {
        formState.amount = 100
        XCTAssertTrue(formState.isValid)
    }

    func testHasRequiredFieldsWithoutCategory() {
        formState.amount = 100
        formState.selectedCategory = nil
        XCTAssertFalse(formState.hasRequiredFields)
    }

    // MARK: - Type Toggle Tests

    func testTransactionTypeExpense() {
        formState.isExpense = true
        XCTAssertEqual(formState.transactionType, .expense)
    }

    func testTransactionTypeIncome() {
        formState.isExpense = false
        XCTAssertEqual(formState.transactionType, .income)
    }

    // MARK: - Reset Tests

    func testResetClearsAllFields() {
        formState.amount = 500
        formState.amountString = "500"
        formState.isExpense = false
        formState.note = "Test note"
        formState.merchantName = "Test merchant"

        formState.reset()

        XCTAssertEqual(formState.amount, 0)
        XCTAssertEqual(formState.amountString, "0")
        XCTAssertTrue(formState.isExpense)
        XCTAssertEqual(formState.note, "")
        XCTAssertEqual(formState.merchantName, "")
        XCTAssertNil(formState.selectedCategory)
        XCTAssertNil(formState.selectedAccount)
    }
}

// MARK: - Transaction Filter Tests

final class TransactionFilterTests: XCTestCase {

    func testInitialFilterHasNoActiveFilters() {
        let filter = TransactionFilter()
        XCTAssertFalse(filter.hasActiveFilters)
    }

    func testFilterWithSearchTextIsActive() {
        var filter = TransactionFilter()
        filter.searchText = "grocery"
        XCTAssertTrue(filter.hasActiveFilters)
    }

    func testFilterWithTransactionTypeIsActive() {
        var filter = TransactionFilter()
        filter.transactionType = .expense
        XCTAssertTrue(filter.hasActiveFilters)
    }

    func testFilterWithCategoryIsActive() {
        var filter = TransactionFilter()
        filter.categoryId = "category-123"
        XCTAssertTrue(filter.hasActiveFilters)
    }

    func testFilterWithAccountIsActive() {
        var filter = TransactionFilter()
        filter.accountId = "account-123"
        XCTAssertTrue(filter.hasActiveFilters)
    }

    func testFilterWithDateRangeIsActive() {
        var filter = TransactionFilter()
        filter.startDate = Date()
        XCTAssertTrue(filter.hasActiveFilters)
    }

    func testResetClearsAllFilters() {
        var filter = TransactionFilter()
        filter.searchText = "test"
        filter.transactionType = .expense
        filter.categoryId = "cat-1"
        filter.accountId = "acc-1"
        filter.startDate = Date()
        filter.endDate = Date()

        filter.reset()

        XCTAssertFalse(filter.hasActiveFilters)
        XCTAssertEqual(filter.searchText, "")
        XCTAssertNil(filter.transactionType)
        XCTAssertNil(filter.categoryId)
        XCTAssertNil(filter.accountId)
        XCTAssertNil(filter.startDate)
        XCTAssertNil(filter.endDate)
    }
}

// MARK: - Transaction Summary Tests

final class TransactionSummaryTests: XCTestCase {

    func testBalanceCalculation() {
        let summary = TransactionSummary(
            totalIncome: 10000,
            totalExpenses: 7500,
            transactionCount: 15,
            period: "January 2026"
        )

        XCTAssertEqual(summary.balance, 2500)
    }

    func testNegativeBalance() {
        let summary = TransactionSummary(
            totalIncome: 5000,
            totalExpenses: 8000,
            transactionCount: 10,
            period: "January 2026"
        )

        XCTAssertEqual(summary.balance, -3000)
    }

    func testEmptySummary() {
        let summary = TransactionSummary.empty

        XCTAssertEqual(summary.totalIncome, 0)
        XCTAssertEqual(summary.totalExpenses, 0)
        XCTAssertEqual(summary.transactionCount, 0)
        XCTAssertEqual(summary.balance, 0)
    }

    func testFormattedBalance() {
        let summary = TransactionSummary(
            totalIncome: 10000,
            totalExpenses: 5000,
            transactionCount: 10,
            period: "Test"
        )

        // Balance should be formatted as currency
        XCTAssertFalse(summary.formattedBalance.isEmpty)
    }
}

// MARK: - Number Pad Key Tests

final class NumberPadKeyTests: XCTestCase {

    func testDigitKeyDisplayValue() {
        let key = NumberPadKey.digit("5")
        XCTAssertEqual(key.displayValue, "5")
    }

    func testDecimalKeyDisplayValue() {
        let key = NumberPadKey.decimal
        XCTAssertEqual(key.displayValue, ".")
    }

    func testBackspaceKeyDisplayValue() {
        let key = NumberPadKey.backspace
        XCTAssertEqual(key.displayValue, "⌫")
    }

    func testDigitKeyAccessibilityLabel() {
        let key = NumberPadKey.digit("7")
        XCTAssertEqual(key.accessibilityLabel, "7")
    }

    func testDecimalKeyAccessibilityLabel() {
        let key = NumberPadKey.decimal
        XCTAssertEqual(key.accessibilityLabel, "Decimal point")
    }

    func testBackspaceKeyAccessibilityLabel() {
        let key = NumberPadKey.backspace
        XCTAssertEqual(key.accessibilityLabel, "Delete")
    }
}

// MARK: - Amount Display Size Tests

final class AmountDisplaySizeTests: XCTestCase {

    func testSmallSizeFontSize() {
        XCTAssertEqual(AmountDisplaySize.small.fontSize, 20)
    }

    func testMediumSizeFontSize() {
        XCTAssertEqual(AmountDisplaySize.medium.fontSize, 28)
    }

    func testLargeSizeFontSize() {
        XCTAssertEqual(AmountDisplaySize.large.fontSize, 40)
    }

    func testHeroSizeFontSize() {
        XCTAssertEqual(AmountDisplaySize.hero.fontSize, 56)
    }

    func testSmallSizeCornerRadius() {
        XCTAssertEqual(AmountDisplaySize.small.cornerRadius, 10)
    }

    func testHeroSizeCornerRadius() {
        XCTAssertEqual(AmountDisplaySize.hero.cornerRadius, 20)
    }
}

// MARK: - Transaction Type Tests

final class TransactionTypeTests: XCTestCase {

    func testExpenseRawValue() {
        XCTAssertEqual(TransactionType.expense.rawValue, "Expense")
    }

    func testIncomeRawValue() {
        XCTAssertEqual(TransactionType.income.rawValue, "Income")
    }

    func testExpenseIcon() {
        XCTAssertEqual(TransactionType.expense.icon, "arrow.up.circle.fill")
    }

    func testIncomeIcon() {
        XCTAssertEqual(TransactionType.income.icon, "arrow.down.circle.fill")
    }

    func testExpenseColorName() {
        XCTAssertEqual(TransactionType.expense.colorName, "red")
    }

    func testIncomeColorName() {
        XCTAssertEqual(TransactionType.income.colorName, "green")
    }

    func testAllCasesCount() {
        XCTAssertEqual(TransactionType.allCases.count, 2)
    }
}

// MARK: - Account Type Tests

final class AccountTypeTests: XCTestCase {

    func testCashRawValue() {
        XCTAssertEqual(AccountType.cash.rawValue, "Cash")
    }

    func testBankRawValue() {
        XCTAssertEqual(AccountType.bank.rawValue, "Bank")
    }

    func testCreditRawValue() {
        XCTAssertEqual(AccountType.credit.rawValue, "Credit")
    }

    func testSavingsRawValue() {
        XCTAssertEqual(AccountType.savings.rawValue, "Savings")
    }

    func testWalletRawValue() {
        XCTAssertEqual(AccountType.wallet.rawValue, "Wallet")
    }

    func testCashIcon() {
        XCTAssertEqual(AccountType.cash.icon, "banknote.fill")
    }

    func testBankIcon() {
        XCTAssertEqual(AccountType.bank.icon, "building.columns.fill")
    }

    func testAllCasesCount() {
        XCTAssertEqual(AccountType.allCases.count, 5)
    }
}

// MARK: - Budget Period Tests

final class BudgetPeriodTests: XCTestCase {

    func testWeeklyDays() {
        XCTAssertEqual(BudgetPeriod.weekly.days, 7)
    }

    func testMonthlyDays() {
        XCTAssertEqual(BudgetPeriod.monthly.days, 30)
    }

    func testYearlyDays() {
        XCTAssertEqual(BudgetPeriod.yearly.days, 365)
    }

    func testDisplayNames() {
        XCTAssertEqual(BudgetPeriod.weekly.displayName, "Weekly")
        XCTAssertEqual(BudgetPeriod.monthly.displayName, "Monthly")
        XCTAssertEqual(BudgetPeriod.yearly.displayName, "Yearly")
    }

    func testIcons() {
        XCTAssertEqual(BudgetPeriod.weekly.icon, "calendar.badge.clock")
        XCTAssertEqual(BudgetPeriod.monthly.icon, "calendar")
        XCTAssertEqual(BudgetPeriod.yearly.icon, "calendar.circle.fill")
    }
}
