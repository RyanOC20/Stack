import Foundation
import UserNotifications

/// A single scheduled reminder derived from an assignment.
struct Reminder: Equatable {
    let id: UUID
    let title: String
    let fireDate: Date
}

/// Decides which assignments warrant a reminder. Pure and testable — no system dependency.
enum ReminderPlanner {
    /// Reminders for incomplete assignments whose due date is still in the future.
    static func reminders(for assignments: [Assignment], now: Date) -> [Reminder] {
        assignments.compactMap { assignment in
            guard !assignment.status.isCompleted, assignment.dueAt > now else { return nil }
            return Reminder(id: assignment.id, title: assignment.name, fireDate: assignment.dueAt)
        }
    }
}

protocol ReminderScheduling {
    /// Prompts once for notification permission (no-op if already decided).
    func requestAuthorization()
    /// Reconciles scheduled local notifications to exactly match the current assignments.
    func sync(_ assignments: [Assignment])
}

/// `UNUserNotificationCenter`-backed scheduler. This is the thin, untestable adapter; the
/// scheduling decisions live in `ReminderPlanner`.
final class UserNotificationScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sync(_ assignments: [Assignment]) {
        let desired = ReminderPlanner.reminders(for: assignments, now: Date())
        // Full resync: this app only schedules assignment reminders, so it's safe to clear our
        // pending requests and re-add the desired set. This also handles due-date edits.
        center.getPendingNotificationRequests { [center] pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier))
            for reminder in desired {
                let content = UNMutableNotificationContent()
                content.title = "Assignment due"
                content.body = reminder.title
                content.sound = .default
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: reminder.fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                center.add(UNNotificationRequest(
                    identifier: reminder.id.uuidString,
                    content: content,
                    trigger: trigger
                ))
            }
        }
    }
}
