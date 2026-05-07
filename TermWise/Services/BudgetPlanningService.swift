import Foundation

/// Bill urgency and onboarding-driven budget layout. No UI types.
enum BudgetPlanningService {

    static func upcomingUrgentBills(
        budgetItems: [BudgetItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [BillReminder] {
        let derivedBills = budgetItems.compactMap { item -> BillReminder? in
            guard item.budgetType == .fixed, item.frequency != .none else { return nil }
            let day = item.dueDay ?? 1
            return BillReminder(id: item.id, title: item.category, dueDay: day, expectedAmount: item.planned)
        }
        return derivedBills.filter { bill in
            guard
                let item = budgetItems.first(where: { $0.id == bill.id }),
                let dayDelta = FixedBillSchedule.daysUntilDue(
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
