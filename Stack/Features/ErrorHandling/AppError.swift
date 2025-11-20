import Foundation

struct AppError: Identifiable, Equatable, Error {
    enum Kind {
        case network
        case validation
        case unknown
    }

    let id = UUID()
    let kind: Kind
    let message: String
}
