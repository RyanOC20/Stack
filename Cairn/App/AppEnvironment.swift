import Foundation

struct AppEnvironment {
    let assignmentRepository: AssignmentRepositoryProtocol
    let courseRepository: CourseRepositoryProviding
    let logger: Logger
    let supabaseClient: SupabaseClient?
    let authService: SupabaseAuthService?

    static let shared = AppEnvironment()

    init(assignmentRepository: AssignmentRepositoryProtocol? = nil,
         courseRepository: CourseRepositoryProviding? = nil,
         logger: Logger = Logger(),
         supabaseClient: SupabaseClient? = nil,
         authService: SupabaseAuthService? = nil) {
        self.logger = logger

        if let assignmentRepository {
            self.assignmentRepository = assignmentRepository
            self.supabaseClient = supabaseClient
            self.authService = authService
        } else if let supabaseClient = supabaseClient ?? AppEnvironment.makeSupabaseClient(logger: logger) {
            self.assignmentRepository = SupabaseAssignmentRepository(client: supabaseClient, logger: logger)
            self.supabaseClient = supabaseClient
            self.authService = authService ?? SupabaseAuthService(client: supabaseClient)
        } else {
            self.assignmentRepository = AssignmentRepository()
            self.supabaseClient = nil
            self.authService = nil
        }

        self.courseRepository = courseRepository ?? CourseRepository()
    }

    private static func makeSupabaseClient(logger: Logger) -> SupabaseClient? {
        guard let config = EnvironmentConfiguration.load(logger: logger) else {
            logger.info("Supabase environment not found; set Config/Environment.plist or SUPABASE_URL/SUPABASE_ANON_KEY. Falling back to in-memory store.")
            return nil
        }
        return SupabaseClient(configuration: .init(url: config.supabaseURL, anonKey: config.supabaseAnonKey))
    }
}
