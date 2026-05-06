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
            Text("Good morning, \(appState.userFirstName)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(appState.currentTerm)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            balanceCard
            planRealityCard
            quickActions
            spendingProgressCard
            insightCards
            recentTransactionsCard
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Balance")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(appState.monthlyBalance.formatted(appState.currencyFormatter))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Income \(appState.totalActualIncome.formatted(appState.currencyFormatter)) • Spend \(appState.totalActualSpend.formatted(appState.currencyFormatter))")
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

    private var planRealityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plan vs. Reality")
                .font(.headline)
            HStack {
                keyValue(label: "Planned", value: appState.totalPlannedSpend)
                Spacer()
                keyValue(label: "Actual", value: appState.totalActualSpend)
                Spacer()
                keyValue(label: "Delta", value: appState.totalPlannedSpend - appState.totalActualSpend)
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

#Preview {
    NavigationStack {
        DashboardView(onQuickAddExpense: {}, onQuickAddIncome: {})
            .environmentObject(AppState())
    }
}
