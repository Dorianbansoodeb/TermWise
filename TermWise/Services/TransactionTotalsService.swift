import Foundation

/// Aggregates over transactions and budget rows. Pure functions — safe to mirror on Android/Kotlin.
enum TransactionTotalsService {

    static func totalPlannedSpend(budgetItems: [BudgetItem]) -> Double {
        budgetItems.reduce(0) { $0 + $1.planned }
    }

    static func totalActualSpend(transactions: [TransactionItem]) -> Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    static func totalSavedApplied(transactions: [TransactionItem]) -> Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.savedApplied }
    }

    static func totalNetSpend(transactions: [TransactionItem]) -> Double {
        max(0, totalActualSpend(transactions: transactions) - totalSavedApplied(transactions: transactions))
    }

    static func totalBudgetCountedSpend(transactions: [TransactionItem]) -> Double {
        totalNetSpend(transactions: transactions)
    }

    static func totalActualIncome(transactions: [TransactionItem]) -> Double {
        transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    static func monthlyBalance(monthlyIncome: Double, transactions: [TransactionItem]) -> Double {
        monthlyIncome + totalActualIncome(transactions: transactions) - totalActualSpend(transactions: transactions)
    }
}
