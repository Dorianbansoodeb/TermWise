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
    let targetAmount: Double?
    let deadline: String?

    private enum CodingKeys: String, CodingKey {
        case id, category, planned, frequency
        case budgetType = "budget_type"
        case dueDay = "due_day"
        case dueWeekday = "due_weekday"
        case dueDate = "due_date"
        case isPaid = "is_paid"
        case targetAmount = "target_amount"
        case deadline
    }

    init(
        id: UUID,
        category: String,
        planned: Double,
        budgetType: String,
        frequency: String,
        dueDay: Int?,
        dueWeekday: Int?,
        dueDate: String?,
        isPaid: Bool,
        targetAmount: Double? = nil,
        deadline: String? = nil
    ) {
        self.id = id
        self.category = category
        self.planned = planned
        self.budgetType = budgetType
        self.frequency = frequency
        self.dueDay = dueDay
        self.dueWeekday = dueWeekday
        self.dueDate = dueDate
        self.isPaid = isPaid
        self.targetAmount = targetAmount
        self.deadline = deadline
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        planned = try container.decode(Double.self, forKey: .planned)
        budgetType = try container.decode(String.self, forKey: .budgetType)
        frequency = try container.decode(String.self, forKey: .frequency)
        dueDay = try container.decodeIfPresent(Int.self, forKey: .dueDay)
        dueWeekday = try container.decodeIfPresent(Int.self, forKey: .dueWeekday)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false
        targetAmount = try container.decodeIfPresent(Double.self, forKey: .targetAmount)
        deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
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
    let availableToBudgetByMonth: [String: Double]
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
        case availableToBudgetByMonth = "available_to_budget_by_month"
        case budgetItems = "budget_items"
        case transactions
    }

    init(
        onboarding: OnboardingDataDTO,
        manualMonthlyLimit: Double?,
        desiredSavingsRate: Double,
        bonusIncomeForMonth: Double,
        currencyCode: String,
        billReminders: [BillReminderDTO],
        weeklyNotes: [String: String],
        pinnedTransactionIds: Set<UUID>,
        monthlyNotes: [String: String],
        hiddenBudgetItemIdsByMonth: [String: Set<UUID>],
        fixedBillActualOverridesByMonth: [String: [UUID: Double]],
        fixedBillPaymentTransactionIdsByMonth: [String: [UUID: UUID]],
        availableToBudgetByMonth: [String: Double],
        budgetItems: [BudgetItemDTO],
        transactions: [TransactionItemDTO]
    ) {
        self.onboarding = onboarding
        self.manualMonthlyLimit = manualMonthlyLimit
        self.desiredSavingsRate = desiredSavingsRate
        self.bonusIncomeForMonth = bonusIncomeForMonth
        self.currencyCode = currencyCode
        self.billReminders = billReminders
        self.weeklyNotes = weeklyNotes
        self.pinnedTransactionIds = pinnedTransactionIds
        self.monthlyNotes = monthlyNotes
        self.hiddenBudgetItemIdsByMonth = hiddenBudgetItemIdsByMonth
        self.fixedBillActualOverridesByMonth = fixedBillActualOverridesByMonth
        self.fixedBillPaymentTransactionIdsByMonth = fixedBillPaymentTransactionIdsByMonth
        self.availableToBudgetByMonth = availableToBudgetByMonth
        self.budgetItems = budgetItems
        self.transactions = transactions
    }
}

extension PersistedStateDTO {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboarding = try container.decode(OnboardingDataDTO.self, forKey: .onboarding)
        manualMonthlyLimit = try container.decodeIfPresent(Double.self, forKey: .manualMonthlyLimit)
        desiredSavingsRate = try container.decode(Double.self, forKey: .desiredSavingsRate)
        bonusIncomeForMonth = try container.decode(Double.self, forKey: .bonusIncomeForMonth)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        billReminders = try container.decode([BillReminderDTO].self, forKey: .billReminders)
        weeklyNotes = try container.decode([String: String].self, forKey: .weeklyNotes)
        pinnedTransactionIds = try container.decodeIfPresent(Set<UUID>.self, forKey: .pinnedTransactionIds) ?? []
        monthlyNotes = try container.decodeIfPresent([String: String].self, forKey: .monthlyNotes) ?? [:]
        hiddenBudgetItemIdsByMonth = try container.decodeIfPresent([String: Set<UUID>].self, forKey: .hiddenBudgetItemIdsByMonth) ?? [:]
        fixedBillActualOverridesByMonth = try container.decodeIfPresent([String: [UUID: Double]].self, forKey: .fixedBillActualOverridesByMonth) ?? [:]
        fixedBillPaymentTransactionIdsByMonth = try container.decodeIfPresent([String: [UUID: UUID]].self, forKey: .fixedBillPaymentTransactionIdsByMonth) ?? [:]
        availableToBudgetByMonth = try container.decodeIfPresent([String: Double].self, forKey: .availableToBudgetByMonth) ?? [:]
        budgetItems = try container.decode([BudgetItemDTO].self, forKey: .budgetItems)
        transactions = try container.decode([TransactionItemDTO].self, forKey: .transactions)
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
            isPaid: isPaid,
            targetAmount: targetAmount,
            deadline: deadline.flatMap { apiDateFormatter.date(from: $0) }
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
            isPaid: isPaid,
            targetAmount: targetAmount,
            deadline: deadline.map { apiDateFormatter.string(from: $0) }
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
            availableToBudgetByMonth: availableToBudgetByMonth,
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
            availableToBudgetByMonth: availableToBudgetByMonth,
            budgetItems: budgetItems.map { $0.toDTO() },
            transactions: transactions.map { $0.toDTO() }
        )
    }
}
