import Foundation

// MARK: - Cross-platform planning domain
// Types and persistence shapes in this file must stay in sync with Android (Kotlin) and backend contracts.

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"

    var id: String { rawValue }
}

struct TransactionItem: Identifiable, Codable {
    let id: UUID
    let amount: Double
    let name: String
    let category: String
    let note: String
    let date: Date
    let createdAt: Date
    let type: TransactionType
    let savedApplied: Double
    /// Optional provenance for API sync / undo; use `TransactionProvenance.markAsPaid` when creating bill-close rows.
    let source: String?
    /// When `source` ties this row to a budget bill.
    let billId: UUID?
    /// When true, UI may offer undo for this synthetic row.
    let undoable: Bool

    private enum CodingKeys: String, CodingKey {
        case id, amount, name, category, note, date, createdAt, type, savedApplied, source, billId, undoable
    }

    init(
        id: UUID,
        amount: Double,
        name: String? = nil,
        category: String,
        note: String,
        date: Date,
        createdAt: Date? = nil,
        type: TransactionType,
        savedApplied: Double = 0,
        source: String? = nil,
        billId: UUID? = nil,
        undoable: Bool = false
    ) {
        self.id = id
        self.amount = amount
        self.name = name ?? category
        self.category = category
        self.note = note
        self.date = date
        self.createdAt = createdAt ?? date
        self.type = type
        self.savedApplied = savedApplied
        self.source = source
        self.billId = billId
        self.undoable = undoable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        amount = try container.decode(Double.self, forKey: .amount)
        let decodedName = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        category = try container.decode(String.self, forKey: .category)
        note = try container.decode(String.self, forKey: .note)
        if let decodedDate = try? container.decode(Date.self, forKey: .date) {
            date = decodedDate
        } else {
            let dateString = try container.decode(String.self, forKey: .date)
            date = TransactionItem.parseDateString(dateString) ?? Date()
        }
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
        type = try container.decode(TransactionType.self, forKey: .type)
        savedApplied = try container.decodeIfPresent(Double.self, forKey: .savedApplied) ?? 0
        name = decodedName.isEmpty ? category : decodedName
        source = try container.decodeIfPresent(String.self, forKey: .source)
        billId = try container.decodeIfPresent(UUID.self, forKey: .billId)
        undoable = try container.decodeIfPresent(Bool.self, forKey: .undoable) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(amount, forKey: .amount)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(note, forKey: .note)
        try container.encode(date, forKey: .date)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(type, forKey: .type)
        try container.encode(savedApplied, forKey: .savedApplied)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(billId, forKey: .billId)
        try container.encode(undoable, forKey: .undoable)
    }

    private static func parseDateString(_ value: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        if let isoDate = isoFormatter.date(from: value) { return isoDate }

        let formatters: [DateFormatter] = {
            let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "MMM d, yyyy", "MMMM d, yyyy"]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = format
                return formatter
            }
        }()
        for formatter in formatters {
            if let parsed = formatter.date(from: value) { return parsed }
        }
        return nil
    }
}

extension TransactionItem: Equatable {
    static func == (lhs: TransactionItem, rhs: TransactionItem) -> Bool {
        lhs.id == rhs.id
            && lhs.amount == rhs.amount
            && lhs.name == rhs.name
            && lhs.category == rhs.category
            && lhs.note == rhs.note
            && lhs.date == rhs.date
            && lhs.createdAt == rhs.createdAt
            && lhs.type == rhs.type
            && lhs.savedApplied == rhs.savedApplied
            && lhs.source == rhs.source
            && lhs.billId == rhs.billId
            && lhs.undoable == rhs.undoable
    }
}

/// Shared bottom undo bar (transaction delete + mark-as-paid on bills).
struct PendingUndoBar: Equatable {
    enum Action: Equatable {
        case restoreRemovedTransaction(TransactionItem)
        case undoMarkAsPaid(billId: UUID, transactionId: UUID)
    }

    let message: String
    let action: Action
}

struct BudgetItem: Identifiable, Codable {
    let id: UUID
    var category: String
    var planned: Double
    var budgetType: BudgetType
    var frequency: PaymentFrequency
    var dueDay: Int?
    var dueWeekday: Int?
    var dueDate: Date?
    var isPaid: Bool

    private enum CodingKeys: String, CodingKey {
        case id, category, planned, budgetType, frequency, dueDay, dueWeekday, dueDate, isPaid
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case dueRule
    }

