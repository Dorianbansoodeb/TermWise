import Foundation

/// Total spending classification for the *Total Spending Trend* chart mode.
///
/// Definitions (single source of truth, mirrored on the Budget Plan screen):
///
///     spendLimit                 = max(0, availableToBudget − savingsTarget)
///     variableDailyRate          = variableSpentSoFar / daysElapsed
///     futureVariableProjection   = variableDailyRate × daysRemaining
///     projectedVariableMonthEnd  = variableDailyRate × daysInMonth
///     projectedMonthEnd          = totalSpent
///                                + futureVariableProjection
///                                + unpaidFixedBillsRemaining
///
/// Critical: **fixed bills are always treated as expected for the month**, regardless of
/// whether they have already been paid. Paying rent on day 10 must not move the projected
/// month-end up — rent was already expected. Equivalently:
///
///     projectedMonthEnd ≈ projectedVariableMonthEnd + expectedFixedBillsThisMonth
///
/// (The "≈" is exact when fixed bills aren't overpaid; overpayment correctly bumps the
/// projection because `unpaidFixedBillsRemaining` is clamped at 0 per bill.)
///
/// Risk band (compares **projected** total to two thresholds):
/// - **Over Budget** — `projected > availableToBudget` → red copy:
///   "Projected to exceed your monthly budget by $X across all expenses."
/// - **Near Limit** — `spendLimit < projected ≤ availableToBudget` → orange copy:
///   "Projected to use money reserved for savings by $X."
/// - **On Track**   — `projected ≤ spendLimit` → green/neutral copy:
///   "Projected spending is within your savings-protected limit."
///
/// Visual mapping enforced by the Dashboard:
/// - Gray dashed line  → `availableToBudget`              (label: "Available $X")
/// - Green line        → `spendLimit`                     (label: "Spend Limit $X")
/// - Red dashed line   → `projectedMonthEndSpend`         (label: "Projected")
///
/// Mirror this file verbatim on Android.
enum TotalSpendingPace {

    enum RiskStatus: String, Codable, Equatable, Sendable {
        case onTrack
        case nearLimit
        case overBudget

        var badgeText: String {
            switch self {
            case .onTrack: return "On Track"
            case .nearLimit: return "Near Limit"
            case .overBudget: return "Over Budget"
            }
        }
    }

    struct Result: Equatable {
        let availableToBudget: Double
        /// Resolved envelope savings target (same source as Budget Plan Savings Target card).
        let savingsTarget: Double
        /// `max(0, availableToBudget − savingsTarget)` — drives the **green** chart line.
        let spendLimit: Double
        /// Sum of net expense amounts this month (all categories — fixed + variable + savings).
        let totalSpent: Double
        /// Variable expenses so far this month — drives the projection slope.
        let variableSpentSoFar: Double
        /// `variableSpentSoFar / daysElapsed × daysInMonth` — month-end variable forecast.
        let projectedVariableMonthEndSpend: Double
        /// Sum of `planned` for **all** fixed/recurring budget items this month, regardless of
        /// whether they're already paid. Drives the displayed "Remaining fixed bills" tooltip
        /// row indirectly via `unpaidFixedBillsRemaining`.
        let expectedFixedBillsThisMonth: Double
        /// Σ over fixed bills of `max(0, planned − actualPaidThisMonth)`. Already-paid bills
        /// drop out so the projection stays invariant when the user marks a bill as paid.
        let unpaidFixedBillsRemaining: Double
        /// `totalSpent + variableDailyRate × daysRemaining + unpaidFixedBillsRemaining`.
        /// Anchors at today's actual; only the variable burn rate is extrapolated forward,
        /// and unpaid fixed bills are added once at month end.
        let projectedMonthEndSpend: Double
        /// `spendLimit × daysElapsed ÷ daysInMonth` — expected cumulative spend by today at pace.
        let expectedSpentByToday: Double
        let status: RiskStatus
        /// `max(0, totalSpent − spendLimit)` — surfaced for after-the-fact reporting.
        let overBudgetByAmount: Double
        /// `max(0, projectedMonthEndSpend − spendLimit)` — drives the **Near Limit** orange copy
        /// ("Projected to use money reserved for savings by $X.").
        let projectedOverBudgetByAmount: Double
        /// `max(0, projectedMonthEndSpend − availableToBudget)` — drives the **Over Budget** red
        /// copy ("Projected to exceed your monthly budget by $X across all expenses."). This is
        /// the *primary* over-budget signal on the Total chart and is intentionally distinct
        /// from `projectedOverBudgetByAmount`.
        let projectedOverAvailableByAmount: Double
    }

