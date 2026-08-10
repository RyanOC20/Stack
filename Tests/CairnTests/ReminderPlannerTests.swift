@testable import Cairn
import XCTest

final class ReminderPlannerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func assignment(name: String, status: AssignmentStatus, dueOffset: TimeInterval) -> Assignment {
        Assignment(status: status, name: name, course: "C", type: .homework, dueAt: now.addingTimeInterval(dueOffset))
    }

    func testSchedulesFutureIncompleteAssignments() {
        let future = assignment(name: "Future", status: .notStarted, dueOffset: 3600)

        let reminders = ReminderPlanner.reminders(for: [future], now: now)

        XCTAssertEqual(reminders.map(\.id), [future.id])
        XCTAssertEqual(reminders.first?.title, "Future")
        XCTAssertEqual(reminders.first?.fireDate, future.dueAt)
    }

    func testSkipsCompletedAndPastAssignments() {
        let completed = assignment(name: "Done", status: .completed, dueOffset: 3600)
        let past = assignment(name: "Overdue", status: .inProgress, dueOffset: -3600)
        let future = assignment(name: "Upcoming", status: .inProgress, dueOffset: 7200)

        let reminders = ReminderPlanner.reminders(for: [completed, past, future], now: now)

        XCTAssertEqual(reminders.map(\.title), ["Upcoming"])
    }
}
