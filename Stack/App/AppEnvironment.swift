import Foundation

struct AppEnvironment {
    let assignmentRepository: AssignmentRepositoryProtocol
    let courseRepository: CourseRepositoryProviding
    let logger: Logger

    static let shared = AppEnvironment()

    init(assignmentRepository: AssignmentRepositoryProtocol? = nil,
         courseRepository: CourseRepositoryProviding? = nil,
         logger: Logger = Logger()) {
        self.logger = logger
        if let assignmentRepository {
            self.assignmentRepository = assignmentRepository
        } else {
            self.assignmentRepository = AssignmentRepository()
        }
        self.courseRepository = courseRepository ?? CourseRepository()
    }
}
