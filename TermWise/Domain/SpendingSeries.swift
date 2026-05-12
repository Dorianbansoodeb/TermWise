import Foundation

enum SpendingSeries {

    /// `startOfDay` values in ascending order: left-most chart slot → newest day (today for trailing; month order for `.currentMonth`).
    static func windowDayStarts(
        for range: SpendTrendRange,
        now: Date,
        calendar: Calendar,
        daysInCalendarMonth: Int
    ) -> [Date] {
        switch range {
        case .sevenDays, .oneWeek, .thirtyDays:
            let span = range.selectedDays(daysInCalendarMonth: daysInCalendarMonth)
            let end = calendar.startOfDay(for: now)
            guard span > 0 else { return [] }
            return (0..<span).compactMap { offset in
                calendar.date(byAdding: .day, value: -(span - 1 - offset), to: end)
            }
        case .currentMonth:
            guard
                let interval = calendar.dateInterval(of: .month, for: now)
            else { return [] }
            var days: [Date] = []
            var day = interval.start
            while day < interval.end {
                days.append(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            return days
        }
    }

    static func cumulativeVariableSpendPerDaySlot(
        transactions: [TransactionItem],
        budgetItems: [BudgetItem],
        orderedDayStarts: [Date],
        calendar: Calendar,
        elapsedSlotsInclusiveOneBased currentSlot: Int
    ) -> [Double] {
        cumulativeSpendPerDaySlot(
            transactions: transactions,
            budgetItems: budgetItems,
            orderedDayStarts: orderedDayStarts,
            calendar: calendar,
            elapsedSlotsInclusiveOneBased: currentSlot,
            includeOnlyVariableCategories: true
        )
    }

    static func cumulativeTotalSpendPerDaySlot(
        transactions: [TransactionItem],
        orderedDayStarts: [Date],
        calendar: Calendar,
        elapsedSlotsInclusiveOneBased currentSlot: Int
    ) -> [Double] {
        cumulativeSpendPerDaySlot(
            transactions: transactions,
            budgetItems: [],
            orderedDayStarts: orderedDayStarts,
            calendar: calendar,
            elapsedSlotsInclusiveOneBased: currentSlot,
            includeOnlyVariableCategories: false
        )
    }

    private static func cumulativeSpendPerDaySlot(
        transactions: [TransactionItem],
        budgetItems: [BudgetItem],
        orderedDayStarts: [Date],
        calendar: Calendar,
        elapsedSlotsInclusiveOneBased currentSlot: Int,
        includeOnlyVariableCategories: Bool
    ) -> [Double] {
        let n = orderedDayStarts.count
        guard n > 0 else { return [] }

        func dayExpenseTotal(on day: Date) -> Double {
            transactions
                .filter { txn in
                    guard txn.type == .expense else { return false }
                    guard calendar.isDate(txn.date, inSameDayAs: day) else { return false }
                    if includeOnlyVariableCategories {
                        return VariableSpendingPace.isVariableCategory(txn.category, budgetItems: budgetItems)
                    }
                    return true
                }
                .reduce(0) { $0 + BudgetSpendCalculator.netExpenseAmount($1) }
        }

        var cumulative: [Double] = []
        cumulative.reserveCapacity(n)
        var running = 0.0

        let todayIdx = max(0, min(n - 1, currentSlot - 1))

        for i in 0..<n {
            let daySpend: Double = {
                if i <= todayIdx { return dayExpenseTotal(on: orderedDayStarts[i]) }
                return 0
            }()
            if i <= todayIdx {
                running += daySpend
            }
            cumulative.append(running)
        }

        guard currentSlot > 0, currentSlot < n else {
            return cumulative
        }

        let plateauAt = cumulative[min(max(0, currentSlot - 1), cumulative.count - 1)]
        for i in currentSlot..<n {
            cumulative[i] = plateauAt
        }
        return cumulative
    }

    static func effectiveTodaySlot(oneBasedWithinWindow currentDayOfCalendarMonth: Int, range: SpendTrendRange, chartSpanDays: Int) -> Int {
        switch range {
        case .sevenDays, .oneWeek, .thirtyDays:
            return chartSpanDays
        case .currentMonth:
            return max(1, min(currentDayOfCalendarMonth, chartSpanDays))
        }
    }

    /// True when fixed bill expectation should count toward a trailing Spend Trend window.
    ///
    /// - TODO: Today we only classify **monthly** fixed items by `dueDay` when the trailing window stays in the **same calendar month** as `referenceNow`. Weekly/biweekly/one‑time schedules and windows that span a month boundary are not fully modeled yet.
    static func fixedMonthlyBillLikelyDueInTrailingWindowSameMonthOrNil(
        item: BudgetItem,
        windowStarts: [Date],
        referenceNow: Date,
        calendar: Calendar
    ) -> Bool {
        guard item.budgetType == .fixed, item.frequency == .monthly, let due = item.dueDay else {
            return false
        }

        guard
            let first = windowStarts.first.map({ calendar.startOfDay(for: $0) }),
            let last = windowStarts.last.map({ calendar.startOfDay(for: $0) }),
            calendar.isDate(first, equalTo: last, toGranularity: .month),
            calendar.isDate(first, equalTo: referenceNow, toGranularity: .month)
        else { return false }

        let yr = calendar.component(.year, from: first)
        let mo = calendar.component(.month, from: first)
        let dim = calendar.range(of: .day, in: .month, for: first)?.count ?? due
        let dueClamped = min(max(1, due), dim)
        guard
            let dueDate = calendar.date(from: DateComponents(year: yr, month: mo, day: dueClamped)),
            calendar.startOfDay(for: dueDate) >= first && calendar.startOfDay(for: dueDate) <= last
        else { return false }

        let startDom = calendar.component(.day, from: first)
        let todayDom = calendar.component(.day, from: last)
        return dueClamped >= startDom && dueClamped <= todayDom
    }
}
