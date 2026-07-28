import Foundation

enum AssignmentType: String, CaseIterable, Identifiable, Codable {
    case homework = "Homework"
    case report = "Report"
    case essay = "Essay"
    case presentation = "Presentation"
    case quiz = "Quiz"
    case exam = "Exam"

    var id: String { rawValue }

    var displayName: String { rawValue }
}
