import Foundation
import SwiftUI
import Combine

/// Holds UI-facing `@Published` state. All persistence goes through `AppRepository` (never `UserDefaults` directly).
/// Pure rules live under `Domain/` and `Services/`; this type orchestrates mutations and sync.
final class AppState: ObservableObject {
    private let repository: AppRepository
    private var cancellables = Set<AnyCancellable>()
    private var fullyPaidToastDismissTask: Task<Void, Never>?

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
    @Published var availableToBudgetByMonth: [String: Double] = [:]
    /// Per calendar month, dollar override for the *Savings Target* card. When set, replaces the
    /// rate-derived target for that month (i.e. user picked **Other** and entered a custom amount).
    @Published var customSavingsTargetByMonth: [String: Double] = [:]
    @Published var fixedBillActualOverridesByMonth: [String: [UUID: Double]] = [:]
    @Published var fixedBillPaymentTransactionIdsByMonth: [String: [UUID: UUID]] = [:]
    @Published var pendingUndo: PendingUndoBar?
    /// Shown when a fixed bill becomes fully paid (`actual >= planned`) after transactions change; cleared after a short delay.
    @Published var fullyPaidBillToast: String?
    /// Set right after the user adds an income transaction so the UI can ask whether to assign it to the budget.
    @Published var pendingIncomePrompt: PendingIncomePrompt?

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

    /// `recurringBillsPlanned + variableSpendingLimits + savingsGoals + savingsTargetThisMonth`.
    /// Sum of planned allocations for non-hidden items plus the envelope-level Savings Target.
    var totalBudgeted: Double {
        FinanceBudgetAllocation.calculateTotalBudgeted(
            budgetItems: budgetItems,
            hiddenBudgetItemIds: hiddenBudgetItemIdsByMonth[currentMonthKey] ?? [],
            savingsTarget: savingsTargetThisMonth
        )
    }

    /// Resolved Savings Target dollar amount for the current month.
    /// Custom override (user picked **Other**) wins; otherwise `availableToBudget * (desiredSavingsRate / 100)`.
    var savingsTargetThisMonth: Double {
        FinanceCalculator.savingsTarget(
            availableToBudget: availableToBudget,
            rate: desiredSavingsRate,
            customAmount: customSavingsTargetByMonth[currentMonthKey]
        )
    }

    /// Same as `totalBudgeted` (legacy name used in some views).
    var totalPlannedSpend: Double { totalBudgeted }

    /// Income transactions dated in the current calendar month.
    var totalIncome: Double {
        FinanceBudgetAllocation.calculateTotalIncome(
            transactions: transactions,
            referenceDate: Date(),
            calendar: Calendar.current
        )
    }

    /// Portion of income the user allocates to budgeting; explicit per-month override or defaults to `totalIncome`, then profile income.
    var availableToBudget: Double {
        FinanceBudgetAllocation.calculateAvailableToBudget(
            explicitByMonth: availableToBudgetByMonth,
            monthKey: currentMonthKey,
            totalIncome: totalIncome,
            fallbackExpectedMonthlyIncome: monthlyIncome
        )
    }

    /// `availableToBudget - totalBudgeted` (positive = reserve / headroom in the envelope sense; negative = over-allocated).
    var unallocatedIncome: Double {
        FinanceBudgetAllocation.calculateUnallocatedIncome(
            availableToBudget: availableToBudget,
            totalBudgeted: totalBudgeted
        )
    }

    /// `totalBudgeted - availableToBudget`. Positive means over-allocated.
    var budgetAllocationDifference: Double {
        FinanceBudgetAllocation.calculateBudgetDifference(
            totalBudgeted: totalBudgeted,
            availableToBudget: availableToBudget
        )
    }

    /// Income received this month that the user has *not* assigned to the budget. Always >= 0.
    var reserveNotBudgeted: Double {
        FinanceBudgetAllocation.calculateReserveNotBudgeted(
            totalIncome: totalIncome,
            availableToBudget: availableToBudget
        )
    }

