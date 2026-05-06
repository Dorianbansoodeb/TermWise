import Foundation
import SwiftUI

enum TransactionType: String, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"

    var id: String { rawValue }
}

struct TransactionItem: Identifiable {
    let id = UUID()
    let amount: Double
    let category: String
    let note: String
    let date: Date
    let type: TransactionType
}

struct BudgetItem: Identifiable {
    let id = UUID()
    let category: String
    var planned: Double
}

struct OnboardingData {
    var currentTerm: String
    var monthlyIncome: Double
    var expectedCoopIncome: Double
    var tuitionGoal: Double
    var monthlySpendingBudget: Double
}

final class AppState: ObservableObject {
    @Published var currentTerm: String = "Fall 2026"
    @Published var monthlyIncome: Double = 3200
    @Published var expectedCoopIncome: Double = 0
    @Published var tuitionGoal: Double = 4300
    @Published var monthlySpendingBudget: Double = 1480
    @Published var draftTransactionType: TransactionType = .expense

    @Published var budgetItems: [BudgetItem] = [
        .init(category: "Rent", planned: 900),
        .init(category: "Groceries", planned: 280),
        .init(category: "Transportation", planned: 120),
        .init(category: "Eating Out", planned: 140),
        .init(category: "Tuition/Savings", planned: 300)
    ]

    @Published var transactions: [TransactionItem] = [
        .init(amount: 920, category: "Paycheque", note: "Biweekly pay", date: Date().addingTimeInterval(-86400 * 2), type: .income),
        .init(amount: 46, category: "Groceries", note: "Weekly grocery run", date: Date().addingTimeInterval(-86400 * 1), type: .expense),
        .init(amount: 8.75, category: "Eating Out", note: "Starbucks", date: Date(), type: .expense),
        .init(amount: 100, category: "Gift", note: "Birthday gift", date: Date(), type: .income)
    ]

    var totalPlannedSpend: Double {
        budgetItems.reduce(0) { $0 + $1.planned }
    }

    var totalActualSpend: Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    var totalActualIncome: Double {
        transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    var monthlyBalance: Double {
        monthlyIncome + totalActualIncome - totalActualSpend
    }

    var awarenessMessages: [String] {
        var messages: [String] = []

        for item in budgetItems {
            let spent = actualAmount(for: item.category)
            let percentUsed = item.planned > 0 ? Int((spent / item.planned) * 100) : 0
            if percentUsed >= 70 && percentUsed < 100 {
                messages.append("You have used \(percentUsed)% of your \(item.category) budget.")
            } else if percentUsed >= 100 {
                messages.append("At this pace, you may exceed your \(item.category) budget.")
            }
        }

        if messages.isEmpty {
            messages.append("You are currently on track with your spending plan.")
        }
        return messages
    }

    func actualAmount(for category: String) -> Double {
        transactions
            .filter { $0.type == .expense && $0.category.localizedCaseInsensitiveContains(category.replacingOccurrences(of: "/Savings", with: "")) }
            .reduce(0) { $0 + $1.amount }
    }

    func addTransaction(amount: Double, category: String, note: String, type: TransactionType) {
        let item = TransactionItem(amount: amount, category: category, note: note, date: Date(), type: type)
        transactions.insert(item, at: 0)
    }

    func apply(onboardingData: OnboardingData) {
        currentTerm = onboardingData.currentTerm
        monthlyIncome = onboardingData.monthlyIncome
        expectedCoopIncome = onboardingData.expectedCoopIncome
        tuitionGoal = onboardingData.tuitionGoal
        monthlySpendingBudget = onboardingData.monthlySpendingBudget

        let nonTuitionTotal = budgetItems.dropLast().reduce(0) { $0 + $1.planned }
        let tuitionPlanned = max(0, monthlySpendingBudget - nonTuitionTotal)
        if let lastIndex = budgetItems.indices.last {
            budgetItems[lastIndex].planned = tuitionPlanned
        }
    }
}
