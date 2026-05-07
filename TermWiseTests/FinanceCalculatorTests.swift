//
//  FinanceCalculatorTests.swift
//  TermWiseTests
//
//  Unit tests for the pure finance/business logic exposed by `FinanceCalculator` plus the
//  stateful Mark-as-Paid / Undo flow on `AppState`. UI is intentionally not exercised here;
//  see `TermWiseUITests` for that.
//
//  Run with: ⌘+U in Xcode (TermWise scheme), or
//  `xcodebuild -scheme TermWise -destination ... test`.
//

import XCTest
@testable import TermWise

final class FinanceCalculatorTests: XCTestCase {

    // MARK: - Test fixtures

    private let cal = Calendar(identifier: .gregorian)
    /// Stable mid-month reference date used everywhere a "current" month is needed.
    /// 15th of May lets us exercise both before-due and after-due bill scenarios.
    private lazy var refDate: Date = {
        cal.date(from: DateComponents(year: 2026, month: 5, day: 15, hour: 12)) ?? Date()
    }()

    private func makeTxn(
        amount: Double,
        category: String,
        type: TransactionType,
        day: Int,
        savedApplied: Double = 0,
        createdHour: Int = 12,
        createdMinute: Int = 0
    ) -> TransactionItem {
        let date = cal.date(from: DateComponents(year: 2026, month: 5, day: day, hour: createdHour, minute: createdMinute)) ?? refDate
        return TransactionItem(
            id: UUID(),
            amount: amount,
            category: category,
            note: "",
            date: date,
            createdAt: date,
            type: type,
            savedApplied: savedApplied
        )
    }

    private func makeBudget(
        category: String,
        planned: Double,
        type: BudgetType,
        frequency: PaymentFrequency = .none,
        dueDay: Int? = nil
    ) -> BudgetItem {
        BudgetItem(
            id: UUID(),
            category: category,
            planned: planned,
            budgetType: type,
            frequency: frequency,
            dueDay: dueDay,
            dueWeekday: nil,
            dueDate: nil
        )
    }

    // MARK: - 1. Income vs budget logic

    func test_totalIncome_sumsOnlyIncomeTransactions() {
        let transactions = [
            makeTxn(amount: 2000, category: "Paycheque", type: .income, day: 1),
            makeTxn(amount: 1000, category: "Co-op", type: .income, day: 5),
            makeTxn(amount: 200, category: "Groceries", type: .expense, day: 3),
            makeTxn(amount: 50, category: "Eating Out", type: .expense, day: 4)
        ]
        let total = FinanceCalculator.totalIncomeThisMonth(
            transactions: transactions,
            referenceDate: refDate,
            calendar: cal
        )
        XCTAssertEqual(total, 3000, accuracy: 0.0001)
    }

    func test_totalExpenses_sumsOnlyExpenseTransactions_andUsesNetAmount() {
        let transactions = [
            makeTxn(amount: 300, category: "Groceries", type: .expense, day: 2),
            makeTxn(amount: 100, category: "Eating Out", type: .expense, day: 4, savedApplied: 25),
            makeTxn(amount: 5000, category: "Paycheque", type: .income, day: 1)
        ]
        let total = FinanceCalculator.totalExpensesThisMonth(
            transactions: transactions,
            referenceDate: refDate,
            calendar: cal
        )
        XCTAssertEqual(total, 300 + (100 - 25), accuracy: 0.0001)
    }

    func test_totalIncome_doesNotAutomaticallyBecomeAvailableToBudget() {
        // Even though income is 3000, an explicit override of 2200 must win.
        let totalIncome = 3000.0
        let availableToBudget = FinanceBudgetAllocation.calculateAvailableToBudget(
            explicitByMonth: ["2026-05": 2200],
            monthKey: "2026-05",
            totalIncome: totalIncome,
            fallbackExpectedMonthlyIncome: 0
        )
        XCTAssertEqual(availableToBudget, 2200, accuracy: 0.0001)
        XCTAssertNotEqual(availableToBudget, totalIncome)
    }