    /// Category-by-category breakdown powering the Plan vs Reality bar + its tap-to-expand
    /// legend on the Dashboard. Only this month's *expense* transactions count; the envelope is
    /// always `availableToBudget` (never the legacy `effectiveMonthlyLimit`).
    var spendingBreakdown: FinanceCalculator.SpendingBreakdown {
        FinanceCalculator.spendingBreakdown(
            transactions: transactions,
            availableToBudget: availableToBudget,
            now: Date(),
            calendar: Calendar.current
        )
    }

    /// Money preserved this month by spending less than the planned envelope. Capped at 0.
    var budgetCushion: Double {
        FinanceBudgetAllocation.calculateBudgetCushionThisMonth(
            totalBudgeted: totalBudgeted,
            totalBudgetCountedSpend: totalBudgetCountedSpend
        )
    }

    /// Month-scoped rollup powering the Budget screen's *Monthly Snapshot* card. Pure logic lives
    /// in `FinanceCalculator.monthlySnapshot(...)`. Includes the envelope-level Savings Target so
    /// the snapshot's `plannedBudget` stays in lockstep with `totalBudgeted`.
    var monthlySnapshot: FinanceCalculator.MonthlySnapshot {
        FinanceCalculator.monthlySnapshot(
            budgetItems: budgetItems,
            transactions: transactions,
            hiddenBudgetItemIds: hiddenBudgetItemIdsByMonth[currentMonthKey] ?? [],
            savingsTarget: savingsTargetThisMonth,
            now: Date(),
            calendar: Calendar.current
        )
    }

    func setAvailableToBudgetForCurrentMonth(_ value: Double) {
        availableToBudgetByMonth[currentMonthKey] = max(0, value)
    }

    /// Picks a standard savings rate (10/15/20%) and clears any custom dollar override for the
    /// current month so the rate-based formula takes over again.
    func setSavingsRate(_ percent: Double) {
        desiredSavingsRate = max(0, min(100, percent))
        clearCustomSavingsTargetForCurrentMonth()
    }

    /// Locks in an explicit dollar amount for the current month's Savings Target (used when the
    /// user picks **Other** and types a custom amount).
    func setCustomSavingsTargetForCurrentMonth(_ amount: Double) {
        customSavingsTargetByMonth[currentMonthKey] = max(0, amount)
    }

    /// Removes any custom override for the current month, falling back to the rate-based target.
    func clearCustomSavingsTargetForCurrentMonth() {
        customSavingsTargetByMonth.removeValue(forKey: currentMonthKey)
    }

