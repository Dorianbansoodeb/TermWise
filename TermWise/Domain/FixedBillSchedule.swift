import Foundation

/// Due-date deltas and paid / upcoming / overdue for fixed bills.
/// Mirror in Android as `FixedBillSchedule` with identical branching.
enum FixedBillSchedule {

    static func daysUntilDue(
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

    static func status(
        for item: BudgetItem,
        transactions: [TransactionItem],
        now: Date,
        calendar: Calendar
    ) -> FixedBillStatus {
        // Both fixed bills and savings goals are paid/upcoming/overdue by transactions vs. planned + due-date.
        guard item.budgetType == .fixed || item.budgetType == .savings else { return .upcoming }
        let actual = BudgetSpendCalculator.actualPaidAmount(for: item, transactions: transactions, now: now, calendar: calendar)
        if actual >= item.planned {
            return .paid
        }
        let delta = daysUntilDue(
            frequency: item.frequency,
            dueDay: item.dueDay,
            dueWeekday: item.dueWeekday,
            dueDate: item.dueDate,
            now: now,
            calendar: calendar
        ) ?? 0
        return delta < 0 ? .overdue : .upcoming
    }

    /// Human-readable due-date description for fixed bills / savings goals (e.g. "Day 15", "Wednesday").
    static func dueDayLabel(for item: BudgetItem, calendar: Calendar = .current) -> String? {
        switch item.frequency {
        case .none:
            return nil
        case .monthly:
            guard let dueDay = item.dueDay else { return nil }
            return "Day \(dueDay)"
        case .weekly, .biweekly:
            guard let dueWeekday = item.dueWeekday else { return nil }
            let symbols = calendar.weekdaySymbols
            let index = max(0, min(symbols.count - 1, dueWeekday - 1))
            return symbols[index]
        case .oneTime:
            guard let dueDate = item.dueDate else { return nil }
            return dueDate.formatted(date: .abbreviated, time: .omitted)
        }
    }
}
