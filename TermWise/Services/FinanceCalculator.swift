import Foundation

/// Single, deliberately thin entry point for **all finance/business logic** in the app.
///
/// `FinanceCalculator` is a pure-Swift facade over the domain helpers (`FinanceBudgetAllocation`,
/// `VariableSpendingPace`, `FixedBillSchedule`, `BudgetSpendCalculator`, `MarkAsPaidRules`,
/// `TransactionTotalsService`). It also exposes a few small helpers that previously lived inside
/// SwiftUI views (transaction grouping, filter summaries, threshold tiers) so they can be
/// unit-tested without spinning up the UI or `AppState`.
///
/// All functions are deterministic, side-effect-free, and accept their inputs as parameters.
/// Tests should target this enum directly (see `FinanceCalculatorTests`).
///
/// Mirror this file verbatim on Android when porting to Kotlin.
enum FinanceCalculator {

    // MARK: - 1. Income vs budget

    /// Sum of `expense` transactions in the same calendar month as `referenceDate`.
    static func totalExpensesThisMonth(
        transactions: [TransactionItem],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Double {
        transactions
            .filter { $0.type == .expense && calendar.isDate($0.date, equalTo: referenceDate, toGranularity: .month) }
            .reduce(0) { $0 + BudgetSpendCalculator.netExpenseAmount($1) }
    }

    /// Sum of `income` transactions in the same calendar month as `referenceDate`.
    static func totalIncomeThisMonth(
        transactions: [TransactionItem],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Double {
        FinanceBudgetAllocation.calculateTotalIncome(
            transactions: transactions,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    /// `max(0, totalIncome - availableToBudget)`. Income kept outside the budget envelope.
    static func reserveNotBudgeted(totalIncome: Double, availableToBudget: Double) -> Double {
        FinanceBudgetAllocation.calculateReserveNotBudgeted(
            totalIncome: totalIncome,
            availableToBudget: availableToBudget
        )
    }

    /// Returns a non-empty warning string when the user has chosen to budget more than the income
    /// they've actually recorded this month. Otherwise `nil`.
    static func availableToBudgetWarning(
        totalIncome: Double,
        availableToBudget: Double
    ) -> String? {
        guard availableToBudget > totalIncome else { return nil }
        return "You're budgeting more than the income you've recorded this month."
    }

    // MARK: - 2. Budget difference

    /// `availableToBudget - totalBudgeted`. Positive = headroom; negative = over-allocated.
    static func budgetDifference(availableToBudget: Double, totalBudgeted: Double) -> Double {
        availableToBudget - totalBudgeted
    }

    /// Dynamic dashboard row: label + display value (always >= 0) + over-budget flag.
    static func unallocatedRow(
        availableToBudget: Double,
        totalBudgeted: Double
    ) -> (label: String, value: Double, isOver: Bool) {
        FinanceBudgetAllocation.unallocatedRow(
            availableToBudget: availableToBudget,
            totalBudgeted: totalBudgeted
        )
    }

    // MARK: - 3. Fixed bill paid logic

    /// A fixed bill is *paid* when actual currency applied >= planned amount.
    static func fixedBillIsPaid(planned: Double, actual: Double) -> Bool {
        actual >= planned
    }

    /// Progress fraction in `[0, 1]`. Returns `1.0` when paid, even if `actual > planned`.
    static func fixedBillProgress(planned: Double, actual: Double) -> Double {
        guard planned > 0 else { return actual > 0 ? 1 : 0 }
        return min(1.0, max(0.0, actual / planned))
    }

    /// Combined paid / upcoming / overdue status for a fixed bill or savings goal.
    /// `daysUntilDue == nil` means no due date (e.g., `.none` frequency) — treated as `upcoming`.
    static func fixedBillStatus(
        planned: Double,
        actual: Double,
        daysUntilDue: Int?
    ) -> FixedBillStatus {
        if fixedBillIsPaid(planned: planned, actual: actual) { return .paid }
        guard let delta = daysUntilDue else { return .upcoming }
        return delta < 0 ? .overdue : .upcoming
    }

    // MARK: - 4. Mark as Paid logic

    /// Remaining currency amount required to bring `actual` up to `planned`. `nil` if already paid.
    static func markAsPaidRemainingAmount(planned: Double, actualPaid: Double) -> Double? {
        MarkAsPaidRules.remainingAmountToReachPlanned(planned: planned, actualPaid: actualPaid)
    }

    // MARK: - 5. Variable spending threshold tiers (anti-repeat warnings)

    /// Threshold tiers that drive the in-app variable-budget warnings.
    /// Tiers are monotonically increasing — once we've shown a tier, never show it (or a lower
    /// tier) again in the same month.
    enum VariableThresholdTier: Int, Comparable, Codable {
        case below = 0   // < 75%
        case at75 = 1    // 75% .. < 90%
        case at90 = 2    // 90% .. < 100%
        case at100 = 3   // >= 100%

        static func < (lhs: VariableThresholdTier, rhs: VariableThresholdTier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var bannerCopy: String? {
            switch self {
            case .below: return nil
            case .at75:  return "You've used 75% of this budget."
            case .at90:  return "You've used 90% of this budget."
            case .at100: return "You've reached 100% of this budget."
            }
        }
    }

    /// Computes the current tier from `actual / planned`. Tiers do not regress automatically —
    /// the caller should use `advanceTier(currentlyShown:newTier:)` to dedupe.
    static func variableThresholdTier(planned: Double, actual: Double) -> VariableThresholdTier {
        guard planned > 0 else { return .below }
        let ratio = actual / planned
        if ratio >= 1.0 { return .at100 }
        if ratio >= 0.9 { return .at90 }
        if ratio >= 0.75 { return .at75 }
        return .below
    }

    /// Anti-repeat helper. Given the highest tier we've already shown the user this month
    /// (`lastShown`) and the freshly computed tier, returns the tier that should be shown now,
    /// or `nil` to suppress (already shown / still below threshold).
    static func nextVariableThresholdToShow(
        lastShown: VariableThresholdTier?,
        newTier: VariableThresholdTier
    ) -> VariableThresholdTier? {
        guard newTier != .below else { return nil }
        if let lastShown, newTier <= lastShown { return nil }
        return newTier
    }

    // MARK: - 6/7. Variable vs fixed separation

    /// True when the transaction's category resolves to a `.variable` budget item, or when no
    /// budget item matches (default to variable so generic "Other" purchases count toward pace).
    /// Fixed bills and savings goals always return `false`.
    static func isVariableTransaction(
        _ transaction: TransactionItem,
        budgetItems: [BudgetItem]
    ) -> Bool {
        guard transaction.type == .expense else { return false }
        return VariableSpendingPace.isVariableCategory(transaction.category, budgetItems: budgetItems)
    }

    /// Subset of `budgetItems` that are variable (used by the Spending Progress card).
    static func variableBudgetItems(_ budgetItems: [BudgetItem]) -> [BudgetItem] {
        budgetItems.filter { $0.budgetType == .variable }
    }

    /// `(item, actual)` pairs for variable budget items only — fixed bills and savings goals are
    /// excluded from this view by design.
    static func variableSpendingProgress(
        budgetItems: [BudgetItem],
        transactions: [TransactionItem]
    ) -> [(item: BudgetItem, actual: Double)] {
        variableBudgetItems(budgetItems).map { item in
            (item, BudgetSpendCalculator.actualAmountAllTime(transactions: transactions, budgetCategory: item.category))
        }
    }

    // MARK: - 8. Variable spending projection / risk

    /// `variableSpent / daysElapsed * daysInMonth`. Always finite; defaults safely on day 0.
    static func projectedMonthEndVariableSpend(
        variableSpent: Double,
        daysElapsed: Int,
        daysInMonth: Int
    ) -> Double {
        let safeElapsed = max(1, min(daysElapsed, daysInMonth))
        let safeMonth = max(1, daysInMonth)
        return variableSpent / Double(safeElapsed) * Double(safeMonth)
    }

    /// Risk classification matching `VariableSpendingPace.RiskStatus`:
    /// - `onTrack`         : projected <= 90% of variable budget
    /// - `watch`           : 90% < projected <= 100%
    /// - `overBudgetRisk`  : projected > 100%
    static func variableRisk(
        projectedMonthEndSpend: Double,
        variableBudget: Double
    ) -> VariableSpendingPace.RiskStatus {
        guard variableBudget > 0 else { return .onTrack }
        if projectedMonthEndSpend > variableBudget { return .overBudgetRisk }
        if projectedMonthEndSpend > variableBudget * 0.9 { return .watch }
        return .onTrack
    }

    // MARK: - 9. Filter summaries

    enum TransactionFilterMode: String, CaseIterable {
        case all
        case expenses
        case income
    }

    /// Per-row data points the UI surfaces under the "Summary" section of the Transactions tab.
    struct FilterSummary: Equatable {
        let mode: TransactionFilterMode
        let totalIncome: Double
        let totalExpenses: Double
        let net: Double
        let netLabel: String
        let incomeCount: Int
        let expenseCount: Int
        let averageIncome: Double
        let averageExpenses: Double
    }

    static func filterSummary(
        for filter: TransactionFilterMode,
        transactions: [TransactionItem]
    ) -> FilterSummary {
        let income = transactions.filter { $0.type == .income }
        let expenses = transactions.filter { $0.type == .expense }
        let totalIncome = income.reduce(0) { $0 + $1.amount }
        let totalExpenses = expenses.reduce(0) { $0 + BudgetSpendCalculator.netExpenseAmount($1) }
        let net = totalIncome - totalExpenses
        let netLabel: String
        switch filter {
        case .all:
            netLabel = "Net"
        case .expenses, .income:
            // Filtered views must not pretend the user's full picture; surface as "Filtered Net".
            netLabel = "Filtered Net"
        }
        return FilterSummary(
            mode: filter,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            net: net,
            netLabel: netLabel,
            incomeCount: income.count,
            expenseCount: expenses.count,
            averageIncome: income.isEmpty ? 0 : totalIncome / Double(income.count),
            averageExpenses: expenses.isEmpty ? 0 : totalExpenses / Double(expenses.count)
        )
    }

    // MARK: - 10. Daily transaction grouping

    /// Pure data shape the Transactions tab renders one section per day.
    struct DailyTransactionGroup: Identifiable, Equatable {
        let id: Date
        let date: Date
        let transactions: [TransactionItem]
        let income: Double
        let expenses: Double
        let net: Double
    }

    /// Groups `transactions` by calendar day (newest day first; newest transaction within each
    /// day first by `createdAt`) and computes per-day income / expenses / net totals.
    static func groupTransactionsByDay(
        _ transactions: [TransactionItem],
        calendar: Calendar = .current
    ) -> [DailyTransactionGroup] {
        let buckets = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
        return buckets
            .map { day, bucket in
                let sorted = bucket.sorted { $0.createdAt > $1.createdAt }
                let income = sorted
                    .filter { $0.type == .income }
                    .reduce(0) { $0 + $1.amount }
                let expenses = sorted
                    .filter { $0.type == .expense }
                    .reduce(0) { $0 + BudgetSpendCalculator.netExpenseAmount($1) }
                return DailyTransactionGroup(
                    id: day,
                    date: day,
                    transactions: sorted,
                    income: income,
                    expenses: expenses,
                    net: income - expenses
                )
            }
            .sorted { $0.date > $1.date }
    }
}
