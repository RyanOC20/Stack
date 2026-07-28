import XCTest
@testable import Cairn

final class ImportModelsTests: XCTestCase {
    private func decode(_ json: String) throws -> ExtractionResponseDTO {
        try JSONDecoder().decode(ExtractionResponseDTO.self, from: Data(json.utf8))
    }

    func testDecodesAndMapsCandidate() throws {
        let response = try decode("""
        {"assignments":[
          {"name":"Essay 1","course":"ENG 210","type":"Essay","dueAt":"2026-10-14T23:59:00-07:00","status":"Not Started","confidence":0.9}
        ]}
        """)
        let candidates = response.assignments.compactMap { $0.toModel() }
        XCTAssertEqual(candidates.count, 1)
        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(candidate.name, "Essay 1")
        XCTAssertEqual(candidate.course, "ENG 210")
        XCTAssertEqual(candidate.type, .essay)
        XCTAssertEqual(candidate.status, .notStarted)
        XCTAssertEqual(candidate.confidence, 0.9, accuracy: 0.0001)
        XCTAssertTrue(candidate.isIncluded)
    }

    func testUnknownEnumsFallBack() throws {
        let response = try decode("""
        {"assignments":[
          {"name":"Mystery","course":"","type":"Lab","dueAt":"2026-01-05T12:00:00Z","status":"Pending","confidence":0.5}
        ]}
        """)
        let candidate = try XCTUnwrap(response.assignments.first?.toModel())
        XCTAssertEqual(candidate.type, .homework)
        XCTAssertEqual(candidate.status, .notStarted)
    }

    func testUnparseableDateIsDropped() throws {
        let response = try decode("""
        {"assignments":[
          {"name":"No Date","course":"","type":"Quiz","dueAt":"someday","status":"Not Started","confidence":0.3}
        ]}
        """)
        XCTAssertNil(response.assignments.first?.toModel())
    }

    func testFractionalSecondsDateParses() throws {
        let response = try decode("""
        {"assignments":[
          {"name":"Frac","course":"","type":"Quiz","dueAt":"2026-03-02T09:30:00.500Z","status":"In Progress","confidence":0.7}
        ]}
        """)
        let candidate = try XCTUnwrap(response.assignments.first?.toModel())
        XCTAssertEqual(candidate.status, .inProgress)
    }
}
