import XCTest
@testable import Stack

final class AssignmentRepositoryTests: XCTestCase {
    func testFetchReturnsSortedAssignments() async throws {
        let now = Date()
        let early = Assignment(status: .notStarted, name: "Early", course: "", type: .homework, dueAt: now)
        let late = Assignment(status: .notStarted, name: "Late", course: "", type: .homework, dueAt: now.addingTimeInterval(3600))
        let repository = AssignmentRepository(seed: [late, early])

        let items = try await repository.fetchAssignments()
        XCTAssertEqual(items.first?.name, "Early")
        XCTAssertEqual(items.last?.name, "Late")
    }

    func testUpsertAndDelete() async throws {
        let repository = AssignmentRepository(seed: [])
        let assignment = Assignment(status: .notStarted, name: "Persist", course: "", type: .quiz, dueAt: Date())
        try await repository.upsertAssignment(assignment)
        var items = try await repository.fetchAssignments()
        XCTAssertEqual(items.count, 1)

        try await repository.deleteAssignment(id: assignment.id)
        items = try await repository.fetchAssignments()
        XCTAssertTrue(items.isEmpty)
    }
}
