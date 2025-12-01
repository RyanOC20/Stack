import Foundation

enum SupabaseErrorMapper {
    static func map(_ error: Error) -> AppError {
        if let supabaseError = error as? SupabaseErrorResponse {
            let message = supabaseError.message ?? supabaseError.error ?? "Supabase error"
            return AppError(kind: .network, message: message)
        }

        if case SupabaseClient.ClientError.missingSession = error {
            return AppError(kind: .network, message: "Please sign in to continue.")
        }

        return AppError(kind: .network, message: error.localizedDescription)
    }
}
