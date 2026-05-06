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
    let savedApplied: Double

    private enum CodingKeys: String, CodingKey {
        case id, amount, category, note, date, type, savedApplied
    }

    init(
        id: UUID,
        amount: Double,
        category: String,
        note: String,
        date: Date,
        type: TransactionType,
        savedApplied: Double = 0
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.type = type
        self.savedApplied = savedApplied
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        amount = try container.decode(Double.self, forKey: .amount)
        category = try container.decode(String.self, forKey: .category)
        note = try container.decode(String.self, forKey: .note)
        date = try container.decode(Date.self, forKey: .date)
        type = try container.decode(TransactionType.self, forKey: .type)
        savedApplied = try container.decodeIfPresent(Double.self, forKey: .savedApplied) ?? 0
    }
}

struct BudgetItem: Identifiable, Codable {
    let id: UUID
    let category: String
    var planned: Double
    var dueDay: Int?
    var dueRule: DueDateRule?

    private enum CodingKeys: String, CodingKey {
        case id, category, planned, dueDay, dueRule
    }

    init(id: UUID, category: String, planned: Double, dueDay: Int?, dueRule: DueDateRule?) {
        self.id = id
        self.category = category
        self.planned = planned
        self.dueDay = dueDay
        self.dueRule = dueRule
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        planned = try container.decode(Double.self, forKey: .planned)
        dueDay = try container.decodeIfPresent(Int.self, forKey: .dueDay)
        dueRule = try container.decodeIfPresent(DueDateRule.self, forKey: .dueRule)
        if dueRule == nil, dueDay != nil {
            dueRule = .monthlyDay
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
    @Published var bonusIncomeForMonth: Double = 0

    // Currency
    @Published var currencyCode: String = "USD"

    @Published var draftTransactionType: TransactionType = .expense

    @Published var budgetItems: [BudgetItem] = [
        .init(id: UUID(), category: "Rent", planned: 900, dueDay: 1, dueRule: .monthlyDay),
        .init(id: UUID(), category: "Groceries", planned: 280, dueDay: nil, dueRule: nil),
        .init(id: UUID(), category: "Transportation", planned: 120, dueDay: nil, dueRule: nil),
        .init(id: UUID(), category: "Eating Out", planned: 140, dueDay: nil, dueRule: nil),
        .init(id: UUID(), category: "Tuition/Savings", planned: 300, dueDay: 7, dueRule: .monthlyDay)
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
            guard let rule = item.dueRule else { return nil }
            let day = item.dueDay ?? 1
            return BillReminder(id: item.id, title: item.category, dueDay: day, expectedAmount: item.planned)
        }
        return derivedBills.filter { bill in
            guard
                let item = budgetItems.first(where: { $0.id == bill.id }),
                let rule = item.dueRule,
                let dayDelta = daysUntilDue(rule: rule, dueDay: item.dueDay, now: now, calendar: calendar)
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

    func addTransaction(
        amount: Double,
        category: String,
        note: String,
        type: TransactionType,
        savedApplied: Double = 0
    ) {
        let item = TransactionItem(
            id: UUID(),
            amount: amount,
            category: category,
            note: note,
            date: Date(),
            type: type,
            savedApplied: savedApplied
        )
        transactions.insert(item, at: 0)
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

    func addBudgetCategory(name: String, planned: Double, dueDay: Int?, dueRule: DueDateRule?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, planned >= 0 else { return }
        budgetItems.append(
            BudgetItem(
                id: UUID(),
                category: trimmed,
                planned: planned,
                dueDay: dueDay,
                dueRule: dueRule
            )
        )
    }

    private func daysUntilDue(rule: DueDateRule, dueDay: Int?, now: Date, calendar: Calendar) -> Int? {
        let startToday = calendar.startOfDay(for: now)
        switch rule {
        case .monthlyDay:
            guard let dueDay else { return nil }
            guard let dueDate = calendar.date(
                from: DateComponents(
                    year: calendar.component(.year, from: now),
                    month: calendar.component(.month, from: now),
                    day: min(28, max(1, dueDay))
                )
            ) else { return nil }
            return calendar.dateComponents([.day], from: startToday, to: dueDate).day
        case .endOfMonth:
            guard let monthRange = calendar.range(of: .day, in: .month, for: now) else { return nil }
            let lastDay = monthRange.count
            guard let dueDate = calendar.date(
                from: DateComponents(
                    year: calendar.component(.year, from: now),
                    month: calendar.component(.month, from: now),
                    day: lastDay
                )
            ) else { return nil }
            return calendar.dateComponents([.day], from: startToday, to: dueDate).day
        case .biweekly:
            let anchorDay = min(28, max(1, dueDay ?? 1))
            guard var nextDue = calendar.date(
                from: DateComponents(
                    year: calendar.component(.year, from: now),
                    month: calendar.component(.month, from: now),
                    day: anchorDay
                )
            ) else { return nil }
            while nextDue < startToday {
                guard let shifted = calendar.date(byAdding: .day, value: 14, to: nextDue) else { break }
                nextDue = shifted
            }
            return calendar.dateComponents([.day], from: startToday, to: nextDue).day
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

        let nonTuitionTotal = budgetItems.dropLast().reduce(0) { $0 + $1.planned }
        let tuitionPlanned = max(0, monthlySpendingBudget - nonTuitionTotal)
        if let lastIndex = budgetItems.indices.last {
            budgetItems[lastIndex].planned = tuitionPlanned
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
            bonusIncomeForMonth = decoded.bonusIncomeForMonth
            currencyCode = decoded.currencyCode
            billReminders = decoded.billReminders
            weeklyNotes = decoded.weeklyNotes
            pinnedTransactionIds = decoded.pinnedTransactionIds
            monthlyNotes = decoded.monthlyNotes
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
    let bonusIncomeForMonth: Double
    let currencyCode: String
    let billReminders: [BillReminder]
    let weeklyNotes: [String: String]
    let pinnedTransactionIds: Set<UUID>
    let monthlyNotes: [String: String]
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
