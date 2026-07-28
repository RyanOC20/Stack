import Foundation

protocol AssignmentRepositoryProtocol {
    func fetchAssignments() async throws -> [Assignment]
    func upsertAssignment(_ assignment: Assignment) async throws
    func deleteAssignment(id: UUID) async throws
}

actor AssignmentRepository: AssignmentRepositoryProtocol {
    private var assignments: [UUID: Assignment]

    init(seed: [Assignment] = AssignmentRepository.makeSeedAssignments()) {
        assignments = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchAssignments() async throws -> [Assignment] {
        assignments.values.sorted { lhs, rhs in
            if lhs.dueAt == rhs.dueAt {
                return lhs.name < rhs.name
            }
            return lhs.dueAt < rhs.dueAt
        }
    }

    func upsertAssignment(_ assignment: Assignment) async throws {
        assignments[assignment.id] = assignment
    }

    func deleteAssignment(id: UUID) async throws {
        assignments[id] = nil
    }

    private static func makeSeedAssignments() -> [Assignment] {
        let now = Date()
        return [
            Assignment(status: .inProgress, name: "Database Systems Essay", course: "CSE 344", type: .essay, dueAt: Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now),
            Assignment(status: .notStarted, name: "Linear Algebra Quiz", course: "MATH 308", type: .quiz, dueAt: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now),
            Assignment(status: .completed, name: "Poetry Presentation", course: "ENG 215", type: .presentation, dueAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now)
        ]
    }
}