    init(
        id: UUID,
        category: String,
        planned: Double,
        budgetType: BudgetType = .variable,
        frequency: PaymentFrequency = .none,
        dueDay: Int?,
        dueWeekday: Int?,
        dueDate: Date?,
        isPaid: Bool = false
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        planned = try container.decode(Double.self, forKey: .planned)
        budgetType = try container.decodeIfPresent(BudgetType.self, forKey: .budgetType) ?? .variable
        frequency = try container.decodeIfPresent(PaymentFrequency.self, forKey: .frequency) ?? .none
        dueDay = try container.decodeIfPresent(Int.self, forKey: .dueDay)
        dueWeekday = try container.decodeIfPresent(Int.self, forKey: .dueWeekday)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false

        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        if let legacyRule = try legacyContainer.decodeIfPresent(DueDateRule.self, forKey: .dueRule), frequency == .none {
            switch legacyRule {
            case .monthlyDay:
                frequency = .monthly
            case .endOfMonth:
                frequency = .monthly
                dueDay = 28
            case .biweekly:
                frequency = .biweekly
            }
        } else if frequency == .none, dueDay != nil {
            frequency = .monthly
        }

        if budgetType == .variable {
            if frequency != .none || dueDay != nil || dueWeekday != nil || dueDate != nil {
                budgetType = .fixed
            }
        }
    }
}

enum BudgetType: String, Codable, CaseIterable, Identifiable {
    case fixed
    case variable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fixed: return "Recurring Bill / Fixed Expense"
        case .variable: return "Variable Spending Category"
        }
    }
}

enum PaymentFrequency: String, Codable, CaseIterable, Identifiable {
    case none
    case monthly
    case weekly
    case biweekly
    case oneTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .oneTime: return "One-time"
        }
    }
}

enum DueDateRule: String, Codable, CaseIterable, Identifiable {
    case monthlyDay
    case endOfMonth
    case biweekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthlyDay: return "Monthly"
        case .endOfMonth: return "End of month"
        case .biweekly: return "Biweekly"
        }
    }
}

struct OnboardingData: Codable {
    var currentTerm: String
    var monthlyIncome: Double
    var expectedCoopIncome: Double
    var tuitionGoal: Double
    var monthlySpendingBudget: Double
}

struct BillReminder: Identifiable, Codable {
    let id: UUID
    var title: String
    var dueDay: Int
    var expectedAmount: Double
}

enum FixedBillStatus {
    case paid
    case upcoming
    case overdue
}

struct PersistedState: Codable {
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
    let budgetItems: [BudgetItem]
    let transactions: [TransactionItem]

    private enum CodingKeys: String, CodingKey {
        case onboarding
        case manualMonthlyLimit
        case desiredSavingsRate
        case bonusIncomeForMonth
        case currencyCode
        case billReminders
        case weeklyNotes
        case pinnedTransactionIds
        case monthlyNotes
        case hiddenBudgetItemIdsByMonth
        case fixedBillActualOverridesByMonth
        case fixedBillPaymentTransactionIdsByMonth
        case budgetItems
        case transactions
    }

    init(
        onboarding: OnboardingData,
        manualMonthlyLimit: Double?,
        desiredSavingsRate: Double,
        bonusIncomeForMonth: Double,
        currencyCode: String,
        billReminders: [BillReminder],
        weeklyNotes: [String: String],
        pinnedTransactionIds: Set<UUID>,
        monthlyNotes: [String: String],
        hiddenBudgetItemIdsByMonth: [String: Set<UUID>],
        fixedBillActualOverridesByMonth: [String: [UUID: Double]],
        fixedBillPaymentTransactionIdsByMonth: [String: [UUID: UUID]],
        budgetItems: [BudgetItem],
        transactions: [TransactionItem]
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
        self.budgetItems = budgetItems
        self.transactions = transactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboarding = try container.decode(OnboardingData.self, forKey: .onboarding)
        manualMonthlyLimit = try container.decodeIfPresent(Double.self, forKey: .manualMonthlyLimit)
        desiredSavingsRate = try container.decode(Double.self, forKey: .desiredSavingsRate)
        bonusIncomeForMonth = try container.decode(Double.self, forKey: .bonusIncomeForMonth)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        billReminders = try container.decode([BillReminder].self, forKey: .billReminders)
        weeklyNotes = try container.decode([String: String].self, forKey: .weeklyNotes)
        pinnedTransactionIds = try container.decodeIfPresent(Set<UUID>.self, forKey: .pinnedTransactionIds) ?? []
        monthlyNotes = try container.decodeIfPresent([String: String].self, forKey: .monthlyNotes) ?? [:]
        hiddenBudgetItemIdsByMonth = try container.decodeIfPresent([String: Set<UUID>].self, forKey: .hiddenBudgetItemIdsByMonth) ?? [:]
        fixedBillActualOverridesByMonth = try container.decodeIfPresent([String: [UUID: Double]].self, forKey: .fixedBillActualOverridesByMonth) ?? [:]
        fixedBillPaymentTransactionIdsByMonth = try container.decodeIfPresent([String: [UUID: UUID]].self, forKey: .fixedBillPaymentTransactionIdsByMonth) ?? [:]
        budgetItems = try container.decode([BudgetItem].self, forKey: .budgetItems)
        transactions = try container.decode([TransactionItem].self, forKey: .transactions)
    }
}

struct MonthlySummary: Identifiable, Codable {
    let id: UUID
    let monthLabel: String
    let planned: Double
    let actual: Double
    let saved: Double

    var isOver: Bool { saved < 0 }
}

struct SavedHistoryPoint: Identifiable {
    let id: String
    let monthLabel: String
    let monthlySaved: Double
    let cumulativeSaved: Double
}
