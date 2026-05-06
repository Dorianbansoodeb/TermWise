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
                    }
                )
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.pie.fill")
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
