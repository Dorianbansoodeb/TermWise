import Foundation

/// Net spend and category matching used by budget + fixed bills.
/// Port this file verbatim (names + formulas) to Android `BudgetSpendCalculator` (or equivalent package).
enum BudgetSpendCalculator {

    static func normalizedCategoryToken(_ category: String) -> String {
        category.replacingOccurrences(of: "/Savings", with: "")
    }

    static func matchesCategory(transactionCategory: String, budgetCategory: String) -> Bool {
        transactionCategory.localizedCaseInsensitiveContains(normalizedCategoryToken(budgetCategory))
    }

    static func netExpenseAmount(_ transaction: TransactionItem) -> Double {
        max(0, transaction.amount - transaction.savedApplied)
    }

    /// All-time net expense total for transactions matching a budget category (variable categories).
    static func actualAmountAllTime(transactions: [TransactionItem], budgetCategory: String) -> Double {
        transactions
            .filter { $0.type == .expense && matchesCategory(transactionCategory: $0.category, budgetCategory: budgetCategory) }
            .reduce(0) { $0 + netExpenseAmount($1) }
    }

    /// Net expenses in the same calendar month as `referenceDate` (fixed bills / recurring).
    static func actualAmountInMonth(
        transactions: [TransactionItem],
        budgetCategory: String,
        referenceDate: Date,
        calendar: Calendar
    ) -> Double {
        transactions
            .filter { $0.type == .expense && calendar.isDate($0.date, equalTo: referenceDate, toGranularity: .month) }
            .filter { matchesCategory(transactionCategory: $0.category, budgetCategory: budgetCategory) }
            .reduce(0) { $0 + netExpenseAmount($1) }
    }

    /// For fixed items: month-scoped actual; for variable: all-time category spend.
    static func actualPaidAmount(
        for item: BudgetItem,
        transactions: [TransactionItem],
        now: Date,
        calendar: Calendar
    ) -> Double {
        guard item.budgetType == .fixed else {
            return actualAmountAllTime(transactions: transactions, budgetCategory: item.category)
        }
        return actualAmountInMonth(
            transactions: transactions,
            budgetCategory: item.category,
            referenceDate: now,
            calendar: calendar
        )
    }
}