    func test_reserveNotBudgeted_isIncomeMinusAvailable_whenIncomeIsLarger() {
        let reserve = FinanceCalculator.reserveNotBudgeted(totalIncome: 3000, availableToBudget: 2200)
        XCTAssertEqual(reserve, 800, accuracy: 0.0001)
    }

    func test_reserveNotBudgeted_isClampedAtZero_whenAvailableExceedsIncome() {
        let reserve = FinanceCalculator.reserveNotBudgeted(totalIncome: 1000, availableToBudget: 1500)
        XCTAssertEqual(reserve, 0)
    }

    func test_availableToBudgetWarning_isReturnedWhenBudgetExceedsRecordedIncome() {
        let warning = FinanceCalculator.availableToBudgetWarning(totalIncome: 1000, availableToBudget: 1500)
        XCTAssertNotNil(warning)
        XCTAssertEqual(
            warning,
            "You're budgeting more than the income you've recorded this month."
        )
    }

    func test_availableToBudgetWarning_isNilWhenBudgetIsAtOrBelowIncome() {
        XCTAssertNil(FinanceCalculator.availableToBudgetWarning(totalIncome: 1000, availableToBudget: 1000))
        XCTAssertNil(FinanceCalculator.availableToBudgetWarning(totalIncome: 1000, availableToBudget: 800))
    }

    // MARK: - 2. Budget difference logic

    func test_budgetDifference_isNegative_whenOverBudget() {
        let diff = FinanceCalculator.budgetDifference(availableToBudget: 1020, totalBudgeted: 1635)
        XCTAssertEqual(diff, -615, accuracy: 0.0001)
    }

    func test_unallocatedRow_overBudget_returnsOverBudgetByLabelAndAbsoluteValue() {
        let row = FinanceCalculator.unallocatedRow(availableToBudget: 1020, totalBudgeted: 1635)
        XCTAssertEqual(row.label, "Over Budget By")
        XCTAssertEqual(row.value, 615, accuracy: 0.0001)
        XCTAssertTrue(row.isOver)
    }

    func test_budgetDifference_isPositive_whenUnderBudget() {
        let diff = FinanceCalculator.budgetDifference(availableToBudget: 2000, totalBudgeted: 1635)
        XCTAssertEqual(diff, 365, accuracy: 0.0001)
    }

    func test_unallocatedRow_underBudget_returnsUnallocatedBudgetLabel() {
        let row = FinanceCalculator.unallocatedRow(availableToBudget: 2000, totalBudgeted: 1635)
        XCTAssertEqual(row.label, "Unallocated Budget")
        XCTAssertEqual(row.value, 365, accuracy: 0.0001)
        XCTAssertFalse(row.isOver)
    }

    // MARK: - 3. Fixed bill paid logic

    func test_fixedBill_isPaid_whenActualEqualsPlanned() {
        XCTAssertTrue(FinanceCalculator.fixedBillIsPaid(planned: 900, actual: 900))
    }

    func test_fixedBill_isPaid_whenActualExceedsPlanned() {
        XCTAssertTrue(FinanceCalculator.fixedBillIsPaid(planned: 900, actual: 901))
    }

    func test_fixedBill_isUnpaid_whenActualBelowPlanned() {
        XCTAssertFalse(FinanceCalculator.fixedBillIsPaid(planned: 900, actual: 500))
    }

    func test_fixedBill_progressIs100Percent_whenPaid() {
        let progress = FinanceCalculator.fixedBillProgress(planned: 900, actual: 900)
        XCTAssertEqual(progress, 1.0, accuracy: 0.0001)
    }

    func test_fixedBill_progressIsCappedAt100Percent_whenOverpaid() {
        let progress = FinanceCalculator.fixedBillProgress(planned: 900, actual: 1500)
        XCTAssertEqual(progress, 1.0, accuracy: 0.0001)
    }

