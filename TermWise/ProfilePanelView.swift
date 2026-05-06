import SwiftUI

struct ProfilePanelView: View {
    @EnvironmentObject private var appState: AppState

    @State private var savingsSlider: Double = 0

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

            currencySection
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            savingsSlider = appState.desiredSavingsRate
        }
    }

    private var monthlyHistoryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Past Months")
                .font(.subheadline)
                .fontWeight(.semibold)

            GeometryReader { proxy in
                let maxMagnitude = max(1, appState.monthlyHistory.map { abs($0.saved) }.max() ?? 1)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(appState.monthlyHistory) { month in
                        let height = CGFloat(abs(month.saved) / maxMagnitude) * (proxy.size.height - 20)
                        VStack {
                            ZStack(alignment: .bottom) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 20, height: proxy.size.height - 20)
                                Capsule()
                                    .fill(month.isOver ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                                    .frame(width: 20, height: height)
                            }
                            Text(month.monthLabel)
                                .font(.caption2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 120)

            Text("Green = under budget, Red = over. Saved shows how much you were under or over your plan.")
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
}

#Preview {
    ProfilePanelView()
        .environmentObject(AppState())
}
