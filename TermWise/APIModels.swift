import Foundation

struct BudgetItemDTO: Codable {
    let id: UUID
    let category: String
    let planned: Double
    let budgetType: String
    let frequency: String
    let dueDay: Int?
    let dueWeekday: Int?
    let dueDate: String?
    let isPaid: Bool
}

struct TransactionItemDTO: Codable {
    let id: UUID
    let amount: Double
    let name: String
    let category: String
    let note: String
    let date: String
    let createdAt: String
    let type: String
    let savedApplied: Double
}

struct PersistedStateDTO: Codable {
    let onboarding: OnboardingData
    let manualMonthlyLimit: Double?
    let desiredSavingsRate: Double
    let bonusIncomeForMonth: Double
    let currencyCode: String
    let billReminders: [BillReminder]
    let weeklyNotes: [String: String]
    let pinnedTransactionIds: Set<UUID>
    let monthlyNotes: [String: String]
    let hiddenBudgetItemIdsByMonth: [String: Set<UUID>]
    let fixedBillActualOverridesByMonth: [String: [UUID: Double]]
    let fixedBillPaymentTransactionIdsByMonth: [String: [UUID: UUID]]
    let budgetItems: [BudgetItemDTO]
    let transactions: [TransactionItemDTO]
}

private let apiDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

extension BudgetItemDTO {
    func toDomain() -> BudgetItem {
        BudgetItem(
            id: id,
            category: category,
            planned: planned,
            budgetType: BudgetType(rawValue: budgetType) ?? .variable,
            frequency: PaymentFrequency(rawValue: frequency) ?? .none,
            dueDay: dueDay,
            dueWeekday: dueWeekday,
            dueDate: dueDate.flatMap { apiDateFormatter.date(from: $0) },
            isPaid: isPaid
        )
    }
}

extension BudgetItem {
    func toDTO() -> BudgetItemDTO {
        BudgetItemDTO(
            id: id,
            category: category,
            planned: planned,
            budgetType: budgetType.rawValue,
            frequency: frequency.rawValue,
            dueDay: dueDay,
            dueWeekday: dueWeekday,
            dueDate: dueDate.map { apiDateFormatter.string(from: $0) },
            isPaid: isPaid
        )
    }
}

extension TransactionItemDTO {
    func toDomain() -> TransactionItem {
        let parsedDate = apiDateFormatter.date(from: date) ?? Date()
        let parsedCreatedAt = apiDateFormatter.date(from: createdAt) ?? parsedDate
        return TransactionItem(
            id: id,
            amount: amount,
            name: name,
            category: category,
            note: note,
            date: parsedDate,
            createdAt: parsedCreatedAt,
            type: TransactionType(rawValue: type) ?? .expense,
            savedApplied: savedApplied
        )
    }
}

extension TransactionItem {
    func toDTO() -> TransactionItemDTO {
        TransactionItemDTO(
            id: id,
            amount: amount,
            name: name,
            category: category,
            note: note,
            date: apiDateFormatter.string(from: date),
            createdAt: apiDateFormatter.string(from: createdAt),
            type: type.rawValue,
            savedApplied: savedApplied
        )
    }
}

extension PersistedStateDTO {
    func toDomain() -> PersistedState {
        PersistedState(
            onboarding: onboarding,
            manualMonthlyLimit: manualMonthlyLimit,
            desiredSavingsRate: desiredSavingsRate,
            bonusIncomeForMonth: bonusIncomeForMonth,
            currencyCode: currencyCode,
            billReminders: billReminders,
            weeklyNotes: weeklyNotes,
            pinnedTransactionIds: pinnedTransactionIds,
            monthlyNotes: monthlyNotes,
            hiddenBudgetItemIdsByMonth: hiddenBudgetItemIdsByMonth,
            fixedBillActualOverridesByMonth: fixedBillActualOverridesByMonth,
            fixedBillPaymentTransactionIdsByMonth: fixedBillPaymentTransactionIdsByMonth,
            budgetItems: budgetItems.map { $0.toDomain() },
            transactions: transactions.map { $0.toDomain() }
        )
    }
}

extension PersistedState {
    func toDTO() -> PersistedStateDTO {
        PersistedStateDTO(
            onboarding: onboarding,
            manualMonthlyLimit: manualMonthlyLimit,
            desiredSavingsRate: desiredSavingsRate,
            bonusIncomeForMonth: bonusIncomeForMonth,
            currencyCode: currencyCode,
            billReminders: billReminders,
            weeklyNotes: weeklyNotes,
            pinnedTransactionIds: pinnedTransactionIds,
            monthlyNotes: monthlyNotes,
            hiddenBudgetItemIdsByMonth: hiddenBudgetItemIdsByMonth,
            fixedBillActualOverridesByMonth: fixedBillActualOverridesByMonth,
            fixedBillPaymentTransactionIdsByMonth: fixedBillPaymentTransactionIdsByMonth,
            budgetItems: budgetItems.map { $0.toDTO() },
            transactions: transactions.map { $0.toDTO() }
        )
    }
}
