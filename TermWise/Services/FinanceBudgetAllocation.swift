import Foundation

/// Separates **income received** from **money allocated to the budget** (fixed, variable, savings goals).
/// Mirror on Android when wiring the same API contract.
enum FinanceBudgetAllocation {

    /// Sum of income transactions dated in the same calendar month as `referenceDate`.
    static func calculateTotalIncome(
        transactions: [TransactionItem],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Double {
        transactions
            .filter { $0.type == .income && calendar.isDate($0.date, equalTo: referenceDate, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Explicit override for `monthKey` if present; otherwise `totalIncome` when positive; otherwise profile expectation (legacy / empty month).
    static func calculateAvailableToBudget(
        explicitByMonth: [String: Double],
        monthKey: String,
        totalIncome: Double,
        fallbackExpectedMonthlyIncome: Double
    ) -> Double {
        if let explicit = explicitByMonth[monthKey] {
            return explicit
        }
        if totalIncome > 0 {
            return totalIncome
        }
        return fallbackExpectedMonthlyIncome
    }

    /// Planned amounts for categories included in this month’s plan (hidden rows excluded).
    static func calculateTotalBudgeted(
        budgetItems: [BudgetItem],
        hiddenBudgetItemIds: Set<UUID>
    ) -> Double {
        budgetItems
            .filter { !hiddenBudgetItemIds.contains($0.id) }
            .reduce(0) { $0 + $1.planned }
    }

    static func calculateUnallocatedIncome(
        availableToBudget: Double,
        totalBudgeted: Double
    ) -> Double {
        availableToBudget - totalBudgeted
    }

    /// `totalBudgeted - availableToBudget`. Positive means over-allocated; negative means headroom.
    static func calculateBudgetDifference(
        totalBudgeted: Double,
        availableToBudget: Double
    ) -> Double {
        totalBudgeted - availableToBudget
    }

    /// `totalIncome - availableToBudget`. Positive when the user is keeping income outside their budget envelope.
    static func calculateReserveNotBudgeted(
        totalIncome: Double,
        availableToBudget: Double
    ) -> Double {
        max(0, totalIncome - availableToBudget)
    }

    /// Money preserved by spending less than what was budgeted so far this month. Reliable, non-negative.
    static func calculateBudgetCushionThisMonth(
        totalBudgeted: Double,
        totalBudgetCountedSpend: Double
    ) -> Double {
        max(0, totalBudgeted - totalBudgetCountedSpend)
    }

    /// Dynamic dashboard label for the budget difference row.
    /// - Returns: `("Unallocated Budget", positive)` when at/under budget, `("Over Budget By", absolute)` otherwise.
    static func unallocatedRow(
        availableToBudget: Double,
        totalBudgeted: Double
    ) -> (label: String, value: Double, isOver: Bool) {
        let diff = availableToBudget - totalBudgeted
        if diff >= 0 {
            return ("Unallocated Budget", diff, false)
        }
        return ("Over Budget By", abs(diff), true)
    }
}
