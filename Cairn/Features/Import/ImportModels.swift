import Foundation

/// A candidate assignment returned by the `extract-assignments` Edge Function,
/// shown in the review sheet before the user confirms it into the list.
struct ExtractedAssignment: Identifiable, Hashable {
    let id: UUID
    var name: String
    var course: String
    var type: AssignmentType
    var dueAt: Date
    var status: AssignmentStatus
    var confidence: Double
    var isIncluded: Bool

    init(id: UUID = UUID(),
         name: String,
         course: String,
         type: AssignmentType,
         dueAt: Date,
         status: AssignmentStatus,
         confidence: Double,
         isIncluded: Bool = true)
    {
        self.id = id
        self.name = name
        self.course = course
        self.type = type
        self.dueAt = dueAt
        self.status = status
        self.confidence = confidence
        self.isIncluded = isIncluded
    }
}

/// Wire form decoded from the Edge Function response. Dates arrive as ISO 8601
/// strings; enum literals match the Postgres/Swift enum raw values.
struct ExtractedAssignmentDTO: Decodable {
    let name: String
    let course: String
    let type: String
    let dueAt: String
    let status: String
    let confidence: Double

    private static let isoWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoWithoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Returns `nil` when the due date can't be parsed, so the candidate is dropped.
    func toModel() -> ExtractedAssignment? {
        guard let dueDate = Self.isoWithFractional.date(from: dueAt)
            ?? Self.isoWithoutFractional.date(from: dueAt)
        else {
            return nil
        }
        return ExtractedAssignment(
            name: name,
            course: course,
            type: AssignmentType(rawValue: type) ?? .homework,
            dueAt: dueDate,
            status: AssignmentStatus(rawValue: status) ?? .notStarted,
            confidence: confidence
        )
    }
}

struct ExtractionResponseDTO: Decodable {
    let assignments: [ExtractedAssignmentDTO]
}
