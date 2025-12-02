import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    private let environment: AppEnvironment
    let assignmentsListViewModel: AssignmentsListViewModel
    @Published private(set) var hasSupabaseSession: Bool

    var authService: SupabaseAuthService? {
        environment.authService
    }

    init(environment: AppEnvironment = .shared) {
        let hasExistingSupabaseSession = environment.supabaseClient?.currentUserID != nil
        let shouldAutoLoad: Bool
        if environment.assignmentRepository is SupabaseAssignmentRepository {
            shouldAutoLoad = hasExistingSupabaseSession
        } else {
            shouldAutoLoad = true
        }

        self.environment = environment
        self.hasSupabaseSession = hasExistingSupabaseSession
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
            hasSupabaseSession = true
            Task {
                await assignmentsListViewModel.loadAssignments()
            }
        }
    }

    func handleLogout() {
        environment.supabaseClient?.clearSession()
        hasSupabaseSession = false
    }
}
