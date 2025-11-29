import SwiftUI

struct QuickAddRowView: View {
    let availableCourses: [String]
    let focusTrigger: UUID
    let onAdd: (AssignmentStatus, String, String, AssignmentType, Date) -> Void

    @State private var status: AssignmentStatus = .notStarted
    @State private var statusText: String = AssignmentStatus.notStarted.displayName
    @State private var name: String = ""
    @State private var course: String = ""
    @State private var type: AssignmentType = .homework
    @State private var typeText: String = AssignmentType.homework.displayName
    @State private var dueDateText: String = QuickAddRowView.formattedDefaultDueDate()
    @State private var dueDateHasError = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case course
        case dueDate
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.columnSpacing) {
            OptionDropdownTextField(
                text: $statusText,
                options: AssignmentStatus.allCases.map { $0.displayName },
                placeholder: "Status…",
                shouldFocus: false,
                onCommit: { value in
                    if let resolved = AssignmentStatus.allCases.first(where: { $0.displayName.caseInsensitiveCompare(value) == .orderedSame }) {
                        status = resolved
                        statusText = resolved.displayName
                    }
                },
                onCancel: {
                    statusText = status.displayName
                }
            )
            .frame(width: AssignmentsListLayout.statusColumnWidth, alignment: .leading)

            TextField("New assignment…", text: $name)
                .font(Typography.assignmentName)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .focused($focusedField, equals: .name)
                .onSubmit { commit() }
                .frame(minWidth: AssignmentsListLayout.nameMinWidth,
                       maxWidth: .infinity,
                       alignment: .leading)

            CourseTextField(
                text: $course,
                suggestions: availableCourses,
                placeholder: "Course…",
                shouldFocus: focusedField == .course,
                onCommit: { _ in
                    commit()
                },
                onCancel: {
                    focusedField = nil
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = .course
            }
            .frame(width: AssignmentsListLayout.courseColumnWidth, alignment: .leading)

            OptionDropdownTextField(
                text: $typeText,
                options: AssignmentType.allCases.map { $0.displayName },
                placeholder: "Type…",
                shouldFocus: false,
                onCommit: { value in
                    if let resolved = AssignmentType.allCases.first(where: { $0.displayName.caseInsensitiveCompare(value) == .orderedSame }) {
                        type = resolved
                        typeText = resolved.displayName
                    }
                },
                onCancel: {
                    typeText = type.displayName
                }
            )
            .frame(width: AssignmentsListLayout.typeColumnWidth, alignment: .leading)

            TextField("MM/DD/YYYY-HH:MM", text: $dueDateText)
                .font(Typography.body)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .dueDate)
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    Rectangle()
                        .stroke(dueDateHasError ? Color.red : Color.clear, lineWidth: 1)
                )
                .onSubmit { commit() }
                .onChange(of: dueDateText) { _ in
                    dueDateHasError = false
                }
                .frame(width: AssignmentsListLayout.dueDateColumnWidth, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .rowBackground(isSelected: false, isDimmed: false)
        .onChange(of: focusTrigger) { _ in
            focusNameField()
        }
    }

    private func focusNameField() {
        focusedField = .name
    }

    private func commit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let dueDate = DateInputField.editFormatter.date(from: dueDateText) else {
            dueDateHasError = true
            focusedField = .dueDate
            return
        }
        dueDateHasError = false
        onAdd(status, trimmedName, course, type, dueDate)
        reset()
    }

    private func reset() {
        status = .notStarted
        statusText = AssignmentStatus.notStarted.displayName
        name = ""
        course = ""
        type = .homework
        typeText = AssignmentType.homework.displayName
        dueDateText = Self.formattedDefaultDueDate()
        focusedField = .name
    }

    private static func formattedDefaultDueDate() -> String {
        DateInputField.editFormatter.string(from: defaultDueDate())
    }

    private static func defaultDueDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 23
        components.minute = 59
        return calendar.date(from: components) ?? tomorrow
    }
}