    func test_fixedBill_progressFractionMatchesRatio_whenPartiallyPaid() {
        // 500 / 900 ≈ 0.5556
        let progress = FinanceCalculator.fixedBillProgress(planned: 900, actual: 500)
        XCTAssertEqual(progress, 500.0 / 900.0, accuracy: 0.0001)
    }

    func test_fixedBillStatus_isPaid_whenActualMeetsPlanned_regardlessOfDueDate() {
        let status = FinanceCalculator.fixedBillStatus(planned: 900, actual: 900, daysUntilDue: -3)
        XCTAssertEqual(status, .paid)
    }

    func test_fixedBillStatus_isOverdue_whenUnpaidAndPastDue() {
        let status = FinanceCalculator.fixedBillStatus(planned: 900, actual: 0, daysUntilDue: -1)
        XCTAssertEqual(status, .overdue)
    }

    func test_fixedBillStatus_isUpcoming_whenUnpaidAndDueInFuture() {
        let status = FinanceCalculator.fixedBillStatus(planned: 900, actual: 0, daysUntilDue: 5)
        XCTAssertEqual(status, .upcoming)
    }

    // MARK: - 4. Mark as Paid logic (stateful: AppState + in-memory repo)

    func test_markAsPaid_remainingAmount_returnsDifference() throws {
        let remaining = try XCTUnwrap(FinanceCalculator.markAsPaidRemainingAmount(planned: 900, actualPaid: 500))
        XCTAssertEqual(remaining, 400, accuracy: 0.0001)
    }

    func test_markAsPaid_remainingAmount_returnsNil_whenAlreadyPaid() {
        XCTAssertNil(FinanceCalculator.markAsPaidRemainingAmount(planned: 900, actualPaid: 900))
        XCTAssertNil(FinanceCalculator.markAsPaidRemainingAmount(planned: 900, actualPaid: 1100))
    }

