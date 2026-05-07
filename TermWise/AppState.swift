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
    let name: String
    let category: String
    let note: String
    let date: Date
    let createdAt: Date
    let type: TransactionType
    let savedApplied: Double

    private enum CodingKeys: String, CodingKey {
        case id, amount, name, category, note, date, createdAt, type, savedApplied
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
        savedApplied: Double = 0
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

final class AppState: ObservableObject {
    private let repository: AppRepository
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
    @Published var bonusIncomeForMonth: Double = 0

    // Currency
    @Published var currencyCode: String = "USD"

    @Published var draftTransactionType: TransactionType = .expense

    @Published var budgetItems: [BudgetItem] = [
        .init(id: UUID(), category: "Rent", planned: 900, budgetType: .fixed, frequency: .monthly, dueDay: 1, dueWeekday: nil, dueDate: nil),
        .init(id: UUID(), category: "Phone bill", planned: 35, budgetType: .fixed, frequency: .monthly, dueDay: 15, dueWeekday: nil, dueDate: nil),
        .init(id: UUID(), category: "Groceries", planned: 280, budgetType: .variable, frequency: .none, dueDay: nil, dueWeekday: nil, dueDate: nil),
        .init(id: UUID(), category: "Transportation", planned: 120, budgetType: .variable, frequency: .none, dueDay: nil, dueWeekday: nil, dueDate: nil),
        .init(id: UUID(), category: "Eating Out", planned: 140, budgetType: .variable, frequency: .none, dueDay: nil, dueWeekday: nil, dueDate: nil),
        .init(id: UUID(), category: "Tuition/Savings", planned: 300, budgetType: .fixed, frequency: .monthly, dueDay: 7, dueWeekday: nil, dueDate: nil)
    ]

    @Published var transactions: [TransactionItem] = AppState.seededMayTransactions()
    @Published var billReminders: [BillReminder] = [
        .init(id: UUID(), title: "Rent", dueDay: 1, expectedAmount: 900),
        .init(id: UUID(), title: "Phone Bill", dueDay: 12, expectedAmount: 65),
        .init(id: UUID(), title: "Credit Card Bill", dueDay: 14, expectedAmount: 220)
    ]
    @Published var weeklyNotes: [String: String] = [:]
    @Published var pinnedTransactionIds: Set<UUID> = []
    @Published var monthlyNotes: [String: String] = [:]
    @Published var hiddenBudgetItemIdsByMonth: [String: Set<UUID>] = [:]
    @Published var fixedBillActualOverridesByMonth: [String: [UUID: Double]] = [:]
    @Published var fixedBillPaymentTransactionIdsByMonth: [String: [UUID: UUID]] = [:]

    // Simple local history for charts in profile panel
    @Published var monthlyHistory: [MonthlySummary] = [
        .init(id: UUID(), monthLabel: "Jan", planned: 1400, actual: 1320, saved: 80),
        .init(id: UUID(), monthLabel: "Feb", planned: 1450, actual: 1520, saved: -70),
        .init(id: UUID(), monthLabel: "Mar", planned: 1500, actual: 1385, saved: 115),
        .init(id: UUID(), monthLabel: "Apr", planned: 1480, actual: 1410, saved: 70)
    ]

    init(repository: AppRepository = SnapshotAppRepository()) {
        self.repository = repository
        load()
        setupAutoSave()
        if let remoteSyncingRepository = repository as? RemoteSyncingAppRepository {
            remoteSyncingRepository.refreshFromRemote { [weak self] snapshot in
                self?.applySnapshot(snapshot)
            }
        }
    }

    var totalPlannedSpend: Double {
        budgetItems.reduce(0) { $0 + $1.planned }
    }

    var totalActualSpend: Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    var totalSavedApplied: Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.savedApplied }
    }

    var totalNetSpend: Double {
        max(0, totalActualSpend - totalSavedApplied)
    }

    var totalBudgetCountedSpend: Double {
        totalNetSpend
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
        effectiveMonthlyLimit - projectedEndOfMonthSpend
    }

    var currentMonthSaved: Double {
        effectiveMonthlyLimit - totalNetSpend + bonusIncomeForMonth
    }

    var monthlySavingsTargetFromBudget: Double {
        effectiveMonthlyLimit * (desiredSavingsRate / 100)
    }

    var spendingGoalLimit: Double {
        max(0, effectiveMonthlyLimit - monthlySavingsTargetFromBudget)
    }

    var expectedTotalSaved: Double {
        max(0, savedHistoryTimeline().last?.cumulativeSaved ?? 0)
    }

    var availableSavedToUse: Double {
        expectedTotalSaved
    }

    func savedHistoryTimeline() -> [SavedHistoryPoint] {
        var points: [SavedHistoryPoint] = []
        var cumulative = 0.0

        for summary in monthlyHistory {
            cumulative += summary.saved
            points.append(
                SavedHistoryPoint(
                    id: summary.id.uuidString,
                    monthLabel: summary.monthLabel,
                    monthlySaved: summary.saved,
                    cumulativeSaved: cumulative
                )
            )
        }

        let monthIndex = max(0, min(11, Calendar.current.component(.month, from: Date()) - 1))
        let currentMonthLabel = Calendar.current.shortMonthSymbols[monthIndex]
        let hasCurrentMonth = points.contains { $0.monthLabel == currentMonthLabel }
        if !hasCurrentMonth {
            let monthSaved = currentMonthSaved
            cumulative += monthSaved
            points.append(
                SavedHistoryPoint(
                    id: "\(currentMonthKey)-current",
                    monthLabel: currentMonthLabel,
                    monthlySaved: monthSaved,
                    cumulativeSaved: cumulative
                )
            )
        }

        return points
    }

    var currencyFormatter: FloatingPointFormatStyle<Double>.Currency {
        .currency(code: currencyCode)
    }

    var currentDayOfMonth: Int {
        Calendar.current.component(.day, from: Date())
    }

    var daysInCurrentMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? currentDayOfMonth
    }

    var expectedDailySpend: Double {
        effectiveMonthlyLimit / Double(max(1, daysInCurrentMonth))
    }

    var currentWeekKey: String {
        let calendar = Calendar.current
        let week = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        return "\(year)-W\(week)"
    }

    var currentWeekNote: String {
        weeklyNotes[currentWeekKey] ?? ""
    }

    var currentMonthKey: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())
        return "\(year)-\(month)"
    }

    var currentMonthNote: String {
        monthlyNotes[currentMonthKey] ?? ""
    }

    var upcomingUrgentBills: [BillReminder] {
        let calendar = Calendar.current
        let now = Date()
        let derivedBills = budgetItems.compactMap { item -> BillReminder? in
            guard item.budgetType == .fixed, item.frequency != .none else { return nil }
            let day = item.dueDay ?? 1
            return BillReminder(id: item.id, title: item.category, dueDay: day, expectedAmount: item.planned)
        }
        return derivedBills.filter { bill in
            guard
                let item = budgetItems.first(where: { $0.id == bill.id }),
                let dayDelta = daysUntilDue(
                    frequency: item.frequency,
                    dueDay: item.dueDay,
                    dueWeekday: item.dueWeekday,
                    dueDate: item.dueDate,
                    now: now,
                    calendar: calendar
                )
            else { return false }
            return dayDelta >= 0 && dayDelta <= 2
        }
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
            .reduce(0) { $0 + max(0, $1.amount - $1.savedApplied) }
    }

    func actualPaidAmount(for item: BudgetItem) -> Double {
        let transactionActual = actualAmount(for: item.category)
        guard item.budgetType == .fixed else { return transactionActual }
        let overrideAmount = fixedBillActualOverridesByMonth[currentMonthKey]?[item.id] ?? 0
        return max(transactionActual, overrideAmount)
    }

    func addTransaction(
        amount: Double,
        name: String? = nil,
        category: String,
        note: String,
        type: TransactionType,
        savedApplied: Double = 0
    ) {
        let now = Date()
        let item = TransactionItem(
            id: UUID(),
            amount: amount,
            name: name,
            category: category,
            note: note,
            date: now,
            createdAt: now,
            type: type,
            savedApplied: savedApplied
        )
        transactions.insert(item, at: 0)
        reconcileFixedBillPaidStates()
    }

    func deleteTransaction(id: UUID) {
        transactions.removeAll { $0.id == id }
        pinnedTransactionIds.remove(id)
    }

    @discardableResult
    func removeTransaction(id: UUID) -> TransactionItem? {
        pinnedTransactionIds.remove(id)
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return nil }
        return transactions.remove(at: index)
    }

    func restoreTransaction(_ transaction: TransactionItem) {
        transactions.insert(transaction, at: 0)
    }

    func addBudgetCategory(
        name: String,
        planned: Double,
        budgetType: BudgetType,
        frequency: PaymentFrequency,
        dueDay: Int?,
        dueWeekday: Int?,
        dueDate: Date?,
        isPaid: Bool
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, planned >= 0 else { return }
        budgetItems.append(
            BudgetItem(
                id: UUID(),
                category: trimmed,
                planned: planned,
                budgetType: budgetType,
                frequency: frequency,
                dueDay: dueDay,
                dueWeekday: dueWeekday,
                dueDate: dueDate,
                isPaid: isPaid
            )
        )
    }

    func hideBudgetItemForCurrentMonth(_ id: UUID) {
        var ids = hiddenBudgetItemIdsByMonth[currentMonthKey] ?? []
        ids.insert(id)
        hiddenBudgetItemIdsByMonth[currentMonthKey] = ids
    }

    func isBudgetItemHiddenForCurrentMonth(_ id: UUID) -> Bool {
        hiddenBudgetItemIdsByMonth[currentMonthKey]?.contains(id) ?? false
    }

    func markFixedBillPaid(_ id: UUID) {
        guard let index = budgetItems.firstIndex(where: { $0.id == id && $0.budgetType == .fixed }) else { return }
        let item = budgetItems[index]
        let monthTransactionMap = fixedBillPaymentTransactionIdsByMonth[currentMonthKey] ?? [:]
        if monthTransactionMap[id] == nil {
            let now = Date()
            let paymentTransaction = TransactionItem(
                id: UUID(),
                amount: item.planned,
                name: item.category,
                category: item.category,
                note: "Bill payment",
                date: now,
                createdAt: now,
                type: .expense,
                savedApplied: 0
            )
            transactions.insert(paymentTransaction, at: 0)
            var updatedMap = monthTransactionMap
            updatedMap[id] = paymentTransaction.id
            fixedBillPaymentTransactionIdsByMonth[currentMonthKey] = updatedMap
        }
        let actual = actualPaidAmount(for: item)
        if actual < item.planned {
            var monthOverrides = fixedBillActualOverridesByMonth[currentMonthKey] ?? [:]
            monthOverrides[id] = item.planned
            fixedBillActualOverridesByMonth[currentMonthKey] = monthOverrides
        }
        budgetItems[index].isPaid = true
    }

    func markFixedBillUnpaid(_ id: UUID) {
        guard let index = budgetItems.firstIndex(where: { $0.id == id && $0.budgetType == .fixed }) else { return }
        if let transactionId = fixedBillPaymentTransactionIdsByMonth[currentMonthKey]?[id] {
            transactions.removeAll { $0.id == transactionId }
            var map = fixedBillPaymentTransactionIdsByMonth[currentMonthKey] ?? [:]
            map.removeValue(forKey: id)
            fixedBillPaymentTransactionIdsByMonth[currentMonthKey] = map
        }
        budgetItems[index].isPaid = false
    }

    func fixedBillStatus(for item: BudgetItem) -> FixedBillStatus {
        guard item.budgetType == .fixed else { return .upcoming }
        if item.isPaid {
            return .paid
        }
        let delta = daysUntilDue(
            frequency: item.frequency,
            dueDay: item.dueDay,
            dueWeekday: item.dueWeekday,
            dueDate: item.dueDate,
            now: Date(),
            calendar: Calendar.current
        ) ?? 0
        return delta < 0 ? .overdue : .upcoming
    }

    private func daysUntilDue(
        frequency: PaymentFrequency,
        dueDay: Int?,
        dueWeekday: Int?,
        dueDate: Date?,
        now: Date,
        calendar: Calendar
    ) -> Int? {
        let startToday = calendar.startOfDay(for: now)
        switch frequency {
        case .none:
            return nil
        case .monthly:
            guard let dueDay else { return nil }
            guard let dueDate = calendar.date(
                from: DateComponents(
                    year: calendar.component(.year, from: now),
                    month: calendar.component(.month, from: now),
                    day: min(28, max(1, dueDay))
                )
            ) else { return nil }
            return calendar.dateComponents([.day], from: startToday, to: dueDate).day
        case .weekly:
            guard let dueWeekday else { return nil }
            let todayWeekday = calendar.component(.weekday, from: startToday)
            return (dueWeekday - todayWeekday + 7) % 7
        case .biweekly:
            guard let dueWeekday else { return nil }
            let todayWeekday = calendar.component(.weekday, from: startToday)
            return (dueWeekday - todayWeekday + 7) % 7
        case .oneTime:
            guard let dueDate else { return nil }
            return calendar.dateComponents([.day], from: startToday, to: calendar.startOfDay(for: dueDate)).day
        }
    }

    func updateWeekNote(_ note: String) {
        weeklyNotes[currentWeekKey] = note
    }

    func monthKey(for date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        return "\(year)-\(month)"
    }

    func monthKey(forMonthLabel monthLabel: String) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        if let monthIndex = symbols.firstIndex(where: { $0.localizedCaseInsensitiveCompare(monthLabel) == .orderedSame }) {
            let year = Calendar.current.component(.year, from: Date())
            return "\(year)-\(monthIndex + 1)"
        }
        return currentMonthKey
    }

    func monthlyNote(forMonthLabel monthLabel: String) -> String {
        monthlyNotes[monthKey(forMonthLabel: monthLabel)] ?? ""
    }

    func updateMonthlyNote(_ note: String, forMonthLabel monthLabel: String) {
        monthlyNotes[monthKey(forMonthLabel: monthLabel)] = note
    }

    func shouldPromptIrregularPurchase(amount: Double) -> Bool {
        guard amount > 0 else { return false }
        let expenseTransactions = transactions.filter { $0.type == .expense }
        let averageExpense =
            expenseTransactions.map(\.amount).reduce(0, +) / Double(max(1, expenseTransactions.count))
        return amount > max(averageExpense * 2.5, effectiveMonthlyLimit * 0.25)
    }

    func dailyActualCumulative() -> [Double] {
        let calendar = Calendar.current
        let now = Date()
        let day = currentDayOfMonth

        let monthTransactions = transactions.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month) && $0.type == .expense
        }

        var cumulative: [Double] = []
        var runningTotal = 0.0
        for currentDay in 1...max(1, day) {
            let dayTotal = monthTransactions
                .filter { calendar.component(.day, from: $0.date) == currentDay }
                .reduce(0) { $0 + max(0, $1.amount - $1.savedApplied) }
            runningTotal += dayTotal
            cumulative.append(runningTotal)
        }
        return cumulative
    }

    var projectedEndOfMonthSpend: Double {
        let currentActual = dailyActualCumulative().last ?? 0
        let remainingDays = max(0, daysInCurrentMonth - currentDayOfMonth)
        return currentActual + expectedDailySpend * Double(remainingDays)
    }

    func projectedAmountForDay(dayNumber: Int) -> Double {
        let cumulative = dailyActualCumulative()
        if dayNumber <= currentDayOfMonth {
            return cumulative[min(dayNumber - 1, max(0, cumulative.count - 1))]
        }

        guard let currentActual = cumulative.last else { return 0 }
        let remainingDays = max(1, daysInCurrentMonth - currentDayOfMonth)
        let perDayProjection = (projectedEndOfMonthSpend - currentActual) / Double(remainingDays)
        let futureOffset = dayNumber - currentDayOfMonth
        return currentActual + perDayProjection * Double(futureOffset)
    }

    func apply(onboardingData: OnboardingData) {
        currentTerm = onboardingData.currentTerm
        monthlyIncome = onboardingData.monthlyIncome
        expectedCoopIncome = onboardingData.expectedCoopIncome
        tuitionGoal = onboardingData.tuitionGoal
        monthlySpendingBudget = onboardingData.monthlySpendingBudget

        let nonTuitionTotal = budgetItems
            .filter { !$0.category.localizedCaseInsensitiveContains("tuition") }
            .reduce(0) { $0 + $1.planned }
        let tuitionPlanned = max(0, monthlySpendingBudget - nonTuitionTotal)
        if let tuitionIndex = budgetItems.firstIndex(where: { $0.category.localizedCaseInsensitiveContains("tuition") }) {
            budgetItems[tuitionIndex].planned = tuitionPlanned
        }
    }

    func suggestedMonthlyBudgetFromGoals() -> Double {
        max(0, monthlyIncome * (1 - desiredSavingsRate / 100))
    }

    func recalculateEstimatedBudget() {
        let suggested = suggestedMonthlyBudgetFromGoals()
        monthlySpendingBudget = suggested
        manualMonthlyLimit = suggested
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
            bonusIncomeForMonth: bonusIncomeForMonth,
            currencyCode: currencyCode,
            billReminders: billReminders,
            weeklyNotes: weeklyNotes,
            pinnedTransactionIds: pinnedTransactionIds,
            monthlyNotes: monthlyNotes,
            hiddenBudgetItemIdsByMonth: hiddenBudgetItemIdsByMonth,
            fixedBillActualOverridesByMonth: fixedBillActualOverridesByMonth,
            fixedBillPaymentTransactionIdsByMonth: fixedBillPaymentTransactionIdsByMonth,
            budgetItems: budgetItems,
            transactions: transactions
        )

        repository.saveSnapshot(snapshot)
    }

    private func load() {
        guard let decoded = repository.loadSnapshot() else { return }
        applySnapshot(decoded)
    }

    private func applySnapshot(_ decoded: PersistedState) {
        let migratedBudgetItems = applyBudgetDefaults(decoded.budgetItems)
        currentTerm = decoded.onboarding.currentTerm
        monthlyIncome = decoded.onboarding.monthlyIncome
        expectedCoopIncome = decoded.onboarding.expectedCoopIncome
        tuitionGoal = decoded.onboarding.tuitionGoal
        monthlySpendingBudget = decoded.onboarding.monthlySpendingBudget
        manualMonthlyLimit = decoded.manualMonthlyLimit
        desiredSavingsRate = decoded.desiredSavingsRate
        bonusIncomeForMonth = decoded.bonusIncomeForMonth
        currencyCode = decoded.currencyCode
        billReminders = decoded.billReminders
        weeklyNotes = decoded.weeklyNotes
        pinnedTransactionIds = decoded.pinnedTransactionIds
        monthlyNotes = decoded.monthlyNotes
        hiddenBudgetItemIdsByMonth = decoded.hiddenBudgetItemIdsByMonth
        fixedBillActualOverridesByMonth = decoded.fixedBillActualOverridesByMonth
        fixedBillPaymentTransactionIdsByMonth = decoded.fixedBillPaymentTransactionIdsByMonth
        budgetItems = migratedBudgetItems
        transactions = decoded.transactions
        reconcileFixedBillPaidStates()
    }

    private func reconcileFixedBillPaidStates() {
        for index in budgetItems.indices where budgetItems[index].budgetType == .fixed {
            if actualPaidAmount(for: budgetItems[index]) >= budgetItems[index].planned {
                budgetItems[index].isPaid = true
            } else if budgetItems[index].frequency == .none {
                budgetItems[index].isPaid = false
            }
        }
    }

    private func applyBudgetDefaults(_ items: [BudgetItem]) -> [BudgetItem] {
        var result: [BudgetItem] = items.map { item in
            var updated = item

            if item.category == "Rent", item.frequency == .none || item.dueDay == nil {
                updated.budgetType = .fixed
                updated.frequency = .monthly
                updated.dueDay = updated.dueDay ?? 1
            }

            if item.category == "Tuition/Savings" {
                updated.budgetType = .fixed
                updated.frequency = .monthly
                updated.dueDay = 7
            }

            if item.category.localizedCaseInsensitiveContains("phone"), item.frequency == .none || item.dueDay == nil {
                updated.budgetType = .fixed
                updated.frequency = .monthly
                updated.dueDay = 15
            }

            if updated.budgetType == .variable, updated.frequency != .none {
                updated.budgetType = .fixed
            }

            return updated
        }

        if !result.contains(where: { $0.category.localizedCaseInsensitiveContains("phone") }) {
            result.append(
                BudgetItem(
                    id: UUID(),
                    category: "Phone bill",
                    planned: 35,
                    budgetType: .fixed,
                    frequency: .monthly,
                    dueDay: 15,
                    dueWeekday: nil,
                    dueDate: nil,
                    isPaid: false
                )
            )
        }

        return result
    }
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

