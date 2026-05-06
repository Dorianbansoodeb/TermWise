import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    let onQuickAddExpense: () -> Void
    let onQuickAddIncome: () -> Void

    @State private var showConverter: Bool = false

    var body: some View {
        ScrollView {
            mainContent
                .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Currency converter") {
                        showConverter = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showConverter) {
            CurrencyConverterView()
                .environmentObject(appState)
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Good morning, \(appState.userFirstName)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(appState.currentTerm)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            expectedSavedCard
            monthlyExpenseBarCard
            spendTrendCard
            quickActions
            spendingProgressCard
            insightCards
            recentTransactionsCard
        }
    }

    private var spendTrendCard: some View {
        let predictedOver = projectedEndOfMonthSpend > appState.effectiveMonthlyLimit
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
                actual: monthlyActualCumulative,
                predicted: monthlyPredictedCumulative,
                predictedColor: predictedOver ? .red : .green,
                limit: appState.effectiveMonthlyLimit
            )
            .frame(height: 150)

            Text("Predicted month-end: \(projectedEndOfMonthSpend.formatted(appState.currencyFormatter)) vs limit \(appState.effectiveMonthlyLimit.formatted(appState.currencyFormatter))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var expectedSavedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Expected Total Saved")
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
    }

    private var monthlyExpenseBarCard: some View {
        let limit = max(1, appState.effectiveMonthlyLimit)
        let totalSpent = appState.totalActualSpend
        let cappedSpent = min(totalSpent, limit)
        let overflow = max(0, totalSpent - limit)

        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Expense Usage")
                .font(.headline)

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 18)

                    HStack(spacing: 0) {
                        ForEach(appState.budgetItems) { item in
                            let spent = appState.actualAmount(for: item.category)
                            let segmentRatio = spent / max(1, cappedSpent)
                            let segmentWidth = width * CGFloat(segmentRatio) * CGFloat(cappedSpent / limit)
                            Rectangle()
                                .fill(colorForCategory(item.category))
                                .frame(width: segmentWidth, height: 18)
                        }

                        if overflow > 0 {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: width * CGFloat(overflow / limit), height: 18)
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
            infoChip(text: "You're under budget by \((appState.totalPlannedSpend - appState.totalActualSpend).formatted(appState.currencyFormatter)) this month")
            infoChip(text: "Eating out is at \(eatingOutPercent)% with 19 days left")
        }
    }

    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Transactions")
                .font(.headline)
            ForEach(appState.transactions.prefix(3)) { item in
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

    private var monthlyActualCumulative: [Double] {
        let calendar = Calendar.current
        let now = Date()
        let day = calendar.component(.day, from: now)

        let monthTransactions = appState.transactions.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month) && $0.type == .expense
        }

        var cumulative: [Double] = []
        var runningTotal = 0.0
        for currentDay in 1...max(1, day) {
            let dayTotal = monthTransactions
                .filter { calendar.component(.day, from: $0.date) == currentDay }
                .reduce(0) { $0 + $1.amount }
            runningTotal += dayTotal
            cumulative.append(runningTotal)
        }
        return cumulative
    }

    private var monthlyPredictedCumulative: [Double] {
        let calendar = Calendar.current
        let now = Date()
        let day = max(1, calendar.component(.day, from: now))
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? day

        let avgPerDay = (monthlyActualCumulative.last ?? 0) / Double(day)
        return (1...daysInMonth).map { Double($0) * avgPerDay }
    }

    private var projectedEndOfMonthSpend: Double {
        monthlyPredictedCumulative.last ?? (monthlyActualCumulative.last ?? 0)
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
    private func infoChip(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct LineTrendChartView: View {
    @EnvironmentObject private var appState: AppState

    let actual: [Double]
    let predicted: [Double]
    let predictedColor: Color
    let limit: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let dataMax = max(1, (actual + predicted + [limit]).max() ?? 1)
            // Add headroom so the limit line is visually around mid-chart.
            let maxY = max(dataMax * 1.6, limit * 2.0)
            let yLimit = height - (CGFloat(limit) / CGFloat(maxY) * height)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.08))

                Path { path in
                    guard actual.count > 1 else { return }
                    for idx in actual.indices {
                        let x = CGFloat(idx) / CGFloat(max(1, actual.count - 1)) * width
                        let y = height - (CGFloat(actual[idx]) / CGFloat(maxY) * height)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                Path { path in
                    guard predicted.count > 1 else { return }
                    for idx in predicted.indices {
                        let x = CGFloat(idx) / CGFloat(max(1, predicted.count - 1)) * width
                        let y = height - (CGFloat(predicted[idx]) / CGFloat(maxY) * height)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(predictedColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))

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
            }
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(onQuickAddExpense: {}, onQuickAddIncome: {})
            .environmentObject(AppState())
    }
}