    @MainActor
    func test_markAsPaid_createsRemainingExpense_andMarksBillPaid() throws {
        let appState = makeIsolatedAppState()

        let rentBillId = UUID()
        let rent = BudgetItem(
            id: rentBillId,
            category: "Rent",
            planned: 900,
            budgetType: .fixed,
            frequency: .monthly,
            dueDay: 1,
            dueWeekday: nil,
            dueDate: nil
        )
        appState.budgetItems = [rent]
        appState.transactions = [
            // Existing partial Rent expense in current month.
            TransactionItem(
                id: UUID(),
                amount: 500,
                category: "Rent",
                note: "Partial rent",
                date: Date(),
                createdAt: Date(),
                type: .expense
            )
        ]

        let initialActual = appState.actualPaidAmount(for: rent)
        XCTAssertEqual(initialActual, 500, accuracy: 0.0001)
        XCTAssertFalse(rent.isPaid)

        // Act
        let created = try XCTUnwrap(appState.markFixedBillRemainingPaid(billId: rentBillId))

        // Assert: a new transaction was created for the missing 400.
        XCTAssertEqual(created.amount, 400, accuracy: 0.0001)
        XCTAssertEqual(created.category, "Rent")
        XCTAssertEqual(created.type, .expense)
        XCTAssertEqual(created.billId, rentBillId)
        XCTAssertEqual(created.source, TransactionProvenance.markAsPaid)
        XCTAssertTrue(created.undoable)

        // Bill state.
        let billNow = try XCTUnwrap(appState.budgetItems.first(where: { $0.id == rentBillId }))
        XCTAssertEqual(appState.actualPaidAmount(for: billNow), 900, accuracy: 0.0001)
        XCTAssertTrue(billNow.isPaid)
        XCTAssertEqual(
            FinanceCalculator.fixedBillProgress(planned: billNow.planned, actual: appState.actualPaidAmount(for: billNow)),
            1.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(appState.fixedBillStatus(for: billNow), .paid)
    }

    @MainActor
    func test_markAsPaid_returnsNil_whenAlreadyFullyPaid() {
        let appState = makeIsolatedAppState()
        let rentBillId = UUID()
        let rent = BudgetItem(
            id: rentBillId,
            category: "Rent",
            planned: 900,
            budgetType: .fixed,
            frequency: .monthly,
            dueDay: 1,
            dueWeekday: nil,
            dueDate: nil
        )
        appState.budgetItems = [rent]
        appState.transactions = [
            TransactionItem(id: UUID(), amount: 900, category: "Rent", note: "", date: Date(), type: .expense)
        ]
        XCTAssertNil(appState.markFixedBillRemainingPaid(billId: rentBillId))
    }

    // MARK: - 5. Undo Mark as Paid logic

    @MainActor
    func test_undoMarkAsPaid_removesGeneratedTransaction_andRestoresUnpaidState() throws {
        let appState = makeIsolatedAppState()
        let rentBillId = UUID()
        let rent = BudgetItem(
            id: rentBillId,
            category: "Rent",
            planned: 900,
            budgetType: .fixed,
            frequency: .monthly,
            dueDay: 1,
            dueWeekday: nil,
            dueDate: nil
        )
        appState.budgetItems = [rent]
        appState.transactions = [
            TransactionItem(id: UUID(), amount: 500, category: "Rent", note: "", date: Date(), type: .expense)
        ]

        let created = try XCTUnwrap(appState.markFixedBillRemainingPaid(billId: rentBillId))
        XCTAssertEqual(appState.transactions.count, 2)
        XCTAssertTrue(appState.budgetItems[0].isPaid)

        // Act: undo the mark-as-paid.
        appState.undoFixedBillMarkAsPaidPayment(billId: rentBillId, transactionId: created.id)

        // Assert: synthetic transaction is gone, bill returns to 500 actual / unpaid.
        XCTAssertEqual(appState.transactions.count, 1)
        XCTAssertFalse(appState.transactions.contains(where: { $0.id == created.id }))

        let billAfter = appState.budgetItems[0]
        XCTAssertEqual(appState.actualPaidAmount(for: billAfter), 500, accuracy: 0.0001)
        XCTAssertFalse(billAfter.isPaid)

        let restoredProgress = FinanceCalculator.fixedBillProgress(
            planned: billAfter.planned,
            actual: appState.actualPaidAmount(for: billAfter)
        )
        XCTAssertEqual(restoredProgress, 500.0 / 900.0, accuracy: 0.0001) // ≈ 55.6%
    }

    // MARK: - 6. Variable spending threshold tiers (anti-repeat warnings)

    func test_variableThreshold_isAt75_whenSpentReaches75PercentOfPlanned() {
        // 280 * 0.75 = 210 → exactly at the 75% boundary
        let tier = FinanceCalculator.variableThresholdTier(planned: 280, actual: 210)
        XCTAssertEqual(tier, .at75)
    }

    func test_variableThreshold_isAt90_whenSpentReaches90PercentOfPlanned() {
        // 280 * 0.9 = 252
        let tier = FinanceCalculator.variableThresholdTier(planned: 280, actual: 252)
        XCTAssertEqual(tier, .at90)
    }

    func test_variableThreshold_isAt100_whenSpentReachesPlanned() {
        let tier = FinanceCalculator.variableThresholdTier(planned: 280, actual: 280)
        XCTAssertEqual(tier, .at100)
    }

    func test_variableThreshold_isBelow_whenUnder75Percent() {
        let tier = FinanceCalculator.variableThresholdTier(planned: 280, actual: 100)
        XCTAssertEqual(tier, .below)
    }

    func test_nextVariableThresholdToShow_suppressesRepeats_atSameTier() {
        // First time at 75% → show.
        XCTAssertEqual(
            FinanceCalculator.nextVariableThresholdToShow(lastShown: nil, newTier: .at75),
            .at75
        )
        // Next call still at 75% → suppress.
        XCTAssertNil(
            FinanceCalculator.nextVariableThresholdToShow(lastShown: .at75, newTier: .at75)
        )
    }

    func test_nextVariableThresholdToShow_advancesToHigherTier() {
        XCTAssertEqual(
            FinanceCalculator.nextVariableThresholdToShow(lastShown: .at75, newTier: .at90),
            .at90
        )
        XCTAssertEqual(
            FinanceCalculator.nextVariableThresholdToShow(lastShown: .at90, newTier: .at100),
            .at100
        )
    }

    func test_nextVariableThresholdToShow_doesNotRegress_toLowerTier() {
        // After hitting 100%, dipping back to 90% must not re-fire.
        XCTAssertNil(
            FinanceCalculator.nextVariableThresholdToShow(lastShown: .at100, newTier: .at90)
        )
    }

    func test_nextVariableThresholdToShow_neverShowsBelowTier() {
        XCTAssertNil(
            FinanceCalculator.nextVariableThresholdToShow(lastShown: nil, newTier: .below)
        )
    }

    // MARK: - 7. Fixed bills vs variable spending separation

    func test_isVariableTransaction_excludesFixedBills() {
        let rent = makeBudget(category: "Rent", planned: 900, type: .fixed, frequency: .monthly, dueDay: 1)
        let groceries = makeBudget(category: "Groceries", planned: 280, type: .variable)
        let budgetItems = [rent, groceries]

        let rentTxn = makeTxn(amount: 900, category: "Rent", type: .expense, day: 1)
        XCTAssertFalse(FinanceCalculator.isVariableTransaction(rentTxn, budgetItems: budgetItems))

        let groceriesTxn = makeTxn(amount: 60, category: "Groceries", type: .expense, day: 3)
        XCTAssertTrue(FinanceCalculator.isVariableTransaction(groceriesTxn, budgetItems: budgetItems))
    }

    func test_isVariableTransaction_excludesSavingsGoals() {
        let savings = makeBudget(category: "Tuition/Savings", planned: 300, type: .savings, frequency: .monthly, dueDay: 7)
        let savingsTxn = makeTxn(amount: 300, category: "Tuition/Savings", type: .expense, day: 7)
        XCTAssertFalse(FinanceCalculator.isVariableTransaction(savingsTxn, budgetItems: [savings]))
    }

    func test_variableSpendingProgress_includesOnlyVariableCategories() {
        let rent = makeBudget(category: "Rent", planned: 900, type: .fixed, frequency: .monthly, dueDay: 1)
        let phone = makeBudget(category: "Phone bill", planned: 35, type: .fixed, frequency: .monthly, dueDay: 15)
        let savings = makeBudget(category: "Tuition/Savings", planned: 300, type: .savings, frequency: .monthly, dueDay: 7)
        let groceries = makeBudget(category: "Groceries", planned: 280, type: .variable)
        let eatingOut = makeBudget(category: "Eating Out", planned: 140, type: .variable)
        let transport = makeBudget(category: "Transportation", planned: 120, type: .variable)
        let fun = makeBudget(category: "Fun", planned: 80, type: .variable)
        let shopping = makeBudget(category: "Shopping", planned: 90, type: .variable)
        let other = makeBudget(category: "Other", planned: 60, type: .variable)
        let budgetItems = [rent, phone, savings, groceries, eatingOut, transport, fun, shopping, other]

        let rows = FinanceCalculator.variableSpendingProgress(budgetItems: budgetItems, transactions: [])
        let categories = rows.map { $0.item.category }
        XCTAssertEqual(Set(categories), Set(["Groceries", "Eating Out", "Transportation", "Fun", "Shopping", "Other"]))
        XCTAssertFalse(categories.contains("Rent"))
        XCTAssertFalse(categories.contains("Phone bill"))
        XCTAssertFalse(categories.contains("Tuition/Savings"))
    }

    // MARK: - 8. Variable spending projection logic

    func test_projectedMonthEndVariableSpend_followsPaceFormula() {
        // 350 over 14 days, 30-day month → 350 / 14 * 30 = 750
        let projected = FinanceCalculator.projectedMonthEndVariableSpend(
            variableSpent: 350,
            daysElapsed: 14,
            daysInMonth: 30
        )
        XCTAssertEqual(projected, 750, accuracy: 0.0001)
    }

    func test_variableRisk_isOverBudgetRisk_whenProjectedExceedsBudget() {
        let risk = FinanceCalculator.variableRisk(
            projectedMonthEndSpend: 750,
            variableBudget: 600
        )
        XCTAssertEqual(risk, .overBudgetRisk)
    }

    func test_variableRisk_isWatch_whenProjectedBetween90And100PercentOfBudget() {
        // 600 * 0.95 = 570
        let risk = FinanceCalculator.variableRisk(
            projectedMonthEndSpend: 570,
            variableBudget: 600
        )
        XCTAssertEqual(risk, .watch)
    }

    func test_variableRisk_isWatch_atExactly100PercentOfBudget() {
        let risk = FinanceCalculator.variableRisk(projectedMonthEndSpend: 600, variableBudget: 600)
        XCTAssertEqual(risk, .watch)
    }

    func test_variableRisk_isOnTrack_whenProjectedBelow90PercentOfBudget() {
        // 600 * 0.85 = 510
        let risk = FinanceCalculator.variableRisk(
            projectedMonthEndSpend: 510,
            variableBudget: 600
        )
        XCTAssertEqual(risk, .onTrack)
    }

    func test_variableRisk_isOnTrack_whenBudgetIsZero() {
        let risk = FinanceCalculator.variableRisk(projectedMonthEndSpend: 200, variableBudget: 0)
        XCTAssertEqual(risk, .onTrack)
    }

    // MARK: - 9. Transaction filtering logic

    private func mixedTransactions() -> [TransactionItem] {
        [
            makeTxn(amount: 2000, category: "Paycheque", type: .income, day: 1),
            makeTxn(amount: 500, category: "Co-op", type: .income, day: 5),
            makeTxn(amount: 200, category: "Groceries", type: .expense, day: 2),
            makeTxn(amount: 80, category: "Eating Out", type: .expense, day: 4),
            makeTxn(amount: 60, category: "Transportation", type: .expense, day: 6, savedApplied: 10)
        ]
    }

    func test_filterAll_returnsBothIncomeAndExpenses() {
        let summary = FinanceCalculator.filterSummary(
            for: .all,
            transactions: mixedTransactions()
        )
        XCTAssertEqual(summary.totalIncome, 2500, accuracy: 0.0001)
        XCTAssertEqual(summary.totalExpenses, 200 + 80 + (60 - 10), accuracy: 0.0001)
        XCTAssertEqual(summary.net, 2500 - 330, accuracy: 0.0001)
        XCTAssertEqual(summary.netLabel, "Net")
    }

    func test_filterExpenses_summaryIncludesOnlyExpenses_andUsesFilteredNetLabel() {
        let expensesOnly = mixedTransactions().filter { $0.type == .expense }
        let summary = FinanceCalculator.filterSummary(for: .expenses, transactions: expensesOnly)
        XCTAssertEqual(summary.totalIncome, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.totalExpenses, 200 + 80 + (60 - 10), accuracy: 0.0001)
        XCTAssertEqual(summary.expenseCount, 3)
        XCTAssertEqual(summary.netLabel, "Filtered Net", "Filtered views must label net as Filtered Net")
        XCTAssertEqual(summary.averageExpenses, (200 + 80 + 50) / 3.0, accuracy: 0.0001)
    }

    func test_filterIncome_summaryShowsIncomeTotalAndCount() {
        let incomeOnly = mixedTransactions().filter { $0.type == .income }
        let summary = FinanceCalculator.filterSummary(for: .income, transactions: incomeOnly)
        XCTAssertEqual(summary.totalIncome, 2500, accuracy: 0.0001)
        XCTAssertEqual(summary.incomeCount, 2)
        XCTAssertEqual(summary.totalExpenses, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.netLabel, "Filtered Net")
        XCTAssertEqual(summary.averageIncome, 1250, accuracy: 0.0001)
    }

    // MARK: - 10. Daily transaction grouping

    func test_groupByDay_groupsTransactionsByCalendarDay() {
        let transactions = [
            makeTxn(amount: 2000, category: "Paycheque", type: .income, day: 1, createdHour: 9),
            makeTxn(amount: 50, category: "Groceries", type: .expense, day: 1, createdHour: 18),
            makeTxn(amount: 30, category: "Eating Out", type: .expense, day: 4, createdHour: 12)
        ]
        let groups = FinanceCalculator.groupTransactionsByDay(transactions, calendar: cal)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].transactions.count, 1) // day 4
        XCTAssertEqual(groups[1].transactions.count, 2) // day 1
    }

    func test_groupByDay_sortsGroupsNewestFirst() {
        let transactions = [
            makeTxn(amount: 10, category: "X", type: .expense, day: 1),
            makeTxn(amount: 10, category: "X", type: .expense, day: 5),
            makeTxn(amount: 10, category: "X", type: .expense, day: 3)
        ]
        let groups = FinanceCalculator.groupTransactionsByDay(transactions, calendar: cal)
        let days = groups.map { cal.component(.day, from: $0.date) }
        XCTAssertEqual(days, [5, 3, 1])
    }

    func test_groupByDay_sortsTransactionsWithinDay_newestCreatedAtFirst() {
        let earlyMorning = makeTxn(amount: 5, category: "Coffee", type: .expense, day: 2, createdHour: 7)
        let evening = makeTxn(amount: 25, category: "Dinner", type: .expense, day: 2, createdHour: 19)
        let lunch = makeTxn(amount: 12, category: "Lunch", type: .expense, day: 2, createdHour: 12)

        let groups = FinanceCalculator.groupTransactionsByDay([earlyMorning, evening, lunch], calendar: cal)
        XCTAssertEqual(groups.count, 1)
        let ordered = groups[0].transactions.map(\.category)
        XCTAssertEqual(ordered, ["Dinner", "Lunch", "Coffee"])
    }

    func test_groupByDay_dailySummaryComputesIncomeExpensesAndNet() {
        let transactions = [
            makeTxn(amount: 100, category: "Gift", type: .income, day: 6),
            makeTxn(amount: 30, category: "Groceries", type: .expense, day: 6),
            makeTxn(amount: 20, category: "Transportation", type: .expense, day: 6, savedApplied: 5)
        ]
        let groups = FinanceCalculator.groupTransactionsByDay(transactions, calendar: cal)
        XCTAssertEqual(groups.count, 1)
        let group = groups[0]
        XCTAssertEqual(group.income, 100, accuracy: 0.0001)
        XCTAssertEqual(group.expenses, 30 + 15, accuracy: 0.0001)
        XCTAssertEqual(group.net, 100 - 45, accuracy: 0.0001)
    }
}

// MARK: - In-memory test infrastructure

/// Repository that never reads or writes anything. Lets us instantiate `AppState` with an
/// empty/known state without polluting `UserDefaults`.
private final class InMemoryAppRepository: AppRepository {
    func loadBudgetItems() -> [BudgetItem]? { nil }
    func saveBudgetItems(_ items: [BudgetItem]) {}
    func loadTransactions() -> [TransactionItem]? { nil }
    func saveTransactions(_ items: [TransactionItem]) {}
    func loadSnapshot() -> PersistedState? { nil }
    func saveSnapshot(_ snapshot: PersistedState) {}
}

@MainActor
private extension FinanceCalculatorTests {
    /// Fresh `AppState` with no persistence, ready to be populated for stateful tests.
    func makeIsolatedAppState() -> AppState {
        let state = AppState(repository: InMemoryAppRepository())
        state.budgetItems = []
        state.transactions = []
        state.availableToBudgetByMonth = [:]
        state.fixedBillPaymentTransactionIdsByMonth = [:]
        state.hiddenBudgetItemIdsByMonth = [:]
        state.pendingIncomePrompt = nil
        state.pendingUndo = nil
        return state
    }
}
