import SwiftUI

/// Profile panel — intentionally simple after the *Budget Goals* section was moved into the
/// Budget Plan screen. Today the Profile screen surfaces:
///
/// 1. The current term + a small "past months" history chart.
/// 2. A currency picker.
/// 3. A **Monthly Note** for the currently-selected month (no budgeting numbers).
/// 4. A placeholder explaining that account / preferences / import-export will live here later.
///
/// Anything that mutates the monthly *budget* (Available to Budget, Savings Target, savings rate,
/// bonus income) lives on the Budget Plan tab so all budgeting controls live in one place. The
/// Monthly Note is a free-form journaling field and is not part of the budget math.
struct ProfilePanelView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedMonth: MonthlySummary?
    /// Local draft mirrored to `appState.monthlyNotes[currentMonthKey]`. Seeded from app state
    /// in `.onAppear` and on month rollover; user edits flush back through `onChange`.
    @State private var monthlyNoteDraft: String = ""

    private let supportedCurrencies = ["USD", "CAD", "EUR", "GBP"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Profile")
                    .font(.headline)

                Text(appState.currentTerm)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                monthlyHistoryChart

                currencySection

                monthlyNoteSection

                profileSettingsPlaceholder
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(item: $selectedMonth) { month in
            MonthDetailPopup(month: month)
                .environmentObject(appState)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { syncNoteDraftFromAppState() }
        .onChange(of: appState.currentMonthKey) { _, _ in syncNoteDraftFromAppState() }
        .onChange(of: monthlyNoteDraft) { _, newValue in
            // Persist immediately so leaving the screen never loses a half-typed note.
            appState.monthlyNotes[appState.currentMonthKey] = newValue
        }
    }

    private func syncNoteDraftFromAppState() {
        monthlyNoteDraft = appState.currentMonthNote
    }

    private var monthlyHistoryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Past Months")
                .font(.subheadline)
                .fontWeight(.semibold)

            GeometryReader { proxy in
                let maxPercent = max(100, appState.monthlyHistory.map { BudgetProgressMetrics.percentUsedDouble(actual: $0.actual, planned: $0.planned) }.max() ?? 100)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(appState.monthlyHistory) { month in
                        let percent = BudgetProgressMetrics.percentUsedDouble(actual: month.actual, planned: month.planned)
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

    /// Free-form note for the currently selected month. Persists immediately on edit via
    /// `onChange(of: monthlyNoteDraft)` (see `body`), and re-syncs when the month rolls over.
    /// Intentionally **not** a budgeting control — see file-level docs.
    private var monthlyNoteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monthly Note")
                .font(.subheadline)
                .fontWeight(.semibold)

            ZStack(alignment: .topLeading) {
                if monthlyNoteDraft.isEmpty {
                    Text("Add a note about this month…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $monthlyNoteDraft)
                    .font(.subheadline)
                    .frame(minHeight: 96)
                    .padding(.horizontal, 4)
                    .scrollContentBackground(.hidden)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            Text("Saved automatically for \(appState.currentTerm).")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Placeholder that replaces the old "Budget Goals" section. Budgeting now lives entirely
    /// on the Budget Plan tab; Profile is reserved for future account/app preferences (currency
    /// lives here today, more will follow). Monthly Note lives directly above this card.
    private var profileSettingsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Profile settings coming soon")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("Account, preferences, import/export, and security settings will live here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MonthDetailPopup: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let month: MonthlySummary

    private var percentUsed: Double {
        BudgetProgressMetrics.percentUsedDouble(actual: month.actual, planned: month.planned)
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
                .background(Color(.secondarySystemBackground))
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
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                monthlyExpenseBreakdown

                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
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
        .background(Color(.secondarySystemBackground))
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
    NavigationStack {
        ProfilePanelView()
            .environmentObject(AppState())
    }
}
