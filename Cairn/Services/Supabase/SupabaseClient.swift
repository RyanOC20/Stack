import Foundation
import Security

struct SupabaseUser: Codable {
    let id: UUID
    let email: String?
}

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let user: SupabaseUser

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseErrorResponse: Decodable, Error {
    let message: String?
    let error: String?
    let errorDescription: String?
    let status: Int?
    let rawBody: String?

    init(message: String?, error: String?, errorDescription: String? = nil, status: Int?, rawBody: String? = nil) {
        self.message = message
        self.error = error
        self.errorDescription = errorDescription
        self.status = status
        self.rawBody = rawBody
    }

    private enum CodingKeys: String, CodingKey {
        case message
        case error
        case errorDescription = "error_description"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let message = try container.decodeIfPresent(String.self, forKey: .message)
        let error = try container.decodeIfPresent(String.self, forKey: .error)
        let errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
        let status = try container.decodeIfPresent(Int.self, forKey: .status)
        self.init(message: message, error: error, errorDescription: errorDescription, status: status)
    }
}

final class SupabaseClient {
    struct Configuration {
        let url: URL
        let anonKey: String
    }

    enum ClientError: Error {
        case missingSession
        case invalidResponse
    }

    let configuration: Configuration
    private let urlSession: URLSession
    private let sessionStore: SupabaseSessionStore
    private let lock = NSLock()
    private var session: SupabaseSession?
    /// Coalesces concurrent 401s into a single in-flight token refresh.
    private var refreshTask: Task<SupabaseSession, Error>?

    init(configuration: Configuration,
         urlSession: URLSession = .shared,
         sessionStore: SupabaseSessionStore? = nil)
    {
        self.configuration = configuration
        self.urlSession = urlSession
        self.sessionStore = sessionStore ?? Self.makeDefaultSessionStore(for: configuration.url.absoluteString)
        session = self.sessionStore.loadSession()
    }

    var currentUserID: UUID? {
        currentSession()?.user.id
    }

    var currentUserEmail: String? {
        currentSession()?.user.email
    }

    private func currentSession() -> SupabaseSession? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }

    func setSession(_ session: SupabaseSession) {
        lock.lock()
        self.session = session
        lock.unlock()
        sessionStore.save(session)
    }

    func clearSession() {
        lock.lock()
        session = nil
        refreshTask?.cancel()
        refreshTask = nil
        lock.unlock()
        sessionStore.clear()
    }

    func makeRequest(path: String,
                     method: String = "GET",
                     queryItems: [URLQueryItem] = [],
                     body: Data? = nil,
                     preferHeader: String? = nil,
                     requiresAuth: Bool = true) throws -> URLRequest
    {
        guard var components = URLComponents(url: configuration.url, resolvingAgainstBaseURL: false) else {
            throw ClientError.invalidResponse
        }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw ClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        if let preferHeader {
            request.setValue(preferHeader, forHTTPHeaderField: "Prefer")
        }
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if requiresAuth {
            guard let accessToken = currentSession()?.accessToken else {
                throw ClientError.missingSession
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    func perform<T: Decodable>(_ request: URLRequest, decoder: JSONDecoder) async throws -> T {
        let (data, httpResponse) = try await sendWithRefresh(request)

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8)
            if let mappedError = try? decoder.decode(SupabaseErrorResponse.self, from: data) {
                throw SupabaseErrorResponse(
                    message: mappedError.message,
                    error: mappedError.error,
                    errorDescription: mappedError.errorDescription,
                    status: mappedError.status ?? httpResponse.statusCode,
                    rawBody: bodyString
                )
            }
            throw SupabaseErrorResponse(
                message: nil,
                error: bodyString,
                errorDescription: nil,
                status: httpResponse.statusCode,
                rawBody: bodyString
            )
        }

        return try decoder.decode(T.self, from: data)
    }

    func performVoid(_ request: URLRequest) async throws {
        let (data, httpResponse) = try await sendWithRefresh(request)

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if let mappedError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                throw mappedError
            }
            throw ClientError.invalidResponse
        }
    }

    /// Revokes the current session server-side (best effort). Callers still clear locally.
    func revokeSession() async throws {
        let request = try makeRequest(path: "/auth/v1/logout", method: "POST")
        try await performVoid(request)
    }

    /// Sends a request and, on a 401 for a session-authenticated request, refreshes the
    /// access token once and replays the request. Non-auth (anon) requests are never refreshed,
    /// which also prevents the refresh call itself from recursing.
    private func sendWithRefresh(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, httpResponse) = try await send(request)
        guard httpResponse.statusCode == 401, canRefresh(for: request) else {
            return (data, httpResponse)
        }

        let refreshed: SupabaseSession
        do {
            refreshed = try await coalescedRefresh()
        } catch {
            // Refresh failed (e.g. refresh token revoked); surface the original 401.
            return (data, httpResponse)
        }

        var retried = request
        retried.setValue("Bearer \(refreshed.accessToken)", forHTTPHeaderField: "Authorization")
        return try await send(retried)
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await send(request, attemptsRemaining: Self.maxRetries)
    }

    /// One bounded retry with a short backoff on transient network failures and 5xx responses.
    /// All requests here are idempotent (GET / upsert-on-conflict / delete-by-id / auth grants),
    /// so replaying a request that may have partially applied is safe.
    private func send(_ request: URLRequest, attemptsRemaining: Int) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClientError.invalidResponse
            }
            if httpResponse.statusCode >= 500, attemptsRemaining > 0 {
                try await Task.sleep(nanoseconds: Self.retryBackoffNanoseconds)
                return try await send(request, attemptsRemaining: attemptsRemaining - 1)
            }
            return (data, httpResponse)
        } catch let error as URLError where attemptsRemaining > 0 && Self.isTransient(error) {
            try await Task.sleep(nanoseconds: Self.retryBackoffNanoseconds)
            return try await send(request, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private static let maxRetries = 1
    private static let retryBackoffNanoseconds: UInt64 = 300_000_000

    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            true
        default:
            false
        }
    }

    private func canRefresh(for request: URLRequest) -> Bool {
        guard let session = currentSession(), !session.refreshToken.isEmpty else { return false }
        return request.value(forHTTPHeaderField: "Authorization") == "Bearer \(session.accessToken)"
    }

    private func coalescedRefresh() async throws -> SupabaseSession {
        try await refreshTaskHandle().value
    }

    /// Synchronous so the `NSLock` isn't touched from an async context (Swift 6 requirement).
    private func refreshTaskHandle() -> Task<SupabaseSession, Error> {
        lock.lock()
        defer { lock.unlock() }
        if let existing = refreshTask {
            return existing
        }
        let newTask = Task { [weak self] () throws -> SupabaseSession in
            guard let self else { throw ClientError.missingSession }
            defer { self.clearRefreshTask() }
            return try await self.performRefresh()
        }
        refreshTask = newTask
        return newTask
    }

    private func clearRefreshTask() {
        lock.lock()
        refreshTask = nil
        lock.unlock()
    }

    private func performRefresh() async throws -> SupabaseSession {
        guard let refreshToken = currentSession()?.refreshToken, !refreshToken.isEmpty else {
            throw ClientError.missingSession
        }

        let body = try JSONEncoder().encode(["refresh_token": refreshToken])
        let request = try makeRequest(
            path: "/auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: body,
            requiresAuth: false
        )

        let (data, httpResponse) = try await send(request)
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8)
            throw SupabaseErrorResponse(message: nil, error: bodyString, status: httpResponse.statusCode, rawBody: bodyString)
        }

        let decoded = try JSONDecoder().decode(RefreshResponse.self, from: data)
        // GoTrue may omit the user on a refresh grant; retain the existing one when it does.
        let user = decoded.user ?? currentSession()?.user
        guard let accessToken = decoded.accessToken,
              let newRefreshToken = decoded.refreshToken,
              let user
        else {
            throw ClientError.missingSession
        }

        let refreshed = SupabaseSession(accessToken: accessToken, refreshToken: newRefreshToken, user: user)
        setSession(refreshed)
        return refreshed
    }

    private static func makeSessionStorageKey(for urlString: String) -> String {
        "SupabaseSession-\(urlString)"
    }

    private static func makeDefaultSessionStore(for urlString: String) -> SupabaseSessionStore {
        let key = makeSessionStorageKey(for: urlString)
        // Migrate any pre-existing plaintext UserDefaults session into the Keychain on first load.
        return KeychainSupabaseSessionStore(
            account: key,
            legacyStore: UserDefaultsSupabaseSessionStore(storageKey: key)
        )
    }

    private struct RefreshResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let user: SupabaseUser?

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user
        }
    }
}