private extension AppState {
    static func seededMayTransactions() -> [TransactionItem] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())

        func makeDate(_ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: 5, day: day, hour: 12)) ?? Date()
        }

        return [
            .init(id: UUID(), amount: 920, category: "Paycheque", note: "Biweekly pay", date: makeDate(2), type: .income),
            .init(id: UUID(), amount: 900, category: "Rent", note: "May rent", date: makeDate(1), type: .expense),
            .init(id: UUID(), amount: 46, category: "Groceries", note: "Weekly grocery run", date: makeDate(2), type: .expense),
            .init(id: UUID(), amount: 18.5, category: "Transportation", note: "Transit reload", date: makeDate(3), type: .expense),
            .init(id: UUID(), amount: 8.75, category: "Eating Out", note: "Starbucks", date: makeDate(3), type: .expense),
            .init(id: UUID(), amount: 52, category: "Groceries", note: "Costco split", date: makeDate(4), type: .expense),
            .init(id: UUID(), amount: 13.25, category: "Eating Out", note: "Bubble tea", date: makeDate(4), type: .expense),
            .init(id: UUID(), amount: 21, category: "Transportation", note: "Ride share", date: makeDate(5), type: .expense),
            .init(id: UUID(), amount: 29, category: "Eating Out", note: "Lunch with friends", date: makeDate(5), type: .expense),
            .init(id: UUID(), amount: 100, category: "Gift", note: "Birthday gift", date: makeDate(5), type: .income),
            .init(id: UUID(), amount: 34.5, category: "Groceries", note: "Produce top-up", date: makeDate(6), type: .expense)
        ].sorted { $0.date > $1.date }
    }
}
