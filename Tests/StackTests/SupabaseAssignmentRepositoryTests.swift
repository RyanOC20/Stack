import XCTest
@testable import Stack

final class SupabaseAssignmentRepositoryTests: XCTestCase {
    private var client: SupabaseClient!
    private var logger: Logger!

    override func setUp() {
        super.setUp()
        let configuration = SupabaseClient.Configuration(
            url: URL(string: "https://example.supabase.co")!,
            anonKey: "anon-key"
        )
        let sessionStore = InMemorySessionStore(storedSession: SupabaseSession(
            accessToken: "access-token",
            refreshToken: "refresh",
            user: SupabaseUser(id: UUID(), email: "user@example.com")
        ))

        client = SupabaseClient(configuration: configuration, urlSession: makeMockURLSession(), sessionStore: sessionStore)
        logger = Logger()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
        logger = nil
        super.tearDown()
    }

    func testFetchAssignmentsDecodesAndSorts() async throws {
        let repository = makeRepository()
        let earliestID = UUID()
        let middleID = UUID()
        let latestID = UUID()
        let handled = expectation(description: "handled fetch")

        MockURLProtocol.requestHandler = { request in
            handled.fulfill()
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/rest/v1/assignments")
            let queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertTrue(queryItems?.contains(where: { $0.name == "order" && $0.value == "due_at" }) == true)

            let body = """
            [
              {
                "id": "\(middleID.uuidString)",
                "status": "In Progress",
                "name": "Beta",
                "course": "CS",
                "type": "Quiz",
                "due_at": "2024-05-02T10:00:00.123Z",
                "created_at": "2024-05-01T10:00:00Z",
                "updated_at": "2024-05-01T10:00:00Z"
              },
              {
                "id": "\(earliestID.uuidString)",
                "status": "Completed",
                "name": "Alpha",
                "course": "History",
                "type": "Exam",
                "due_at": "2024-05-01T09:00:00Z",
                "created_at": "2024-04-30T10:00:00Z",
                "updated_at": "2024-04-30T10:00:00Z"
              },
              {
                "id": "\(latestID.uuidString)",
                "status": "Not Started",
                "name": "Gamma",
                "course": "Math",
                "type": "Homework",
                "due_at": "2024-05-03T10:00:00+00:00",
                "created_at": "2024-05-01T11:00:00Z",
                "updated_at": "2024-05-01T11:00:00Z"
              }
            ]
            """.data(using: .utf8)!

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }

        let assignments = try await repository.fetchAssignments()
        await fulfillment(of: [handled], timeout: 1)

        XCTAssertEqual(assignments.map(\.id), [earliestID, middleID, latestID])
        XCTAssertEqual(assignments.first?.status, .completed)
        XCTAssertEqual(assignments[1].type, .quiz)
        XCTAssertEqual(assignments.last?.type, .homework)
    }

    func testUpsertAssignmentPostsPayload() async throws {
        let repository = makeRepository()
        let assignment = Assignment(
            status: .inProgress,
            name: "Persisted",
            course: "CS",
            type: .report,
            dueAt: ISO8601DateFormatter().date(from: "2024-05-05T10:00:00Z") ?? Date()
        )
        let handled = expectation(description: "handled upsert")

        MockURLProtocol.requestHandler = { request in
            handled.fulfill()
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/rest/v1/assignments")
            let queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertTrue(queryItems?.contains(where: { $0.name == "on_conflict" && $0.value == "id" }) == true)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation,resolution=merge-duplicates")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

            guard let data = httpBodyData(from: request) else {
                XCTFail("Missing request body")
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("[]".utf8))
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            let payload = try XCTUnwrap(json?.first)
            XCTAssertEqual(payload["status"] as? String, assignment.status.rawValue)
            XCTAssertEqual(payload["name"] as? String, assignment.name)
            XCTAssertEqual(payload["course"] as? String, assignment.course)
            XCTAssertEqual(payload["type"] as? String, assignment.type.rawValue)
            let dueAtString = try XCTUnwrap(payload["due_at"] as? String)
            XCTAssertTrue(dueAtString.contains("."), "Expected fractional seconds in \(dueAtString)")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        try await repository.upsertAssignment(assignment)
        await fulfillment(of: [handled], timeout: 1)
    }

    func testDeleteAssignmentSendsDeleteRequest() async throws {
        let repository = makeRepository()
        let targetID = UUID()
        let handled = expectation(description: "handled delete")

        MockURLProtocol.requestHandler = { request in
            handled.fulfill()
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/rest/v1/assignments")
            let queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertTrue(queryItems?.contains(where: { $0.name == "id" && $0.value == "eq.\(targetID.uuidString)" }) == true)

            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        try await repository.deleteAssignment(id: targetID)
        await fulfillment(of: [handled], timeout: 1)
    }

    private func makeRepository() -> SupabaseAssignmentRepository {
        SupabaseAssignmentRepository(client: client, logger: logger)
    }
}
