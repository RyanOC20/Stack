import Foundation

@MainActor
final class AppState: ObservableObject {
    private let environment: AppEnvironment
    let assignmentsListViewModel: AssignmentsListViewModel

    var authService: SupabaseAuthService? {
        environment.authService
    }

    init(environment: AppEnvironment = .shared) {
        self.environment = environment
        assignmentsListViewModel = AssignmentsListViewModel(
            assignmentRepository: environment.assignmentRepository,
            courseRepository: environment.courseRepository,
            logger: environment.logger
        )
    }

    func handleAuthentication(session: SupabaseSession?) {
        if let session {
            environment.supabaseClient?.setSession(session)
            Task {
                await assignmentsListViewModel.loadAssignments()
            }
        }
    }

    func handleLogout() {
        environment.supabaseClient?.clearSession()
    }
}
