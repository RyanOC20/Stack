import Foundation
import SwiftUI

enum AssignmentStatus: String, CaseIterable, Identifiable, Codable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"

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

    var isCompleted: Bool {
        self == .completed
    }

    var textColor: Color {
        Color.white
    }
}
