import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(
                    onQuickAddExpense: {
                        appState.draftTransactionType = .expense
                        selectedTab = .add
                    },
                    onQuickAddIncome: {
                        appState.draftTransactionType = .income
                        selectedTab = .add
                    },
                    onViewMoreTransactions: {
                        selectedTab = .transactions
                    }
                )
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.dashboard)

            NavigationStack {
                TransactionsView()
            }
            .tabItem {
                Label("Transactions", systemImage: "list.bullet.rectangle")
            }
            .tag(AppTab.transactions)

            NavigationStack {
                BudgetPlanView()
            }
            .tabItem {
                Label("Budget", systemImage: "wallet.pass.fill")
            }
            .tag(AppTab.budget)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(AppTab.profile)

            NavigationStack {
                AddTransactionView(defaultType: appState.draftTransactionType) {
                    selectedTab = .dashboard
                }
            }
            .tabItem {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .tag(AppTab.add)
        }
        .safeAreaInset(edge: .bottom) {
            if let undo = appState.pendingUndo {
                HStack {
                    Text(undo.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Undo") {
                        appState.performPendingUndo()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.thinMaterial)
            }
        }
    }
}

private enum AppTab {
    case dashboard
    case transactions
    case budget
    case profile
    case add
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
