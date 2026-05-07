import Foundation

/// Bill urgency and onboarding-driven budget layout. No UI types.
enum BudgetPlanningService {

    /// Per-bill urgent message for the dashboard. Filters out paid bills.
    struct UrgentBillMessage: Identifiable {
        let id: UUID
        let billCategory: String
        let amount: Double
        /// Negative when overdue, 0 = today, positive = upcoming days.
        let daysUntilDue: Int
        let isOverdue: Bool
    }

    /// Bills (fixed + savings goals) that are due within the next 2 days OR overdue and unpaid.
    /// Caller composes display text via `urgentBillSentence`.
    static func urgentBillMessages(
        budgetItems: [BudgetItem],
        transactions: [TransactionItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [UrgentBillMessage] {
        budgetItems.compactMap { item -> UrgentBillMessage? in
            guard item.budgetType == .fixed || item.budgetType == .savings else { return nil }
            guard item.frequency != .none else { return nil }

            let actual = BudgetSpendCalculator.actualPaidAmount(
                for: item,
                transactions: transactions,
                now: now,
                calendar: calendar
            )
            // Already paid: never urgent.
            if actual >= item.planned { return nil }

            guard let delta = FixedBillSchedule.daysUntilDue(
                frequency: item.frequency,
                dueDay: item.dueDay,
                dueWeekday: item.dueWeekday,
                dueDate: item.dueDate,
                now: now,
                calendar: calendar
            ) else { return nil }

            let upcomingWindow = delta >= 0 && delta <= 2
            let overdue = delta < 0
            guard upcomingWindow || overdue else { return nil }

            return UrgentBillMessage(
                id: item.id,
                billCategory: item.category,
                amount: max(0, item.planned - actual),
                daysUntilDue: delta,
                isOverdue: overdue
            )
        }
    }

    /// Cleaner copy than the legacy "Pay X in <= 2 days" wording.
    /// - "<Bill> is overdue ($X)."
    /// - "<Bill> is due today ($X)."
    /// - "<Bill> is due tomorrow ($X)."
    /// - "<Bill> is due in N days ($X)."
    static func urgentBillSentence(
        _ message: UrgentBillMessage,
        currencyFormat: FloatingPointFormatStyle<Double>.Currency
    ) -> String {
        let amount = message.amount.formatted(currencyFormat)
        if message.isOverdue {
            return "\(message.billCategory) is overdue (\(amount))."
        }
        switch message.daysUntilDue {
        case 0:
            return "\(message.billCategory) is due today (\(amount))."
        case 1:
            return "\(message.billCategory) is due tomorrow (\(amount))."
        default:
            return "\(message.billCategory) is due in \(message.daysUntilDue) days (\(amount))."
        }
    }

    /// Legacy alias kept for any caller reading `BillReminder` directly.
    /// Prefer `urgentBillMessages` going forward.
    static func upcomingUrgentBills(
        budgetItems: [BudgetItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [BillReminder] {
        urgentBillMessages(budgetItems: budgetItems, transactions: [], now: now, calendar: calendar)
            .map { BillReminder(id: $0.id, title: $0.billCategory, dueDay: max(0, $0.daysUntilDue), expectedAmount: $0.amount) }
    }

    /// After onboarding, recompute tuition line from remaining monthly budget (same rule as server should use).
    static func applyOnboardingTuitionSplit(
        data: OnboardingData,
        budgetItems: [BudgetItem]
    ) -> [BudgetItem] {
        var items = budgetItems
        let nonTuitionTotal = items
            .filter { !$0.category.localizedCaseInsensitiveContains("tuition") }
            .reduce(0) { $0 + $1.planned }
        let tuitionPlanned = max(0, data.monthlySpendingBudget - nonTuitionTotal)
        if let tuitionIndex = items.firstIndex(where: { $0.category.localizedCaseInsensitiveContains("tuition") }) {
            items[tuitionIndex].planned = tuitionPlanned
        }
        return items
    }
}
