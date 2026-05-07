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

    /// Spendable amount after the envelope savings target is reserved:
    /// `max(0, availableToBudget − savingsTarget)`. Used as the Total Spending Trend gray
    /// “Spend Limit” line and for total-mode risk vs actual spending.
    static func usableBudgetAfterSavings(
        availableToBudget: Double,
        savingsTarget: Double
    ) -> Double {
        max(0, max(0, availableToBudget) - max(0, savingsTarget))
    }

    // MARK: - Spending trend tooltip (unit-test contract)

    // The trend tooltip is context-sensitive: tapping a past/current day shows **Actual** and
    // omits Projected; tapping a future day shows **Projected** (or total-mode breakdown rows)
    // and omits Actual. Variable mode: Actual/Projected + Budget Pace. Total mode: projected
    // breakdown rows only on future days — **Available** appears only on the gray chart line,
    // never in the tooltip; **Spend Limit** is shown only as the green chart reference (never in the callout).

    /// Variable Spending Trend tooltip rows for `selectedDay <= currentDay` (after the date).
    /// **Never** includes Limit or Savings Target — keeps the callout compact.
    static let spendingTrendVariableTooltipRowTitlesPast: [String] = ["Actual", "Budget Pace"]

    /// Variable Spending Trend tooltip rows for `selectedDay > currentDay`.
    static let spendingTrendVariableTooltipRowTitlesFuture: [String] = ["Projected", "Budget Pace"]

    /// Total Spending Trend tooltip rows for `selectedDay <= currentDay` (after the date).
    /// Actual cumulative total only. **Available** is on-chart only (gray dashed line), never here. **Never** Spend Limit.
    static let spendingTrendTotalTooltipRowTitlesPast: [String] = ["Actual"]

    /// Total Spending Trend tooltip rows for `selectedDay > currentDay` (after the date).
    /// Projected total and unpaid fixed remainder. The variable component is intentionally
    /// omitted to keep the callout compact — it can be inferred from `Projected total − Remaining fixed`.
    /// **Available** is on-chart only, never here. **Never** Spend Limit.
    static let spendingTrendTotalTooltipRowTitlesFuture: [String] = [
        "Projected total spending",
        "Remaining fixed bills"
    ]

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

    // MARK: - Savings target (Budget Plan "Savings Target" card)

    /// Resolves the *envelope-level* savings target the user has chosen for this month.
    ///
    /// - When `customAmount` is non-`nil`, it wins (the user picked **Other** and entered a dollar
    ///   amount). Negative values are clamped at 0.
    /// - Otherwise the target is `availableToBudget * (rate / 100)` (rate as a whole number).
    /// - Negative `availableToBudget` is treated as 0.
    static func savingsTarget(
        availableToBudget: Double,
        rate: Double,
        customAmount: Double? = nil
    ) -> Double {
        if let custom = customAmount {
            return max(0, custom)
        }
        let safeAvailable = max(0, availableToBudget)
        let safeRate = max(0, min(100, rate)) / 100
        return safeAvailable * safeRate
    }

    // MARK: - Monthly snapshot (Budget screen "Monthly Snapshot" card)

    /// Pure, month-scoped rollup that powers the Budget screen's *Monthly Snapshot* card. Compares
    /// **planned allocations** (sum of all non-hidden budget items' planned amounts plus the
    /// envelope-level Savings Target) against the **actual spending** the user has recorded this
    /// calendar month. Variable and recurring slices are tracked separately so the UI can surface
    /// them without recomputing.
    ///
    /// Important properties enforced by this type:
    /// - `plannedBudget` is `sum(item.planned)` over non-hidden budget items, **plus**
    ///   `savingsTarget` (the envelope-level savings number from the Savings Target card). It
    ///   never includes income, never includes actual spending, and never double-counts.
    /// - `actualSpending` is *current month* net expense (transaction.amount − savedApplied),
    ///   never an all-time total.
    /// - `remaining` is signed: positive ⇒ "Remaining Budget", negative ⇒ "Over Spent".
    /// - `recurringBillsTotal` counts only `.fixed` items, ignoring savings goals.
    struct MonthlySnapshot: Equatable {
        let plannedBudget: Double
        let actualSpending: Double
        let remaining: Double
        let savingsTarget: Double
        let variablePlanned: Double
        let variableSpent: Double
        let recurringBillsTotal: Int
        let recurringBillsPaid: Int

        var isOverSpent: Bool { remaining < 0 }
        var isVariableOverPlanned: Bool { variableSpent > variablePlanned }
        var allRecurringBillsPaid: Bool { recurringBillsTotal > 0 && recurringBillsPaid == recurringBillsTotal }
    }

    static func monthlySnapshot(
        budgetItems: [BudgetItem],
        transactions: [TransactionItem],
        hiddenBudgetItemIds: Set<UUID>,
        savingsTarget: Double = 0,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MonthlySnapshot {
        let visibleItems = budgetItems.filter { !hiddenBudgetItemIds.contains($0.id) }

        let itemsPlanned = visibleItems.reduce(0) { $0 + max(0, $1.planned) }
        let resolvedSavingsTarget = max(0, savingsTarget)
        let plannedBudget = itemsPlanned + resolvedSavingsTarget

        let actualSpending = totalExpensesThisMonth(
            transactions: transactions,
            referenceDate: now,
            calendar: calendar
        )

        let variablePlanned = visibleItems
            .filter { $0.budgetType == .variable }
            .reduce(0) { $0 + max(0, $1.planned) }

        let variableSpent = VariableSpendingPace.variableSpent(
            transactions: transactions,
            budgetItems: budgetItems,
            calendar: calendar,
            now: now
        )

        let recurring = visibleItems.filter { $0.budgetType == .fixed }
        let recurringPaid = recurring.filter {
            BudgetSpendCalculator.actualPaidAmount(
                for: $0,
                transactions: transactions,
                now: now,
                calendar: calendar
            ) >= $0.planned
        }.count

        return MonthlySnapshot(
            plannedBudget: plannedBudget,
            actualSpending: actualSpending,
            remaining: plannedBudget - actualSpending,
            savingsTarget: resolvedSavingsTarget,
            variablePlanned: variablePlanned,
            variableSpent: variableSpent,
            recurringBillsTotal: recurring.count,
            recurringBillsPaid: recurringPaid
        )
    }

    // MARK: - 9b. Spending breakdown by category (Plan vs Reality bar)
    //
    // Pure helper used by the Dashboard's Plan vs Reality bar and its tap-to-expand legend.
    // Inputs:
    //   - `transactions`: all transactions; the helper filters to current-month expenses.
    //   - `availableToBudget`: the *source of truth* for the budget envelope. Income transactions
    //     and the legacy "monthly spending limit" are deliberately ignored here.
    //
    // Output is sorted by spent amount descending so the bar renders the largest segment first.

    /// One row of the spending breakdown legend / one segment of the Plan vs Reality bar.
    struct SpendingBreakdownSegment: Equatable {
        let category: String
        /// Net expense amount spent in this category in the selected month (`>= 0`).
        let amount: Double
        /// Share of *actual spending* this category represents, in `[0, 1]`. Sums to ~1.0
        /// across all segments. Useful for the legend's percentage column.
        let percentageOfActual: Double
    }

    /// Aggregate result the bar + legend share. `availableToBudget` is mirrored back so the UI
    /// never has to second-guess which envelope the percentages were computed against.
    struct SpendingBreakdown: Equatable {
        let segments: [SpendingBreakdownSegment]
        /// Sum of net expense amounts in the selected month.
        let actualSpending: Double
        /// Mirror of the input — convenient for label rendering.
        let availableToBudget: Double
        /// `true` iff `actualSpending > availableToBudget`.
        let isOverBudget: Bool
        /// `max(0, actualSpending - availableToBudget)` — what to show after "Over budget by".
        let overBudgetBy: Double
    }

    /// Group current-month *expense* transactions by category and produce a breakdown that the
    /// Plan vs Reality bar (segments) and its tap-to-expand legend (rows) can both render.
    ///
    /// - Income transactions are ignored.
    /// - Categories are grouped case-insensitively but the *original* casing of the first
    ///   transaction in each bucket is preserved for display.
    /// - Negative or zero net amounts (e.g. a bill closed with a 100% saved-applied row) are
    ///   skipped so they don't pollute the breakdown.
    /// - Segments are returned sorted by `amount` descending (ties broken alphabetically by
    ///   category) so the largest spend always renders first.
    static func spendingBreakdown(
        transactions: [TransactionItem],
        availableToBudget: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SpendingBreakdown {
        let monthExpenses = transactions.filter {
            $0.type == .expense && calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }

        // Sum each category's net spend (`amount - savedApplied`, clamped to >= 0).
        var totalsByLowercased: [String: (display: String, amount: Double)] = [:]
        for txn in monthExpenses {
            let net = BudgetSpendCalculator.netExpenseAmount(txn)
            guard net > 0 else { continue }
            let key = txn.category.lowercased()
            if var entry = totalsByLowercased[key] {
                entry.amount += net
                totalsByLowercased[key] = entry
            } else {
                totalsByLowercased[key] = (display: txn.category, amount: net)
            }
        }

        let actualSpending = totalsByLowercased.values.reduce(0) { $0 + $1.amount }
        let safeTotal = max(actualSpending, 0.0001) // guard against /0 when there's no spend yet

        let segments = totalsByLowercased.values
            .map { entry in
                SpendingBreakdownSegment(
                    category: entry.display,
                    amount: entry.amount,
                    percentageOfActual: entry.amount / safeTotal
                )
            }
            .sorted { lhs, rhs in
                if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
                return lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
            }

        let safeAvailable = max(0, availableToBudget)
        let isOver = actualSpending > safeAvailable
        return SpendingBreakdown(
            segments: segments,
            actualSpending: actualSpending,
            availableToBudget: safeAvailable,
            isOverBudget: isOver,
            overBudgetBy: max(0, actualSpending - safeAvailable)
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
