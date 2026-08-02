import Foundation

enum AssignmentType: String, CaseIterable, Identifiable, Codable {
    case homework = "Homework"
    case report = "Report"
    case essay = "Essay"
    case presentation = "Presentation"
    case quiz = "Quiz"
    case exam = "Exam"

    var id: String {
        rawValue
    }

    var displayName: String {
        rawValue
    }

    /// Case-insensitive lookup by user-facing name, used when committing a dropdown value.
    init?(displayName: String) {
        guard let match = Self.allCases.first(where: {
            $0.displayName.caseInsensitiveCompare(displayName) == .orderedSame
        }) else {
            return nil
        }
        self = match
    }
}
