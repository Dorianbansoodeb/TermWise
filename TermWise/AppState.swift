import Foundation
import SwiftUI
import Combine

/// Holds UI-facing `@Published` state. All persistence goes through `AppRepository` (never `UserDefaults` directly).
/// Pure rules live under `Domain/` and `Services/`; this type orchestrates mutations and sync.
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
    @Published var pendingUndo: PendingUndoBar?

    // Simple local history for charts in profile panel
    @Published var monthlyHistory: [MonthlySummary] = [
        .init(id: UUID(), monthLabel: "Jan", planned: 1400, actual: 1320, saved: 80),
        .init(id: UUID(), monthLabel: "Feb", planned: 1450, actual: 1520, saved: -70),
        .init(id: UUID(), monthLabel: "Mar", planned: 1500, actual: 1385, saved: 115),
        .init(id: UUID(), monthLabel: "Apr", planned: 1480, actual: 1410, saved: 70)
    ]

    init(repository: AppRepository = LocalCacheAppRepository()) {
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
        TransactionTotalsService.totalPlannedSpend(budgetItems: budgetItems)
    }

    var totalActualSpend: Double {
        TransactionTotalsService.totalActualSpend(transactions: transactions)
    }

    var totalSavedApplied: Double {
        TransactionTotalsService.totalSavedApplied(transactions: transactions)
    }

    var totalNetSpend: Double {
        TransactionTotalsService.totalNetSpend(transactions: transactions)
    }

    var totalBudgetCountedSpend: Double {
        TransactionTotalsService.totalBudgetCountedSpend(transactions: transactions)
    }

    var totalActualIncome: Double {
        TransactionTotalsService.totalActualIncome(transactions: transactions)
    }

    var monthlyBalance: Double {
        TransactionTotalsService.monthlyBalance(monthlyIncome: monthlyIncome, transactions: transactions)
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
        SpendingAnalyticsService.savedHistoryTimeline(
            monthlyHistory: monthlyHistory,
            currentMonthKey: currentMonthKey,
            currentMonthSaved: currentMonthSaved,
            calendar: Calendar.current
        )
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
        CalendarPeriodKeys.weekKey()
    }

    var currentWeekNote: String {
        weeklyNotes[currentWeekKey] ?? ""
    }

    var currentMonthKey: String {
        CalendarPeriodKeys.monthKey(for: Date())
    }

    var currentMonthNote: String {
        monthlyNotes[currentMonthKey] ?? ""
    }

    var upcomingUrgentBills: [BillReminder] {
        BudgetPlanningService.upcomingUrgentBills(budgetItems: budgetItems)
    }

    var awarenessMessages: [String] {
        SpendingAnalyticsService.awarenessMessages(budgetItems: budgetItems, transactions: transactions)
    }

    func actualAmount(for category: String) -> Double {
        BudgetSpendCalculator.actualAmountAllTime(transactions: transactions, budgetCategory: category)
    }

    /// Net expense total for a category in the current calendar month (used for recurring bills).
    func actualAmountInCurrentMonth(forCategory category: String) -> Double {
        BudgetSpendCalculator.actualAmountInMonth(
            transactions: transactions,
            budgetCategory: category,
            referenceDate: Date(),
            calendar: Calendar.current
        )
    }

    func actualPaidAmount(for item: BudgetItem) -> Double {
        BudgetSpendCalculator.actualPaidAmount(
            for: item,
            transactions: transactions,
            now: Date(),
            calendar: Calendar.current
        )
    }

    @discardableResult
    func addTransaction(
        amount: Double,
        name: String? = nil,
        category: String,
        note: String,
        type: TransactionType,
        savedApplied: Double = 0,
        source: String? = nil,
        billId: UUID? = nil,
        undoable: Bool = false
    ) -> TransactionItem {
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
            savedApplied: savedApplied,
            source: source,
            billId: billId,
            undoable: undoable
        )
        transactions.insert(item, at: 0)
        reconcileFixedBillPaidStates()
        return item
    }

    func deleteTransaction(id: UUID) {
        transactions.removeAll { $0.id == id }
        pinnedTransactionIds.remove(id)
        reconcileFixedBillPaidStates()
    }

    @discardableResult
    func removeTransaction(id: UUID) -> TransactionItem? {
        pinnedTransactionIds.remove(id)
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = transactions.remove(at: index)
        reconcileFixedBillPaidStates()
        return removed
    }

    func restoreTransaction(_ transaction: TransactionItem) {
        transactions.insert(transaction, at: 0)
        reconcileFixedBillPaidStates()
    }

    func presentRemovedTransactionUndo(_ removed: TransactionItem) {
        pendingUndo = PendingUndoBar(
            message: "Removed \(removed.category)",
            action: .restoreRemovedTransaction(removed)
        )
    }

    func presentMarkAsPaidUndo(billId: UUID, transactionId: UUID, addedAmount: Double, billCategoryName: String) {
        let formatted = addedAmount.formatted(currencyFormatter)
        pendingUndo = PendingUndoBar(
            message: "Added \(formatted) to \(billCategoryName)",
            action: .undoMarkAsPaid(billId: billId, transactionId: transactionId)
        )
    }

    func performPendingUndo() {
        guard let bar = pendingUndo else { return }
        switch bar.action {
        case .restoreRemovedTransaction(let transaction):
            restoreTransaction(transaction)
        case .undoMarkAsPaid(let billId, let transactionId):
            undoFixedBillMarkAsPaidPayment(billId: billId, transactionId: transactionId)
        }
        pendingUndo = nil
    }

    func dismissPendingUndo() {
        pendingUndo = nil
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
        reconcileFixedBillPaidStates()
    }

    func hideBudgetItemForCurrentMonth(_ id: UUID) {
        var ids = hiddenBudgetItemIdsByMonth[currentMonthKey] ?? []
        ids.insert(id)
        hiddenBudgetItemIdsByMonth[currentMonthKey] = ids
    }

    func isBudgetItemHiddenForCurrentMonth(_ id: UUID) -> Bool {
        hiddenBudgetItemIdsByMonth[currentMonthKey]?.contains(id) ?? false
    }

    /// Creates an expense for the remaining bill amount (current month) so `actual >= planned`.
    /// TODO: Backend should own this mutation when API mode is enabled; keep local behavior for offline.
    @discardableResult
    func markFixedBillRemainingPaid(billId: UUID) -> TransactionItem? {
        guard let item = budgetItems.first(where: { $0.id == billId && $0.budgetType == .fixed }) else { return nil }
        let actual = actualPaidAmount(for: item)
        guard let remaining = MarkAsPaidRules.remainingAmountToReachPlanned(planned: item.planned, actualPaid: actual) else { return nil }

        let paymentTransaction = addTransaction(
            amount: remaining,
            name: item.category,
            category: item.category,
            note: "Bill payment (remaining)",
            type: .expense,
            savedApplied: 0,
            source: TransactionProvenance.markAsPaid,
            billId: billId,
            undoable: true
        )

        var monthMap = fixedBillPaymentTransactionIdsByMonth[currentMonthKey] ?? [:]
        monthMap[billId] = paymentTransaction.id
        fixedBillPaymentTransactionIdsByMonth[currentMonthKey] = monthMap

        return paymentTransaction
    }

    func undoFixedBillMarkAsPaidPayment(billId: UUID, transactionId: UUID) {
        guard
            let txn = transactions.first(where: { $0.id == transactionId }),
            MarkAsPaidRules.qualifiesForUndo(transaction: txn, billId: billId)
        else { return }
        _ = removeTransaction(id: transactionId)
        var map = fixedBillPaymentTransactionIdsByMonth[currentMonthKey] ?? [:]
        if map[billId] == transactionId {
            map.removeValue(forKey: billId)
            fixedBillPaymentTransactionIdsByMonth[currentMonthKey] = map
        }
    }

    func fixedBillStatus(for item: BudgetItem) -> FixedBillStatus {
        FixedBillSchedule.status(for: item, transactions: transactions, now: Date(), calendar: Calendar.current)
    }

    func updateWeekNote(_ note: String) {
        weeklyNotes[currentWeekKey] = note
    }

    func monthKey(for date: Date) -> String {
        CalendarPeriodKeys.monthKey(for: date)
    }

    func monthKey(forMonthLabel monthLabel: String) -> String {
        CalendarPeriodKeys.monthKey(forMonthLabel: monthLabel, referenceNow: Date())
    }

    func monthlyNote(forMonthLabel monthLabel: String) -> String {
        monthlyNotes[monthKey(forMonthLabel: monthLabel)] ?? ""
    }

    func updateMonthlyNote(_ note: String, forMonthLabel monthLabel: String) {
        monthlyNotes[monthKey(forMonthLabel: monthLabel)] = note
    }

    func shouldPromptIrregularPurchase(amount: Double) -> Bool {
        SpendingAnalyticsService.shouldPromptIrregularPurchase(
            amount: amount,
            transactions: transactions,
            effectiveMonthlyLimit: effectiveMonthlyLimit
        )
    }

    func dailyActualCumulative() -> [Double] {
        SpendingAnalyticsService.dailyActualCumulative(
            transactions: transactions,
            currentDayOfMonth: currentDayOfMonth,
            calendar: Calendar.current,
            now: Date()
        )
    }

    var projectedEndOfMonthSpend: Double {
        let cumulative = dailyActualCumulative()
        return SpendingAnalyticsService.projectedEndOfMonthSpend(
            dailyActualCumulative: cumulative,
            currentDayOfMonth: currentDayOfMonth,
            daysInCurrentMonth: daysInCurrentMonth,
            effectiveMonthlyLimit: effectiveMonthlyLimit
        )
    }

    func projectedAmountForDay(dayNumber: Int) -> Double {
        let cumulative = dailyActualCumulative()
        return SpendingAnalyticsService.projectedAmountForDay(
            dayNumber: dayNumber,
            dailyActualCumulative: cumulative,
            currentDayOfMonth: currentDayOfMonth,
            daysInCurrentMonth: daysInCurrentMonth,
            projectedEndOfMonthSpend: projectedEndOfMonthSpend
        )
    }

    func apply(onboardingData: OnboardingData) {
        currentTerm = onboardingData.currentTerm
        monthlyIncome = onboardingData.monthlyIncome
        expectedCoopIncome = onboardingData.expectedCoopIncome
        tuitionGoal = onboardingData.tuitionGoal
        monthlySpendingBudget = onboardingData.monthlySpendingBudget
        budgetItems = BudgetPlanningService.applyOnboardingTuitionSplit(
            data: onboardingData,
            budgetItems: budgetItems
        )
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
        let migratedBudgetItems = BudgetItemMigration.applyDefaults(decoded.budgetItems)
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
        FixedBillPaidSync.reconcile(
            budgetItems: &budgetItems,
            transactions: transactions,
            now: Date(),
            calendar: Calendar.current
        )
    }
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