protocol SupabaseSessionStore {
    func loadSession() -> SupabaseSession?
    func save(_ session: SupabaseSession)
    func clear()
}

struct UserDefaultsSupabaseSessionStore: SupabaseSessionStore {
    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard,
         storageKey: String,
         encoder: JSONEncoder = JSONEncoder(),
         decoder: JSONDecoder = JSONDecoder())
    {
        self.defaults = defaults
        self.storageKey = storageKey
        self.encoder = encoder
        self.decoder = decoder
    }

    func loadSession() -> SupabaseSession? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? decoder.decode(SupabaseSession.self, from: data)
    }

    func save(_ session: SupabaseSession) {
        guard let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}

/// Low-level Keychain access, isolated behind a protocol so the session store's logic
/// (encode/decode + migration) is testable without touching the real Keychain.
protocol KeychainBackend {
    func read(service: String, account: String) -> Data?
    func write(_ data: Data, service: String, account: String)
    func delete(service: String, account: String)
}

/// Keychain-backed session store. Access/refresh tokens are secrets, so they live in the
/// Keychain (device-only, after-first-unlock) rather than plaintext UserDefaults. On first
/// load it migrates any session left behind by a previous UserDefaults-backed build.
struct KeychainSupabaseSessionStore: SupabaseSessionStore {
    private let service: String
    private let account: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let backend: KeychainBackend
    private let legacyStore: SupabaseSessionStore?

    init(service: String = "com.cairn.app.supabase-session",
         account: String,
         encoder: JSONEncoder = JSONEncoder(),
         decoder: JSONDecoder = JSONDecoder(),
         backend: KeychainBackend = SystemKeychainBackend(),
         legacyStore: SupabaseSessionStore? = nil)
    {
        self.service = service
        self.account = account
        self.encoder = encoder
        self.decoder = decoder
        self.backend = backend
        self.legacyStore = legacyStore
    }

    func loadSession() -> SupabaseSession? {
        if let data = backend.read(service: service, account: account),
           let session = try? decoder.decode(SupabaseSession.self, from: data)
        {
            return session
        }
        // One-time migration from a legacy plaintext store.
        if let legacyStore, let migrated = legacyStore.loadSession() {
            save(migrated)
            legacyStore.clear()
            return migrated
        }
        return nil
    }

    func save(_ session: SupabaseSession) {
        guard let data = try? encoder.encode(session) else { return }
        backend.write(data, service: service, account: account)
    }

    func clear() {
        backend.delete(service: service, account: account)
    }
}

/// Real Keychain implementation using `Security`'s generic-password items.
struct SystemKeychainBackend: KeychainBackend {
    func read(service: String, account: String) -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    func write(_ data: Data, service: String, account: String) {
        let query = baseQuery(service: service, account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func delete(service: String, account: String) {
        SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
