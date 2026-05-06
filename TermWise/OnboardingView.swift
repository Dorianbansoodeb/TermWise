import SwiftUI

struct OnboardingView: View {
    let onContinue: (OnboardingData) -> Void

    @State private var currentTerm: String = "Fall 2026"
    @State private var monthlyIncome: String = "3200"
    @State private var expectedCoopIncome: String = "0"
    @State private var tuitionGoal: String = "4300"
    @State private var monthlyBudget: String = "1480"
    @State private var rentBudget: String = "800"
    @State private var groceriesBudget: String = "260"
    @State private var transportBudget: String = "120"
    @State private var eatingOutBudget: String = "180"
    @State private var step: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Set up your term plan")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ProgressView(value: Double(step + 1), total: 4)
                    .padding(.horizontal)
                    .tint(.blue)

                Text("Step \(step + 1) of 4")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Group {
                    switch step {
                    case 0:
                        onboardingCard(
                            title: "Monthly Income",
                            subtitle: "How much do you usually bring in each month?"
                        ) {
                            TextField("Monthly income", text: $monthlyIncome)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    case 1:
                        onboardingCard(
                            title: "Tuition Goal",
                            subtitle: "Set your savings target for tuition."
                        ) {
                            TextField("Tuition goal", text: $tuitionGoal)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    case 2:
                        onboardingCard(
                            title: "Budget Categories",
                            subtitle: "Set category targets for your monthly plan."
                        ) {
                            categoryInput("Rent", value: $rentBudget)
                            categoryInput("Groceries", value: $groceriesBudget)
                            categoryInput("Transportation", value: $transportBudget)
                            categoryInput("Eating Out", value: $eatingOutBudget)
                            HStack {
                                Text("Monthly spending budget")
                                Spacer()
                                Text(estimatedBudgetTotal.formatted(.currency(code: "USD")))
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .padding(.top, 4)
                        }
                    default:
                        onboardingCard(
                            title: "Co-op Term Info",
                            subtitle: "Add your current term and expected co-op income."
                        ) {
                            TextField("Current school term", text: $currentTerm)
                                .textFieldStyle(.roundedBorder)
                            TextField("Expected co-op income", text: $expectedCoopIncome)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                HStack(spacing: 12) {
                    if step > 0 {
                        Button("Back") {
                            step -= 1
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(step == 3 ? "Continue" : "Next") {
                        if step < 3 {
                            if step == 2 {
                                monthlyBudget = String(estimatedBudgetTotal)
                            }
                            step += 1
                        } else {
                            let data = OnboardingData(
                                currentTerm: currentTerm.isEmpty ? "Current Term" : currentTerm,
                                monthlyIncome: Double(monthlyIncome) ?? 0,
                                expectedCoopIncome: Double(expectedCoopIncome) ?? 0,
                                tuitionGoal: Double(tuitionGoal) ?? 0,
                                monthlySpendingBudget: Double(monthlyBudget) ?? 0
                            )
                            onContinue(data)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Onboarding")
        }
    }

    private func onboardingCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var estimatedBudgetTotal: Double {
        (Double(rentBudget) ?? 0) +
        (Double(groceriesBudget) ?? 0) +
        (Double(transportBudget) ?? 0) +
        (Double(eatingOutBudget) ?? 0)
    }

    private func categoryInput(_ label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
                .textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    OnboardingView(onContinue: { _ in })
}
