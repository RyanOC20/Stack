import XCTest
@testable import Stack

final class AssignmentDTOTests: XCTestCase {
    func testToModelMapsValidRawValues() {
        let now = Date()
        let dto = AssignmentDTO(
            assignment: Assignment(
                status: .completed,
                name: "Mapped",
                course: "Course",
                type: .exam,
                dueAt: now,
                createdAt: now.addingTimeInterval(-100),
                updatedAt: now.addingTimeInterval(-50)
            )
        )

        let model = dto.toModel()
        XCTAssertEqual(model.id, dto.id)
        XCTAssertEqual(model.status, .completed)
        XCTAssertEqual(model.type, .exam)
        XCTAssertEqual(model.name, "Mapped")
        XCTAssertEqual(model.course, "Course")
        XCTAssertEqual(model.dueAt, dto.dueAt)
        XCTAssertEqual(model.createdAt, dto.createdAt)
        XCTAssertEqual(model.updatedAt, dto.updatedAt)
    }

    func testToModelFallsBackForUnknownEnums() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "status": "Unknown",
          "name": "Fallback",
          "course": "Course",
          "type": "Mystery",
          "due_at": "2024-05-01T10:00:00Z",
          "created_at": "2024-04-01T10:00:00Z",
          "updated_at": "2024-04-02T10:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(AssignmentDTO.self, from: json)

        let model = dto.toModel()
        XCTAssertEqual(model.status, .notStarted)
        XCTAssertEqual(model.type, .homework)
    }
}
