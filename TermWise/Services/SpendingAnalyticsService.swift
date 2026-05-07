import Foundation

/// Awareness copy, projections, and spend curves. Backend may eventually return these precomputed.
enum SpendingAnalyticsService {

    static func awarenessMessages(
        budgetItems: [BudgetItem],
        transactions: [TransactionItem]
    ) -> [String] {
        var messages: [String] = []
        for item in budgetItems {
            let spent = BudgetSpendCalculator.actualAmountAllTime(transactions: transactions, budgetCategory: item.category)
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

    static func savedHistoryTimeline(
        monthlyHistory: [MonthlySummary],
        currentMonthKey: String,
        currentMonthSaved: Double,
        calendar: Calendar = .current
    ) -> [SavedHistoryPoint] {
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

        let monthIndex = max(0, min(11, calendar.component(.month, from: Date()) - 1))
        let currentMonthLabel = calendar.shortMonthSymbols[monthIndex]
        let hasCurrentMonth = points.contains { $0.monthLabel == currentMonthLabel }
        if !hasCurrentMonth {
            cumulative += currentMonthSaved
            points.append(
                SavedHistoryPoint(
                    id: "\(currentMonthKey)-current",
                    monthLabel: currentMonthLabel,
                    monthlySaved: currentMonthSaved,
                    cumulativeSaved: cumulative
                )
            )
        }

        return points
    }

    static func dailyActualCumulative(
        transactions: [TransactionItem],
        currentDayOfMonth: Int,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [Double] {
        let monthTransactions = transactions.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month) && $0.type == .expense
        }

        var cumulative: [Double] = []
        var runningTotal = 0.0
        for currentDay in 1...max(1, currentDayOfMonth) {
            let dayTotal = monthTransactions
                .filter { calendar.component(.day, from: $0.date) == currentDay }
                .reduce(0) { $0 + max(0, $1.amount - $1.savedApplied) }
            runningTotal += dayTotal
            cumulative.append(runningTotal)
        }
        return cumulative
    }

    static func projectedEndOfMonthSpend(
        dailyActualCumulative: [Double],
        currentDayOfMonth: Int,
        daysInCurrentMonth: Int,
        effectiveMonthlyLimit: Double
    ) -> Double {
        let currentActual = dailyActualCumulative.last ?? 0
        let remainingDays = max(0, daysInCurrentMonth - currentDayOfMonth)
        let expectedDailySpend = effectiveMonthlyLimit / Double(max(1, daysInCurrentMonth))
        return currentActual + expectedDailySpend * Double(remainingDays)
    }

    static func projectedAmountForDay(
        dayNumber: Int,
        dailyActualCumulative: [Double],
        currentDayOfMonth: Int,
        daysInCurrentMonth: Int,
        projectedEndOfMonthSpend: Double
    ) -> Double {
        if dayNumber <= currentDayOfMonth {
            return dailyActualCumulative[min(dayNumber - 1, max(0, dailyActualCumulative.count - 1))]
        }
        guard let currentActual = dailyActualCumulative.last else { return 0 }
        let remainingDays = max(1, daysInCurrentMonth - currentDayOfMonth)
        let perDayProjection = (projectedEndOfMonthSpend - currentActual) / Double(remainingDays)
        let futureOffset = dayNumber - currentDayOfMonth
        return currentActual + perDayProjection * Double(futureOffset)
    }

    static func shouldPromptIrregularPurchase(
        amount: Double,
        transactions: [TransactionItem],
        effectiveMonthlyLimit: Double
    ) -> Bool {
        guard amount > 0 else { return false }
        let expenseTransactions = transactions.filter { $0.type == .expense }
        let averageExpense =
            expenseTransactions.map(\.amount).reduce(0, +) / Double(max(1, expenseTransactions.count))
        return amount > max(averageExpense * 2.5, effectiveMonthlyLimit * 0.25)
    }
}
