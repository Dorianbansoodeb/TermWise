import SwiftUI

struct OnboardingView: View {
    let onContinue: (OnboardingData) -> Void

    @State private var currentTerm: String = "Fall 2026"
    @State private var monthlyIncome: String = "3200"
    @State private var expectedCoopIncome: String = "0"
    @State private var tuitionGoal: String = "4300"
    @State private var monthlyBudget: String = "1480"

    var body: some View {
        NavigationStack {
            Form {
                Section("Term Setup") {
                    TextField("Current school term", text: $currentTerm)
                }

                Section("Income") {
                    TextField("Monthly income", text: $monthlyIncome)
                        .keyboardType(.decimalPad)
                    TextField("Expected co-op income", text: $expectedCoopIncome)
                        .keyboardType(.decimalPad)
                }

                Section("Goals") {
                    TextField("Tuition goal / savings goal", text: $tuitionGoal)
                        .keyboardType(.decimalPad)
                    TextField("Monthly spending budget", text: $monthlyBudget)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button("Continue") {
                        let data = OnboardingData(
                            currentTerm: currentTerm.isEmpty ? "Current Term" : currentTerm,
                            monthlyIncome: Double(monthlyIncome) ?? 0,
                            expectedCoopIncome: Double(expectedCoopIncome) ?? 0,
                            tuitionGoal: Double(tuitionGoal) ?? 0,
                            monthlySpendingBudget: Double(monthlyBudget) ?? 0
                        )
                        onContinue(data)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Onboarding")
        }
    }
}

#Preview {
    OnboardingView(onContinue: { _ in })
}
