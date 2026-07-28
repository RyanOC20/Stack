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

        return AppError(kind: .network, message: error.localizedDescription)
    }
}
