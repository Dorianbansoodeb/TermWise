import SwiftUI

struct BudgetPlanView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var focusedCategoryId: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard
                tuitionSavingsCard

                ForEach($appState.budgetItems) { $item in
                    budgetCategoryCard(item: $item)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Budget Plan")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                AppOverflowMenu()
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedCategoryId = nil }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Monthly Snapshot")
                .font(.headline)
            metricRow("Planned Total", appState.totalPlannedSpend)
            metricRow("Actual Spend", appState.totalActualSpend)
            metricRow("Delta", appState.totalPlannedSpend - appState.totalActualSpend, emphasize: true)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var tuitionSavingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tuition/Savings Goal")
                .font(.headline)
            Text("Goal: \(appState.tuitionGoal.formatted(appState.currencyFormatter))")
                .font(.subheadline)
            Text("Projected monthly savings: \(appState.projectedSavingsThisMonth.formatted(appState.currencyFormatter))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func budgetCategoryCard(item: Binding<BudgetItem>) -> some View {
        let actual = appState.actualAmount(for: item.wrappedValue.category)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.wrappedValue.category)
                    .font(.headline)
                Spacer()
                Text(actual > item.wrappedValue.planned ? "Over" : "On Track")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((actual > item.wrappedValue.planned ? Color.red : Color.green).opacity(0.15))
                    .clipShape(Capsule())
            }

            ProgressView(value: actual, total: max(1, item.wrappedValue.planned))
                .tint(actual > item.wrappedValue.planned ? .red : .blue)

            HStack {
                Text("Planned")
                Spacer()
                TextField("0", value: item.planned, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedCategoryId, equals: item.wrappedValue.id)
            }

            HStack {
                Text("Actual")
                Spacer()
                Text(actual.formatted(appState.currencyFormatter))
                    .foregroundStyle(actual > item.wrappedValue.planned ? .red : .secondary)
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func metricRow(_ label: String, _ value: Double, emphasize: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.formatted(appState.currencyFormatter))
                .foregroundStyle(emphasize ? (value < 0 ? .red : .green) : .secondary)
                .fontWeight(emphasize ? .semibold : .regular)
        }
    }
}

#Preview {
    NavigationStack {
        BudgetPlanView()
            .environmentObject(AppState())
    }
}
