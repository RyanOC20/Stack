import Foundation
import SwiftUI

enum AssignmentStatus: String, CaseIterable, Identifiable, Codable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var isCompleted: Bool {
        self == .completed
    }

    var textColor: Color {
        Color.white
    }
}
