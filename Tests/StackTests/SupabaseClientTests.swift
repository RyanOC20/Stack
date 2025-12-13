import XCTest
@testable import Stack

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

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
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
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
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
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let body = """
            {"message":"bad","status":401}
            """.data(using: .utf8)!
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

    private func makeClient() -> SupabaseClient {
        SupabaseClient(configuration: configuration, urlSession: urlSession, sessionStore: sessionStore)
    }

    private func makeSession() -> SupabaseSession {
        SupabaseSession(accessToken: "access-token", refreshToken: "refresh-token", user: SupabaseUser(id: UUID(), email: "user@example.com"))
    }
}

private struct Payload: Codable {
    let value: String
}
