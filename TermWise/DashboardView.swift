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
        .navigationTitle("Dashboard")
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
            Text("Plan vs. Reality")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(appState.currentTerm)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                metricCard(title: "Balance", value: appState.monthlyBalance, color: .blue)
                metricCard(title: "Actual Spend", value: appState.totalActualSpend, color: .orange)
            }

            HStack(spacing: 12) {
                metricCard(title: "Planned Spend", value: appState.totalPlannedSpend, color: .indigo)
                metricCard(title: "Delta", value: appState.totalPlannedSpend - appState.totalActualSpend, color: .green)
            }

            HStack(spacing: 12) {
                Button("Quick Add Expense", action: onQuickAddExpense)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("Quick Add Income", action: onQuickAddIncome)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Awareness")
                    .font(.headline)
                ForEach(appState.awarenessMessages, id: \.self) { message in
                    infoChip(text: message)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Category Progress")
                    .font(.headline)
                ForEach(appState.budgetItems) { item in
                    let spent = appState.actualAmount(for: item.category)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.category)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(spent.formatted(appState.currencyFormatter)) / \(item.planned.formatted(appState.currencyFormatter))")
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: spent, total: item.planned == 0 ? 1 : item.planned)
                            .tint(spent > item.planned ? .red : .blue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricCard(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.formatted(appState.currencyFormatter))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func infoChip(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        DashboardView(onQuickAddExpense: {}, onQuickAddIncome: {})
            .environmentObject(AppState())
    }
}
