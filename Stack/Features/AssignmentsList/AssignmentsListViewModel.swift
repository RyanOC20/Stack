import Foundation
import SwiftUI

@MainActor
final class AssignmentsListViewModel: ObservableObject {
    struct EditingContext: Equatable {
        enum Field: Equatable {
            case name
            case course
            case dueDate
        }

        let assignmentID: UUID
        let field: Field
    }

    @Published private(set) var assignments: [Assignment] = []
    @Published var selectedAssignmentID: UUID?
    @Published var editingContext: EditingContext?
    @Published var quickAddFocusTrigger = UUID()
    @Published var errorMessage: String?

    var availableCourses: [String] {
        courseRepository.availableCourses(from: assignments)
    }

    var canUndoDelete: Bool {
        !undoStack.isEmpty
    }

    private struct DeletedSnapshot {
        let assignment: Assignment
        let index: Int
    }

    private let assignmentRepository: AssignmentRepositoryProtocol
    private let courseRepository: CourseRepositoryProviding
    private let logger: Logger
    private var undoStack: [DeletedSnapshot] = []

    init(assignmentRepository: AssignmentRepositoryProtocol,
         courseRepository: CourseRepositoryProviding,
         logger: Logger) {
        self.assignmentRepository = assignmentRepository
        self.courseRepository = courseRepository
        self.logger = logger

        Task {
            await loadAssignments()
        }
    }

    func loadAssignments() async {
        do {
            assignments = try await assignmentRepository.fetchAssignments()
            selectedAssignmentID = assignments.first?.id
        } catch {
            logger.error("Failed to load assignments: \(error.localizedDescription)")
            errorMessage = "Unable to load assignments."
        }
    }

    func select(_ assignmentID: UUID?) {
        selectedAssignmentID = assignmentID
    }

    func deselect() {
        selectedAssignmentID = nil
        editingContext = nil
    }

    func moveSelection(_ direction: MoveCommandDirection) {
        guard !assignments.isEmpty else { return }
        let offset: Int
        switch direction {
        case .up:
            offset = -1
        case .down:
            offset = 1
        default:
            return
        }

        guard let currentID = selectedAssignmentID,
              let currentIndex = assignments.firstIndex(where: { $0.id == currentID })
        else {
            selectedAssignmentID = assignments.first?.id
            return
        }

        let targetIndex = max(0, min(assignments.count - 1, currentIndex + offset))
        selectedAssignmentID = assignments[targetIndex].id
    }

    func beginEditingSelectedAssignmentName() {
        guard let selectedAssignmentID else { return }
        editingContext = EditingContext(assignmentID: selectedAssignmentID, field: .name)
    }

    func requestEditing(for assignment: Assignment, field: EditingContext.Field) {
        editingContext = EditingContext(assignmentID: assignment.id, field: field)
    }

    func clearEditingContext() {
        editingContext = nil
    }

    func updateStatus(_ status: AssignmentStatus, for assignment: Assignment) {
        var updated = assignment
        updated.status = status
        persist(updated)
    }

    func updateName(_ name: String, for assignment: Assignment) {
        var updated = assignment
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persist(updated)
    }

    func updateCourse(_ course: String, for assignment: Assignment) {
        var updated = assignment
        updated.course = course.trimmingCharacters(in: .whitespaces)
        persist(updated)
    }

    func updateType(_ type: AssignmentType, for assignment: Assignment) {
        var updated = assignment
        updated.type = type
        persist(updated)
    }

    func updateDueDate(_ date: Date, for assignment: Assignment) {
        var updated = assignment
        updated.dueAt = date
        persist(updated)
    }

    func deleteSelectedAssignment() {
        guard let currentID = selectedAssignmentID,
              let index = assignments.firstIndex(where: { $0.id == currentID })
        else { return }

        let removed = assignments.remove(at: index)
        undoStack.append(DeletedSnapshot(assignment: removed, index: index))
        let nextIndex = min(index, assignments.count - 1)
        if nextIndex >= 0, assignments.indices.contains(nextIndex) {
            selectedAssignmentID = assignments[nextIndex].id
        } else {
            selectedAssignmentID = nil
        }

        Task {
            do {
                try await assignmentRepository.deleteAssignment(id: removed.id)
            } catch {
                _ = undoStack.popLast()
                assignments.insert(removed, at: index)
                selectedAssignmentID = removed.id
                errorMessage = "Delete failed."
            }
        }
    }

    func undoDelete() {
        guard let snapshot = undoStack.popLast() else { return }
        assignments.insert(snapshot.assignment, at: min(snapshot.index, assignments.count))
        selectedAssignmentID = snapshot.assignment.id
        Task {
            do {
                try await assignmentRepository.upsertAssignment(snapshot.assignment)
            } catch {
                errorMessage = "Undo failed."
            }
        }
    }

    func focusQuickAddRow() {
        editingContext = nil
        selectedAssignmentID = nil
        quickAddFocusTrigger = UUID()
    }

    func addAssignment(name: String,
                       course: String,
                       type: AssignmentType,
                       dueAt: Date,
                       status: AssignmentStatus = .notStarted) {
        var cleanedCourse = course
        if cleanedCourse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cleanedCourse = ""
        }

        let newAssignment = Assignment(
            status: status,
            name: name,
            course: cleanedCourse,
            type: type,
            dueAt: dueAt
        )

        insertAssignment(newAssignment)

        Task {
            do {
                try await assignmentRepository.upsertAssignment(newAssignment)
            } catch {
                errorMessage = "Saving assignment failed."
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func persist(_ assignment: Assignment) {
        if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments[index] = assignment
            resortAssignments()
        }

        Task {
            do {
                try await assignmentRepository.upsertAssignment(assignment)
            } catch {
                errorMessage = "Save failed."
            }
        }
    }

    private func insertAssignment(_ assignment: Assignment) {
        assignments.append(assignment)
        resortAssignments()
        selectedAssignmentID = assignment.id
    }

    private func resortAssignments() {
        assignments.sort { lhs, rhs in
            if lhs.dueAt == rhs.dueAt {
                return lhs.name < rhs.name
            }
            return lhs.dueAt < rhs.dueAt
        }
    }
}
