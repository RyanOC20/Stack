@testable import Cairn
import XCTest

final class SupabaseClientTests: XCTestCase {
    private var sessionStore: InMemorySessionStore!
    private var urlSession: URLSession!
    private var configuration: SupabaseClient.Configuration!

    override func setUp() {
        super.setUp()
        sessionStore = InMemorySessionStore()
        urlSession = makeMockURLSession()
        configuration = SupabaseClient.Configuration(url: URL(string: "https://example.supabase.co")!, anonKey: "anon-key")
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testMakeRequestRequiresSessionWhenAuthNeeded() {
        let client = makeClient()
        XCTAssertThrowsError(try client.makeRequest(path: "/rest/v1/assignments")) { error in
            guard case SupabaseClient.ClientError.missingSession = error else {
                return XCTFail("Expected missingSession, got \(error)")
            }
        }
    }

    func testMakeRequestBuildsHeadersWithSession() throws {
        let client = makeClient()
        client.setSession(makeSession())
        let body = Data("{}".utf8)

        let request = try client.makeRequest(
            path: "/rest/v1/assignments",
            method: "POST",
            queryItems: [URLQueryItem(name: "order", value: "due_at")],
            body: body,
            preferHeader: "return=representation"
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation")

        let components = try URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.path, "/rest/v1/assignments")
        XCTAssertTrue(components?.queryItems?.contains(where: { $0.name == "order" && $0.value == "due_at" }) == true)
    }

    func testMakeRequestUsesAnonKeyWhenAuthNotRequired() throws {
        let client = makeClient()

        let request = try client.makeRequest(path: "/auth/v1/signup", requiresAuth: false)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer anon-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-key")
    }

    func testPerformDecodesSuccessfulResponse() async throws {
        let client = makeClient()
        MockURLProtocol.requestHandler = { request in
            let response = makeHTTPResponse(for: request, statusCode: 200)
            let body = try JSONEncoder().encode(Payload(value: "ok"))
            return (response, body)
        }

        let request = URLRequest(url: configuration.url)
        let payload: Payload = try await client.perform(request, decoder: JSONDecoder())
        XCTAssertEqual(payload.value, "ok")
    }

    func testPerformMapsSupabaseErrorResponse() async {
        let client = makeClient()
        MockURLProtocol.requestHandler = { request in
            let response = makeHTTPResponse(for: request, statusCode: 401)
            let body = Data("""
            {"message":"bad","status":401}
            """.utf8)
            return (response, body)
        }

        let request = URLRequest(url: configuration.url)
        do {
            let _: Payload = try await client.perform(request, decoder: JSONDecoder())
            XCTFail("Expected SupabaseErrorResponse")
        } catch let error as SupabaseErrorResponse {
            XCTAssertEqual(error.message, "bad")
            XCTAssertEqual(error.status, 401)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testPerformRefreshesExpiredAccessTokenAndRetries() async throws {
        let client = makeClient()
        client.setSession(makeSession())
        let refreshedUserID = UUID()

        MockURLProtocol.requestHandler = { request in
            let authorization = request.value(forHTTPHeaderField: "Authorization")
            if request.url?.path == "/auth/v1/token" {
                let body = Data("""
                {
                  "access_token": "new-access",
                  "refresh_token": "new-refresh",
                  "user": { "id": "\(refreshedUserID.uuidString)", "email": "user@example.com" }
                }
                """.utf8)
                return (makeHTTPResponse(for: request, statusCode: 200), body)
            }
            if authorization == "Bearer new-access" {
                let body = try JSONEncoder().encode(Payload(value: "ok"))
                return (makeHTTPResponse(for: request, statusCode: 200), body)
            }
            // Stale access token.
            return (makeHTTPResponse(for: request, statusCode: 401), Data(#"{"message":"expired","status":401}"#.utf8))
        }

        let request = try client.makeRequest(path: "/rest/v1/assignments")
        let payload: Payload = try await client.perform(request, decoder: JSONDecoder())

        XCTAssertEqual(payload.value, "ok")
        // The refreshed session (new user + rotated tokens) is now the active one.
        XCTAssertEqual(client.currentUserID, refreshedUserID)
    }

    func testPerformSurfacesOriginalErrorWhenRefreshFails() async throws {
        let client = makeClient()
        client.setSession(makeSession())

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/auth/v1/token" {
                return (makeHTTPResponse(for: request, statusCode: 401), Data(#"{"message":"invalid refresh token"}"#.utf8))
            }
            return (makeHTTPResponse(for: request, statusCode: 401), Data(#"{"message":"expired","status":401}"#.utf8))
        }

        let request = try client.makeRequest(path: "/rest/v1/assignments")
        do {
            let _: Payload = try await client.perform(request, decoder: JSONDecoder())
            XCTFail("Expected SupabaseErrorResponse")
        } catch let error as SupabaseErrorResponse {
            XCTAssertEqual(error.status, 401)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    private func makeClient() -> SupabaseClient {
        SupabaseClient(configuration: configuration, urlSession: urlSession, sessionStore: sessionStore)
    }

    private func makeSession() -> SupabaseSession {
        SupabaseSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            user: SupabaseUser(id: UUID(), email: "user@example.com")
        )
    }
}

private struct Payload: Codable {
    let value: String
}
