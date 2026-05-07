import Foundation

protocol AppStateDataStore {
    func loadSnapshot() -> PersistedState?
    func saveSnapshot(_ snapshot: PersistedState)
}

protocol RemoteSyncingAppStateDataStore: AppStateDataStore {
    func refreshFromRemote(apply: @escaping (PersistedState) -> Void)
}

struct LocalUserDefaultsAppStateDataStore: AppStateDataStore {
    private let storageKey: String

    init(storageKey: String = "termwise.appState.v1") {
        self.storageKey = storageKey
    }

    func loadSnapshot() -> PersistedState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        do {
            return try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            return nil
        }
    }

    func saveSnapshot(_ snapshot: PersistedState) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Intentionally ignore save failures for local fallback mode.
        }
    }
}

protocol RemoteAppStateClient {
    func fetchSnapshot(completion: @escaping (Result<PersistedState, Error>) -> Void)
    func pushSnapshot(_ snapshot: PersistedState, completion: @escaping (Result<Void, Error>) -> Void)
}

struct URLSessionRemoteAppStateClient: RemoteAppStateClient {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchSnapshot(completion: @escaping (Result<PersistedState, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("v1/app-state")
        let task = session.dataTask(with: url) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                let data
            else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            do {
                let snapshot = try JSONDecoder().decode(PersistedState.self, from: data)
                completion(.success(snapshot))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    func pushSnapshot(_ snapshot: PersistedState, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("v1/app-state")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(snapshot)
        } catch {
            completion(.failure(error))
            return
        }

        let task = session.dataTask(with: request) { _, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            completion(.success(()))
        }
        task.resume()
    }
}

final class CachedRemoteAppStateDataStore: RemoteSyncingAppStateDataStore {
    private let localStore: AppStateDataStore
    private let remoteClient: RemoteAppStateClient

    init(localStore: AppStateDataStore = LocalUserDefaultsAppStateDataStore(), remoteClient: RemoteAppStateClient) {
        self.localStore = localStore
        self.remoteClient = remoteClient
    }

    func loadSnapshot() -> PersistedState? {
        localStore.loadSnapshot()
    }

    func saveSnapshot(_ snapshot: PersistedState) {
        localStore.saveSnapshot(snapshot)
        remoteClient.pushSnapshot(snapshot) { _ in
            // Keep local UX resilient even if network sync fails.
        }
    }

    func refreshFromRemote(apply: @escaping (PersistedState) -> Void) {
        remoteClient.fetchSnapshot { [localStore] result in
            guard case .success(let snapshot) = result else { return }
            localStore.saveSnapshot(snapshot)
            DispatchQueue.main.async {
                apply(snapshot)
            }
        }
    }
}
