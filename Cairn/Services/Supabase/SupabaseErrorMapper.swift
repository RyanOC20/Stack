import Foundation

enum SupabaseErrorMapper {
    static func map(_ error: Error) -> AppError {
        if let supabaseError = error as? SupabaseErrorResponse {
            var message = supabaseError.message
                ?? supabaseError.errorDescription
                ?? supabaseError.error
                ?? supabaseError.rawBody
                ?? "Supabase error"
            if let status = supabaseError.status {
                message += " (status: \(status))"
            }
            return AppError(kind: .network, message: message)
        }

        if case SupabaseClient.ClientError.missingSession = error {
            return AppError(kind: .network, message: "Please sign in to continue.")
        }

        if let urlError = error as? URLError, isOffline(urlError) {
            return AppError(kind: .network, message: "You appear to be offline. Check your connection and try again.")
        }

        return AppError(kind: .network, message: error.localizedDescription)
    }

    private static func isOffline(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .timedOut, .dataNotAllowed:
            true
        default:
            false
        }
    }
}
