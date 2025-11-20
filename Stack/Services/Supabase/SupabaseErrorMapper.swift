import Foundation

enum SupabaseErrorMapper {
    static func map(_ error: Error) -> AppError {
        AppError(kind: .network, message: error.localizedDescription)
    }
}
