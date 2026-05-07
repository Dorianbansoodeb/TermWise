import Foundation

/// Reads and writes domain models via `PersistedStateDTO` / nested DTOs (snake_case JSON contract).
/// Wire `OfflineFirstRemoteSyncingAppRepository` in front of this type for cache + API.
final class APIAppRepository: AppRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func loadBudgetItems() -> [BudgetItem]? {
        do {
            // TODO: Confirm backend contract for GET /api/budgets response shape.
            let dtos = try client.get("api/budgets", responseType: [BudgetItemDTO].self)
            return dtos.map { $0.toDomain() }
        } catch {
            return nil
        }
    }

    func saveBudgetItems(_ items: [BudgetItem]) {
        let payload = items.map { $0.toDTO() }
        // TODO: Confirm backend contract for PUT /api/budgets request/response.
        _ = try? client.put("api/budgets", body: payload, responseType: EmptyAPIResponse.self)
    }

    func loadTransactions() -> [TransactionItem]? {
        do {
            // TODO: Confirm backend contract for GET /api/transactions response shape.
            let dtos = try client.get("api/transactions", responseType: [TransactionItemDTO].self)
            return dtos.map { $0.toDomain() }
        } catch {
            return nil
        }
    }

    func saveTransactions(_ items: [TransactionItem]) {
        let payload = items.map { $0.toDTO() }
        // TODO: Confirm backend contract for PUT /api/transactions request/response.
        _ = try? client.put("api/transactions", body: payload, responseType: EmptyAPIResponse.self)
    }

    func loadSnapshot() -> PersistedState? {
        do {
            // TODO: Confirm backend contract for GET /api/snapshot response shape.
            let dto = try client.get("api/snapshot", responseType: PersistedStateDTO.self)
            return dto.toDomain()
        } catch {
            return nil
        }
    }

    func saveSnapshot(_ snapshot: PersistedState) {
        // TODO: Confirm backend contract for PUT /api/snapshot request/response.
        _ = try? client.put("api/snapshot", body: snapshot.toDTO(), responseType: EmptyAPIResponse.self)
    }
}

/// **Offline-first:** reads always from `localRepository` (fast cache); writes update cache then API when `syncOnSave`.
/// **Remote refresh:** `refreshFromRemote` replaces cache from `apiRepository` then applies on the main thread.
final class OfflineFirstRemoteSyncingAppRepository: RemoteSyncingAppRepository {
    private let localRepository: AppRepository
    private let apiRepository: AppRepository
    private let syncOnSave: Bool

    init(localRepository: AppRepository, apiRepository: AppRepository, syncOnSave: Bool = true) {
        self.localRepository = localRepository
        self.apiRepository = apiRepository
        self.syncOnSave = syncOnSave
    }

    func loadBudgetItems() -> [BudgetItem]? {
        localRepository.loadBudgetItems()
    }

    func saveBudgetItems(_ items: [BudgetItem]) {
        localRepository.saveBudgetItems(items)
        if syncOnSave { apiRepository.saveBudgetItems(items) }
    }

    func loadTransactions() -> [TransactionItem]? {
        localRepository.loadTransactions()
    }

    func saveTransactions(_ items: [TransactionItem]) {
        localRepository.saveTransactions(items)
        if syncOnSave { apiRepository.saveTransactions(items) }
    }

    func loadSnapshot() -> PersistedState? {
        localRepository.loadSnapshot()
    }

    func saveSnapshot(_ snapshot: PersistedState) {
        localRepository.saveSnapshot(snapshot)
        if syncOnSave { apiRepository.saveSnapshot(snapshot) }
    }

    func refreshFromRemote(apply: @escaping (PersistedState) -> Void) {
        DispatchQueue.global(qos: .utility).async { [localRepository, apiRepository] in
            guard let snapshot = apiRepository.loadSnapshot() else { return }
            localRepository.saveSnapshot(snapshot)
            DispatchQueue.main.async {
                apply(snapshot)
            }
        }
    }
}
