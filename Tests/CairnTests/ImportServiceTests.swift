@testable import Cairn
import XCTest

final class ImportServiceTests: XCTestCase {
    private func makeService() -> ImportService {
        let store = InMemorySessionStore(storedSession: SupabaseSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            user: SupabaseUser(id: UUID(), email: "user@example.com")
        ))
        let configuration = SupabaseClient.Configuration(url: URL(string: "https://example.supabase.co")!, anonKey: "anon-key")
        let client = SupabaseClient(configuration: configuration, urlSession: makeMockURLSession(), sessionStore: store)
        return ImportService(client: client, logger: Logger())
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testExtractFromTextReturnsCandidatesSortedByDueDate() async throws {
        let service = makeService()

        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/rest/v1/imports":
                return (makeHTTPResponse(for: request, statusCode: 201), Data(#"[{"id":"\#(UUID().uuidString)"}]"#.utf8))
            case "/functions/v1/extract-assignments":
                let body = Data("""
                {"assignments":[
                  {
                    "name":"Later essay","course":"History","type":"Essay",
                    "dueAt":"2024-06-02T10:00:00Z","status":"Not Started","confidence":0.9
                  },
                  {
                    "name":"Sooner quiz","course":"Math","type":"Quiz",
                    "dueAt":"2024-06-01T10:00:00Z","status":"Not Started","confidence":0.8
                  }
                ]}
                """.utf8)
                return (makeHTTPResponse(for: request, statusCode: 200), body)
            default:
                return (makeHTTPResponse(for: request, statusCode: 200), Data("[]".utf8))
            }
        }

        let candidates = try await service.extract(from: .text("syllabus text"))

        XCTAssertEqual(candidates.map(\.name), ["Sooner quiz", "Later essay"], "Candidates are sorted by due date")
        XCTAssertEqual(candidates.first?.type, .quiz)
    }

    func testExtractMapsFunctionFailureToImportError() async {
        let service = makeService()

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/functions/v1/extract-assignments" {
                return (makeHTTPResponse(for: request, statusCode: 502), Data(#"{"error":"extraction failed: boom"}"#.utf8))
            }
            return (makeHTTPResponse(for: request, statusCode: 201), Data(#"[{"id":"\#(UUID().uuidString)"}]"#.utf8))
        }

        do {
            _ = try await service.extract(from: .text("x"))
            XCTFail("Expected ImportError.functionFailed")
        } catch let ImportService.ImportError.functionFailed(message) {
            XCTAssertTrue(message.contains("boom"), "Surfaces the function's error message: \(message)")
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
