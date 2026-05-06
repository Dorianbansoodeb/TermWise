import SwiftUI

struct BudgetPlanView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("Monthly Budget Plan") {
                ForEach(appState.budgetItems) { item in
                    let actual = appState.actualAmount(for: item.category)
                    VStack(alignment: .leading, spacing: 8) {
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
                            Text(item.planned, format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Actual")
                            Spacer()
                            Text(actual, format: .currency(code: "USD"))
                                .foregroundStyle(actual > item.planned ? .red : .primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Budget Plan")
    }
}

#Preview {
    NavigationStack {
        BudgetPlanView()
            .environmentObject(AppState())
    }
}