    /// Locks in the current `availableToBudget` as an explicit override for the current month.
    /// Called before a new income transaction so subsequent income additions don't auto-grow the envelope.
    private func snapshotAvailableToBudgetIfNeeded() {
        if availableToBudgetByMonth[currentMonthKey] == nil {
            availableToBudgetByMonth[currentMonthKey] = availableToBudget
        }
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

    /// Structured urgent-bill messages for the dashboard (paid bills excluded). Uses transactions to compute remaining amount.
    var urgentBillMessages: [BudgetPlanningService.UrgentBillMessage] {
        BudgetPlanningService.urgentBillMessages(
            budgetItems: budgetItems,
            transactions: transactions,
            now: Date(),
            calendar: Calendar.current
        )
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
        let beforePaid = fixedBillsFullyPaidSnapshot()
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
        reconcileFixedBillPaidStates(previousFullyPaid: beforePaid)
        return item
    }

    /// Adds an **income** transaction without auto-growing `availableToBudget`, then queues a prompt
    /// asking the user whether to assign it to the budget.
    ///
    /// - Snapshots the current `availableToBudget` as an explicit override (if missing) so this and
    ///   future income additions cannot silently inflate the envelope.
    /// - Creates the income transaction.
    /// - Sets `pendingIncomePrompt` so the UI can present the choice.
    @discardableResult
    func addIncomeAndPromptIfNeeded(
        amount: Double,
        category: String,
        note: String,
        savedApplied: Double = 0
    ) -> TransactionItem? {
        guard amount > 0 else { return nil }
        snapshotAvailableToBudgetIfNeeded()
        let item = addTransaction(
            amount: amount,
            category: category,
            note: note,
            type: .income,
            savedApplied: savedApplied
        )
        pendingIncomePrompt = PendingIncomePrompt(
            transactionId: item.id,
            amount: amount,
            categoryName: category
        )
        return item
    }

    /// Apply the income to the budget envelope: increases `availableToBudget` by the prompted amount.
    func confirmAddIncomeToBudget() {
        guard let prompt = pendingIncomePrompt else { return }
        let newAvailable = availableToBudget + prompt.amount
        setAvailableToBudgetForCurrentMonth(newAvailable)
        pendingIncomePrompt = nil
    }

    /// Keep the income outside the budget; `availableToBudget` stays unchanged. Reserve grows.
    func keepIncomeAsReserve() {
        // Snapshot already happened; no further mutation needed.
        pendingIncomePrompt = nil
    }

    /// Dismisses the prompt without changing budget assignment (equivalent to keeping as reserve).
    func dismissIncomePrompt() {
        pendingIncomePrompt = nil
    }

    func deleteTransaction(id: UUID) {
        let beforePaid = fixedBillsFullyPaidSnapshot()
        transactions.removeAll { $0.id == id }
        pinnedTransactionIds.remove(id)
        reconcileFixedBillPaidStates(previousFullyPaid: beforePaid)
    }

    @discardableResult
    func removeTransaction(id: UUID) -> TransactionItem? {
        let beforePaid = fixedBillsFullyPaidSnapshot()
        pinnedTransactionIds.remove(id)
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = transactions.remove(at: index)
        reconcileFixedBillPaidStates(previousFullyPaid: beforePaid)
        return removed
    }

    func restoreTransaction(_ transaction: TransactionItem) {
        let beforePaid = fixedBillsFullyPaidSnapshot()
        transactions.insert(transaction, at: 0)
        reconcileFixedBillPaidStates(previousFullyPaid: beforePaid)
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
        addBudgetItem(
            name: name,
            planned: planned,
            budgetType: budgetType,
            frequency: frequency,
            dueDay: dueDay,
            dueWeekday: dueWeekday,
            dueDate: dueDate,
            isPaid: isPaid,
            targetAmount: nil,
            deadline: nil
        )
    }

    /// Generic budget-item creator (variable / fixed / savings).
    func addBudgetItem(
        name: String,
        planned: Double,
        budgetType: BudgetType,
        frequency: PaymentFrequency,
        dueDay: Int?,
        dueWeekday: Int?,
        dueDate: Date?,
        isPaid: Bool = false,
        targetAmount: Double? = nil,
        deadline: Date? = nil
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, planned >= 0 else { return }
        let beforePaid = fixedBillsFullyPaidSnapshot()
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
                isPaid: isPaid,
                targetAmount: targetAmount,
                deadline: deadline
            )
        )
        reconcileFixedBillPaidStates(previousFullyPaid: beforePaid)
    }

    /// In-place edit of an existing budget item.
    func updateBudgetItem(
        id: UUID,
        name: String,
        planned: Double,
        budgetType: BudgetType,
        frequency: PaymentFrequency,
        dueDay: Int?,
        dueWeekday: Int?,
        dueDate: Date?,
        targetAmount: Double? = nil,
        deadline: Date? = nil
    ) {
        guard let index = budgetItems.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, planned >= 0 else { return }
        let beforePaid = fixedBillsFullyPaidSnapshot()
        var item = budgetItems[index]
        item.category = trimmed
        item.planned = planned
        item.budgetType = budgetType
        item.frequency = frequency
        item.dueDay = dueDay
        item.dueWeekday = dueWeekday
        item.dueDate = dueDate
        item.targetAmount = targetAmount
        item.deadline = deadline
        budgetItems[index] = item
        reconcileFixedBillPaidStates(previousFullyPaid: beforePaid)
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

    // MARK: - Variable spending pace (chart + risk badge)

    /// Variable-only pace summary used by the Spending Trend chart and risk badge.
    /// Fixed/recurring bills are excluded; they are tracked via `FixedBillSchedule`.
    var variableSpendingPace: VariableSpendingPace.Result {
        VariableSpendingPace.evaluate(
            budgetItems: budgetItems,
            transactions: transactions,
            currentDayOfMonth: currentDayOfMonth,
            daysInMonth: daysInCurrentMonth,
            calendar: Calendar.current,
            now: Date()
        )
    }

    /// Cumulative variable expenses per day, day 1...currentDayOfMonth (chart blue line).
    func dailyVariableActualCumulative() -> [Double] {
        VariableSpendingPace.dailyVariableActualCumulative(
            transactions: transactions,
            budgetItems: budgetItems,
            currentDayOfMonth: currentDayOfMonth,
            calendar: Calendar.current,
            now: Date()
        )
    }

    /// Per-day projection used when scrubbing the Spending Trend chart. Variable-only.
    func projectedVariableAmountForDay(dayNumber: Int) -> Double {
        let cumulative = dailyVariableActualCumulative()
        return SpendingAnalyticsService.projectedAmountForDay(
            dayNumber: dayNumber,
            dailyActualCumulative: cumulative,
            currentDayOfMonth: currentDayOfMonth,
            daysInCurrentMonth: daysInCurrentMonth,
            projectedEndOfMonthSpend: variableSpendingPace.projectedMonthEndSpend
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
        max(0, availableToBudget * (1 - desiredSavingsRate / 100))
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
            availableToBudgetByMonth: availableToBudgetByMonth,
            customSavingsTargetByMonth: customSavingsTargetByMonth,
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
        availableToBudgetByMonth = decoded.availableToBudgetByMonth
        customSavingsTargetByMonth = decoded.customSavingsTargetByMonth
        fixedBillActualOverridesByMonth = decoded.fixedBillActualOverridesByMonth
        fixedBillPaymentTransactionIdsByMonth = decoded.fixedBillPaymentTransactionIdsByMonth
        budgetItems = migratedBudgetItems
        transactions = decoded.transactions
        reconcileFixedBillPaidStates(previousFullyPaid: nil)
    }

    /// For each fixed bill, whether `actual >= planned` for the current month (transaction-derived).
    private func fixedBillsFullyPaidSnapshot() -> [UUID: Bool] {
        let calendar = Calendar.current
        let now = Date()
        var map: [UUID: Bool] = [:]
        for item in budgetItems where item.budgetType == .fixed {
            let actual = BudgetSpendCalculator.actualPaidAmount(
                for: item,
                transactions: transactions,
                now: now,
                calendar: calendar
            )
            map[item.id] = actual >= item.planned
        }
        return map
    }

    private func reconcileFixedBillPaidStates(previousFullyPaid: [UUID: Bool]? = nil) {
        FixedBillPaidSync.reconcile(
            budgetItems: &budgetItems,
            transactions: transactions,
            now: Date(),
            calendar: Calendar.current
        )
        guard let previous = previousFullyPaid else { return }
        publishFullyPaidTransitionToasts(previousFullyPaid: previous)
    }

    private func publishFullyPaidTransitionToasts(previousFullyPaid: [UUID: Bool]) {
        let calendar = Calendar.current
        let now = Date()
        var categories: [String] = []
        for item in budgetItems where item.budgetType == .fixed {
            let actual = BudgetSpendCalculator.actualPaidAmount(
                for: item,
                transactions: transactions,
                now: now,
                calendar: calendar
            )
            let nowFullyPaid = actual >= item.planned
            let wasFullyPaid = previousFullyPaid[item.id] ?? false
            if !wasFullyPaid && nowFullyPaid {
                categories.append(item.category)
            }
        }
        guard !categories.isEmpty else { return }
        let message: String
        if categories.count == 1 {
            message = "Fully paid \(categories[0])"
        } else {
            message = "Fully paid \(categories.joined(separator: ", "))"
        }
        fullyPaidBillToast = message
        fullyPaidToastDismissTask?.cancel()
        fullyPaidToastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.fullyPaidBillToast = nil
        }
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
