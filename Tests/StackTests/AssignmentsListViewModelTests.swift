import XCTest
@testable import Stack

@MainActor
final class AssignmentsListViewModelTests: XCTestCase {
    func testAddAssignmentAppendsAndPersists() async throws {
        let repository = MockAssignmentRepository(assignments: [])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger()
        )

        await viewModel.loadAssignments()

        viewModel.addAssignment(
            name: "Test",
            course: "CS 101",
            type: .homework,
            dueAt: Date()
        )

        XCTAssertEqual(viewModel.assignments.count, 1)
        let storedCount = await repository.assignmentCount
        XCTAssertEqual(storedCount, 1)
    }

    func testDeleteAndUndo() async throws {
        let assignment = Assignment(status: .notStarted, name: "Delete", course: "ART 100", type: .essay, dueAt: Date())
        let repository = MockAssignmentRepository(assignments: [assignment])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger()
        )

        await viewModel.loadAssignments()
        viewModel.select(assignment.id)
        viewModel.deleteSelectedAssignment()

        XCTAssertEqual(viewModel.assignments.count, 0)

        viewModel.undoDelete()
        XCTAssertEqual(viewModel.assignments.count, 1)
        XCTAssertEqual(viewModel.assignments.first?.id, assignment.id)
    }
}

actor MockAssignmentRepository: AssignmentRepositoryProtocol {
    private var storage: [UUID: Assignment]

    init(assignments: [Assignment]) {
        storage = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0) })
    }

    var assignmentCount: Int {
        storage.count
    }

    func fetchAssignments() async throws -> [Assignment] {
        storage.values.sorted { $0.name < $1.name }
    }

    func upsertAssignment(_ assignment: Assignment) async throws {
        storage[assignment.id] = assignment
    }

    func deleteAssignment(id: UUID) async throws {
        storage[id] = nil
    }
}
