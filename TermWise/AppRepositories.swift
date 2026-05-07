import Foundation

protocol BudgetRepository {
    func loadBudgetItems() -> [BudgetItem]?
    func saveBudgetItems(_ items: [BudgetItem])
}

protocol TransactionRepository {
    func loadTransactions() -> [TransactionItem]?
    func saveTransactions(_ items: [TransactionItem])
}

protocol AppRepository: BudgetRepository, TransactionRepository {
    func loadSnapshot() -> PersistedState?
    func saveSnapshot(_ snapshot: PersistedState)
}

protocol RemoteSyncingAppRepository: AppRepository {
    func refreshFromRemote(apply: @escaping (PersistedState) -> Void)
}

final class SnapshotAppRepository: AppRepository {
    private let dataStore: AppStateDataStore

    init(dataStore: AppStateDataStore = LocalUserDefaultsAppStateDataStore()) {
        self.dataStore = dataStore
    }

    func loadBudgetItems() -> [BudgetItem]? {
        loadSnapshot()?.budgetItems
    }

    func saveBudgetItems(_ items: [BudgetItem]) {
        guard var snapshot = loadSnapshot() else { return }
        snapshot = PersistedState(
            onboarding: snapshot.onboarding,
            manualMonthlyLimit: snapshot.manualMonthlyLimit,
            desiredSavingsRate: snapshot.desiredSavingsRate,
            bonusIncomeForMonth: snapshot.bonusIncomeForMonth,
            currencyCode: snapshot.currencyCode,
            billReminders: snapshot.billReminders,
            weeklyNotes: snapshot.weeklyNotes,
            pinnedTransactionIds: snapshot.pinnedTransactionIds,
            monthlyNotes: snapshot.monthlyNotes,
            hiddenBudgetItemIdsByMonth: snapshot.hiddenBudgetItemIdsByMonth,
            fixedBillActualOverridesByMonth: snapshot.fixedBillActualOverridesByMonth,
            fixedBillPaymentTransactionIdsByMonth: snapshot.fixedBillPaymentTransactionIdsByMonth,
            budgetItems: items,
            transactions: snapshot.transactions
        )
        saveSnapshot(snapshot)
    }

    func loadTransactions() -> [TransactionItem]? {
        loadSnapshot()?.transactions
    }

    func saveTransactions(_ items: [TransactionItem]) {
        guard var snapshot = loadSnapshot() else { return }
        snapshot = PersistedState(
            onboarding: snapshot.onboarding,
            manualMonthlyLimit: snapshot.manualMonthlyLimit,
            desiredSavingsRate: snapshot.desiredSavingsRate,
            bonusIncomeForMonth: snapshot.bonusIncomeForMonth,
            currencyCode: snapshot.currencyCode,
            billReminders: snapshot.billReminders,
            weeklyNotes: snapshot.weeklyNotes,
            pinnedTransactionIds: snapshot.pinnedTransactionIds,
            monthlyNotes: snapshot.monthlyNotes,
            hiddenBudgetItemIdsByMonth: snapshot.hiddenBudgetItemIdsByMonth,
            fixedBillActualOverridesByMonth: snapshot.fixedBillActualOverridesByMonth,
            fixedBillPaymentTransactionIdsByMonth: snapshot.fixedBillPaymentTransactionIdsByMonth,
            budgetItems: snapshot.budgetItems,
            transactions: items
        )
        saveSnapshot(snapshot)
    }

    func loadSnapshot() -> PersistedState? {
        dataStore.loadSnapshot()
    }

    func saveSnapshot(_ snapshot: PersistedState) {
        dataStore.saveSnapshot(snapshot)
    }
}
