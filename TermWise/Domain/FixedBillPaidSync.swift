import Foundation

/// Keeps `BudgetItem.isPaid` aligned with transaction-derived actuals for fixed bills.
enum FixedBillPaidSync {

    static func reconcile(
        budgetItems: inout [BudgetItem],
        transactions: [TransactionItem],
        now: Date,
        calendar: Calendar
    ) {
        for index in budgetItems.indices where budgetItems[index].budgetType == .fixed {
            let actual = BudgetSpendCalculator.actualPaidAmount(
                for: budgetItems[index],
                transactions: transactions,
                now: now,
                calendar: calendar
            )
            budgetItems[index].isPaid = actual >= budgetItems[index].planned
        }
    }
}
