import SwiftUI

struct BudgetPlanView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var focusedCategoryId: UUID?

    var body: some View {
        List {
            Section("This Month") {
                HStack {
                    Text("Planned Total")
                    Spacer()
                    Text(appState.totalPlannedSpend.formatted(.currency(code: "USD")))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Actual Spend")
                    Spacer()
                    Text(appState.totalActualSpend.formatted(.currency(code: "USD")))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Delta")
                    Spacer()
                    Text((appState.totalPlannedSpend - appState.totalActualSpend).formatted(.currency(code: "USD")))
                        .foregroundStyle(appState.totalActualSpend > appState.totalPlannedSpend ? .red : .green)
                        .fontWeight(.semibold)
                }
            }

            Section("Monthly Budget Plan (Editable)") {
                ForEach($appState.budgetItems) { $item in
                    let actual = appState.actualAmount(for: item.category)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(item.category)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(actual > item.planned ? "Over" : "On Track")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((actual > item.planned ? Color.red : Color.green).opacity(0.15))
                                .clipShape(Capsule())
                        }

                        HStack {
                            Text("Planned")
                            Spacer()
                            TextField("0", value: $item.planned, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .focused($focusedCategoryId, equals: item.id)
                        }

                        HStack {
                            Text("Actual")
                            Spacer()
                            Text(actual.formatted(.currency(code: "USD")))
                                .foregroundStyle(actual > item.planned ? .red : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Budget Plan")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedCategoryId = nil }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BudgetPlanView()
            .environmentObject(AppState())
    }
}
