import Foundation

@MainActor
final class AppState: ObservableObject {
    private let environment: AppEnvironment
    let assignmentsListViewModel: AssignmentsListViewModel

    var hasSupabaseSession: Bool {
        environment.supabaseClient?.currentUserID != nil
    }

    var authService: SupabaseAuthService? {
        environment.authService
    }

    init(environment: AppEnvironment = .shared) {
        let shouldAutoLoad: Bool
        if environment.assignmentRepository is SupabaseAssignmentRepository {
            shouldAutoLoad = environment.supabaseClient?.currentUserID != nil
        } else {
            shouldAutoLoad = true
        }

        self.environment = environment
        assignmentsListViewModel = AssignmentsListViewModel(
            assignmentRepository: environment.assignmentRepository,
            courseRepository: environment.courseRepository,
            logger: environment.logger,
            autoLoad: shouldAutoLoad
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
