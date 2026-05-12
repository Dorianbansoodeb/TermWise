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

    /// Test helper — defaults `expectedFixedBillsThisMonth` and `unpaidFixedBillsRemaining`
    /// to `0` so legacy tests don't have to thread new parameters through every call. Tests
    /// that exercise the fixed-bill behavior pass them explicitly.
    private func evaluateTotal(
        transactions: [TransactionItem],
        availableToBudget: Double,
        savingsTarget: Double,
        variableSpentSoFar: Double,
        expectedFixedBillsThisMonth: Double = 0,
        unpaidFixedBillsRemaining: Double = 0,
        currentDayOfMonth: Int,
        daysInMonth: Int,
        now: Date? = nil
    ) -> TotalSpendingPace.Result {
        TotalSpendingPace.evaluate(
            transactions: transactions,
            availableToBudget: availableToBudget,
            savingsTarget: savingsTarget,
            variableSpentSoFar: variableSpentSoFar,
            expectedFixedBillsThisMonth: expectedFixedBillsThisMonth,
            unpaidFixedBillsRemaining: unpaidFixedBillsRemaining,
            currentDayOfMonth: currentDayOfMonth,
            daysInMonth: daysInMonth,
            calendar: cal,
            now: now ?? refDate
        )
    }

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

    // MARK: - Savings target (Budget Plan)

    func test_savingsTarget_rateBased_returnsAvailableTimesRate() {
        let target = FinanceCalculator.savingsTarget(availableToBudget: 2020, rate: 15)
        XCTAssertEqual(target, 303, accuracy: 0.0001)
    }

    func test_savingsTarget_zeroRate_returnsZero() {
        XCTAssertEqual(FinanceCalculator.savingsTarget(availableToBudget: 2020, rate: 0), 0, accuracy: 0.0001)
    }

    func test_savingsTarget_rateAboveOneHundred_isClampedAtOneHundred() {
        let target = FinanceCalculator.savingsTarget(availableToBudget: 1000, rate: 250)
        XCTAssertEqual(target, 1000, accuracy: 0.0001)
    }

    func test_savingsTarget_negativeAvailable_isClampedAtZero() {
        XCTAssertEqual(FinanceCalculator.savingsTarget(availableToBudget: -500, rate: 15), 0, accuracy: 0.0001)
    }

    func test_savingsTarget_customAmount_winsOverRate() {
        let target = FinanceCalculator.savingsTarget(availableToBudget: 2020, rate: 15, customAmount: 500)
        XCTAssertEqual(target, 500, accuracy: 0.0001, "Custom dollar amount must override the rate-based calc")
    }

    func test_savingsTarget_customAmount_negativeIsClampedAtZero() {
        let target = FinanceCalculator.savingsTarget(availableToBudget: 2020, rate: 15, customAmount: -50)
        XCTAssertEqual(target, 0, accuracy: 0.0001)
    }

    // MARK: - Total budgeted with savings target

    func test_totalBudgeted_withDefaultSavingsTarget_isUnchangedFromItemSum() {
        let items = [
            makeBudget(category: "Rent", planned: 900, type: .fixed),
            makeBudget(category: "Groceries", planned: 280, type: .variable)
        ]
        let total = FinanceBudgetAllocation.calculateTotalBudgeted(
            budgetItems: items,
            hiddenBudgetItemIds: []
        )
        XCTAssertEqual(total, 1180, accuracy: 0.0001)
    }

    func test_totalBudgeted_addsSavingsTargetOnTopOfPlannedItems() {
        let items = [
            makeBudget(category: "Rent", planned: 900, type: .fixed),
            makeBudget(category: "Groceries", planned: 280, type: .variable)
        ]
        let total = FinanceBudgetAllocation.calculateTotalBudgeted(
            budgetItems: items,
            hiddenBudgetItemIds: [],
            savingsTarget: 303
        )
        XCTAssertEqual(total, 1180 + 303, accuracy: 0.0001)
    }

    func test_totalBudgeted_negativeSavingsTarget_isClampedAtZero() {
        let items = [makeBudget(category: "Rent", planned: 900, type: .fixed)]
        let total = FinanceBudgetAllocation.calculateTotalBudgeted(
            budgetItems: items,
            hiddenBudgetItemIds: [],
            savingsTarget: -200
        )
        XCTAssertEqual(total, 900, accuracy: 0.0001)
    }

    // MARK: - AppState wiring (stateful)

    @MainActor
    func test_appState_savingsTargetThisMonth_defaultsToFifteenPercent() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0 // ignore the legacy fallback
        state.setAvailableToBudgetForCurrentMonth(2000)
        // desiredSavingsRate already defaults to 15.
        XCTAssertEqual(state.savingsTargetThisMonth, 300, accuracy: 0.0001)
    }

    @MainActor
    func test_appState_setSavingsRate_clearsCustomOverride_andRecomputesTarget() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        state.setAvailableToBudgetForCurrentMonth(2000)
        state.setCustomSavingsTargetForCurrentMonth(750)
        XCTAssertEqual(state.savingsTargetThisMonth, 750, accuracy: 0.0001)

        state.setSavingsRate(20)
        XCTAssertNil(state.customSavingsTargetByMonth[state.currentMonthKey], "Setting a standard rate must drop the custom override")
        XCTAssertEqual(state.savingsTargetThisMonth, 400, accuracy: 0.0001)
    }

    @MainActor
    func test_appState_customOverride_winsOverRate() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        state.setAvailableToBudgetForCurrentMonth(2000)
        state.setSavingsRate(15)
        XCTAssertEqual(state.savingsTargetThisMonth, 300, accuracy: 0.0001)

        state.setCustomSavingsTargetForCurrentMonth(425)
        XCTAssertEqual(state.savingsTargetThisMonth, 425, accuracy: 0.0001)
    }

    @MainActor
    func test_appState_clearCustomOverride_fallsBackToRate() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        state.setAvailableToBudgetForCurrentMonth(2000)
        state.setSavingsRate(10)
        state.setCustomSavingsTargetForCurrentMonth(900)
        XCTAssertEqual(state.savingsTargetThisMonth, 900, accuracy: 0.0001)

        state.clearCustomSavingsTargetForCurrentMonth()
        XCTAssertEqual(state.savingsTargetThisMonth, 200, accuracy: 0.0001)
    }

    @MainActor
    func test_appState_totalBudgeted_includesSavingsTargetThisMonth() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        state.setAvailableToBudgetForCurrentMonth(2000)
        state.budgetItems = [
            makeBudget(category: "Rent", planned: 900, type: .fixed),
            makeBudget(category: "Groceries", planned: 280, type: .variable)
        ]
        state.setSavingsRate(15)
        // 900 + 280 + 0.15 * 2000 = 1480
        XCTAssertEqual(state.totalBudgeted, 1480, accuracy: 0.0001)
    }

    @MainActor
    func test_appState_changingSavingsRate_immediatelyUpdatesTotalBudgeted() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        state.setAvailableToBudgetForCurrentMonth(1000)
        state.budgetItems = [makeBudget(category: "Rent", planned: 500, type: .fixed)]
        state.setSavingsRate(10)
        XCTAssertEqual(state.totalBudgeted, 600, accuracy: 0.0001) // 500 + 100

        state.setSavingsRate(20)
        XCTAssertEqual(state.totalBudgeted, 700, accuracy: 0.0001) // 500 + 200
    }

    // MARK: - Income prompt + "Total Income is informational only" invariants
    //
    // The budgeting model promises:
    //   • Total Income never silently controls Available to Budget once the user has expressed any
    //     intent (an explicit edit OR going through the income prompt).
    //   • Default behavior on first launch / demo data: when no override is set yet,
    //     `availableToBudget` derives from `totalIncome`.
    //   • The income prompt offers two outcomes: "Add to Available Budget" (envelope grows by the
    //     income amount) or "Keep as Reserve" (envelope stays put, Reserve grows).

    @MainActor
    func test_availableToBudget_defaultsToTotalIncome_whenNoOverrideExists() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        // Seed a single income transaction in the current month.
        let now = Date()
        state.transactions = [
            TransactionItem(id: UUID(), amount: 1020, category: "Paycheque", note: "", date: now, type: .income)
        ]
        XCTAssertNil(state.availableToBudgetByMonth[state.currentMonthKey], "No override should exist on a fresh state")
        XCTAssertEqual(state.availableToBudget, 1020, accuracy: 0.0001)
        XCTAssertEqual(state.totalIncome, 1020, accuracy: 0.0001)
    }

    @MainActor
    func test_availableToBudget_locksIn_onceUserEditsIt() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        let now = Date()
        state.transactions = [
            TransactionItem(id: UUID(), amount: 1000, category: "Paycheque", note: "", date: now, type: .income)
        ]
        // User edits Available to Budget to a value lower than income.
        state.setAvailableToBudgetForCurrentMonth(800)

        // Adding a new income transaction (without going through the prompt) must NOT auto-grow
        // the envelope. The override wins.
        state.transactions.insert(
            TransactionItem(id: UUID(), amount: 500, category: "Gift", note: "", date: now, type: .income),
            at: 0
        )
        XCTAssertEqual(state.totalIncome, 1500, accuracy: 0.0001)
        XCTAssertEqual(state.availableToBudget, 800, accuracy: 0.0001, "Once locked in, Available to Budget never silently follows income")
        // Reserve = totalIncome - availableToBudget.
        XCTAssertEqual(state.reserveNotBudgeted, 700, accuracy: 0.0001)
    }

    @MainActor
    func test_addIncomeAndPromptIfNeeded_snapshotsAvailableToBudget_beforeAddingIncome() throws {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        // Pre-existing income makes derived Available to Budget = $1,000.
        let now = Date()
        state.transactions = [
            TransactionItem(id: UUID(), amount: 1000, category: "Paycheque", note: "", date: now, type: .income)
        ]
        XCTAssertNil(state.availableToBudgetByMonth[state.currentMonthKey])
        XCTAssertEqual(state.availableToBudget, 1000, accuracy: 0.0001)

        // Add new income via the prompt path. The override must be locked in BEFORE the new
        // transaction lands, so adding income never silently grows the envelope.
        _ = state.addIncomeAndPromptIfNeeded(amount: 500, category: "Gift", note: "")

        XCTAssertNotNil(state.pendingIncomePrompt)
        let snapshotted = try XCTUnwrap(state.availableToBudgetByMonth[state.currentMonthKey], "snapshot must be set after addIncomeAndPromptIfNeeded")
        XCTAssertEqual(snapshotted, 1000, accuracy: 0.0001, "snapshot must capture pre-income value")
        XCTAssertEqual(state.availableToBudget, 1000, accuracy: 0.0001, "Adding income alone never grows the envelope")
        XCTAssertEqual(state.totalIncome, 1500, accuracy: 0.0001)
    }

    @MainActor
    func test_confirmAddIncomeToBudget_growsAvailableToBudgetByExactlyIncomeAmount() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        let now = Date()
        state.transactions = [
            TransactionItem(id: UUID(), amount: 1000, category: "Paycheque", note: "", date: now, type: .income)
        ]
        _ = state.addIncomeAndPromptIfNeeded(amount: 500, category: "Gift", note: "")

        state.confirmAddIncomeToBudget()

        XCTAssertNil(state.pendingIncomePrompt)
        XCTAssertEqual(state.availableToBudget, 1500, accuracy: 0.0001, "Confirming must grow Available to Budget by the income amount")
        XCTAssertEqual(state.totalIncome, 1500, accuracy: 0.0001)
        XCTAssertEqual(state.reserveNotBudgeted, 0, accuracy: 0.0001)
    }

    @MainActor
    func test_keepIncomeAsReserve_doesNotChangeAvailableToBudget() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        let now = Date()
        state.transactions = [
            TransactionItem(id: UUID(), amount: 1000, category: "Paycheque", note: "", date: now, type: .income)
        ]
        _ = state.addIncomeAndPromptIfNeeded(amount: 500, category: "Gift", note: "")

        state.keepIncomeAsReserve()

        XCTAssertNil(state.pendingIncomePrompt)
        XCTAssertEqual(state.availableToBudget, 1000, accuracy: 0.0001, "Keep-as-Reserve must leave the envelope unchanged")
        XCTAssertEqual(state.totalIncome, 1500, accuracy: 0.0001)
        XCTAssertEqual(state.reserveNotBudgeted, 500, accuracy: 0.0001, "Reserve must absorb the new income")
    }

    @MainActor
    func test_dismissIncomePrompt_isEquivalentToKeepAsReserve_forBudgetMath() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        let now = Date()
        state.transactions = [
            TransactionItem(id: UUID(), amount: 1000, category: "Paycheque", note: "", date: now, type: .income)
        ]
        _ = state.addIncomeAndPromptIfNeeded(amount: 500, category: "Gift", note: "")

        state.dismissIncomePrompt()

        XCTAssertNil(state.pendingIncomePrompt)
        XCTAssertEqual(state.availableToBudget, 1000, accuracy: 0.0001)
        XCTAssertEqual(state.reserveNotBudgeted, 500, accuracy: 0.0001)
    }

    @MainActor
    func test_savingsTarget_alwaysFollowsAvailableToBudget_notTotalIncome() {
        let state = makeIsolatedAppState()
        state.monthlyIncome = 0
        let now = Date()
        state.transactions = [
            TransactionItem(id: UUID(), amount: 5000, category: "Co-op", note: "", date: now, type: .income)
        ]
        state.setSavingsRate(15)
        // User keeps a much smaller envelope than their income.
        state.setAvailableToBudgetForCurrentMonth(1600)
        XCTAssertEqual(state.totalIncome, 5000, accuracy: 0.0001)
        XCTAssertEqual(state.savingsTargetThisMonth, 240, accuracy: 0.0001, "Savings target must use Available to Budget × rate, not Total Income")

        // Bumping Available to Budget recomputes the target deterministically.
        state.setAvailableToBudgetForCurrentMonth(2020)
        XCTAssertEqual(state.savingsTargetThisMonth, 303, accuracy: 0.0001)
    }

    // MARK: - Usable budget after savings + spending trend tooltip contract

    func test_usableBudgetAfterSavings_matchesAvailableMinusSavingsTarget() {
        XCTAssertEqual(
            FinanceCalculator.usableBudgetAfterSavings(availableToBudget: 1000, savingsTarget: 150),
            850,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            FinanceCalculator.usableBudgetAfterSavings(availableToBudget: 1000, savingsTarget: 1200),
            0,
            accuracy: 0.0001
        )
    }

    // Tooltip is context-sensitive: past/today shows Actual (no Projected); future shows
    // Projected (no Actual). Variable mode adds Budget Pace; Total mode includes Available to
    // Budget in the callout per dashboard spec; Spend Limit is chart-only.

    func test_spendingTrend_tooltip_variable_past_showsActual_notProjected() {
        let titles = FinanceCalculator.spendingTrendVariableTooltipRowTitlesPast
        XCTAssertEqual(titles, ["Actual", "Budget Pace"])
        XCTAssertTrue(titles.contains("Actual"))
        XCTAssertFalse(titles.contains("Projected"))
        XCTAssertFalse(titles.contains(where: { $0.localizedCaseInsensitiveContains("Savings") }))
    }

    func test_spendingTrend_tooltip_variable_future_showsProjected_notActual() {
        let titles = FinanceCalculator.spendingTrendVariableTooltipRowTitlesFuture
        XCTAssertEqual(titles, ["Projected", "Budget Pace"])
        XCTAssertTrue(titles.contains("Projected"))
        XCTAssertFalse(titles.contains("Actual"))
    }

    func test_spendingTrend_tooltip_total_past_showsActualAndAvailable_neverSpendLimitOrSavings() {
        let titles = FinanceCalculator.spendingTrendTotalTooltipRowTitlesPast
        XCTAssertEqual(titles, ["Actual", "Available to Budget"])
        XCTAssertTrue(titles.contains("Actual"))
        XCTAssertTrue(titles.contains("Available to Budget"))
        XCTAssertFalse(titles.contains(where: { $0.localizedCaseInsensitiveContains("Spend Limit") }))
        XCTAssertFalse(titles.contains("Projected"))
        XCTAssertFalse(titles.contains(where: { $0.localizedCaseInsensitiveContains("Savings") }))
    }

    func test_spendingTrend_tooltip_total_future_showsFullBreakdown_neverSpendLimit() {
        let titles = FinanceCalculator.spendingTrendTotalTooltipRowTitlesFuture
        XCTAssertEqual(
            titles,
            [
                "Projected total spending",
                "Projected variable spending",
                "Remaining fixed bills",
                "Available to Budget"
            ]
        )
        XCTAssertFalse(titles.contains(where: { $0.localizedCaseInsensitiveContains("Spend Limit") }))
        XCTAssertFalse(titles.contains("Actual"))
        XCTAssertFalse(titles.contains(where: { $0.localizedCaseInsensitiveContains("Savings") }))
    }

    // MARK: - Total spending pace (Total Spending Trend chart mode)
    //
    // Definitions (single source of truth):
    //   spendLimit                 = max(0, availableToBudget − savingsTarget)
    //   variableDailyRate          = variableSpentSoFar / daysElapsed
    //   futureVariableProjection   = variableDailyRate × daysRemaining
    //   projectedVariableMonthEnd  = variableDailyRate × daysInMonth
    //   projectedMonthEnd          = totalSpent
    //                              + futureVariableProjection
    //                              + unpaidFixedBillsRemaining
    //
    // Fixed bills are ALWAYS treated as expected for the month, so paying rent doesn't move the
    // projection up. The two equivalent formulations:
    //   projectedMonthEnd ≈ projectedVariableMonthEnd + expectedFixedBillsThisMonth
    //   projectedMonthEnd  = totalSpent + futureVariableProjection + unpaidFixedBillsRemaining
    // (≈ becomes = when no fixed bill is overpaid, since unpaidFixedBillsRemaining is clamped
    // at zero per bill.)
    //
    // Status (3-state, projection vs **two thresholds**):
    //   - Over Budget if projected > availableToBudget
    //   - Near Limit  if spendLimit < projected ≤ availableToBudget
    //   - On Track    if projected ≤ spendLimit
    //
    // Result amounts:
    //   - projectedOverAvailableByAmount = max(0, projected − availableToBudget)
    //     → primary red copy ("Projected to exceed your monthly budget by $X across all
    //     expenses.").
    //   - projectedOverBudgetByAmount    = max(0, projected − spendLimit)
    //     → secondary orange copy ("Projected to use money reserved for savings by $X.").
    //
    // Visual mapping (Dashboard, not asserted in this file):
    //   Gray dashed line → availableToBudget  (label: "Available $X")
    //   Green line       → spendLimit          (label: "Spend Limit $X")
    //   Red dashed line  → projectedMonthEnd   (label: "Projected")

    func test_totalSpendingPace_totalSpent_includesAllExpenseCategories() {
        let transactions = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1),
            makeTxn(amount: 60, category: "Groceries", type: .expense, day: 3),
            makeTxn(amount: 35, category: "Phone bill", type: .expense, day: 4),
            makeTxn(amount: 300, category: "Tuition/Savings", type: .expense, day: 7)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 2000,
            savingsTarget: 0,
            variableSpentSoFar: 60, // only Groceries is variable here
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.totalSpent, 1295, accuracy: 0.0001, "Fixed + variable + savings all count")
    }

    func test_totalSpendingPace_ignoresIncomeTransactions() {
        let transactions = [
            makeTxn(amount: 2000, category: "Paycheque", type: .income, day: 1),
            makeTxn(amount: 100, category: "Groceries", type: .expense, day: 3)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1000,
            savingsTarget: 0,
            variableSpentSoFar: 100,
            currentDayOfMonth: 5,
            daysInMonth: 31
        )
        XCTAssertEqual(result.totalSpent, 100, accuracy: 0.0001)
    }

    func test_totalSpendingPace_ignoresTransactionsOutsideCurrentMonth() {
        let aprilTxn = TransactionItem(
            id: UUID(),
            amount: 999,
            category: "Rent",
            note: "",
            date: cal.date(from: DateComponents(year: 2026, month: 4, day: 30))!,
            createdAt: refDate,
            type: .expense,
            savedApplied: 0
        )
        let mayTxn = makeTxn(amount: 100, category: "Groceries", type: .expense, day: 5)
        let result = evaluateTotal(
            transactions: [aprilTxn, mayTxn],
            availableToBudget: 1000,
            savingsTarget: 0,
            variableSpentSoFar: 100,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.totalSpent, 100, accuracy: 0.0001)
    }

    func test_totalSpendingPace_spendLimit_subtractsSavingsTarget_fromAvailable() {
        let result = evaluateTotal(
            transactions: [],
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 0,
            currentDayOfMonth: 15,
            daysInMonth: 30
        )
        XCTAssertEqual(result.spendLimit, 850, accuracy: 0.0001)
        XCTAssertEqual(
            result.spendLimit,
            FinanceCalculator.usableBudgetAfterSavings(availableToBudget: 1000, savingsTarget: 150),
            accuracy: 0.0001
        )
    }

    /// User example: Available $1,600 − Savings $240 = Spend Limit $1,360.
    func test_totalSpendingPace_protectedSpendLimit_isAvailableMinusSavingsTarget_userExample() {
        let result = evaluateTotal(
            transactions: [],
            availableToBudget: 1600,
            savingsTarget: 240,
            variableSpentSoFar: 0,
            currentDayOfMonth: 15,
            daysInMonth: 30
        )
        XCTAssertEqual(result.availableToBudget, 1600, accuracy: 0.0001, "Gray dashed line value")
        XCTAssertEqual(result.spendLimit, 1360, accuracy: 0.0001, "Green line value (= protected spend limit)")
        XCTAssertEqual(result.spendLimit, result.availableToBudget - result.savingsTarget, accuracy: 0.0001)
    }

    func test_totalSpendingPace_isOnTrack_whenProjectedAtOrBelowSpendLimit() {
        // spendLimit 850, daysRemaining 16. variableSpent 400 → rate ≈ 26.67
        // → projected = 400 + 26.67 × 16 ≈ 826.67 ≤ 850 → onTrack (within savings-protected limit)
        let transactions = [
            makeTxn(amount: 400, category: "Groceries", type: .expense, day: 1)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 400,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.spendLimit, 850, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(result.projectedMonthEndSpend, 850)
        XCTAssertEqual(result.status, .onTrack)
        XCTAssertEqual(result.projectedOverAvailableByAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(result.projectedOverBudgetByAmount, 0, accuracy: 0.0001)
    }

    func test_totalSpendingPace_isNearLimit_whenProjectedBetweenSpendLimitAndAvailable() {
        // variableSpent 450 → rate = 30 → projected = 450 + 30 × 16 = 930
        // spendLimit 850, available 1000 → 850 < 930 ≤ 1000 → nearLimit
        let transactions = [
            makeTxn(amount: 450, category: "Groceries", type: .expense, day: 1)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 450,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.spendLimit, 850, accuracy: 0.0001)
        XCTAssertEqual(result.projectedMonthEndSpend, 930, accuracy: 0.0001)
        XCTAssertGreaterThan(result.projectedMonthEndSpend, 850)
        XCTAssertLessThanOrEqual(result.projectedMonthEndSpend, 1000)
        XCTAssertEqual(result.status, .nearLimit)
        XCTAssertEqual(result.projectedOverBudgetByAmount, 80, accuracy: 0.0001,
                       "Orange copy: projected − spendLimit (= 930 − 850)")
        XCTAssertEqual(result.projectedOverAvailableByAmount, 0, accuracy: 0.0001,
                       "Not over Available yet — primary red copy stays hidden")
    }

    func test_totalSpendingPace_isOverBudget_whenProjectedExceedsAvailableToBudget() {
        // variableSpent 600 → rate = 40 → projected = 600 + 40 × 16 = 1240 > 1000
        let transactions = [
            makeTxn(amount: 600, category: "Groceries", type: .expense, day: 1)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 600,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.projectedMonthEndSpend, 1240, accuracy: 0.0001)
        XCTAssertGreaterThan(result.projectedMonthEndSpend, result.availableToBudget,
                             "Over Budget threshold compares against availableToBudget, not spendLimit")
        XCTAssertEqual(result.status, .overBudget)
        XCTAssertEqual(result.projectedOverAvailableByAmount, 240, accuracy: 0.0001,
                       "Red copy: projected − availableToBudget (= 1240 − 1000)")
        XCTAssertEqual(result.projectedOverBudgetByAmount, 390, accuracy: 0.0001,
                       "Spend-limit overshoot still reported as a separate amount")
    }

    /// Three states cover the full real line: any projection falls into exactly one.
    func test_totalSpendingPace_threeStateBoundaries_useAvailableAsTheOuterCap() {
        // available 1000, savings 150 → spendLimit 850. Pin projection by tweaking variableSpent.
        // Day 15/31 → projected = vs + (vs/15)*16 = vs * 31 / 15.
        // vs = 411.29 → projected ≈ 850 (boundary onTrack/nearLimit)
        // vs = 483.87 → projected ≈ 1000 (boundary nearLimit/overBudget)
        let make: (Double) -> TotalSpendingPace.Result = { vs in
            self.evaluateTotal(
                transactions: [self.makeTxn(amount: vs, category: "Groceries", type: .expense, day: 1)],
                availableToBudget: 1000,
                savingsTarget: 150,
                variableSpentSoFar: vs,
                currentDayOfMonth: 15,
                daysInMonth: 31
            )
        }
        XCTAssertEqual(make(411).status, .onTrack,    "projected ≤ spendLimit")
        XCTAssertEqual(make(412).status, .nearLimit,  "spendLimit < projected ≤ available")
        XCTAssertEqual(make(484).status, .overBudget, "projected > available")
    }

    /// **Critical regression**: rent paid once on day 1 must not be linearly projected forward.
    /// Old behavior: $900 / 5 × 31 = $5,580 (wrong). New behavior anchors at $900 + 0 × 26 = $900.
    func test_totalSpendingPace_projection_doesNotMultiplyFixedBillsAcrossTheMonth() {
        let transactions = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1)
        ]
        let day5 = cal.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 12))!
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 2000,
            savingsTarget: 0,
            variableSpentSoFar: 0, // rent is fixed → no variable burn rate
            currentDayOfMonth: 5,
            daysInMonth: 31,
            now: day5
        )
        XCTAssertEqual(result.totalSpent, 900, accuracy: 0.0001)
        XCTAssertEqual(result.projectedMonthEndSpend, 900, accuracy: 0.0001,
                       "Fixed bills paid once must not extrapolate across the month")
        XCTAssertNotEqual(result.projectedMonthEndSpend, 900.0 / 5.0 * 31.0, "Old wrong formula")
    }

    /// Slope is **variableDailyRate**, anchored at `totalSpent`.
    /// totalSpent 1100 (rent 900 + groceries 200), day 5/30, variable 200, remaining 25
    /// → projected = 1100 + (200/5) × 25 = 1100 + 1000 = 2100
    func test_totalSpendingPace_projection_anchorsAtTotalSpent_andSlopesByVariableRateOnly() {
        let transactions = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1),
            makeTxn(amount: 200, category: "Groceries", type: .expense, day: 3)
        ]
        let day5 = cal.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 12))!
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 5000,
            savingsTarget: 0,
            variableSpentSoFar: 200,
            currentDayOfMonth: 5,
            daysInMonth: 30,
            now: day5
        )
        XCTAssertEqual(result.totalSpent, 1100, accuracy: 0.0001)
        XCTAssertEqual(result.projectedMonthEndSpend, 2100, accuracy: 0.0001)
        XCTAssertEqual(result.variableSpentSoFar, 200, accuracy: 0.0001)
    }

    func test_totalSpendingPace_overBudgetByAmount_usesActual_minusSpendLimit() {
        // actual 1402 already exceeds spendLimit (850) — surfaces the "Over spend limit by $X" copy
        let transactions = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1),
            makeTxn(amount: 502, category: "Groceries", type: .expense, day: 3)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 502,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.spendLimit, 850, accuracy: 0.0001)
        XCTAssertEqual(result.totalSpent, 1402, accuracy: 0.0001)
        XCTAssertEqual(result.status, .overBudget)
        XCTAssertEqual(result.overBudgetByAmount, 552, accuracy: 0.0001, "actual − spendLimit")
    }

    func test_totalSpendingPace_projectedOverBudgetByAmount_usesProjected_minusSpendLimit() {
        // variableSpent 500 day 15/31 → projected ≈ 1033.33; spendLimit 850 → projected over by ≈ 183.33
        let transactions = [
            makeTxn(amount: 500, category: "Groceries", type: .expense, day: 1)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 500,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.projectedOverBudgetByAmount, result.projectedMonthEndSpend - 850, accuracy: 0.0001)
        XCTAssertGreaterThan(result.projectedOverBudgetByAmount, 0)
        // Actual ($500) is still below spendLimit ($850) → no "Over spend limit by" copy yet.
        XCTAssertEqual(result.overBudgetByAmount, 0, accuracy: 0.0001)
    }

    func test_totalSpendingPace_canBeOnTrack_whenHighAbsoluteSpend_butProjectedBelowSpendLimit() {
        // total $1402 (rent + groceries), spendLimit 4500. With variableSpent = $502:
        // projected = 1402 + (502/15) × 16 ≈ 1937.47, well below 4500.
        let transactions = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1),
            makeTxn(amount: 502, category: "Groceries", type: .expense, day: 3)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 5000,
            savingsTarget: 500,
            variableSpentSoFar: 502,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.spendLimit, 4500, accuracy: 0.0001)
        XCTAssertEqual(result.totalSpent, 1402, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(result.projectedMonthEndSpend, 4500)
        XCTAssertEqual(result.status, .onTrack)
    }

    /// $900 rent only, no variable burn → projected = $900. With available $1,000 and savings
    /// $150 (spendLimit $850), the projection sits **between** spendLimit and available, so the
    /// status is `.nearLimit`, not `.overBudget`.
    func test_totalSpendingPace_isNearLimit_whenProjectedExceedsSpendLimit_butNotAvailable() {
        let transactions = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 0,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.spendLimit, 850, accuracy: 0.0001)
        XCTAssertEqual(result.projectedMonthEndSpend, 900, accuracy: 0.0001)
        XCTAssertEqual(result.status, .nearLimit, "Projected $900 ≤ available $1000 → not Over Budget")
        XCTAssertEqual(result.projectedOverBudgetByAmount, 50, accuracy: 0.0001, "= projected − spendLimit")
        XCTAssertEqual(result.projectedOverAvailableByAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(result.overBudgetByAmount, 50, accuracy: 0.0001, "= actual − spendLimit (kept for reporting)")
    }

    func test_totalSpendingPace_notOnTrack_whenVariableWouldBeRisky_butTotalProjectedUnderSpendLimit() {
        let variableRisk = VariableSpendingPace.evaluate(
            budgetItems: [
                makeBudget(category: "Groceries", planned: 600, type: .variable),
                makeBudget(category: "Rent", planned: 900, type: .fixed, frequency: .monthly, dueDay: 1)
            ],
            transactions: [
                makeTxn(amount: 550, category: "Groceries", type: .expense, day: 3)
            ],
            currentDayOfMonth: 15,
            daysInMonth: 31,
            calendar: cal,
            now: refDate
        )
        let totalStatus = evaluateTotal(
            transactions: [
                makeTxn(amount: 550, category: "Groceries", type: .expense, day: 3)
            ],
            availableToBudget: 5000,
            savingsTarget: 500,
            variableSpentSoFar: 550,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(variableRisk.status, .overBudgetRisk, "Projected variable burn exceeds flexible budget")
        XCTAssertEqual(totalStatus.status, .onTrack, "Total projected under spend limit $4500 — still on track")
    }

    func test_totalSpendingPace_clampsNegativeAvailable_andFlagsSpendWhenSpendLimitIsZero() {
        let transactions = [
            makeTxn(amount: 50, category: "Eating Out", type: .expense, day: 4)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: -100,
            savingsTarget: 0,
            variableSpentSoFar: 50,
            currentDayOfMonth: 5,
            daysInMonth: 31
        )
        XCTAssertEqual(result.availableToBudget, 0, accuracy: 0.0001)
        XCTAssertEqual(result.spendLimit, 0, accuracy: 0.0001)
        XCTAssertEqual(result.status, .overBudget)
    }

    /// All-variable scenario with no fixed bills: formula collapses to the variable formula,
    /// since `totalSpent + variableRate × daysRemaining + 0 = variableSpent / daysElapsed × daysInMonth`
    /// when totalSpent equals variableSpent.
    func test_totalSpendingPace_projection_matchesVariableFormula_whenAllSpendingIsVariable() {
        let transactions = (1...5).map { day in
            makeTxn(amount: 100, category: "Groceries", type: .expense, day: day)
        }
        let day5 = cal.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 12))!
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 2000,
            savingsTarget: 0,
            variableSpentSoFar: 500,
            currentDayOfMonth: 5,
            daysInMonth: 31,
            now: day5
        )
        XCTAssertEqual(result.projectedMonthEndSpend, 3100, accuracy: 0.0001)
        XCTAssertEqual(result.projectedMonthEndSpend, 500.0 / 5.0 * 31.0, accuracy: 0.0001)
    }

    func test_totalSpendingPace_expectedSpentByToday_isProRatedSpendLimit() {
        let result = evaluateTotal(
            transactions: [],
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 0,
            currentDayOfMonth: 15,
            daysInMonth: 30
        )
        XCTAssertEqual(result.expectedSpentByToday, 425, accuracy: 0.0001)
    }

    /// Variable Spending Trend projection stays at the simpler formula.
    func test_variableSpendingPace_projection_usesSpentDividedByDaysElapsedTimesDaysInMonth() {
        let txns = (1...5).map { makeTxn(amount: 100, category: "Groceries", type: .expense, day: $0) }
        let day5 = cal.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 12))!
        let variable = VariableSpendingPace.evaluate(
            budgetItems: [makeBudget(category: "Groceries", planned: 1000, type: .variable)],
            transactions: txns,
            currentDayOfMonth: 5,
            daysInMonth: 30,
            calendar: cal,
            now: day5
        )
        XCTAssertEqual(variable.projectedMonthEndSpend, 500.0 / 5.0 * 30.0, accuracy: 0.0001)
    }

    /// Documents the chart line semantics. Gray = `availableToBudget` (label "Available $X"),
    /// Green = `spendLimit` (label "Spend Limit $X"). Red dashed = `projectedMonthEndSpend`.
    func test_totalSpendingPace_chartLineSemantics_grayIsAvailable_greenIsSpendLimit() {
        let result = evaluateTotal(
            transactions: [],
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 0,
            currentDayOfMonth: 15,
            daysInMonth: 30
        )
        XCTAssertEqual(result.availableToBudget, 1800, accuracy: 0.0001, "Gray dashed line value")
        XCTAssertEqual(result.spendLimit, 1560, accuracy: 0.0001, "Green line value (= protected spend limit)")
        XCTAssertNotEqual(result.spendLimit, result.savingsTarget, "Green line is NOT the savings target")
        XCTAssertEqual(result.spendLimit, result.availableToBudget - result.savingsTarget, accuracy: 0.0001)
    }

    /// **Primary** over-budget metric — compares projected total against `availableToBudget`,
    /// not `spendLimit`. Powers the red "Projected to exceed your monthly budget by $X across
    /// all expenses." copy on the Total Spending Trend card.
    func test_totalSpendingPace_projectedOverAvailableByAmount_isProjected_minusAvailableToBudget() {
        // variableSpent 600 day 15/31 → projected = 600 + 600/15 × 16 = 1240; available 1000.
        // projectedOverAvailable = 240 (the user-facing "across all expenses" figure).
        let transactions = [
            makeTxn(amount: 600, category: "Groceries", type: .expense, day: 1)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 600,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.projectedMonthEndSpend, 1240, accuracy: 0.0001)
        XCTAssertEqual(result.projectedOverAvailableByAmount, 240, accuracy: 0.0001,
                       "Red copy uses available, not spendLimit")
        XCTAssertNotEqual(
            result.projectedOverAvailableByAmount,
            result.projectedOverBudgetByAmount,
            "Available-based and spendLimit-based amounts must be distinct values"
        )
    }

    /// `projectedOverAvailableByAmount` is clamped at zero whenever the projection sits at or
    /// below the full monthly budget — keeping the red copy hidden in `.nearLimit` / `.onTrack`.
    func test_totalSpendingPace_projectedOverAvailableByAmount_isZero_whenProjectedAtOrBelowAvailable() {
        // variableSpent 450 → projected 930 ≤ available 1000 → .nearLimit, no red copy
        let transactions = [
            makeTxn(amount: 450, category: "Groceries", type: .expense, day: 1)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1000,
            savingsTarget: 150,
            variableSpentSoFar: 450,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.status, .nearLimit)
        XCTAssertEqual(result.projectedOverAvailableByAmount, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(result.projectedOverBudgetByAmount, 0,
                             "Orange copy still triggered: projected exceeds spendLimit")
    }

    /// Sanity-check the user-supplied $1,800 / $240 / $1,560 numbers end-to-end:
    /// available = $1,800; spendLimit = $1,560; if projected = $2,000 → red copy says $200.
    func test_totalSpendingPace_userExample_redCopyUsesAvailable_notSpendLimit() {
        // To get projected ≈ 2000 with totalSpent == variableSpent (all-variable proxy):
        // projected = vs × 31 / 15 → vs = 2000 × 15 / 31 ≈ 967.74
        let transactions = [
            makeTxn(amount: 967.74, category: "Groceries", type: .expense, day: 1)
        ]
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 967.74,
            currentDayOfMonth: 15,
            daysInMonth: 31
        )
        XCTAssertEqual(result.availableToBudget, 1800, accuracy: 0.0001)
        XCTAssertEqual(result.spendLimit, 1560, accuracy: 0.0001)
        XCTAssertEqual(result.projectedMonthEndSpend, 2000, accuracy: 0.05)
        XCTAssertEqual(result.status, .overBudget)
        XCTAssertEqual(result.projectedOverAvailableByAmount, 200, accuracy: 0.05,
                       "Red copy says ≈ $200 (= 2000 − 1800), not 440 (= 2000 − 1560)")
    }

    // MARK: - Total spending pace — fixed-bill projection (the "paying rent shouldn't move
    // the projection" invariants)

    /// `projectedVariableMonthEndSpend = variableSpentSoFar / daysElapsed × daysInMonth`.
    /// Independent of any fixed-bill input.
    func test_totalSpendingPace_projectedVariableMonthEnd_isPureVariablePace() {
        let transactions = [
            makeTxn(amount: 200, category: "Groceries", type: .expense, day: 1)
        ]
        let day10 = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,
            expectedFixedBillsThisMonth: 955, // intentionally non-zero, must NOT bleed in
            unpaidFixedBillsRemaining: 955,
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        XCTAssertEqual(result.projectedVariableMonthEndSpend, 200.0 / 10.0 * 30.0, accuracy: 0.0001)
        XCTAssertEqual(result.projectedVariableMonthEndSpend, 600, accuracy: 0.0001)
    }

    /// User's worked example — projection = projected variable + expected fixed bills.
    /// Available $1,800; expectedFixed $955; var $200 of 10/30 → projected 1,555.
    func test_totalSpendingPace_projectedMonthEnd_equalsProjectedVariablePlusExpectedFixedBills_whenNothingPaid() {
        let transactions = [
            makeTxn(amount: 200, category: "Groceries", type: .expense, day: 1)
        ]
        let day10 = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let result = evaluateTotal(
            transactions: transactions,
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,
            expectedFixedBillsThisMonth: 955,
            unpaidFixedBillsRemaining: 955, // all bills still unpaid
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        XCTAssertEqual(result.projectedMonthEndSpend, 1555, accuracy: 0.0001,
                       "= projectedVariable 600 + expectedFixed 955")
        XCTAssertEqual(
            result.projectedMonthEndSpend,
            result.projectedVariableMonthEndSpend + result.expectedFixedBillsThisMonth,
            accuracy: 0.0001
        )
    }

    /// **Critical invariant**: paying an already-expected fixed bill must not change the
    /// projected month-end. Two evaluations with identical envelopes/variables, the only
    /// difference being whether rent has been paid:
    func test_totalSpendingPace_payingAFixedBill_doesNotIncreaseProjectedMonthEnd() {
        let day10 = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let groceries = makeTxn(amount: 200, category: "Groceries", type: .expense, day: 1)
        let rentPayment = makeTxn(amount: 900, category: "Rent", type: .expense, day: 10)

        let beforeRentPaid = evaluateTotal(
            transactions: [groceries],
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,
            expectedFixedBillsThisMonth: 955,
            unpaidFixedBillsRemaining: 955, // rent + phone still owed
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        let afterRentPaid = evaluateTotal(
            transactions: [groceries, rentPayment],
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,                 // variable unchanged
            expectedFixedBillsThisMonth: 955,        // expectations unchanged
            unpaidFixedBillsRemaining: 55,           // only phone left = 55
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        XCTAssertEqual(beforeRentPaid.projectedMonthEndSpend, 1555, accuracy: 0.0001)
        XCTAssertEqual(afterRentPaid.projectedMonthEndSpend, 1555, accuracy: 0.0001)
        XCTAssertEqual(
            beforeRentPaid.projectedMonthEndSpend,
            afterRentPaid.projectedMonthEndSpend,
            accuracy: 0.0001,
            "Paying an expected fixed bill must not move the projection"
        )
        XCTAssertGreaterThan(afterRentPaid.totalSpent, beforeRentPaid.totalSpent,
                             "Actual blue line still jumps when a bill is paid")
        XCTAssertLessThan(afterRentPaid.unpaidFixedBillsRemaining, beforeRentPaid.unpaidFixedBillsRemaining,
                          "Remaining fixed bills must shrink as bills are paid")
    }

    /// Partial payment example: rent planned $900, $500 paid → remaining $400. The remaining
    /// portion plus the still-unpaid phone bill ($55) feed `unpaidFixedBillsRemaining`.
    func test_totalSpendingPace_partialPayment_includesPlannedMinusActual_inProjection() {
        let day10 = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let result = evaluateTotal(
            transactions: [
                makeTxn(amount: 200, category: "Groceries", type: .expense, day: 1),
                makeTxn(amount: 500, category: "Rent", type: .expense, day: 10)
            ],
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,
            expectedFixedBillsThisMonth: 955,
            unpaidFixedBillsRemaining: 455, // max(0, 900−500)=400 + phone 55
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        // totalSpent 700 + futureVariable 400 + remaining 455 = 1555
        XCTAssertEqual(result.totalSpent, 700, accuracy: 0.0001)
        XCTAssertEqual(result.projectedMonthEndSpend, 1555, accuracy: 0.0001,
                       "Partial payment keeps projection invariant")
        XCTAssertEqual(result.unpaidFixedBillsRemaining, 455, accuracy: 0.0001)
    }

    /// Unpaid bills due later in the month must still bump the projected month-end.
    func test_totalSpendingPace_unpaidFixedBills_areIncludedInFutureProjection() {
        let day10 = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let withFixed = evaluateTotal(
            transactions: [makeTxn(amount: 200, category: "Groceries", type: .expense, day: 1)],
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,
            expectedFixedBillsThisMonth: 955,
            unpaidFixedBillsRemaining: 955,
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        let withoutFixed = evaluateTotal(
            transactions: [makeTxn(amount: 200, category: "Groceries", type: .expense, day: 1)],
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,
            expectedFixedBillsThisMonth: 0,
            unpaidFixedBillsRemaining: 0,
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        XCTAssertEqual(
            withFixed.projectedMonthEndSpend - withoutFixed.projectedMonthEndSpend,
            955,
            accuracy: 0.0001,
            "Adding $955 of unpaid fixed bills increases projection by exactly that much"
        )
    }

    /// Variable pace must ignore fixed bills entirely.
    func test_totalSpendingPace_fixedBills_doNotAffectVariablePace() {
        let day10 = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let withRentPaid = evaluateTotal(
            transactions: [
                makeTxn(amount: 200, category: "Groceries", type: .expense, day: 1),
                makeTxn(amount: 900, category: "Rent", type: .expense, day: 10)
            ],
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,
            expectedFixedBillsThisMonth: 955,
            unpaidFixedBillsRemaining: 55,
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        let withRentUnpaid = evaluateTotal(
            transactions: [makeTxn(amount: 200, category: "Groceries", type: .expense, day: 1)],
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,
            expectedFixedBillsThisMonth: 955,
            unpaidFixedBillsRemaining: 955,
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        XCTAssertEqual(
            withRentPaid.projectedVariableMonthEndSpend,
            withRentUnpaid.projectedVariableMonthEndSpend,
            accuracy: 0.0001,
            "Variable pace is invariant to whether fixed bills have been paid"
        )
    }

    /// Overpaying a fixed bill is not refunded by the projection — `unpaidFixedBillsRemaining`
    /// is clamped at 0 per bill, but the actual overpayment stays in `totalSpent`.
    func test_totalSpendingPace_overpaidFixedBills_areClampedAtZeroRemaining_andLeakIntoActual() {
        let day10 = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let result = evaluateTotal(
            transactions: [
                makeTxn(amount: 200, category: "Groceries", type: .expense, day: 1),
                makeTxn(amount: 1000, category: "Rent", type: .expense, day: 10) // planned 900
            ],
            availableToBudget: 1800,
            savingsTarget: 240,
            variableSpentSoFar: 200,
            expectedFixedBillsThisMonth: 955,
            unpaidFixedBillsRemaining: 55,            // rent clamps to 0 + phone 55
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        // totalSpent 1200 + futureVariable 400 + remaining 55 = 1655 (= invariant 1555 + $100 overpayment)
        XCTAssertEqual(result.totalSpent, 1200, accuracy: 0.0001)
        XCTAssertEqual(result.projectedMonthEndSpend, 1655, accuracy: 0.0001,
                       "Overpaid fixed bills correctly raise the projection by the overpayment")
    }

    /// Document the negative case explicitly: the old broken formula
    /// `projected = totalSpent / daysElapsed × daysInMonth` would inflate fixed bills.
    /// $900 rent on day 10 of 30 with no variable spending must NOT yield 2700.
    func test_totalSpendingPace_projection_doesNotUseTotalSpentDividedByDaysFormula() {
        let day10 = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let result = evaluateTotal(
            transactions: [makeTxn(amount: 900, category: "Rent", type: .expense, day: 10)],
            availableToBudget: 2000,
            savingsTarget: 0,
            variableSpentSoFar: 0,
            expectedFixedBillsThisMonth: 900,
            unpaidFixedBillsRemaining: 0,             // rent already paid
            currentDayOfMonth: 10,
            daysInMonth: 30,
            now: day10
        )
        let totalSpentTimesPace = result.totalSpent / 10.0 * 30.0 // = 2700
        XCTAssertEqual(totalSpentTimesPace, 2700, accuracy: 0.0001)
        XCTAssertNotEqual(result.projectedMonthEndSpend, totalSpentTimesPace,
                          "Old wrong formula must not be used")
        XCTAssertEqual(result.projectedMonthEndSpend, 900, accuracy: 0.0001,
                       "Correct projection: rent paid + 0 variable + 0 unpaid fixed = $900")
    }

    func test_totalSpendingPace_badgeText_matchesSpec() {
        XCTAssertEqual(TotalSpendingPace.RiskStatus.onTrack.badgeText, "On Track")
        XCTAssertEqual(TotalSpendingPace.RiskStatus.nearLimit.badgeText, "Near Limit")
        XCTAssertEqual(TotalSpendingPace.RiskStatus.overBudget.badgeText, "Over Budget")
    }

    func test_variableSpendingPace_status_usesProjectedMonthEnd_notMonthToDateSpendAlone() {
        // Heavy spend early → projected month-end exceeds variable budget even if MTD < budget.
        let budgetItems = [
            makeBudget(category: "Groceries", planned: 500, type: .variable),
            makeBudget(category: "Rent", planned: 900, type: .fixed, frequency: .monthly, dueDay: 1)
        ]
        let transactions = [
            makeTxn(amount: 400, category: "Groceries", type: .expense, day: 2)
        ]
        let result = VariableSpendingPace.evaluate(
            budgetItems: budgetItems,
            transactions: transactions,
            currentDayOfMonth: 5,
            daysInMonth: 31,
            calendar: cal,
            now: refDate
        )
        XCTAssertLessThan(result.variableSpent, result.variableBudget)
        XCTAssertGreaterThan(result.projectedMonthEndSpend, result.variableBudget)
        XCTAssertEqual(result.status, .overBudgetRisk)
    }

    // MARK: - Spending breakdown (Plan vs Reality bar)
    //
    // Pinned invariants:
    //   • Income transactions never appear in the breakdown.
    //   • Only the *current calendar month* counts (last month's spending is ignored).
    //   • Categories are grouped case-insensitively but the original casing is preserved.
    //   • Net amount per row uses `amount - savedApplied`; non-positive rows are dropped.
    //   • Segments are sorted by spent amount descending, ties broken alphabetically.
    //   • `availableToBudget` drives the over-budget flag, *never* the legacy spending limit.

    func test_spendingBreakdown_ignoresIncomeTransactions() {
        let transactions = [
            makeTxn(amount: 2000, category: "Paycheque", type: .income, day: 1),
            makeTxn(amount: 100, category: "Groceries", type: .expense, day: 3)
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: 1000,
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.segments.first?.category, "Groceries")
        XCTAssertEqual(result.actualSpending, 100, accuracy: 0.0001)
    }

    func test_spendingBreakdown_groupsByCategory_caseInsensitively_andPreservesFirstSeenCasing() throws {
        let transactions = [
            makeTxn(amount: 60, category: "Groceries", type: .expense, day: 2),
            makeTxn(amount: 40, category: "groceries", type: .expense, day: 5),
            makeTxn(amount: 20, category: "GROCERIES", type: .expense, day: 7)
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: 500,
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(result.segments.count, 1, "All three rows should collapse into one segment")
        let only = try XCTUnwrap(result.segments.first)
        XCTAssertEqual(only.category, "Groceries", "Display casing must match the first transaction seen")
        XCTAssertEqual(only.amount, 120, accuracy: 0.0001)
    }

    func test_spendingBreakdown_excludesTransactionsOutsideCurrentMonth() {
        let aprilTxn = TransactionItem(
            id: UUID(),
            amount: 999,
            category: "Rent",
            note: "",
            date: cal.date(from: DateComponents(year: 2026, month: 4, day: 30))!,
            createdAt: refDate,
            type: .expense,
            savedApplied: 0
        )
        let mayTxn = makeTxn(amount: 100, category: "Groceries", type: .expense, day: 5)
        let result = FinanceCalculator.spendingBreakdown(
            transactions: [aprilTxn, mayTxn],
            availableToBudget: 1000,
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.segments.first?.category, "Groceries")
        XCTAssertEqual(result.actualSpending, 100, accuracy: 0.0001)
    }

    func test_spendingBreakdown_usesNetAmount_subtractingSavedApplied() throws {
        let transactions = [
            makeTxn(amount: 100, category: "Eating Out", type: .expense, day: 3, savedApplied: 30),
            makeTxn(amount: 50, category: "Eating Out", type: .expense, day: 7) // pure spend
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: 200,
            now: refDate,
            calendar: cal
        )
        let segment = try XCTUnwrap(result.segments.first)
        // Net = (100-30) + 50 = 120.
        XCTAssertEqual(segment.amount, 120, accuracy: 0.0001)
        XCTAssertEqual(result.actualSpending, 120, accuracy: 0.0001)
    }

    func test_spendingBreakdown_dropsRowsWithZeroOrNegativeNet() {
        let transactions = [
            makeTxn(amount: 100, category: "Phone bill", type: .expense, day: 4, savedApplied: 100), // fully covered
            makeTxn(amount: 30, category: "Eating Out", type: .expense, day: 6)
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: 200,
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(result.segments.count, 1, "Phone bill row with savedApplied == amount must be dropped")
        XCTAssertEqual(result.segments.first?.category, "Eating Out")
    }

    func test_spendingBreakdown_sortsByAmountDescending_thenAlphabetically() {
        let transactions = [
            makeTxn(amount: 100, category: "Eating Out", type: .expense, day: 3),
            makeTxn(amount: 200, category: "Rent", type: .expense, day: 1),
            makeTxn(amount: 100, category: "Groceries", type: .expense, day: 5),
            makeTxn(amount: 50, category: "Transportation", type: .expense, day: 8)
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: 600,
            now: refDate,
            calendar: cal
        )
        let categories = result.segments.map { $0.category }
        XCTAssertEqual(categories, ["Rent", "Eating Out", "Groceries", "Transportation"],
                       "Largest first; ties (Eating Out vs Groceries at $100) break alphabetically")
    }

    func test_spendingBreakdown_percentages_sumToOne_acrossSegments() {
        let transactions = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1),
            makeTxn(amount: 132.50, category: "Groceries", type: .expense, day: 3),
            makeTxn(amount: 18.50, category: "Transportation", type: .expense, day: 4),
            makeTxn(amount: 300, category: "Tuition/Savings", type: .expense, day: 7),
            makeTxn(amount: 51, category: "Other", type: .expense, day: 10)
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: 1500,
            now: refDate,
            calendar: cal
        )
        let sum = result.segments.reduce(0) { $0 + $1.percentageOfActual }
        XCTAssertEqual(sum, 1.0, accuracy: 0.0001, "All segment percentages must sum to 1.0")
        XCTAssertEqual(result.actualSpending, 1402, accuracy: 0.0001)
    }

    func test_spendingBreakdown_isOverBudget_isFalse_whenActualLessThanOrEqualToAvailable() {
        let transactions = [
            makeTxn(amount: 800, category: "Rent", type: .expense, day: 1)
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: 1000,
            now: refDate,
            calendar: cal
        )
        XCTAssertFalse(result.isOverBudget)
        XCTAssertEqual(result.overBudgetBy, 0, accuracy: 0.0001)
    }

    func test_spendingBreakdown_isOverBudget_returnsExactOverflow_whenActualExceedsAvailable() {
        let transactions = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1),
            makeTxn(amount: 502, category: "Groceries", type: .expense, day: 3)
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: 1000,
            now: refDate,
            calendar: cal
        )
        XCTAssertTrue(result.isOverBudget)
        XCTAssertEqual(result.actualSpending, 1402, accuracy: 0.0001)
        XCTAssertEqual(result.overBudgetBy, 402, accuracy: 0.0001, "User's worked example: $1,402 actual − $1,000 envelope = $402 over")
    }

    func test_spendingBreakdown_handlesEmptyTransactions_withoutDivisionByZero() {
        let result = FinanceCalculator.spendingBreakdown(
            transactions: [],
            availableToBudget: 1000,
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(result.segments.count, 0)
        XCTAssertEqual(result.actualSpending, 0, accuracy: 0.0001)
        XCTAssertFalse(result.isOverBudget)
    }

    func test_spendingBreakdown_clampsNegativeAvailableToBudget_toZero() {
        let transactions = [
            makeTxn(amount: 100, category: "Rent", type: .expense, day: 1)
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: -50,
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(result.availableToBudget, 0, accuracy: 0.0001)
        XCTAssertTrue(result.isOverBudget, "Any positive spend with non-positive envelope is over budget")
        XCTAssertEqual(result.overBudgetBy, 100, accuracy: 0.0001)
    }

    func test_spendingBreakdown_includesBothFixedAndVariableCategories() {
        // Rent is a fixed bill; Groceries / Eating Out are variable. Both should appear in the
        // breakdown — the bar represents *spending*, not budget item type.
        let transactions = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1),
            makeTxn(amount: 60, category: "Groceries", type: .expense, day: 3),
            makeTxn(amount: 25, category: "Eating Out", type: .expense, day: 8)
        ]
        let result = FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: 1500,
            now: refDate,
            calendar: cal
        )
        let categories = Set(result.segments.map { $0.category })
        XCTAssertEqual(categories, ["Rent", "Groceries", "Eating Out"])
    }

    // MARK: - Monthly snapshot (Budget screen)

    /// Helper: builds a small, well-known set of budget items + transactions for the snapshot tests.
    private func snapshotFixtures() -> (budgetItems: [BudgetItem], transactions: [TransactionItem]) {
        let rent = makeBudget(category: "Rent", planned: 900, type: .fixed, frequency: .monthly, dueDay: 1)
        let phone = makeBudget(category: "Phone bill", planned: 35, type: .fixed, frequency: .monthly, dueDay: 15)
        let groceries = makeBudget(category: "Groceries", planned: 280, type: .variable)
        let eatingOut = makeBudget(category: "Eating Out", planned: 140, type: .variable)
        let savings = makeBudget(category: "Tuition/Savings", planned: 300, type: .savings, frequency: .monthly, dueDay: 7)

        let transactions = [
            // Recurring bills: only rent has been paid this month.
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 1),
            // Variable spending: $260 used out of $420 planned.
            makeTxn(amount: 60, category: "Groceries", type: .expense, day: 2),
            makeTxn(amount: 100, category: "Groceries", type: .expense, day: 5),
            makeTxn(amount: 100, category: "Eating Out", type: .expense, day: 8),
            // Income — must NEVER affect snapshot rollups.
            makeTxn(amount: 2000, category: "Paycheque", type: .income, day: 1)
        ]

        return ([rent, phone, groceries, eatingOut, savings], transactions)
    }

    func test_monthlySnapshot_plannedBudget_isSumOfPlannedAllocations_excludingHiddenItems() {
        let (items, transactions) = snapshotFixtures()
        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        // 900 + 35 + 280 + 140 + 300 = 1655
        XCTAssertEqual(snapshot.plannedBudget, 1655, accuracy: 0.0001)
    }

    func test_monthlySnapshot_plannedBudget_doesNotIncludeIncome() {
        // Add a 5,000 income transaction; the planned budget must not change.
        var (items, transactions) = snapshotFixtures()
        transactions.append(makeTxn(amount: 5000, category: "Co-op", type: .income, day: 10))

        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(snapshot.plannedBudget, 1655, accuracy: 0.0001)

        // And mutating budget items but keeping the same transactions also can't drag actual into planned.
        items.append(makeBudget(category: "Other", planned: 50, type: .variable))
        let snapshot2 = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(snapshot2.plannedBudget, 1705, accuracy: 0.0001)
    }

    func test_monthlySnapshot_plannedBudget_doesNotIncludeActualSpending() {
        let (items, _) = snapshotFixtures()
        // Snapshot with NO transactions — planned must be unchanged.
        let bare = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: [],
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(bare.plannedBudget, 1655, accuracy: 0.0001)
        XCTAssertEqual(bare.actualSpending, 0, accuracy: 0.0001)
    }

    func test_monthlySnapshot_actualSpending_isCurrentMonthOnly_andComesFromTransactions() {
        let (items, transactions) = snapshotFixtures()
        // Add an expense from the previous month — it must be excluded.
        let prevMonth = cal.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: 12)) ?? refDate
        let priorMonthExpense = TransactionItem(
            id: UUID(),
            amount: 500,
            category: "Groceries",
            note: "",
            date: prevMonth,
            createdAt: prevMonth,
            type: .expense
        )

        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions + [priorMonthExpense],
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        // Current-month expenses: 900 (rent) + 60 + 100 (groceries) + 100 (eating out) = 1160
        XCTAssertEqual(snapshot.actualSpending, 1160, accuracy: 0.0001)
    }

    func test_monthlySnapshot_remaining_isPositive_whenUnderBudget() {
        let (items, transactions) = snapshotFixtures()
        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        // 1655 planned − 1160 actual = 495 remaining
        XCTAssertEqual(snapshot.remaining, 495, accuracy: 0.0001)
        XCTAssertFalse(snapshot.isOverSpent)
    }

    func test_monthlySnapshot_remaining_isNegative_whenOverBudget() {
        let (items, _) = snapshotFixtures()
        // Spend $2,000 of variable spending in one transaction.
        let bigExpense = makeTxn(amount: 2000, category: "Eating Out", type: .expense, day: 10)
        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: [bigExpense],
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(snapshot.actualSpending, 2000, accuracy: 0.0001)
        XCTAssertEqual(snapshot.remaining, 1655 - 2000, accuracy: 0.0001) // -345
        XCTAssertTrue(snapshot.isOverSpent)
    }

    func test_monthlySnapshot_variableSpendingUsed_tracksOnlyVariableCategories() {
        let (items, transactions) = snapshotFixtures()
        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        // Variable planned: groceries 280 + eating out 140 = 420
        XCTAssertEqual(snapshot.variablePlanned, 420, accuracy: 0.0001)
        // Variable spent: 60 + 100 + 100 = 260 (rent/income excluded)
        XCTAssertEqual(snapshot.variableSpent, 260, accuracy: 0.0001)
        XCTAssertFalse(snapshot.isVariableOverPlanned)
    }

    func test_monthlySnapshot_recurringBillsPaid_countsOnlyFixedItems() {
        let (items, transactions) = snapshotFixtures()
        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        // Two recurring bills (Rent, Phone). Only Rent is paid. Tuition/Savings is a savings goal,
        // not a recurring bill — it must NOT count toward this metric.
        XCTAssertEqual(snapshot.recurringBillsTotal, 2)
        XCTAssertEqual(snapshot.recurringBillsPaid, 1)
        XCTAssertFalse(snapshot.allRecurringBillsPaid)
    }

    func test_monthlySnapshot_allRecurringBillsPaid_whenEveryFixedItemIsCovered() {
        let (items, transactions) = snapshotFixtures()
        // Add a Phone-bill payment so all recurring bills are covered.
        let phonePayment = makeTxn(amount: 35, category: "Phone bill", type: .expense, day: 10)
        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions + [phonePayment],
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(snapshot.recurringBillsTotal, 2)
        XCTAssertEqual(snapshot.recurringBillsPaid, 2)
        XCTAssertTrue(snapshot.allRecurringBillsPaid)
    }

    func test_monthlySnapshot_savingsTarget_isAddedToPlannedBudget() {
        let (items, transactions) = snapshotFixtures()
        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            savingsTarget: 250,
            now: refDate,
            calendar: cal
        )
        // 1655 (sum of planned items) + 250 (savings target) = 1905
        XCTAssertEqual(snapshot.savingsTarget, 250, accuracy: 0.0001)
        XCTAssertEqual(snapshot.plannedBudget, 1655 + 250, accuracy: 0.0001)
    }

    func test_monthlySnapshot_savingsTarget_flowsIntoRemaining() {
        let (items, transactions) = snapshotFixtures()
        let withoutTarget = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            now: refDate,
            calendar: cal
        )
        let withTarget = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            savingsTarget: 250,
            now: refDate,
            calendar: cal
        )
        // Remaining must grow by exactly the savings target (planned - actual).
        XCTAssertEqual(withTarget.remaining - withoutTarget.remaining, 250, accuracy: 0.0001)
    }

    func test_monthlySnapshot_savingsTarget_negativeValueIsClampedAtZero() {
        let (items, transactions) = snapshotFixtures()
        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [],
            savingsTarget: -100,
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(snapshot.savingsTarget, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.plannedBudget, 1655, accuracy: 0.0001)
    }

    func test_monthlySnapshot_hiddenItems_areExcludedFromAllRollups() {
        let (items, transactions) = snapshotFixtures()
        // Hide Phone bill ($35 planned). The recurring count drops to 1 and planned drops by 35.
        let phoneId = items.first(where: { $0.category == "Phone bill" })!.id
        let snapshot = FinanceCalculator.monthlySnapshot(
            budgetItems: items,
            transactions: transactions,
            hiddenBudgetItemIds: [phoneId],
            now: refDate,
            calendar: cal
        )
        XCTAssertEqual(snapshot.plannedBudget, 1655 - 35, accuracy: 0.0001)
        XCTAssertEqual(snapshot.recurringBillsTotal, 1)
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

    // MARK: - Spending trend range math

    func test_spendTrendRange_selectedDays_sevenTrailingAndMonthLength() {
        XCTAssertEqual(SpendTrendRange.sevenDays.selectedDays(daysInCalendarMonth: 31), 7)
        XCTAssertEqual(SpendTrendRange.oneWeek.selectedDays(daysInCalendarMonth: 31), 7)
        XCTAssertEqual(SpendTrendRange.thirtyDays.selectedDays(daysInCalendarMonth: 28), 30)
        XCTAssertEqual(SpendTrendRange.currentMonth.selectedDays(daysInCalendarMonth: 31), 31)
        XCTAssertEqual(SpendTrendRange.currentMonth.selectedDays(daysInCalendarMonth: 28), 28)
    }

    func test_spendTrendRange_variablePickerCases_orderAndCount() {
        XCTAssertEqual(SpendTrendRange.variablePickerCases.count, 4)
        XCTAssertEqual(
            SpendTrendRange.variablePickerCases,
            [.sevenDays, .oneWeek, .thirtyDays, .currentMonth]
        )
    }

    func test_spendTrendRange_totalChart_isMonthOnly_documented() {
        // Total Spending Trend uses `SpendTrendRange.currentMonth` only in `DashboardView`;
        // short-range enum cases exist for Variable mode exclusively.
        XCTAssertEqual(SpendTrendRange.currentMonth.selectedDays(daysInCalendarMonth: 31), 31)
    }

    func test_spendTrend_selectedWindow_currentMonthSpansFullMonth_calendarDays() {
        let dim = 31
        let days = SpendingSeries.windowDayStarts(
            for: .currentMonth,
            now: refDate,
            calendar: cal,
            daysInCalendarMonth: dim
        )
        XCTAssertEqual(days.count, dim)
        XCTAssertEqual(cal.component(.day, from: days.first!), 1)
        XCTAssertEqual(cal.component(.day, from: days.last!), dim)
        XCTAssertEqual(cal.component(.month, from: days.last!), cal.component(.month, from: refDate))
    }

    func test_spendTrend_selectedWindow_thirtyEndsToday() {
        let dim = 31
        let days = SpendingSeries.windowDayStarts(
            for: .thirtyDays,
            now: refDate,
            calendar: cal,
            daysInCalendarMonth: dim
        )
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(cal.startOfDay(for: days.last!), cal.startOfDay(for: refDate))
    }

    func test_spendTrend_variableSeries_excludesFixedCategories() {
        let budgetItems = [
            makeBudget(category: "Groceries", planned: 200, type: .variable),
            makeBudget(category: "Rent", planned: 900, type: .fixed, frequency: .monthly, dueDay: 1),
            makeBudget(category: "Phone bill", planned: 40, type: .fixed, frequency: .monthly, dueDay: 10),
            makeBudget(category: "Tuition/Savings", planned: 250, type: .fixed, frequency: .monthly, dueDay: 5),
            makeBudget(category: "Subscriptions", planned: 20, type: .fixed, frequency: .monthly, dueDay: 12),
            makeBudget(category: "Loan payments", planned: 60, type: .fixed, frequency: .monthly, dueDay: 20),
        ]

        let txns = [
            makeTxn(amount: 25, category: "Groceries", type: .expense, day: 13),
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 13),
            makeTxn(amount: 40, category: "Phone bill", type: .expense, day: 13),
            makeTxn(amount: 250, category: "Tuition/Savings", type: .expense, day: 13),
            makeTxn(amount: 20, category: "Subscriptions", type: .expense, day: 13),
            makeTxn(amount: 60, category: "Loan payments", type: .expense, day: 13),
        ]

        let orderedDays = SpendingSeries.windowDayStarts(
            for: .sevenDays,
            now: refDate,
            calendar: cal,
            daysInCalendarMonth: 31
        )
        XCTAssertEqual(orderedDays.count, 7)
        let series = SpendingSeries.cumulativeVariableSpendPerDaySlot(
            transactions: txns,
            budgetItems: budgetItems,
            orderedDayStarts: orderedDays,
            calendar: cal,
            elapsedSlotsInclusiveOneBased: 7
        )

        XCTAssertEqual(series.last!, 25, accuracy: 0.0001, "Only Groceries should count toward variable pacing")
    }

    func test_spendTrend_totalSeries_includesFixedAndVariableExpenseCategories() {
        let orderedDays = SpendingSeries.windowDayStarts(
            for: .sevenDays,
            now: refDate,
            calendar: cal,
            daysInCalendarMonth: 31
        )
        let txns = [
            makeTxn(amount: 900, category: "Rent", type: .expense, day: 14),
            makeTxn(amount: 12, category: "Coffee", type: .expense, day: 15),
        ]
        let cumulative = SpendingSeries.cumulativeTotalSpendPerDaySlot(
            transactions: txns,
            orderedDayStarts: orderedDays,
            calendar: cal,
            elapsedSlotsInclusiveOneBased: 7
        )

        XCTAssertEqual(cumulative.last!, 900 + 12, accuracy: 0.0001)
    }

    func test_spendTrend_scaledPeriod_formula_andMonthIdentity() {
        let avail = 3000.0
        let savings = 600.0
        let monthlyVar = 930.0
        let dim = 31

        let monthScaled = SpendTrendRangeMath.scaledPeriod(
            availableToBudget: avail,
            savingsTarget: savings,
            monthlyVariableLimit: monthlyVar,
            selectedDays: dim,
            daysInMonth: dim
        )
        XCTAssertEqual(monthScaled.periodAvailableToBudget, avail, accuracy: 0.0001)
        XCTAssertEqual(monthScaled.periodSavingsTarget, savings, accuracy: 0.0001)
        XCTAssertEqual(monthScaled.periodSpendLimit, avail - savings, accuracy: 0.0001)
        XCTAssertEqual(monthScaled.periodVariableLimit, monthlyVar, accuracy: 0.0001)

        let sevenScaled = SpendTrendRangeMath.scaledPeriod(
            availableToBudget: avail,
            savingsTarget: savings,
            monthlyVariableLimit: monthlyVar,
            selectedDays: 7,
            daysInMonth: dim
        )
        let ratio = Double(7) / Double(dim)

        XCTAssertEqual(sevenScaled.periodVariableLimit, monthlyVar * ratio, accuracy: 0.0001)
        XCTAssertEqual(sevenScaled.periodAvailableToBudget, avail * ratio, accuracy: 0.0001)
        XCTAssertEqual(sevenScaled.periodSavingsTarget, savings * ratio, accuracy: 0.0001)
        XCTAssertEqual(sevenScaled.periodSpendLimit, (avail - savings) * ratio, accuracy: 0.0001)

        let thirtyScaled = SpendTrendRangeMath.scaledPeriod(
            availableToBudget: avail,
            savingsTarget: savings,
            monthlyVariableLimit: monthlyVar,
            selectedDays: 30,
            daysInMonth: dim
        )
        let ratio30 = Double(30) / Double(dim)

        XCTAssertEqual(thirtyScaled.periodVariableLimit, monthlyVar * ratio30, accuracy: 0.0001)
        XCTAssertEqual(thirtyScaled.periodAvailableToBudget, avail * ratio30, accuracy: 0.0001)
        XCTAssertEqual(thirtyScaled.periodSavingsTarget, savings * ratio30, accuracy: 0.0001)
        XCTAssertEqual(thirtyScaled.periodSpendLimit, (avail - savings) * ratio30, accuracy: 0.0001)
    }

    func test_totalSpendTrend_projection_invariant_whenPayingExpectedFixed_insideWindow() {
        let elapsed = 10
        let span = 30
        let totalBefore = 400.0
        let variableSpent = 100.0
        let unpaidBefore = 100.0
        let payment = 50.0

        let before = TotalSpendingPace.evaluateWithTotals(
            totalSpentThisPeriod: totalBefore,
            availableToBudget: 2000,
            savingsTarget: 0,
            variableSpentSoFar: variableSpent,
            expectedFixedBillsThisPeriod: 0,
            unpaidFixedBillsRemainingThisPeriod: unpaidBefore,
            currentDayOfPeriod: elapsed,
            periodLengthDays: span
        )

        let after = TotalSpendingPace.evaluateWithTotals(
            totalSpentThisPeriod: totalBefore + payment,
            availableToBudget: 2000,
            savingsTarget: 0,
            variableSpentSoFar: variableSpent,
            expectedFixedBillsThisPeriod: 0,
            unpaidFixedBillsRemainingThisPeriod: unpaidBefore - payment,
            currentDayOfPeriod: elapsed,
            periodLengthDays: span
        )

        XCTAssertEqual(before.projectedMonthEndSpend, after.projectedMonthEndSpend, accuracy: 0.0001)
    }

    func test_spendingTrend_tooltipArrays_neverReferenceSpendLimit() {
        for rows in [
            FinanceCalculator.spendingTrendVariableTooltipRowTitlesPast,
            FinanceCalculator.spendingTrendVariableTooltipRowTitlesFuture,
            FinanceCalculator.spendingTrendTotalTooltipRowTitlesPast,
            FinanceCalculator.spendingTrendTotalTooltipRowTitlesFuture,
        ] {
            XCTAssertFalse(rows.contains(where: { $0.localizedCaseInsensitiveContains("Spend Limit") }))
        }
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
        state.customSavingsTargetByMonth = [:]
        state.fixedBillPaymentTransactionIdsByMonth = [:]
        state.hiddenBudgetItemIdsByMonth = [:]
        state.pendingIncomePrompt = nil
        state.pendingUndo = nil
        return state
    }
}
