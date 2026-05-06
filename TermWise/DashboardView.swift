import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var recentlyRemovedTransaction: TransactionItem?

    let onQuickAddExpense: () -> Void
    let onQuickAddIncome: () -> Void
    let onViewMoreTransactions: () -> Void

    var body: some View {
        ScrollView {
            mainContent
                .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AppOverflowMenu()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let removed = recentlyRemovedTransaction {
                HStack {
                    Text("Removed \(removed.category)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Undo") {
                        appState.restoreTransaction(removed)
                        recentlyRemovedTransaction = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.thinMaterial)
            }
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !appState.upcomingUrgentBills.isEmpty {
                urgentBillsCard
            }

            Text("\(greetingText), \(displayName)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(appState.currentTerm)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            expectedSavedCard
            monthlyExpenseBarCard()
            spendTrendCard
            quickActions
            spendingProgressCard
            insightCards
            recentTransactionsCard
        }
    }

    private var spendTrendCard: some View {
        let predictedOver = appState.projectedEndOfMonthSpend > appState.effectiveMonthlyLimit
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Spending Trend")
                    .font(.headline)
                Spacer()
                Text(predictedOver ? "Risk: Over budget" : "Good pace")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((predictedOver ? Color.red : Color.green).opacity(0.15))
                    .clipShape(Capsule())
            }

            LineTrendChartView(
                dailyActualCumulative: appState.dailyActualCumulative(),
                currentDay: appState.currentDayOfMonth,
                daysInMonth: appState.daysInCurrentMonth,
                projectedEndValue: appState.projectedEndOfMonthSpend,
                projectedColor: predictedOver ? .red : .green,
                limit: appState.effectiveMonthlyLimit
            )
            .frame(height: 150)

            Text("Projection runs from today to month-end using expected daily usage (\(appState.expectedDailySpend.formatted(appState.currencyFormatter))/day).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var expectedSavedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Main Balance")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(appState.expectedTotalSaved.formatted(appState.currencyFormatter))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Income \(appState.monthlyIncome.formatted(appState.currencyFormatter)) • Spend \(appState.totalActualSpend.formatted(appState.currencyFormatter))")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .blue.opacity(0.2), radius: 14, y: 8)
    }

    private func monthlyExpenseBarCard() -> some View {
        let limit = max(1, appState.effectiveMonthlyLimit)
        let totalSpent = appState.totalActualSpend
        let cappedSpent = min(totalSpent, limit)
        let overflow = max(0, totalSpent - limit)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Plan vs Reality")
                .font(.headline)

            GeometryReader { proxy in
                let chartWidth = proxy.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 18)

                    HStack(spacing: 0) {
                        ForEach(appState.budgetItems) { item in
                            let spent = appState.actualAmount(for: item.category)
                            let segmentRatio = spent / max(1, cappedSpent)
                            let segmentWidth = chartWidth * CGFloat(segmentRatio) * CGFloat(cappedSpent / limit)
                            Rectangle()
                                .fill(colorForCategory(item.category))
                                .frame(width: segmentWidth, height: 18)
                        }

                        if overflow > 0 {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: chartWidth * CGFloat(overflow / limit), height: 18)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(height: 18)

            HStack {
                Text("Spent \(totalSpent.formatted(appState.currencyFormatter)) / Allowed \(appState.effectiveMonthlyLimit.formatted(appState.currencyFormatter))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if overflow > 0 {
                    Text("Over by \(overflow.formatted(appState.currencyFormatter))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button(action: onQuickAddExpense) {
                Label("Quick Add Expense", systemImage: "minus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: onQuickAddIncome) {
                Label("Quick Add Income", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var spendingProgressCard: some View {
        let progress = min(1.0, appState.totalActualSpend / max(1, appState.effectiveMonthlyLimit))
        return VStack(alignment: .leading, spacing: 12) {
            Text("Spending Progress")
                .font(.headline)

            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progress > 1 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.budgetItems.prefix(3)) { item in
                        let spent = appState.actualAmount(for: item.category)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ProgressView(value: spent, total: max(1, item.planned))
                                .tint(spent > item.planned ? .red : .blue)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var insightCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insights")
                .font(.headline)
            infoChip(
                text: "You’re \(budgetDelta >= 0 ? "under" : "over") budget by \(abs(budgetDelta).formatted(appState.currencyFormatter)) this month",
                tone: budgetDelta >= 0 ? .green : .red
            )
            infoChip(text: "Eating out is at \(eatingOutPercent)% with \(remainingDaysInMonth) days left", tone: .orange)
            if let awareness = appState.awarenessMessages.first {
                infoChip(text: awareness, tone: .blue)
            }
        }
    }

    private var urgentBillsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Urgent")
                .font(.headline)
            ForEach(appState.upcomingUrgentBills) { bill in
                Text("Pay \(bill.title) in <= 2 days (\(bill.expectedAmount.formatted(appState.currencyFormatter))).")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                Button("View more") {
                    onViewMoreTransactions()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(recentTransactions.prefix(3)) { item in
                HStack {
                    Image(systemName: item.type == .expense ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(item.type == .expense ? .red : .green)
                    VStack(alignment: .leading) {
                        Text(item.category)
                            .fontWeight(.semibold)
                        Text(item.note.isEmpty ? "No note" : item.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(item.type == .expense ? "-" : "+")\(item.amount.formatted(appState.currencyFormatter))")
                        .fontWeight(.semibold)
                        .foregroundStyle(item.type == .expense ? .red : .green)

                    Button(role: .destructive) {
                        recentlyRemovedTransaction = appState.removeTransaction(id: item.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var eatingOutPercent: Int {
        guard let eating = appState.budgetItems.first(where: { $0.category.localizedCaseInsensitiveContains("eating") }) else { return 0 }
        let spent = appState.actualAmount(for: eating.category)
        return Int((spent / max(1, eating.planned)) * 100)
    }

    private func keyValue(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.formatted(appState.currencyFormatter))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        let value = category.lowercased()
        if value.contains("rent") { return .indigo }
        if value.contains("grocer") { return .green }
        if value.contains("transport") { return .orange }
        if value.contains("eat") { return .pink }
        if value.contains("tuition") || value.contains("saving") { return .teal }
        return .blue
    }

    @ViewBuilder
    private func infoChip(text: String, tone: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tone.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var budgetDelta: Double {
        appState.totalPlannedSpend - appState.totalActualSpend
    }

    private var remainingDaysInMonth: Int {
        max(0, appState.daysInCurrentMonth - appState.currentDayOfMonth)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var displayName: String {
        appState.userFirstName.isEmpty ? "Piere" : appState.userFirstName
    }

    private var recentTransactions: [TransactionItem] {
        appState.transactions.sorted { lhs, rhs in
            let leftPinned = appState.pinnedTransactionIds.contains(lhs.id)
            let rightPinned = appState.pinnedTransactionIds.contains(rhs.id)
            if leftPinned != rightPinned {
                return leftPinned && !rightPinned
            }
            return lhs.date > rhs.date
        }
    }
}

private struct LineTrendChartView: View {
    @EnvironmentObject private var appState: AppState

    let dailyActualCumulative: [Double]
    let currentDay: Int
    let daysInMonth: Int
    let projectedEndValue: Double
    let projectedColor: Color
    let limit: Double
    @State private var selectedDayIndex: Int? = nil

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let dataMax = max(1, (dailyActualCumulative + [projectedEndValue, limit]).max() ?? 1)
            // Add headroom so the limit line is visually around mid-chart.
            let maxY = max(dataMax * 1.6, limit * 2.0)
            let yLimit = height - (CGFloat(limit) / CGFloat(maxY) * height)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.08))

                Path { path in
                    guard !dailyActualCumulative.isEmpty else { return }
                    let firstY = height - (CGFloat(dailyActualCumulative[0]) / CGFloat(maxY) * height)
                    path.move(to: CGPoint(x: 0, y: firstY))

                    // Stair-step (stagnant) graph from day 1 to current day.
                    for dayIndex in 1..<dailyActualCumulative.count {
                        let previous = dailyActualCumulative[dayIndex - 1]
                        let current = dailyActualCumulative[dayIndex]
                        let x = CGFloat(dayIndex) / CGFloat(max(1, daysInMonth - 1)) * width
                        let prevY = height - (CGFloat(previous) / CGFloat(maxY) * height)
                        let currY = height - (CGFloat(current) / CGFloat(maxY) * height)
                        path.addLine(to: CGPoint(x: x, y: prevY))
                        path.addLine(to: CGPoint(x: x, y: currY))
                    }
                }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                // Straight dotted projection from current day to end of month.
                Path { path in
                    guard let currentValue = dailyActualCumulative.last else { return }
                    let currentX = CGFloat(max(0, currentDay - 1)) / CGFloat(max(1, daysInMonth - 1)) * width
                    let currentY = height - (CGFloat(currentValue) / CGFloat(maxY) * height)
                    let endX = width
                    let endY = height - (CGFloat(projectedEndValue) / CGFloat(maxY) * height)

                    path.move(to: CGPoint(x: currentX, y: currentY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(projectedColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))

                // Limit line
                if limit > 0 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yLimit))
                        path.addLine(to: CGPoint(x: width, y: yLimit))
                    }
                    .stroke(Color.gray.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                    Text("Limit \(limit.formatted(appState.currencyFormatter))")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Capsule())
                        .position(x: min(width - 70, max(60, width * 0.72)), y: max(12, yLimit - 10))
                }

                // Day markers for readability
                HStack {
                    Text("1")
                    Spacer()
                    Text("\(daysInMonth)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .frame(maxHeight: .infinity, alignment: .bottom)

                if let selectedDayIndex {
                    let x = CGFloat(selectedDayIndex) / CGFloat(max(1, daysInMonth - 1)) * width
                    let amount = amountFor(dayIndex: selectedDayIndex)
                    let y = height - (CGFloat(amount) / CGFloat(maxY) * height)
                    let isFuture = selectedDayIndex + 1 > currentDay
                    let dayExpectedLimit = limit * (Double(selectedDayIndex + 1) / Double(max(1, daysInMonth)))
                    let statusColor: Color = isFuture
                        ? (amount <= dayExpectedLimit ? .green : .red)
                        : .blue

                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(Color.gray.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .position(x: x, y: y)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateLabel(for: selectedDayIndex))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(amount.formatted(appState.currencyFormatter))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .position(
                        x: min(width - 80, max(80, x)),
                        y: max(20, y - 24)
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = min(max(0, value.location.x), width)
                        let ratio = clampedX / max(1, width)
                        let index = Int(round(ratio * CGFloat(max(1, daysInMonth - 1))))
                        selectedDayIndex = min(max(0, index), max(0, daysInMonth - 1))
                    }
                    .onEnded { _ in
                        selectedDayIndex = nil
                    }
            )
        }
    }

    private func amountFor(dayIndex: Int) -> Double {
        let dayNumber = dayIndex + 1
        return appState.projectedAmountForDay(dayNumber: dayNumber)
    }

    private func dateLabel(for dayIndex: Int) -> String {
        let month = Calendar.current.component(.month, from: Date())
        let symbols = Calendar.current.shortMonthSymbols
        let name = symbols[max(0, min(symbols.count - 1, month - 1))]
        return "\(name) \(dayIndex + 1)"
    }
}

#Preview {
    NavigationStack {
        DashboardView(onQuickAddExpense: {}, onQuickAddIncome: {}, onViewMoreTransactions: {})
            .environmentObject(AppState())
    }
}
