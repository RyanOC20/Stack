import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    private let environment: AppEnvironment
    let assignmentsListViewModel: AssignmentsListViewModel
    let importViewModel: ImportViewModel?
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

        if let supabaseClient = environment.supabaseClient {
            let service = ImportService(client: supabaseClient, logger: environment.logger)
            let listViewModel = assignmentsListViewModel
            importViewModel = ImportViewModel(service: service) { candidate in
                listViewModel.addAssignment(
                    name: candidate.name,
                    course: candidate.course,
                    type: candidate.type,
                    dueAt: candidate.dueAt,
                    status: candidate.status
                )
            }
        } else {
            importViewModel = nil
        }

        assignmentsListViewModel.onSessionExpired = { [weak self] in
            self?.handleLogout()
        }
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
