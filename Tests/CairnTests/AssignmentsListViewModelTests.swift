@testable import Cairn
import XCTest

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

    func testDeleteAndUndo() async {
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

        viewModel.undo()
        XCTAssertEqual(viewModel.assignments.count, 1)
        XCTAssertEqual(viewModel.assignments.first?.id, assignment.id)

        viewModel.redo()
        XCTAssertEqual(viewModel.assignments.count, 0)
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

    func testMoveFieldSelectionWraps() async {
        let assignment = Assignment(status: .inProgress, name: "Edit", course: "BIO", type: .exam, dueAt: Date())
        let repository = MockAssignmentRepository(assignments: [assignment])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        XCTAssertEqual(viewModel.selectedField, .status)

        viewModel.moveFieldSelection(.left)
        XCTAssertEqual(viewModel.selectedField, .dueDate)

        viewModel.moveFieldSelection(.right)
        XCTAssertEqual(viewModel.selectedField, .status)

        viewModel.moveFieldSelection(.right)
        XCTAssertEqual(viewModel.selectedField, .name)

        viewModel.moveFieldSelection(.right)
        XCTAssertEqual(viewModel.selectedField, .course)
    }

    func testBeginEditingUsesSelectedField() async {
        let assignment = Assignment(status: .inProgress, name: "Edit", course: "BIO", type: .exam, dueAt: Date())
        let repository = MockAssignmentRepository(assignments: [assignment])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        viewModel.select(assignment.id)
        viewModel.selectField(.course)
        viewModel.beginEditingSelectedField()

        XCTAssertEqual(viewModel.editingContext, .init(assignmentID: assignment.id, field: .course))
    }

    func testUndoRedoUpdate() async {
        let assignment = Assignment(status: .inProgress, name: "Original", course: "BIO", type: .exam, dueAt: Date())
        let repository = MockAssignmentRepository(assignments: [assignment])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        viewModel.updateName("Updated", for: assignment)
        XCTAssertEqual(viewModel.assignments.first?.name, "Updated")

        viewModel.undo()
        XCTAssertEqual(viewModel.assignments.first?.name, "Original")

        viewModel.redo()
        XCTAssertEqual(viewModel.assignments.first?.name, "Updated")
    }

    func testUndoRedoAdd() async {
        let repository = MockAssignmentRepository(assignments: [])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        viewModel.addAssignment(
            name: "New",
            course: "MATH",
            type: .homework,
            dueAt: Date()
        )
        XCTAssertEqual(viewModel.assignments.count, 1)

        viewModel.undo()
        XCTAssertEqual(viewModel.assignments.count, 0)

        viewModel.redo()
        XCTAssertEqual(viewModel.assignments.count, 1)
    }

    func testCreateAssignmentAndBeginEditingNameInsertsAtTop() async {
        let now = Date()
        let existing = Assignment(status: .notStarted, name: "Existing", course: "BIO", type: .quiz, dueAt: now)
        let repository = MockAssignmentRepository(assignments: [existing])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        viewModel.createAssignmentAndBeginEditingName()

        XCTAssertEqual(viewModel.assignments.count, 2)
        XCTAssertEqual(viewModel.assignments.first?.name, "New assignment…")
        XCTAssertEqual(viewModel.selectedAssignmentID, viewModel.assignments.first?.id)
        XCTAssertEqual(viewModel.selectedField, .name)
        if let firstID = viewModel.assignments.first?.id {
            XCTAssertEqual(
                viewModel.editingContext,
                .init(assignmentID: firstID, field: .name)
            )
        } else {
            XCTFail("Expected a newly created assignment at the top of the list.")
        }
    }

    func testFailedUpdateRollsBackOptimisticChange() async throws {
        let assignment = Assignment(status: .inProgress, name: "Original", course: "BIO", type: .exam, dueAt: Date())
        let repository = MockAssignmentRepository(assignments: [assignment], writeError: SupabaseClient.ClientError.invalidResponse)
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        viewModel.updateName("Updated", for: assignment)
        XCTAssertEqual(viewModel.assignments.first?.name, "Updated", "Change should apply optimistically first")

        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(viewModel.assignments.first?.name, "Original", "Failed save should roll back")
        XCTAssertEqual(viewModel.errorMessage, "Save failed.")
        XCTAssertFalse(viewModel.canUndo, "The failed mutation's undo snapshot should be dropped")
    }

    func testFailedAddRollsBackInsertion() async throws {
        let repository = MockAssignmentRepository(assignments: [], writeError: SupabaseClient.ClientError.invalidResponse)
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        viewModel.addAssignment(name: "Temp", course: "CS", type: .homework, dueAt: Date())
        XCTAssertEqual(viewModel.assignments.count, 1)

        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(viewModel.assignments.count, 0, "Failed add should roll back")
        XCTAssertEqual(viewModel.errorMessage, "Saving assignment failed.")
    }

    private func makeSearchViewModel() async -> (AssignmentsListViewModel, [Assignment]) {
        let now = Date()
        let essay = Assignment(status: .notStarted, name: "Essay on Rome", course: "History", type: .essay, dueAt: now)
        let calc = Assignment(status: .notStarted, name: "Calc set", course: "Math", type: .homework, dueAt: now.addingTimeInterval(100))
        let quiz = Assignment(status: .notStarted, name: "History quiz", course: "History", type: .quiz, dueAt: now.addingTimeInterval(200))
        let repository = MockAssignmentRepository(assignments: [essay, calc, quiz])
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )
        await viewModel.loadAssignments()
        return (viewModel, [essay, calc, quiz])
    }

    func testSearchFiltersByNameAndCourse() async {
        let (viewModel, _) = await makeSearchViewModel()

        viewModel.searchQuery = "history"
        // Matches "Essay on Rome" (course History) and "History quiz" (name + course).
        XCTAssertEqual(viewModel.displayedAssignments.map(\.name), ["Essay on Rome", "History quiz"])

        viewModel.searchQuery = "calc"
        XCTAssertEqual(viewModel.displayedAssignments.map(\.name), ["Calc set"])

        viewModel.searchQuery = "   "
        XCTAssertEqual(viewModel.displayedAssignments.count, 3, "Blank query shows everything")
    }

    func testSearchReconcilesSelectionToFirstVisible() async {
        let (viewModel, items) = await makeSearchViewModel()
        // Select the Calculus assignment, then filter to History-only.
        viewModel.select(items[1].id)

        viewModel.searchQuery = "history"

        XCTAssertEqual(viewModel.selectedAssignmentID, items[0].id, "Hidden selection jumps to first visible")
    }

    func testNavigationStaysWithinFilteredResults() async {
        let (viewModel, items) = await makeSearchViewModel()
        viewModel.searchQuery = "history" // [Essay on Rome, History quiz]

        XCTAssertEqual(viewModel.selectedAssignmentID, items[0].id)
        viewModel.moveSelection(.down)
        XCTAssertEqual(viewModel.selectedAssignmentID, items[2].id, "Skips the filtered-out Calculus row")
        viewModel.moveSelection(.down)
        XCTAssertEqual(viewModel.selectedAssignmentID, items[2].id, "Clamps at the last visible row")
    }

    func testMutationSessionExpiryTriggersLogout() async {
        let assignment = Assignment(status: .inProgress, name: "Original", course: "BIO", type: .exam, dueAt: Date())
        let expired = SupabaseErrorResponse(message: "JWT expired", error: nil, status: 401, rawBody: nil)
        let repository = MockAssignmentRepository(assignments: [assignment], writeError: expired)
        let viewModel = AssignmentsListViewModel(
            assignmentRepository: repository,
            courseRepository: CourseRepository(),
            logger: Logger(),
            autoLoad: false
        )

        await viewModel.loadAssignments()
        let loggedOut = expectation(description: "session expired triggers logout")
        viewModel.onSessionExpired = { loggedOut.fulfill() }

        viewModel.updateName("Updated", for: assignment)
        await fulfillment(of: [loggedOut], timeout: 1)

        XCTAssertNil(viewModel.errorMessage, "Session expiry logs out silently rather than showing a banner")
        XCTAssertEqual(viewModel.assignments.first?.name, "Original", "The optimistic change should still roll back")
    }
}

actor MockAssignmentRepository: AssignmentRepositoryProtocol {
    private var storage: [UUID: Assignment]
    private let writeError: Error?

    init(assignments: [Assignment], writeError: Error? = nil) {
        storage = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0) })
        self.writeError = writeError
    }

    var assignmentCount: Int {
        storage.count
    }

    func fetchAssignments() async throws -> [Assignment] {
        storage.values.sorted { $0.name < $1.name }
    }

    func upsertAssignment(_ assignment: Assignment) async throws {
        if let writeError {
            throw writeError
        }
        storage[assignment.id] = assignment
    }

    func deleteAssignment(id: UUID) async throws {
        if let writeError {
            throw writeError
        }
        storage[id] = nil
    }
}
