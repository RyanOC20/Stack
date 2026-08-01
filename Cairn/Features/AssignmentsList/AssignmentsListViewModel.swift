import Foundation
import SwiftUI

@MainActor
final class AssignmentsListViewModel: ObservableObject {
    struct EditingContext: Equatable {
        enum Field: Equatable {
            case name
            case course
            case dueDate
            case status
            case type
        }

        let assignmentID: UUID
        let field: Field
    }

    @Published private(set) var assignments: [Assignment] = []
    @Published var selectedAssignmentID: UUID?
    @Published var selectedField: EditingContext.Field = .status
    @Published var editingContext: EditingContext?
    @Published var quickAddFocusTrigger = UUID()
    @Published var errorMessage: String?
    var onSessionExpired: (() -> Void)?

    var availableCourses: [String] {
        courseRepository.availableCourses(from: assignments)
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    private struct HistorySnapshot {
        let assignments: [Assignment]
        let selectedAssignmentID: UUID?
        let selectedField: EditingContext.Field
    }

    private let assignmentRepository: AssignmentRepositoryProtocol
    private let courseRepository: CourseRepositoryProviding
    private let logger: Logger
    private var undoStack: [HistorySnapshot] = []
    private var redoStack: [HistorySnapshot] = []
    private static let orderedFields: [EditingContext.Field] = [.status, .name, .course, .type, .dueDate]

    init(assignmentRepository: AssignmentRepositoryProtocol,
         courseRepository: CourseRepositoryProviding,
         logger: Logger,
         autoLoad: Bool = true) {
        self.assignmentRepository = assignmentRepository
        self.courseRepository = courseRepository
        self.logger = logger

        if autoLoad {
            Task {
                await loadAssignments()
            }
        }
    }

    func loadAssignments() async {
        do {
            assignments = try await assignmentRepository.fetchAssignments()
            selectedAssignmentID = assignments.first?.id
            selectedField = .status
            editingContext = nil
            undoStack.removeAll()
            redoStack.removeAll()
            errorMessage = nil
        } catch {
            let mappedError = SupabaseErrorMapper.map(error)
            logger.error("Failed to load assignments: \(mappedError.message)")

            if let supabaseError = error as? SupabaseErrorResponse,
               let status = supabaseError.status,
               status == 401 || status == 403 {
                // Session expired: log out silently instead of flashing an error banner.
                errorMessage = nil
                onSessionExpired?()
            } else {
                errorMessage = mappedError.message
            }
        }
    }

    func select(_ assignmentID: UUID?) {
        selectedAssignmentID = assignmentID
        if assignmentID == nil {
            editingContext = nil
        }
    }

    func selectFirstAssignment() {
        selectedAssignmentID = assignments.first?.id
    }

    func deselect() {
        selectedAssignmentID = nil
        editingContext = nil
    }

    func cancelAllSelectionsAndEditing() {
        deselect()
    }

    func moveSelection(_ direction: MoveCommandDirection) {
        guard !assignments.isEmpty else { return }

        guard let currentID = selectedAssignmentID,
              let currentIndex = assignments.firstIndex(where: { $0.id == currentID })
        else {
            // Nothing selected yet — engage the top-left field.
            selectedAssignmentID = assignments.first?.id
            selectedField = .status
            return
        }

        let offset: Int
        switch direction {
        case .up:
            offset = -1
        case .down:
            offset = 1
        default:
            return
        }

        let targetIndex = max(0, min(assignments.count - 1, currentIndex + offset))
        selectedAssignmentID = assignments[targetIndex].id
    }

    func moveFieldSelection(_ direction: MoveCommandDirection) {
        guard editingContext == nil else { return }
        guard !assignments.isEmpty else { return }

        guard selectedAssignmentID != nil else {
            // Nothing selected yet — engage the top-left field.
            selectedAssignmentID = assignments.first?.id
            selectedField = .status
            return
        }

        guard let currentIndex = Self.orderedFields.firstIndex(of: selectedField) else {
            selectedField = .status
            return
        }

        let offset: Int
        switch direction {
        case .left:
            offset = -1
        case .right:
            offset = 1
        default:
            return
        }

        let count = Self.orderedFields.count
        let targetIndex = (currentIndex + offset + count) % count
        selectedField = Self.orderedFields[targetIndex]
    }

    func beginEditingSelectedField() {
        guard let selectedAssignmentID else { return }
        editingContext = EditingContext(assignmentID: selectedAssignmentID, field: selectedField)
    }

    func requestEditing(for assignment: Assignment, field: EditingContext.Field) {
        selectedAssignmentID = assignment.id
        selectedField = field
        editingContext = EditingContext(assignmentID: assignment.id, field: field)
    }

    func selectField(_ field: EditingContext.Field) {
        selectedField = field
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

        let previous = currentSnapshot()
        recordUndoSnapshot()
        let removed = assignments.remove(at: index)
        editingContext = nil
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
                applySnapshot(previous)
                errorMessage = "Delete failed."
            }
        }
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        let previousAssignments = assignments
        redoStack.append(currentSnapshot())
        applySnapshot(snapshot)
        syncRepository(from: previousAssignments, to: snapshot.assignments, failureMessage: "Undo failed.")
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        let previousAssignments = assignments
        undoStack.append(currentSnapshot())
        applySnapshot(snapshot)
        syncRepository(from: previousAssignments, to: snapshot.assignments, failureMessage: "Redo failed.")
    }

    func focusQuickAddRow() {
        editingContext = nil
        selectedAssignmentID = nil
        quickAddFocusTrigger = UUID()
    }

    func createAssignmentAndBeginEditingName() {
        let newAssignment = Assignment(
            status: .notStarted,
            name: "New assignment…",
            course: "",
            type: .homework,
            dueAt: Self.defaultDueDate()
        )

        recordUndoSnapshot()
        assignments.insert(newAssignment, at: 0)
        selectedAssignmentID = newAssignment.id
        selectedField = .name
        editingContext = EditingContext(assignmentID: newAssignment.id, field: .name)

        Task {
            do {
                try await assignmentRepository.upsertAssignment(newAssignment)
            } catch {
                errorMessage = "Saving assignment failed."
            }
        }
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

        recordUndoSnapshot()
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
        guard let index = assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        guard assignments[index] != assignment else { return }

        recordUndoSnapshot()
        assignments[index] = assignment
        selectedAssignmentID = assignment.id
        resortAssignments()

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
        selectedField = .name
        editingContext = nil
    }

    private func resortAssignments() {
        assignments.sort { lhs, rhs in
            if lhs.dueAt == rhs.dueAt {
                return lhs.name < rhs.name
            }
            return lhs.dueAt < rhs.dueAt
        }
    }

    private func recordUndoSnapshot() {
        undoStack.append(currentSnapshot())
        redoStack.removeAll()
    }

    private func currentSnapshot() -> HistorySnapshot {
        HistorySnapshot(
            assignments: assignments,
            selectedAssignmentID: selectedAssignmentID,
            selectedField: selectedField
        )
    }

    private func applySnapshot(_ snapshot: HistorySnapshot) {
        assignments = snapshot.assignments
        if let selectedID = snapshot.selectedAssignmentID,
           assignments.contains(where: { $0.id == selectedID }) {
            selectedAssignmentID = selectedID
        } else {
            selectedAssignmentID = assignments.first?.id
        }
        selectedField = snapshot.selectedField
        editingContext = nil
    }

    private func syncRepository(from previous: [Assignment], to next: [Assignment], failureMessage: String) {
        let previousByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        let nextByID = Dictionary(uniqueKeysWithValues: next.map { ($0.id, $0) })

        Task {
            do {
                for assignment in next where previousByID[assignment.id] != assignment {
                    try await assignmentRepository.upsertAssignment(assignment)
                }

                for assignment in previous where nextByID[assignment.id] == nil {
                    try await assignmentRepository.deleteAssignment(id: assignment.id)
                }
            } catch {
                errorMessage = failureMessage
            }
        }
    }

    private static func defaultDueDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 23
        components.minute = 59
        return calendar.date(from: components) ?? tomorrow
    }
}
