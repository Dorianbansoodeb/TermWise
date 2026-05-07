import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var completedIds: Set<UUID> = []
    @State private var markedIds: Set<UUID> = []
    @State private var showSavedHistory = false
    @State private var savedHistoryMode: SavedHistoryMode = .cumulative
    /// Whether the Plan vs Reality bar is showing its tap-to-expand legend.
    @State private var isBreakdownExpanded = false
    /// Selected mode for the Spending Trend chart. `@State` keeps the choice for the lifetime
    /// of the dashboard view (i.e. for the app session) without persisting across launches.
    @State private var spendTrendMode: SpendTrendMode = .variable

    /// Two-mode toggle for the Spending Trend chart card.
    enum SpendTrendMode {
        case variable
        case total
    }

    let onQuickAddExpense: () -> Void
    let onQuickAddIncome: () -> Void
    let onViewMoreTransactions: () -> Void

    var body: some View {
        ScrollView {
            mainContent
                .padding()
        }
        .reservesBottomNavSpace()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AppOverflowMenu()
            }
        }
        .sheet(isPresented: $showSavedHistory) {
            SavedHistorySheet(
                mode: $savedHistoryMode,
                points: appState.savedHistoryTimeline()
            )
            .environmentObject(appState)
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            urgentBillsCard

            Text("\(greetingText), \(displayName)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(appState.currentTerm)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            incomeAndBudgetCard
            expectedSavedCard
            monthlyExpenseBarCard()
            spendTrendCard
            quickActions
            spendingProgressCard
            insightCards
            recentTransactionsCard
        }
    }

    private var incomeAndBudgetCard: some View {
        let unallocatedRow = FinanceBudgetAllocation.unallocatedRow(
            availableToBudget: appState.availableToBudget,
            totalBudgeted: appState.totalBudgeted
        )
        return VStack(alignment: .leading, spacing: 10) {
            Text("Income & Budget")
                .font(.headline)
            dashboardFinanceRow("Total Income", appState.totalIncome)
            dashboardFinanceRow("Available to Budget", appState.availableToBudget)
            if appState.reserveNotBudgeted > 0 {
                dashboardFinanceRow("Reserve / Not Budgeted", appState.reserveNotBudgeted)
            }
            dashboardFinanceRow("Total Budgeted", appState.totalBudgeted)
            dashboardFinanceRow(
                unallocatedRow.label,
                unallocatedRow.value,
                valueColor: unallocatedRow.isOver ? .red : .primary
            )
            if appState.availableToBudget > appState.totalIncome && appState.totalIncome > 0 {
                infoLine(
                    "You are budgeting more than your recorded income.",
                    color: .red
                )
            }
            if unallocatedRow.isOver {
                infoLine(
                    "Your budget is over your available amount by \(unallocatedRow.value.formatted(appState.currencyFormatter)).",
                    color: .red
                )
            } else if unallocatedRow.value > 0 {
                infoLine(
                    "You have \(unallocatedRow.value.formatted(appState.currencyFormatter)) left unallocated.",
                    color: .secondary
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func infoLine(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
    }

    private func dashboardFinanceRow(_ label: String, _ value: Double, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value.formatted(appState.currencyFormatter))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
        }
    }

    /// **Spending Trend** card with a Variable ↔ Total toggle.
    private var spendTrendCard: some View {
        Group {
            switch spendTrendMode {
            case .variable:
                variableSpendTrendCard
            case .total:
                totalSpendTrendCard
            }
        }
    }

    /// Variable Spending Trend — pace-based risk on **projected** flexible spending vs variable
    /// budget. Gray dashed = `variableBudget` ("Limit $X"), orange dashed = budget pace,
    /// red dashed = projected. The green Spend Limit reference is intentionally omitted here:
    /// it lives at `availableToBudget − savingsTarget` and would not sit on the same axis as
    /// the variable budget, so showing it would distort scale.
    private var variableSpendTrendCard: some View {
        let pace = appState.variableSpendingPace
        let badgeColor: Color = {
            switch pace.status {
            case .onTrack: return .green
            case .watch: return .orange
            case .overBudgetRisk: return .red
            }
        }()
        let projectedOverLimit = max(0, pace.projectedMonthEndSpend - pace.variableBudget)

        return VStack(alignment: .leading, spacing: 10) {
            spendTrendHeader(
                title: "Variable Spending Trend",
                subtitle: "Flexible spending risk",
                badgeText: pace.status.badgeText,
                badgeColor: badgeColor
            )

            LineTrendChartView(
                mode: .variable,
                dailyActualCumulative: appState.dailyVariableActualCumulative(),
                currentDay: appState.currentDayOfMonth,
                daysInMonth: appState.daysInCurrentMonth,
                projectedEndValue: pace.projectedMonthEndSpend,
                projectedColor: badgeColor,
                limitValue: pace.variableBudget,
                limitLabelPrefix: "Limit",
                showGreenEnvelopeLine: false,
                greenLineAxisValue: 0,
                greenLineLabelPrefix: "Spend Limit",
                greenLineLabelAmount: 0,
                projectedForDay: { appState.projectedVariableAmountForDay(dayNumber: $0) }
            )
            .frame(height: 200)

            VStack(alignment: .leading, spacing: 4) {
                Text("Fixed bills are tracked separately. This chart shows flexible spending pace.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if projectedOverLimit > 0 {
                    Text("Projected over spend limit by \(projectedOverLimit.formatted(appState.currencyFormatter))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Total Spending Trend — compares **projected** total spending against two thresholds:
    /// the full monthly budget (`availableToBudget`, gray dashed) and the savings-protected
    /// `spendLimit` (green line). The card shows one of three mutually exclusive messages:
    ///
    /// - red    — `projected > availableToBudget`: "Projected to exceed your monthly budget by $X
    ///   across all expenses."
    /// - orange — `spendLimit < projected ≤ availableToBudget`: "Projected to pass your
    ///   savings-protected spend limit by $X."
    /// - green  — `projected ≤ spendLimit`: "Projected spending is within your savings-protected
    ///   limit."
    ///
    /// When `savingsTarget > 0` we also show the savings-aware reference line:
    /// "Spend Limit after savings target: $X.XX".
    private var totalSpendTrendCard: some View {
        let pace = appState.totalSpendingPace
        let showSpendLimitReference = pace.savingsTarget > 0 && pace.spendLimit > 0
        let badgeColor: Color = {
            switch pace.status {
            case .onTrack: return .green
            case .nearLimit: return .orange
            case .overBudget: return .red
            }
        }()

        return VStack(alignment: .leading, spacing: 10) {
            spendTrendHeader(
                title: "Total Spending Trend",
                subtitle: "Total budget status",
                badgeText: pace.status.badgeText,
                badgeColor: badgeColor
            )

            LineTrendChartView(
                mode: .total,
                dailyActualCumulative: appState.dailyActualCumulative(),
                currentDay: appState.currentDayOfMonth,
                daysInMonth: appState.daysInCurrentMonth,
                projectedEndValue: pace.projectedMonthEndSpend,
                projectedColor: badgeColor,
                limitValue: pace.availableToBudget,
                limitLabelPrefix: "Available",
                showGreenEnvelopeLine: showSpendLimitReference,
                greenLineAxisValue: pace.spendLimit,
                greenLineLabelPrefix: "Spend Limit",
                greenLineLabelAmount: pace.spendLimit,
                projectedForDay: { appState.projectedTotalAmountForDay(dayNumber: $0) },
                projectedVariableForDay: { appState.projectedVariableAmountForDay(dayNumber: $0) },
                unpaidFixedBillsRemaining: pace.unpaidFixedBillsRemaining
            )
            .frame(height: 200)

            VStack(alignment: .leading, spacing: 4) {
                Text("Total projection uses variable spending pace plus expected fixed bills.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showSpendLimitReference {
                    Text("Spend Limit after savings target: \(pace.spendLimit.formatted(appState.currencyFormatter))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                totalSpendTrendStatusMessage(pace: pace)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// One of the three mutually exclusive Total Spending Trend status messages.
    /// See `totalSpendTrendCard` for the threshold semantics.
    @ViewBuilder
    private func totalSpendTrendStatusMessage(pace: TotalSpendingPace.Result) -> some View {
        switch pace.status {
        case .overBudget:
            Text("Projected to exceed your monthly budget by \(pace.projectedOverAvailableByAmount.formatted(appState.currencyFormatter)) across all expenses.")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
        case .nearLimit:
            Text("Projected to use money reserved for savings by \(pace.projectedOverBudgetByAmount.formatted(appState.currencyFormatter)).")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
        case .onTrack:
            Text("Projected spending is within your savings-protected limit.")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    /// Header — title + risk-context subtitle + pill + swap icon.
    private func spendTrendHeader(title: String, subtitle: String, badgeText: String, badgeColor: Color) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(badgeText)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(badgeColor.opacity(0.15))
                .foregroundStyle(badgeColor)
                .clipShape(Capsule())

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    spendTrendMode = (spendTrendMode == .variable) ? .total : .variable
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle spending trend mode")
            .accessibilityHint(spendTrendMode == .variable ? "Switch to Total Spending Trend" : "Switch to Variable Spending Trend")
        }
    }

    @ViewBuilder
    private var expectedSavedCard: some View {
        if appState.budgetCushion > 0 {
            Button {
                showSavedHistory = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Budget Cushion")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(appState.budgetCushion.formatted(appState.currencyFormatter))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Money preserved by staying under planned spending this month.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Tap to view past months")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .buttonStyle(.plain)
            .background(
                LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .blue.opacity(0.2), radius: 14, y: 8)
        }
    }

    /// **Plan vs Reality** card.
    ///
    /// Coloured segments represent **what the money was spent on** this month, grouped by
    /// transaction category. The denominator is always `appState.availableToBudget` (the
    /// envelope from the Budget Plan screen) — never the legacy `effectiveMonthlyLimit`. Tap
    /// the bar to expand a small breakdown legend; tap again to collapse.
    private func monthlyExpenseBarCard() -> some View {
        let breakdown = appState.spendingBreakdown
        let limit = max(1, breakdown.availableToBudget)
        let actualSpending = breakdown.actualSpending
        let isOver = breakdown.isOverBudget

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Plan vs Reality")
                    .font(.headline)
                Spacer()
                Image(systemName: isBreakdownExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isBreakdownExpanded.toggle()
                }
            } label: {
                planVsRealityBar(breakdown: breakdown, limit: limit)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Plan vs Reality bar")
            .accessibilityHint(isBreakdownExpanded ? "Collapse spending breakdown" : "Expand spending breakdown")

            HStack(alignment: .firstTextBaseline) {
                Text("Actual \(actualSpending.formatted(appState.currencyFormatter)) / Available to Budget \(limit.formatted(appState.currencyFormatter))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isOver {
                    Text("Over budget by \(breakdown.overBudgetBy.formatted(appState.currencyFormatter))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }

            Text("Tap bar to view spending breakdown")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if appState.totalSavedApplied > 0 {
                Text("Gross spent this month: \(appState.totalActualSpend.formatted(appState.currencyFormatter)) • Used from saved: \(appState.totalSavedApplied.formatted(appState.currencyFormatter))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isBreakdownExpanded {
                spendingBreakdownLegend(breakdown)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            // Red border when over budget, as a small but unmissable warning indicator.
            RoundedRectangle(cornerRadius: 16)
                .stroke(isOver ? Color.red.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }

    /// The compact horizontal bar itself — segments come from `breakdown.segments` (sorted
    /// largest-first) and are scaled against `availableToBudget`. When the user is over budget
    /// the segments naturally overflow past 100% of the track and a red overflow tile is
    /// appended; the bar's `clipShape` keeps everything tidy inside the rounded rectangle.
    private func planVsRealityBar(
        breakdown: FinanceCalculator.SpendingBreakdown,
        limit: Double
    ) -> some View {
        GeometryReader { proxy in
            let chartWidth = proxy.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.12))
                    .frame(height: 18)

                HStack(spacing: 0) {
                    ForEach(breakdown.segments, id: \.category) { segment in
                        let width = chartWidth * CGFloat(segment.amount / limit)
                        Rectangle()
                            .fill(CategoryPalette.color(for: segment.category))
                            .frame(width: width, height: 18)
                    }

                    if breakdown.isOverBudget {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: chartWidth * CGFloat(breakdown.overBudgetBy / limit), height: 18)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(height: 18)
        .contentShape(Rectangle())
    }

    /// Tap-to-expand legend rendered directly under the bar. Each row mirrors one bar segment:
    /// coloured dot · category · amount · share of *actual* spending. Empty months render a
    /// short hint instead of an empty list.
    @ViewBuilder
    private func spendingBreakdownLegend(_ breakdown: FinanceCalculator.SpendingBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            if breakdown.segments.isEmpty {
                Text("No expense transactions yet this month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(breakdown.segments, id: \.category) { segment in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(CategoryPalette.color(for: segment.category))
                            .frame(width: 10, height: 10)
                        Text(segment.category)
                            .font(.caption)
                        Spacer()
                        Text(segment.amount.formatted(appState.currencyFormatter))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text("\(Int((segment.percentageOfActual * 100).rounded()))%")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
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
        let pace = appState.variableSpendingPace
        let progress: Double = pace.variableBudget > 0
            ? min(1.0, pace.variableSpent / pace.variableBudget)
            : 0
        let variableItems = appState.budgetItems.filter { $0.budgetType == .variable }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Variable Spending Progress")
                .font(.headline)

            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progress >= 1 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 8) {
                    if variableItems.isEmpty {
                        Text("Add a variable spending category in Budget to track flexible categories.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(variableItems.prefix(3)) { item in
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

            Text("Recurring bills are tracked separately under Budget → Recurring Bills.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var insightCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insights")
                .font(.headline)
            infoChip(
                text: savingsProjectionMessage,
                tone: appState.projectedSavingsThisMonth >= 0 ? .green : .red
            )
            infoChip(text: "Eating out is at \(eatingOutPercent)% with \(remainingDaysInMonth) days left", tone: .orange)
            if let awareness = appState.awarenessMessages.first {
                infoChip(text: awareness, tone: .blue)
            }
        }
    }

    @ViewBuilder
    private var urgentBillsCard: some View {
        let messages = appState.urgentBillMessages
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Urgent")
                    .font(.headline)
                ForEach(messages) { message in
                    Text(BudgetPlanningService.urgentBillSentence(message, currencyFormat: appState.currencyFormatter))
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
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
                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(item.type == .expense ? "-" : "+")\(item.amount.formatted(appState.currencyFormatter))")
                        .fontWeight(.semibold)
                        .foregroundStyle(item.type == .expense ? .red : .green)

                    Button(role: .destructive) {
                        if let removed = appState.removeTransaction(id: item.id) {
                            appState.presentRemovedTransactionUndo(removed)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        if let removed = appState.removeTransaction(id: item.id) {
                            appState.presentRemovedTransactionUndo(removed)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        toggle(&markedIds, item.id)
                    } label: {
                        Label("Mark", systemImage: "flag")
                    }
                    .tint(.orange)
                    Button {
                        toggle(&appState.pinnedTransactionIds, item.id)
                    } label: {
                        Label("Pin", systemImage: "pin")
                    }
                    .tint(.yellow)
                    Button {
                        toggle(&completedIds, item.id)
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle")
                    }
                    .tint(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var eatingOutPercent: Int {
        guard let eating = appState.budgetItems.first(where: { $0.category.localizedCaseInsensitiveContains("eating") }) else { return 0 }
        let spent = appState.actualAmount(for: eating.category)
        return BudgetProgressMetrics.percentUsed(actual: spent, planned: eating.planned)
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

    private var savingsProjectionMessage: String {
        let projection = appState.projectedSavingsThisMonth
        if projection >= 0 {
            return "You’re on track to save \(projection.formatted(appState.currencyFormatter)) by month-end."
        }
        return "At this pace, you may miss your savings target by \(abs(projection).formatted(appState.currencyFormatter))."
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

    private func toggle(_ set: inout Set<UUID>, _ id: UUID) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

}

private enum SavedHistoryMode: String, CaseIterable, Identifiable {
    case cumulative
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cumulative: return "Cumulative"
        case .monthly: return "Monthly"
        }
    }
}

private struct SavedHistorySheet: View {
    @EnvironmentObject private var appState: AppState
    @Binding var mode: SavedHistoryMode
    let points: [SavedHistoryPoint]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Picker("View", selection: $mode) {
                    ForEach(SavedHistoryMode.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                SavedHistoryChart(mode: mode, points: points)
                    .frame(height: 220)

                VStack(alignment: .leading, spacing: 6) {
                    Text(mode == .cumulative ? "Cumulative total by month" : "Saved amount each month")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ForEach(points.suffix(6)) { point in
                        HStack {
                            Text(point.monthLabel)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(value(for: point).formatted(appState.currencyFormatter))
                                .foregroundStyle(value(for: point) >= 0 ? .green : .red)
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Saved Over Time")
        }
    }

    private func value(for point: SavedHistoryPoint) -> Double {
        mode == .cumulative ? point.cumulativeSaved : point.monthlySaved
    }
}

private struct SavedHistoryChart: View {
    @EnvironmentObject private var appState: AppState
    let mode: SavedHistoryMode
    let points: [SavedHistoryPoint]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let values = points.map { mode == .cumulative ? $0.cumulativeSaved : $0.monthlySaved }
            let maxAbsValue = max(1, values.map { abs($0) }.max() ?? 1)
            let midY = height / 2
            let stepX = width / CGFloat(max(1, points.count - 1))

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.08))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: width, y: midY))
                }
                .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                if mode == .cumulative {
                    Path { path in
                        guard !values.isEmpty else { return }
                        let firstY = yPosition(for: values[0], height: height, maxAbsValue: maxAbsValue)
                        path.move(to: CGPoint(x: 0, y: firstY))
                        for (index, value) in values.enumerated().dropFirst() {
                            path.addLine(to: CGPoint(x: CGFloat(index) * stepX, y: yPosition(for: value, height: height, maxAbsValue: maxAbsValue)))
                        }
                    }
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                } else {
                    HStack(alignment: .center, spacing: 0) {
                        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                            let barHeight = CGFloat(abs(value) / maxAbsValue) * (height * 0.42)
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                if value >= 0 {
                                    Rectangle()
                                        .fill(Color.green.opacity(0.8))
                                        .frame(width: max(8, stepX * 0.45), height: barHeight)
                                    Color.clear.frame(height: height * 0.5 - barHeight)
                                } else {
                                    Color.clear.frame(height: height * 0.5)
                                    Rectangle()
                                        .fill(Color.red.opacity(0.8))
                                        .frame(width: max(8, stepX * 0.45), height: barHeight)
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(width: index == points.count - 1 ? max(8, stepX * 0.6) : stepX)
                        }
                    }
                }

                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(points) { point in
                            Text(point.monthLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                }
            }
        }
    }

    private func yPosition(for value: Double, height: CGFloat, maxAbsValue: Double) -> CGFloat {
        let center = height / 2
        let scale = (height * 0.42) / CGFloat(maxAbsValue)
        return center - CGFloat(value) * scale
    }
}

private struct LineTrendChartView: View {
    @EnvironmentObject private var appState: AppState

    enum Mode { case variable, total }

    let mode: Mode
    let dailyActualCumulative: [Double]
    let currentDay: Int
    let daysInMonth: Int
    let projectedEndValue: Double
    let projectedColor: Color
    /// Gray dashed line value — variable: variable budget ("Limit $X"); total: `availableToBudget`
    /// ("Available $X"). **Never** spendLimit on the gray line in either mode.
    let limitValue: Double
    let limitLabelPrefix: String
    /// When true, draws the green reference line at `greenLineAxisValue` (total mode: spendLimit).
    let showGreenEnvelopeLine: Bool
    /// Y-axis position for the green line. Total mode passes `spendLimit`; variable mode is off.
    let greenLineAxisValue: Double
    /// Pill prefix for the green-line label, e.g. "Spend Limit" → renders "Spend Limit $X".
    let greenLineLabelPrefix: String
    /// Dollar amount rendered in the green-line pill (total mode: `spendLimit`).
    let greenLineLabelAmount: Double
    let projectedForDay: (Int) -> Double
    /// Total mode only — projected variable cumulative for `dayNumber`. Used in the future-day
    /// tooltip to show variable separately from the total projection.
    var projectedVariableForDay: ((Int) -> Double)? = nil
    /// Total mode only — Σ `max(0, planned − actualPaid)` for fixed bills this month. Surfaced
    /// in the future-day tooltip as "Remaining fixed bills". Default `0` keeps variable mode quiet.
    var unpaidFixedBillsRemaining: Double = 0

    @State private var selectedDayIndex: Int? = nil

    private let leftInset: CGFloat = 14
    private let rightInset: CGFloat = 14
    private let topInset: CGFloat = 22
    private let bottomInset: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let outerWidth = proxy.size.width
            let outerHeight = proxy.size.height
            let width = max(1, outerWidth - leftInset - rightInset)
            let height = max(1, outerHeight - topInset - bottomInset)

            let greenForScale = (showGreenEnvelopeLine && greenLineAxisValue > 0) ? greenLineAxisValue : 0.0
            let dataMax = max(
                1,
                (dailyActualCumulative + [projectedEndValue, limitValue, greenForScale]).max() ?? 1
            )
            let maxY = max(dataMax * 1.25, limitValue * 1.2, greenForScale * 1.05)
            let yLimit = topInset + (height - (CGFloat(limitValue) / CGFloat(maxY) * height))
            let yGreen = topInset + (height - (CGFloat(greenForScale) / CGFloat(maxY) * height))
            let yProjected = topInset + (height - (CGFloat(projectedEndValue) / CGFloat(maxY) * height))
            let projectedX = leftInset + width

            /// Label priority (per spec): Projected > Available/Limit > Spend Limit > Budget Pace.
            /// The gray "Available" pill is anchored on the left edge while the green
            /// "Spend Limit" pill is on the right — they never overlap horizontally, so
            /// matching Y values aren't a collision. Only the red "Projected" pill (also on
            /// the right) can crowd green; in that case green hides since Projected outranks it.
            let hideGreenLineLabel =
                showGreenEnvelopeLine && greenForScale > 0
                && abs(yGreen - yProjected) < 22

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.08))

                actualPath(width: width, height: height, maxY: maxY)

                if mode == .variable {
                    paceLine(width: width, height: height, maxY: maxY)
                }

                limitLine(width: width, yLimit: yLimit)

                savingsEnvelopeLine(width: width, yGreen: yGreen, show: showGreenEnvelopeLine && greenForScale > 0)

                projectionLine(
                    width: width,
                    height: height,
                    maxY: maxY,
                    projectedX: projectedX,
                    projectedY: yProjected
                )

                limitLabel(yLimit: yLimit)

                if mode == .variable {
                    paceLabel(width: width, height: height, maxY: maxY, yLimit: yLimit)
                }

                if !hideGreenLineLabel {
                    savingsTargetLabel(yGreen: yGreen, yLimit: yLimit, chartWidth: width)
                }

                projectedLabel(yProjected: yProjected, yLimit: yLimit, yGreen: yGreen, projectedX: projectedX)

                dayAxis(outerWidth: outerWidth, outerHeight: outerHeight)

                if let selectedDayIndex {
                    selectedDayOverlay(
                        index: selectedDayIndex,
                        width: width,
                        height: height,
                        outerWidth: outerWidth,
                        outerHeight: outerHeight,
                        maxY: maxY
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = min(max(leftInset, value.location.x), leftInset + width)
                        let ratio = (clampedX - leftInset) / max(1, width)
                        let index = Int(round(ratio * CGFloat(max(1, daysInMonth - 1))))
                        selectedDayIndex = min(max(0, index), max(0, daysInMonth - 1))
                    }
                    .onEnded { _ in
                        selectedDayIndex = nil
                    }
            )
        }
    }

    // MARK: - Lines

    private func actualPath(width: CGFloat, height: CGFloat, maxY: Double) -> some View {
        Path { path in
            guard !dailyActualCumulative.isEmpty else { return }
            let firstY = topInset + (height - (CGFloat(dailyActualCumulative[0]) / CGFloat(maxY) * height))
            path.move(to: CGPoint(x: leftInset, y: firstY))

            for dayIndex in 1..<dailyActualCumulative.count {
                let previous = dailyActualCumulative[dayIndex - 1]
                let current = dailyActualCumulative[dayIndex]
                let x = leftInset + CGFloat(dayIndex) / CGFloat(max(1, daysInMonth - 1)) * width
                let prevY = topInset + (height - (CGFloat(previous) / CGFloat(maxY) * height))
                let currY = topInset + (height - (CGFloat(current) / CGFloat(maxY) * height))
                path.addLine(to: CGPoint(x: x, y: prevY))
                path.addLine(to: CGPoint(x: x, y: currY))
            }
        }
        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }

    private func paceLine(width: CGFloat, height: CGFloat, maxY: Double) -> some View {
        Path { path in
            guard limitValue > 0, daysInMonth > 0 else { return }
            let endY = topInset + (height - (CGFloat(limitValue) / CGFloat(maxY) * height))
            path.move(to: CGPoint(x: leftInset, y: topInset + height))
            path.addLine(to: CGPoint(x: leftInset + width, y: endY))
        }
        .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3]))
    }

    private func limitLine(width: CGFloat, yLimit: CGFloat) -> some View {
        Group {
            if limitValue > 0 {
                Path { path in
                    path.move(to: CGPoint(x: leftInset, y: yLimit))
                    path.addLine(to: CGPoint(x: leftInset + width, y: yLimit))
                }
                .stroke(Color.gray.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
    }

    /// Solid green horizontal line at the **Savings Target** Y axis value (`greenLineAxisValue`,
    /// which is `savingsTarget` in both modes). The pill label shows the same dollar amount.
    private func savingsEnvelopeLine(width: CGFloat, yGreen: CGFloat, show: Bool) -> some View {
        Group {
            if show {
                Path { path in
                    path.move(to: CGPoint(x: leftInset, y: yGreen))
                    path.addLine(to: CGPoint(x: leftInset + width, y: yGreen))
                }
                .stroke(Color.green, style: StrokeStyle(lineWidth: 1.5))
            }
        }
    }

    private func projectionLine(
        width: CGFloat,
        height: CGFloat,
        maxY: Double,
        projectedX: CGFloat,
        projectedY: CGFloat
    ) -> some View {
        Path { path in
            guard let currentValue = dailyActualCumulative.last else { return }
            let currentX = leftInset + CGFloat(max(0, currentDay - 1)) / CGFloat(max(1, daysInMonth - 1)) * width
            let currentY = topInset + (height - (CGFloat(currentValue) / CGFloat(maxY) * height))
            path.move(to: CGPoint(x: currentX, y: currentY))
            path.addLine(to: CGPoint(x: projectedX, y: projectedY))
        }
        .stroke(projectedColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))
    }

    // MARK: - Labels (collision-aware)

    /// Gray reference label (variable: "Limit $X"; total: "Available $X"). Never "Spend Limit".
    private func limitLabel(yLimit: CGFloat) -> some View {
        Group {
            if limitValue > 0 {
                let limitText = "\(limitLabelPrefix) \(limitValue.formatted(appState.currencyFormatter))"
                let preferredY = max(topInset + 8, yLimit - 12)
                pillLabel(limitText, color: .secondary)
                    .position(x: leftInset + 6 + labelWidth(for: limitText) / 2, y: preferredY)
            }
        }
    }

    private func paceLabel(width: CGFloat, height: CGFloat, maxY: Double, yLimit: CGFloat) -> some View {
        Group {
            if limitValue > 0 {
                let xRatio: CGFloat = 0.55
                let xPos = leftInset + width * xRatio
                let valueAt = limitValue * Double(xRatio)
                let yLine = topInset + (height - (CGFloat(valueAt) / CGFloat(maxY) * height))
                let candidateY = yLine + 14
                let safeY = abs(candidateY - yLimit) < 16 ? max(topInset + 6, yLine - 14) : candidateY
                pillLabel("Budget Pace", color: .orange)
                    .position(x: xPos, y: safeY)
            }
        }
    }

    /// Green-line pill — total: "Spend Limit $X". Hidden when `hideGreenLineLabel` collides
    /// with the gray line, since gray (Available / Limit) ranks above Spend Limit in priority.
    private func savingsTargetLabel(yGreen: CGFloat, yLimit: CGFloat, chartWidth: CGFloat) -> some View {
        Group {
            if greenLineLabelAmount > 0 {
                let labelText = "\(greenLineLabelPrefix) \(greenLineLabelAmount.formatted(appState.currencyFormatter))"
                let xPos = leftInset + chartWidth * 0.72
                let above = yGreen - 12
                let below = yGreen + 12
                let candidate = (abs(above - yLimit) < 16) ? below : above
                pillLabel(labelText, color: .green)
                    .position(x: xPos, y: candidate)
            }
        }
    }

    private func projectedLabel(yProjected: CGFloat, yLimit: CGFloat, yGreen: CGFloat, projectedX: CGFloat) -> some View {
        let label = "Projected"
        let widthEstimate = labelWidth(for: label)
        let labelX = max(leftInset + widthEstimate / 2, projectedX - widthEstimate / 2 - 4)
        let above = yProjected - 12
        let below = yProjected + 12
        var candidate = above < topInset + 6 ? below : above
        if abs(candidate - yLimit) < 14 {
            candidate = (candidate > yLimit) ? candidate + 14 : candidate - 14
        }
        let greenShown = showGreenEnvelopeLine && greenLineAxisValue > 0
        if greenShown && abs(candidate - yGreen) < 14 {
            candidate = (candidate > yGreen) ? candidate + 14 : candidate - 14
        }
        return pillLabel(label, color: projectedColor)
            .position(x: labelX, y: candidate)
    }

    private func pillLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
    }

    /// Cheap label-width estimate used for collision-safe positioning.
    private func labelWidth(for text: String) -> CGFloat {
        CGFloat(text.count) * 6.5 + 14
    }

    private func dayAxis(outerWidth: CGFloat, outerHeight: CGFloat) -> some View {
        HStack {
            Text("1")
            Spacer()
            Text("\(daysInMonth)")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, leftInset)
        .frame(width: outerWidth, height: outerHeight, alignment: .bottom)
    }

    // MARK: - Selected-day callout

    @ViewBuilder
    private func selectedDayOverlay(
        index: Int,
        width: CGFloat,
        height: CGFloat,
        outerWidth: CGFloat,
        outerHeight: CGFloat,
        maxY: Double
    ) -> some View {
        let dayNumber = index + 1
        let x = leftInset + CGFloat(index) / CGFloat(max(1, daysInMonth - 1)) * width
        let isPastOrToday = dayNumber <= currentDay

        // Actual cumulative variable spend on this day, only available for days <= today.
        let actualForDay: Double? = {
            guard isPastOrToday, !dailyActualCumulative.isEmpty else { return nil }
            let arrayIndex = min(index, dailyActualCumulative.count - 1)
            guard arrayIndex >= 0 else { return nil }
            return dailyActualCumulative[arrayIndex]
        }()

        // Projected value follows the red projection line: equals actual on past days, extrapolates for future days.
        let projected = projectedForDay(dayNumber)

        // Budget pace follows the orange dashed line: limit * day/daysInMonth. Variable mode only.
        let paceForDay = limitValue * (Double(dayNumber) / Double(max(1, daysInMonth)))

        // Anchor the dot on the red projection line for visual consistency with the projection.
        let dotY = topInset + (height - (CGFloat(projected) / CGFloat(maxY) * height))

        Path { path in
            path.move(to: CGPoint(x: x, y: topInset))
            path.addLine(to: CGPoint(x: x, y: topInset + height))
        }
        .stroke(Color.gray.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        Circle()
            .fill(projectedColor)
            .frame(width: 10, height: 10)
            .position(x: x, y: dotY)

        tooltipBubble(
            day: index,
            actual: actualForDay,
            projected: projected,
            pace: paceForDay
        )
        .position(
            tooltipPosition(
                anchorX: x,
                anchorY: dotY,
                outerWidth: outerWidth,
                outerHeight: outerHeight,
                hasActual: actualForDay != nil
            )
        )
    }

    /// Tap tooltip — context-sensitive (matches `FinanceCalculator.spendingTrend...TooltipRowTitles`):
    ///
    /// - Variable, past/today : Actual · Budget Pace
    /// - Variable, future     : Projected · Budget Pace
    /// - Total,    past/today : Actual (Available is gray line only; Spend Limit is on-chart only)
    /// - Total,    future     : Projected total · Projected variable · Remaining fixed bills
    ///
    /// Projected is **never** shown for `selectedDay <= currentDay`; Actual is **never** shown
    /// for `selectedDay > currentDay`.
    private func tooltipBubble(
        day index: Int,
        actual: Double?,
        projected: Double,
        pace: Double
    ) -> some View {
        // `actual` is non-nil only for `selectedDay <= currentDay` (set upstream in
        // selectedDayOverlay). The presence of actual is the past/future signal.
        VStack(alignment: .leading, spacing: 4) {
            Text(dateLabel(for: index))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if mode == .variable {
                if let actual {
                    tooltipRow(label: "Actual", value: actual, color: .blue)
                } else {
                    tooltipRow(label: "Projected", value: projected, color: projectedColor)
                }
                tooltipRow(label: "Budget Pace", value: pace, color: .orange)
            } else if let actual {
                tooltipRow(label: "Actual", value: actual, color: .blue)
            } else {
                tooltipRow(label: "Projected total spending", value: projected, color: projectedColor)
                tooltipRow(label: "Remaining fixed bills", value: unpaidFixedBillsRemaining, color: .secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }

    private func tooltipRow(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text("\(label):")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.formatted(appState.currencyFormatter))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    /// Keeps the tooltip inside the chart bounds. Row count mirrors `tooltipBubble`:
    /// Variable: date · Actual/Projected · Budget Pace (3). Total past: date · Actual (2).
    /// Total future: date · projected total · remaining fixed (3).
    private func tooltipPosition(
        anchorX: CGFloat,
        anchorY: CGFloat,
        outerWidth: CGFloat,
        outerHeight: CGFloat,
        hasActual: Bool
    ) -> CGPoint {
        let rowHeight: CGFloat = 18
        let totalRows: CGFloat = {
            if mode == .variable { return 3 }
            return hasActual ? 2 : 3
        }()
        let estimatedWidth: CGFloat = 200
        let estimatedHeight: CGFloat = max(64, totalRows * rowHeight + 16)
        let halfW = estimatedWidth / 2
        let halfH = estimatedHeight / 2
        let margin: CGFloat = 6

        let clampedX = min(outerWidth - halfW - margin, max(halfW + margin, anchorX))

        let preferredAbove = anchorY - halfH - 14
        let preferredBelow = anchorY + halfH + 14
        let aboveFits = preferredAbove >= halfH + margin
        let chosenY = aboveFits ? preferredAbove : preferredBelow
        let clampedY = min(outerHeight - halfH - margin, max(halfH + margin, chosenY))

        return CGPoint(x: clampedX, y: clampedY)
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
