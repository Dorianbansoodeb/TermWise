import Foundation

// MARK: - Wire format (backend / Android)
// These DTOs define the canonical JSON field names (snake_case) for the future REST API.
// Domain models in `Domain/PlanningTypes.swift` stay UI-agnostic; map at the repository boundary.

// MARK: - Onboarding

struct OnboardingDataDTO: Codable {
    let currentTerm: String
    let monthlyIncome: Double
    let expectedCoopIncome: Double
    let tuitionGoal: Double
    let monthlySpendingBudget: Double

    private enum CodingKeys: String, CodingKey {
        case currentTerm = "current_term"
        case monthlyIncome = "monthly_income"
        case expectedCoopIncome = "expected_coop_income"
        case tuitionGoal = "tuition_goal"
        case monthlySpendingBudget = "monthly_spending_budget"
    }
}

extension OnboardingDataDTO {
    func toDomain() -> OnboardingData {
        OnboardingData(
            currentTerm: currentTerm,
            monthlyIncome: monthlyIncome,
            expectedCoopIncome: expectedCoopIncome,
            tuitionGoal: tuitionGoal,
            monthlySpendingBudget: monthlySpendingBudget
        )
    }
}

extension OnboardingData {
    func toDTO() -> OnboardingDataDTO {
        OnboardingDataDTO(
            currentTerm: currentTerm,
            monthlyIncome: monthlyIncome,
            expectedCoopIncome: expectedCoopIncome,
            tuitionGoal: tuitionGoal,
            monthlySpendingBudget: monthlySpendingBudget
        )
    }
}

// MARK: - Bill reminders

struct BillReminderDTO: Codable {
    let id: UUID
    let title: String
    let dueDay: Int
    let expectedAmount: Double

    private enum CodingKeys: String, CodingKey {
        case id, title
        case dueDay = "due_day"
        case expectedAmount = "expected_amount"
    }
}

extension BillReminderDTO {
    func toDomain() -> BillReminder {
        BillReminder(id: id, title: title, dueDay: dueDay, expectedAmount: expectedAmount)
    }
}

extension BillReminder {
    func toDTO() -> BillReminderDTO {
        BillReminderDTO(id: id, title: title, dueDay: dueDay, expectedAmount: expectedAmount)
    }
}

// MARK: - Budget & transactions

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

    private enum CodingKeys: String, CodingKey {
        case id, category, planned, frequency
        case budgetType = "budget_type"
        case dueDay = "due_day"
        case dueWeekday = "due_weekday"
        case dueDate = "due_date"
        case isPaid = "is_paid"
    }
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
    let source: String?
    let billId: UUID?
    let undoable: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, amount, name, category, note, date, type, source
        case createdAt = "created_at"
        case savedApplied = "saved_applied"
        case billId = "bill_id"
        case undoable
    }
}

// MARK: - Full snapshot (GET/PUT /api/snapshot)

struct PersistedStateDTO: Codable {
    let onboarding: OnboardingDataDTO
    let manualMonthlyLimit: Double?
    let desiredSavingsRate: Double
    let bonusIncomeForMonth: Double
    let currencyCode: String
    let billReminders: [BillReminderDTO]
    let weeklyNotes: [String: String]
    let pinnedTransactionIds: Set<UUID>
    let monthlyNotes: [String: String]
    let hiddenBudgetItemIdsByMonth: [String: Set<UUID>]
    let fixedBillActualOverridesByMonth: [String: [UUID: Double]]
    let fixedBillPaymentTransactionIdsByMonth: [String: [UUID: UUID]]
    let budgetItems: [BudgetItemDTO]
    let transactions: [TransactionItemDTO]

    private enum CodingKeys: String, CodingKey {
        case onboarding
        case manualMonthlyLimit = "manual_monthly_limit"
        case desiredSavingsRate = "desired_savings_rate"
        case bonusIncomeForMonth = "bonus_income_for_month"
        case currencyCode = "currency_code"
        case billReminders = "bill_reminders"
        case weeklyNotes = "weekly_notes"
        case pinnedTransactionIds = "pinned_transaction_ids"
        case monthlyNotes = "monthly_notes"
        case hiddenBudgetItemIdsByMonth = "hidden_budget_item_ids_by_month"
        case fixedBillActualOverridesByMonth = "fixed_bill_actual_overrides_by_month"
        case fixedBillPaymentTransactionIdsByMonth = "fixed_bill_payment_transaction_ids_by_month"
        case budgetItems = "budget_items"
        case transactions
    }
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
            savedApplied: savedApplied,
            source: source,
            billId: billId,
            undoable: undoable ?? false
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
            savedApplied: savedApplied,
            source: source,
            billId: billId,
            undoable: undoable
        )
    }
}

extension PersistedStateDTO {
    func toDomain() -> PersistedState {
        PersistedState(
            onboarding: onboarding.toDomain(),
            manualMonthlyLimit: manualMonthlyLimit,
            desiredSavingsRate: desiredSavingsRate,
            bonusIncomeForMonth: bonusIncomeForMonth,
            currencyCode: currencyCode,
            billReminders: billReminders.map { $0.toDomain() },
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
            onboarding: onboarding.toDTO(),
            manualMonthlyLimit: manualMonthlyLimit,
            desiredSavingsRate: desiredSavingsRate,
            bonusIncomeForMonth: bonusIncomeForMonth,
            currencyCode: currencyCode,
            billReminders: billReminders.map { $0.toDTO() },
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
