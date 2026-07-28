import Foundation

struct Assignment: Identifiable, Hashable, Codable {
    let id: UUID
    var status: AssignmentStatus
    var name: String
    var course: String
    var type: AssignmentType
    var dueAt: Date
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         status: AssignmentStatus,
         name: String,
         course: String,
         type: AssignmentType,
         dueAt: Date,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.status = status
        self.name = name
        self.course = course
        self.type = type
        self.dueAt = dueAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
