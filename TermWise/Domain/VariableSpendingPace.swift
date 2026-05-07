import Foundation

/// Variable (flexible) spending pace + risk classification.
///
/// Fixed/recurring bills (rent, phone, subscriptions, insurance, loans, tuition/savings) are
/// excluded from this calculation. They have due dates and are tracked via
/// `FixedBillSchedule` / `FixedBillPaidSync`, not by daily spending pace.
///
/// Mirror this file verbatim (names + formulas) to Android and any backend analytics route.
enum VariableSpendingPace {

    enum RiskStatus: String, Codable {
        case onTrack
        case watch
        case overBudgetRisk

        var badgeText: String {
            switch self {
            case .onTrack: return "On Track"
            case .watch: return "Watch"
            case .overBudgetRisk: return "Over Budget Risk"
            }
        }
    }

    struct Result {
        let variableBudget: Double
        let variableSpent: Double
        let expectedSpentByToday: Double
        let projectedMonthEndSpend: Double
        let status: RiskStatus
    }

    /// True when the transaction's category resolves to a `.variable` budget item, or is
    /// uncategorized (default to variable so generic "Other" purchases count toward pace).
    /// Fixed bills and savings goals are excluded — they have their own status tracking.
    static func isVariableCategory(_ category: String, budgetItems: [BudgetItem]) -> Bool {
        if let match = budgetItems.first(where: {
            BudgetSpendCalculator.matchesCategory(transactionCategory: category, budgetCategory: $0.category)
        }) {
            return match.budgetType == .variable
        }
        return true
    }

    static func variableTransactionsThisMonth(
        transactions: [TransactionItem],
        budgetItems: [BudgetItem],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [TransactionItem] {
        transactions.filter {
            $0.type == .expense
                && calendar.isDate($0.date, equalTo: now, toGranularity: .month)
                && isVariableCategory($0.category, budgetItems: budgetItems)
        }
    }

    /// Sum of `planned` over budget items where `budgetType == .variable`.
    static func variableBudget(budgetItems: [BudgetItem]) -> Double {
        budgetItems
            .filter { $0.budgetType == .variable }
            .reduce(0) { $0 + max(0, $1.planned) }
    }

    /// Net variable spend in the current calendar month.
    static func variableSpent(
        transactions: [TransactionItem],
        budgetItems: [BudgetItem],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Double {
        variableTransactionsThisMonth(
            transactions: transactions,
            budgetItems: budgetItems,
            calendar: calendar,
            now: now
        )
        .reduce(0) { $0 + BudgetSpendCalculator.netExpenseAmount($1) }
    }

    /// Cumulative variable expense per day, day 1...currentDayOfMonth.
    static func dailyVariableActualCumulative(
        transactions: [TransactionItem],
        budgetItems: [BudgetItem],
        currentDayOfMonth: Int,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [Double] {
        let monthVariable = variableTransactionsThisMonth(
            transactions: transactions,
            budgetItems: budgetItems,
            calendar: calendar,
            now: now
        )
        var cumulative: [Double] = []
        var running = 0.0
        for day in 1...max(1, currentDayOfMonth) {
            let dayTotal = monthVariable
                .filter { calendar.component(.day, from: $0.date) == day }
                .reduce(0) { $0 + BudgetSpendCalculator.netExpenseAmount($1) }
            running += dayTotal
            cumulative.append(running)
        }
        return cumulative
    }

    /// Cumulative *expected* variable spend across the whole month, day 1...daysInMonth.
    /// Drawn as the orange "Budget Pace" line on the trend chart.
    static func dailyExpectedCumulative(
        variableBudget: Double,
        daysInMonth: Int
    ) -> [Double] {
        guard daysInMonth > 0 else { return [] }
        let perDay = variableBudget / Double(daysInMonth)
        return (1...daysInMonth).map { Double($0) * perDay }
    }

    /// Risk classification for the dashboard badge / chart projection color.
    ///
    /// - `onTrack`        : projected month-end <= 90% of variable budget
    /// - `watch`          : projected month-end in (90%, 100%] of variable budget
    /// - `overBudgetRisk` : projected month-end > variable budget
    static func evaluate(
        budgetItems: [BudgetItem],
        transactions: [TransactionItem],
        currentDayOfMonth: Int,
        daysInMonth: Int,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Result {
        let budget = variableBudget(budgetItems: budgetItems)
        let spent = variableSpent(
            transactions: transactions,
            budgetItems: budgetItems,
            calendar: calendar,
            now: now
        )
        let safeDaysInMonth = max(1, daysInMonth)
        let safeDaysElapsed = max(1, min(currentDayOfMonth, daysInMonth))
        let expected = budget * (Double(safeDaysElapsed) / Double(safeDaysInMonth))
        let projected = spent / Double(safeDaysElapsed) * Double(safeDaysInMonth)

        let status: RiskStatus
        if budget <= 0 {
            status = .onTrack
        } else if projected <= budget * 0.9 {
            status = .onTrack
        } else if projected <= budget {
            status = .watch
        } else {
            status = .overBudgetRisk
        }

        return Result(
            variableBudget: budget,
            variableSpent: spent,
            expectedSpentByToday: expected,
            projectedMonthEndSpend: projected,
            status: status
        )
    }
}
