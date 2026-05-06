import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("First name", text: $appState.userFirstName)
                }

                Section("Budget Behavior") {
                    HStack {
                        Text("Monthly limit")
                        Spacer()
                        Text((appState.manualMonthlyLimit ?? appState.monthlySpendingBudget).formatted(appState.currencyFormatter))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Saved available")
                        Spacer()
                        Text(appState.availableSavedToUse.formatted(appState.currencyFormatter))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AppSettingsView()
        .environmentObject(AppState())
}
