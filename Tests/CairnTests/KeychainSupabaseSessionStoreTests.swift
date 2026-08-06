@testable import Cairn
import XCTest

final class KeychainSupabaseSessionStoreTests: XCTestCase {
    private func makeSession(accessToken: String = "access-token") -> SupabaseSession {
        SupabaseSession(
            accessToken: accessToken,
            refreshToken: "refresh-token",
            user: SupabaseUser(id: UUID(), email: "user@example.com")
        )
    }

    func testSaveThenLoadRoundTrips() {
        let store = KeychainSupabaseSessionStore(account: "acct", backend: InMemoryKeychainBackend())
        let session = makeSession()

        store.save(session)
        let loaded = store.loadSession()

        XCTAssertEqual(loaded?.accessToken, session.accessToken)
        XCTAssertEqual(loaded?.user.id, session.user.id)
    }

    func testClearRemovesSession() {
        let store = KeychainSupabaseSessionStore(account: "acct", backend: InMemoryKeychainBackend())
        store.save(makeSession())

        store.clear()

        XCTAssertNil(store.loadSession())
    }

    func testMigratesLegacySessionOnFirstLoad() {
        let backend = InMemoryKeychainBackend()
        let legacy = InMemorySessionStore(storedSession: makeSession(accessToken: "legacy-access"))
        let store = KeychainSupabaseSessionStore(account: "acct", backend: backend, legacyStore: legacy)

        let loaded = store.loadSession()

        // Returned the migrated session…
        XCTAssertEqual(loaded?.accessToken, "legacy-access")
        // …persisted it into the Keychain backend…
        XCTAssertNotNil(backend.read(service: "com.cairn.app.supabase-session", account: "acct"))
        // …and cleared the legacy store so migration only happens once.
        XCTAssertNil(legacy.loadSession())
    }

    func testAccountsAreIsolated() {
        let backend = InMemoryKeychainBackend()
        let storeA = KeychainSupabaseSessionStore(account: "a", backend: backend)
        let storeB = KeychainSupabaseSessionStore(account: "b", backend: backend)

        storeA.save(makeSession(accessToken: "a-token"))

        XCTAssertEqual(storeA.loadSession()?.accessToken, "a-token")
        XCTAssertNil(storeB.loadSession())
    }
}

/// In-memory stand-in for the real Keychain, keyed by service+account.
private final class InMemoryKeychainBackend: KeychainBackend {
    private var storage: [String: Data] = [:]

    private func key(_ service: String, _ account: String) -> String {
        "\(service)\u{0}\(account)"
    }

    func read(service: String, account: String) -> Data? {
        storage[key(service, account)]
    }

    func write(_ data: Data, service: String, account: String) {
        storage[key(service, account)] = data
    }

    func delete(service: String, account: String) {
        storage[key(service, account)] = nil
    }
}
