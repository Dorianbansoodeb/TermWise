import Foundation
import SwiftUI
import Combine

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"

    var id: String { rawValue }
}

struct TransactionItem: Identifiable, Codable {
    let id: UUID
    let amount: Double
    let category: String
    let note: String
    let date: Date
    let type: TransactionType
}

struct BudgetItem: Identifiable, Codable {
    let id: UUID
    let category: String
    var planned: Double
}

struct OnboardingData: Codable {
    var currentTerm: String
    var monthlyIncome: Double
    var expectedCoopIncome: Double
    var tuitionGoal: Double
    var monthlySpendingBudget: Double
}

final class AppState: ObservableObject {
    private static let storageKey = "termwise.appState.v1"
    private var cancellables = Set<AnyCancellable>()

    // Core profile and goals
    @Published var userFirstName: String = "Piere"
    @Published var currentTerm: String = "Fall 2026"
    @Published var monthlyIncome: Double = 3200
    @Published var expectedCoopIncome: Double = 0
    @Published var tuitionGoal: Double = 4300
    @Published var monthlySpendingBudget: Double = 1480
    @Published var manualMonthlyLimit: Double? = nil
    @Published var desiredSavingsRate: Double = 15 // percent of income the student wants to save

    // Currency
    @Published var currencyCode: String = "USD"

    @Published var draftTransactionType: TransactionType = .expense

    @Published var budgetItems: [BudgetItem] = [
        .init(id: UUID(), category: "Rent", planned: 900),
        .init(id: UUID(), category: "Groceries", planned: 280),
        .init(id: UUID(), category: "Transportation", planned: 120),
        .init(id: UUID(), category: "Eating Out", planned: 140),
        .init(id: UUID(), category: "Tuition/Savings", planned: 300)
    ]

    @Published var transactions: [TransactionItem] = [
        .init(id: UUID(), amount: 920, category: "Paycheque", note: "Biweekly pay", date: Date().addingTimeInterval(-86400 * 2), type: .income),
        .init(id: UUID(), amount: 46, category: "Groceries", note: "Weekly grocery run", date: Date().addingTimeInterval(-86400 * 1), type: .expense),
        .init(id: UUID(), amount: 8.75, category: "Eating Out", note: "Starbucks", date: Date(), type: .expense),
        .init(id: UUID(), amount: 100, category: "Gift", note: "Birthday gift", date: Date(), type: .income)
    ]

    // Simple local history for charts in profile panel
    @Published var monthlyHistory: [MonthlySummary] = [
        .init(id: UUID(), monthLabel: "Jan", planned: 1400, actual: 1320, saved: 80),
        .init(id: UUID(), monthLabel: "Feb", planned: 1450, actual: 1520, saved: -70),
        .init(id: UUID(), monthLabel: "Mar", planned: 1500, actual: 1385, saved: 115),
        .init(id: UUID(), monthLabel: "Apr", planned: 1480, actual: 1410, saved: 70)
    ]

    init() {
        load()
        setupAutoSave()
    }

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

    var effectiveMonthlyLimit: Double {
        manualMonthlyLimit ?? monthlySpendingBudget
    }

    var projectedSavingsThisMonth: Double {
        let targetSavingsAmount = monthlyIncome * (desiredSavingsRate / 100)
        return max(0, targetSavingsAmount - max(0, totalActualSpend - effectiveMonthlyLimit))
    }

    var currencyFormatter: FloatingPointFormatStyle<Double>.Currency {
        .currency(code: currencyCode)
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
        let item = TransactionItem(id: UUID(), amount: amount, category: category, note: note, date: Date(), type: type)
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

    private func setupAutoSave() {
        objectWillChange
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    private func save() {
        let snapshot = PersistedState(
            onboarding: .init(
                currentTerm: currentTerm,
                monthlyIncome: monthlyIncome,
                expectedCoopIncome: expectedCoopIncome,
                tuitionGoal: tuitionGoal,
                monthlySpendingBudget: monthlySpendingBudget
            ),
            manualMonthlyLimit: manualMonthlyLimit,
            desiredSavingsRate: desiredSavingsRate,
            currencyCode: currencyCode,
            budgetItems: budgetItems,
            transactions: transactions
        )

        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            // Intentionally ignore save failures for MVP local mode
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
            currentTerm = decoded.onboarding.currentTerm
            monthlyIncome = decoded.onboarding.monthlyIncome
            expectedCoopIncome = decoded.onboarding.expectedCoopIncome
            tuitionGoal = decoded.onboarding.tuitionGoal
            monthlySpendingBudget = decoded.onboarding.monthlySpendingBudget
            manualMonthlyLimit = decoded.manualMonthlyLimit
            desiredSavingsRate = decoded.desiredSavingsRate
            currencyCode = decoded.currencyCode
            budgetItems = decoded.budgetItems
            transactions = decoded.transactions
        } catch {
            // If decoding fails (schema changes), fall back to defaults
        }
    }
}

private struct PersistedState: Codable {
    let onboarding: OnboardingData
    let manualMonthlyLimit: Double?
    let desiredSavingsRate: Double
    let currencyCode: String
    let budgetItems: [BudgetItem]
    let transactions: [TransactionItem]
}

struct MonthlySummary: Identifiable, Codable {
    let id: UUID
    let monthLabel: String
    let planned: Double
    let actual: Double
    let saved: Double

    var isOver: Bool { saved < 0 }
}
