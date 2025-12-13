import XCTest
@testable import Stack

final class SupabaseAuthServiceTests: XCTestCase {
    private var client: SupabaseClient!
    private var sessionStore: InMemorySessionStore!
    private var service: SupabaseAuthService!

    override func setUp() {
        super.setUp()
        sessionStore = InMemorySessionStore()
        let configuration = SupabaseClient.Configuration(
            url: URL(string: "https://example.supabase.co")!,
            anonKey: "anon-key"
        )
        client = SupabaseClient(configuration: configuration, urlSession: makeMockURLSession(), sessionStore: sessionStore)
        service = SupabaseAuthService(client: client)
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
        sessionStore = nil
        service = nil
        super.tearDown()
    }

    func testSignUpSetsSession() async throws {
        let handled = expectation(description: "handled sign up")
        let userID = UUID()

        MockURLProtocol.requestHandler = { request in
            handled.fulfill()
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/auth/v1/signup")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer anon-key")

            guard let body = httpBodyData(from: request) else {
                XCTFail("Missing sign up body")
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let responseBody = Data("{}".utf8)
                return (response, responseBody)
            }

            let json = try JSONSerialization.jsonObject(with: body) as? [String: String]
            XCTAssertEqual(json?["email"], "user@example.com")
            XCTAssertEqual(json?["password"], "password")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let responseBody = """
            {"access_token":"token","refresh_token":"refresh","user":{"id":"\(userID.uuidString)","email":"user@example.com"}}
            """.data(using: .utf8)!
            return (response, responseBody)
        }

        let session = try await service.signUp(email: "user@example.com", password: "password")
        await fulfillment(of: [handled], timeout: 1)

        XCTAssertEqual(session.accessToken, "token")
        XCTAssertEqual(client.currentUserID, userID)
        XCTAssertEqual(sessionStore.storedSession?.refreshToken, "refresh")
    }

    func testSignInRequiresTokens() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let responseBody = Data("{}".utf8)
            return (response, responseBody)
        }

        do {
            _ = try await service.signIn(email: "user@example.com", password: "password")
            XCTFail("Expected missing session error")
        } catch SupabaseClient.ClientError.missingSession {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testSignInUsesPasswordGrantQueryItem() async throws {
        let handled = expectation(description: "handled sign in")
        let userID = UUID()
        MockURLProtocol.requestHandler = { request in
            handled.fulfill()
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            XCTAssertTrue(components?.queryItems?.contains(where: { $0.name == "grant_type" && $0.value == "password" }) == true)

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let responseBody = """
            {"access_token":"access","refresh_token":"refresh","user":{"id":"\(userID.uuidString)","email":null}}
            """.data(using: .utf8)!
            return (response, responseBody)
        }

        _ = try await service.signIn(email: "user@example.com", password: "password")
        await fulfillment(of: [handled], timeout: 1)
        XCTAssertEqual(client.currentUserID, userID)
    }
}
