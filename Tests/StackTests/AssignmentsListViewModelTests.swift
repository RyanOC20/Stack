import XCTest
@testable import Stack

@MainActor
final class AssignmentsListViewModelTests: XCTestCase {
    func testAddAssignmentAppendsAndPersists() async throws {
        let repository = MockAssignmentRepository(assignments: [])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()

        viewModel.addAssignment(
            name: "Test",
            course: "CS 101",
            type: .homework,
            dueAt: Date()
        )

        await Task.yield()
        try await Task.sleep(nanoseconds: 10_000_000)

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
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        viewModel.select(assignment.id)
        viewModel.deleteSelectedAssignment()

        XCTAssertEqual(viewModel.assignments.count, 0)

        viewModel.undoDelete()
        XCTAssertEqual(viewModel.assignments.count, 1)
        XCTAssertEqual(viewModel.assignments.first?.id, assignment.id)
    }

    func testMoveSelectionRespectsBounds() async {
        let now = Date()
        let first = Assignment(status: .notStarted, name: "Alpha", course: "", type: .homework, dueAt: now)
        let second = Assignment(status: .notStarted, name: "Beta", course: "", type: .homework, dueAt: now.addingTimeInterval(100))
        let repository = MockAssignmentRepository(assignments: [first, second])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        XCTAssertEqual(viewModel.selectedAssignmentID, first.id)

        viewModel.moveSelection(.down)
        XCTAssertEqual(viewModel.selectedAssignmentID, second.id)

        viewModel.moveSelection(.down)
        XCTAssertEqual(viewModel.selectedAssignmentID, second.id)

        viewModel.moveSelection(.up)
        XCTAssertEqual(viewModel.selectedAssignmentID, first.id)
    }

    func testEditingContextProgression() async {
        let assignment = Assignment(status: .inProgress, name: "Edit", course: "BIO", type: .exam, dueAt: Date())
        let repository = MockAssignmentRepository(assignments: [assignment])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        viewModel.requestEditing(for: assignment, field: .status)

        viewModel.beginEditingNextField()
        XCTAssertEqual(viewModel.editingContext, .init(assignmentID: assignment.id, field: .name))

        viewModel.beginEditingNextField()
        XCTAssertEqual(viewModel.editingContext, .init(assignmentID: assignment.id, field: .course))

        viewModel.beginEditingNextField()
        XCTAssertEqual(viewModel.editingContext, .init(assignmentID: assignment.id, field: .type))

        viewModel.beginEditingNextField()
        XCTAssertEqual(viewModel.editingContext, .init(assignmentID: assignment.id, field: .dueDate))

        viewModel.beginEditingNextField()
        XCTAssertNil(viewModel.editingContext)
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
