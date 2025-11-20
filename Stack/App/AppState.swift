import Foundation

@MainActor
final class AppState: ObservableObject {
    let assignmentsListViewModel: AssignmentsListViewModel

    init(environment: AppEnvironment = .shared) {
        assignmentsListViewModel = AssignmentsListViewModel(
            assignmentRepository: environment.assignmentRepository,
            courseRepository: environment.courseRepository,
            logger: environment.logger
        )
    }
}
