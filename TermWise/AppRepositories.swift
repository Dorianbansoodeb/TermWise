import Foundation

// MARK: - Repository boundaries
// `AppState` depends only on `AppRepository` — never on `UserDefaults` or URLSession directly.
// - **Remote / source of truth:** use `APIAppRepository` + `OfflineFirstRemoteSyncingAppRepository` so writes hit the API and local store acts as cache.
// - **Offline / previews:** use `LocalCacheAppRepository` backed by `AppStateDataStore` (disk cache until backend is wired).

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

/// Persists the full `PersistedState` through `AppStateDataStore` (typically `UserDefaults` as offline cache).
final class LocalCacheAppRepository: AppRepository {
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
            availableToBudgetByMonth: snapshot.availableToBudgetByMonth,
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
            availableToBudgetByMonth: snapshot.availableToBudgetByMonth,
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

/// Backward-compatible name; prefer `LocalCacheAppRepository` in new code.
typealias SnapshotAppRepository = LocalCacheAppRepository
