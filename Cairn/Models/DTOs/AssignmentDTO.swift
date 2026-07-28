import Foundation

struct AssignmentDTO: Codable {
    let id: UUID
    let status: String
    let name: String
    let course: String
    let type: String
    let dueAt: Date
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case name
        case course
        case type
        case dueAt = "due_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(assignment: Assignment) {
        id = assignment.id
        status = assignment.status.rawValue
        name = assignment.name
        course = assignment.course
        type = assignment.type.rawValue
        dueAt = assignment.dueAt
        createdAt = assignment.createdAt
        updatedAt = assignment.updatedAt
    }

    func toModel() -> Assignment {
        Assignment(
            id: id,
            status: AssignmentStatus(rawValue: status) ?? .notStarted,
            name: name,
            course: course,
            type: AssignmentType(rawValue: type) ?? .homework,
            dueAt: dueAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
