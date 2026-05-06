import SwiftUI

struct ProfilePanelView: View {
    @EnvironmentObject private var appState: AppState

    @State private var savingsSlider: Double = 0
    @State private var selectedMonth: MonthlySummary?
    @State private var weeklyNoteDraft: String = ""

    private let supportedCurrencies = ["USD", "CAD", "EUR", "GBP"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile & Goals")
                .font(.headline)

            Text(appState.currentTerm)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            monthlyHistoryChart

            goalsSection

            billsSection

            weeklyNotesSection

            recalculateSection

            currencySection
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            savingsSlider = appState.desiredSavingsRate
            weeklyNoteDraft = appState.currentWeekNote
        }
        .sheet(item: $selectedMonth) { month in
            MonthDetailPopup(month: month)
                .environmentObject(appState)
        }
    }

    private var monthlyHistoryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Past Months")
                .font(.subheadline)
                .fontWeight(.semibold)

            GeometryReader { proxy in
                let maxPercent = max(100, appState.monthlyHistory.map { (100 * $0.actual / max(1, $0.planned)) }.max() ?? 100)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(appState.monthlyHistory) { month in
                        let percent = (100 * month.actual / max(1, month.planned))
                        let capped = min(percent, maxPercent)
                        let height = CGFloat(capped / maxPercent) * (proxy.size.height - 34)
                        Button {
                            selectedMonth = month
                        } label: {
                            VStack {
                                Text("\(Int(percent))%")
                                    .font(.caption2)
                                    .foregroundStyle(month.isOver ? .red : .green)
                                ZStack(alignment: .bottom) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(width: 26, height: proxy.size.height - 34)
                                    Capsule()
                                        .fill(month.isOver ? Color.red.opacity(0.85) : Color.green.opacity(0.85))
                                        .frame(width: 26, height: height)
                                }
                                Text(month.monthLabel)
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 140)

            Text("Tap a month to view details. Shows percentage of budget used (can exceed 100%).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading) {
                Text("Monthly limit override")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField(
                        "Limit",
                        value: Binding(
                            get: { appState.manualMonthlyLimit ?? appState.monthlySpendingBudget },
                            set: { appState.manualMonthlyLimit = $0 }
                        ),
                        format: .number
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    Text(appState.currencyCode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading) {
                Text("Desired savings from spending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Slider(value: $savingsSlider, in: 0...50, step: 1) {
                        Text("Savings")
                    } minimumValueLabel: {
                        Text("0%")
                            .font(.caption2)
                    } maximumValueLabel: {
                        Text("50%")
                            .font(.caption2)
                    }
                    .onChange(of: savingsSlider) { newValue in
                        appState.desiredSavingsRate = newValue
                    }
                    Text("\(Int(savingsSlider))%")
                        .font(.caption)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Projected monthly savings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appState.projectedSavingsThisMonth.formatted(appState.currencyFormatter))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading) {
                Text("Bonus income (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("0", value: $appState.bonusIncomeForMonth, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Currency")
                .font(.subheadline)
                .fontWeight(.semibold)

            Picker("Currency", selection: $appState.currencyCode) {
                ForEach(supportedCurrencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var recalculateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recalculate Estimated Budget")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Based on your income and savings rate, suggested monthly budget is \(appState.suggestedMonthlyBudgetFromGoals().formatted(appState.currencyFormatter)).")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Recalculate now") {
                appState.recalculateEstimatedBudget()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var billsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bill Due Dates")
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach($appState.billReminders) { $bill in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.title)
                            .fontWeight(.semibold)
                        Text("Expected \(bill.expectedAmount.formatted(appState.currencyFormatter))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper("Due \(bill.dueDay)", value: $bill.dueDay, in: 1...28)
                        .labelsHidden()
                    Text("Due \(bill.dueDay)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Reminder: Pay credit card bill on time.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var weeklyNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("End-of-Week Note")
                .font(.subheadline)
                .fontWeight(.semibold)
            TextEditor(text: $weeklyNoteDraft)
                .frame(minHeight: 90)
                .padding(8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button("Save week note") {
                appState.updateWeekNote(weeklyNoteDraft)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct MonthDetailPopup: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let month: MonthlySummary

    private var percentUsed: Double {
        (month.actual / max(1, month.planned)) * 100
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(month.monthLabel) Budget Details")
                    .font(.title3)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 10) {
                    barRow(label: "Planned", value: month.planned, color: .blue)
                    barRow(label: "Actual", value: month.actual, color: month.isOver ? .red : .green)
                    barRow(label: "Saved", value: abs(month.saved), color: month.isOver ? .red : .mint)
                }
                .padding()
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Budget used: \(Int(percentUsed))%")
                        .font(.headline)
                    Text(month.isOver ? "You were over budget this month." : "You were under budget this month.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                monthlyIncomeBreakdown
                monthlyExpenseBreakdown

                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }

    private var monthlyIncomeBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Budget")
                .font(.headline)
            HStack {
                Text("Budget for month")
                Spacer()
                Text(month.planned.formatted(appState.currencyFormatter))
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var monthlyExpenseBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Expense Breakdown (Actual vs Expected)")
                .font(.headline)

            ForEach(expenseBreakdownItems, id: \.category) { row in
                HStack {
                    Text(row.category)
                    Spacer()
                    Text("\(row.actual.formatted(appState.currencyFormatter)) / \(row.expected.formatted(appState.currencyFormatter))")
                        .font(.caption)
                        .foregroundStyle(row.actual > row.expected ? .red : .secondary)
                }
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var expenseBreakdownItems: [(category: String, expected: Double, actual: Double)] {
        let totalExpectedTemplate = max(1, appState.budgetItems.reduce(0) { $0 + $1.planned })
        let ratio = month.actual / max(1, month.planned)
        return appState.budgetItems.map { item in
            let expected = (item.planned / totalExpectedTemplate) * month.planned
            let actual = expected * ratio
            return (item.category, expected, actual)
        }
    }

    private func barRow(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(value.formatted(appState.currencyFormatter))
                    .fontWeight(.semibold)
            }
            ProgressView(value: value, total: max(month.actual, month.planned, 1))
                .tint(color)
        }
    }
}

#Preview {
    ProfilePanelView()
        .environmentObject(AppState())
}
