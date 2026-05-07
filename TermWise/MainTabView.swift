import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var showAddTransactionSheet = false
    @EnvironmentObject private var appState: AppState

    private static let fabOrange = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
    private static let pillHeight: CGFloat = 64
    private static let fabSize: CGFloat = 64

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(
                    onQuickAddExpense: {
                        appState.draftTransactionType = .expense
                        showAddTransactionSheet = true
                    },
                    onQuickAddIncome: {
                        appState.draftTransactionType = .income
                        showAddTransactionSheet = true
                    },
                    onViewMoreTransactions: {
                        selectedTab = .transactions
                    }
                )
            }
            .toolbar(.hidden, for: .tabBar)
            .tag(AppTab.dashboard)

            NavigationStack {
                TransactionsView()
            }
            .toolbar(.hidden, for: .tabBar)
            .tag(AppTab.transactions)

            NavigationStack {
                BudgetPlanView()
            }
            .toolbar(.hidden, for: .tabBar)
            .tag(AppTab.budget)

            NavigationStack {
                ProfileView()
            }
            .toolbar(.hidden, for: .tabBar)
            .tag(AppTab.profile)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let toast = appState.fullyPaidBillToast {
                Text(toast)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.14))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.green.opacity(0.35))
                            .frame(height: 1)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.fullyPaidBillToast)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                }
                bottomNavRow
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showAddTransactionSheet) {
            NavigationStack {
                AddTransactionView(defaultType: appState.draftTransactionType) {
                    showAddTransactionSheet = false
                }
                .environmentObject(appState)
            }
        }
        .alert(
            "Add this income to your budget?",
            isPresented: Binding(
                get: { appState.pendingIncomePrompt != nil },
                set: { if !$0 { appState.dismissIncomePrompt() } }
            ),
            presenting: appState.pendingIncomePrompt
        ) { _ in
            Button("Add to Budget") {
                appState.confirmAddIncomeToBudget()
            }
            Button("Keep as Reserve") {
                appState.keepIncomeAsReserve()
            }
            Button("Cancel", role: .cancel) {
                appState.dismissIncomePrompt()
            }
        } message: { prompt in
            Text(incomePromptMessage(prompt))
        }
    }

    private func incomePromptMessage(_ prompt: PendingIncomePrompt) -> String {
        let amount = prompt.amount.formatted(appState.currencyFormatter)
        return "Add this \(amount) (\(prompt.categoryName)) to your Available to Budget? Choose Keep as Reserve to leave your budget unchanged."
    }

    private var bottomNavRow: some View {
        HStack(spacing: 12) {
            tabBarPill
            addTransactionFAB
        }
    }

    private var tabBarPill: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: Self.pillHeight)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Self.fabOrange : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: Self.pillHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var addTransactionFAB: some View {
        Button {
            appState.draftTransactionType = .expense
            showAddTransactionSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Self.fabSize, height: Self.fabSize)
                .background(Self.fabOrange)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add transaction")
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case budget
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .transactions: return "Transactions"
        case .budget: return "Budget"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .transactions: return "list.bullet.rectangle"
        case .budget: return "wallet.pass.fill"
        case .profile: return "person.crop.circle"
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