    /// Net total expense in the current calendar month — every expense category counts.
    static func totalSpent(
        transactions: [TransactionItem],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Double {
        transactions
            .filter { $0.type == .expense && calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + BudgetSpendCalculator.netExpenseAmount($1) }
    }

    /// Risk + limits for the Total Spending Trend card and chart.
    ///
    /// All "fixed bill" inputs are pre-aggregated **dollar totals** (not per-bill data) so the
    /// domain stays free of `BudgetItem` knowledge:
    /// - `expectedFixedBillsThisMonth`  — Σ planned over all non-variable items expected this month
    /// - `unpaidFixedBillsRemaining`    — Σ `max(0, planned − actualPaidThisMonth)` over the same set
    ///
    /// `variableSpentSoFar` should come from `VariableSpendingPace.variableSpent(...)` so both
    /// charts agree on what counts as variable.
    static func evaluate(
        transactions: [TransactionItem],
        availableToBudget: Double,
        savingsTarget: Double,
        variableSpentSoFar: Double,
        expectedFixedBillsThisMonth: Double,
        unpaidFixedBillsRemaining: Double,
        currentDayOfMonth: Int,
        daysInMonth: Int,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Result {
        let safeAvailable = max(0, availableToBudget)
        let safeSavings = max(0, savingsTarget)
        let spendLimit = max(0, safeAvailable - safeSavings)
        let safeVariableSpent = max(0, variableSpentSoFar)
        let safeExpectedFixed = max(0, expectedFixedBillsThisMonth)
        let safeUnpaidFixed = max(0, unpaidFixedBillsRemaining)

        let spent = totalSpent(transactions: transactions, calendar: calendar, now: now)

        let safeDaysInMonth = max(1, daysInMonth)
        let safeDaysElapsed = max(1, min(currentDayOfMonth, daysInMonth))
        let daysRemaining = max(0, safeDaysInMonth - safeDaysElapsed)

        // Variable burn rate, used both for the future variable slope and the standalone
        // "month-end variable" forecast surfaced in tooltips/tests.
        let variableDailyRate = safeVariableSpent / Double(safeDaysElapsed)
        let futureVariableProjection = variableDailyRate * Double(daysRemaining)
        let projectedVariableMonthEnd = variableDailyRate * Double(safeDaysInMonth)

        // Anchor at today's actual; project forward by variable pace only; add the still-owed
        // fixed bill amount in one shot. Already-paid fixed bills are baked into `spent`, so
        // re-paying does not double count.
        let projected = spent + futureVariableProjection + safeUnpaidFixed

        let expected = spendLimit * (Double(safeDaysElapsed) / Double(safeDaysInMonth))
        let overBy = max(0, spent - spendLimit)
        let projectedOverSpendLimit = max(0, projected - spendLimit)
        let projectedOverAvailable = max(0, projected - safeAvailable)

        // Status compares *projected* month-end total against the two thresholds.
        let status: RiskStatus
        if projected > safeAvailable {
            status = .overBudget
        } else if projected > spendLimit {
            status = .nearLimit
        } else {
            status = .onTrack
        }

        return Result(
            availableToBudget: safeAvailable,
            savingsTarget: safeSavings,
            spendLimit: spendLimit,
            totalSpent: spent,
            variableSpentSoFar: safeVariableSpent,
            projectedVariableMonthEndSpend: projectedVariableMonthEnd,
            expectedFixedBillsThisMonth: safeExpectedFixed,
            unpaidFixedBillsRemaining: safeUnpaidFixed,
            projectedMonthEndSpend: projected,
            expectedSpentByToday: expected,
            status: status,
            overBudgetByAmount: overBy,
            projectedOverBudgetByAmount: projectedOverSpendLimit,
            projectedOverAvailableByAmount: projectedOverAvailable
        )
    }
}
