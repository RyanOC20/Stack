import SwiftUI

struct QuickAddRowView: View {
    let availableCourses: [String]
    let focusTrigger: UUID
    let onAdd: (AssignmentStatus, String, String, AssignmentType, Date) -> Void

    @State private var status: AssignmentStatus = .notStarted
    @State private var name: String = ""
    @State private var course: String = ""
    @State private var type: AssignmentType = .homework
    @State private var dueDateText: String = DateInputField.editFormatter.string(from: Date().addingTimeInterval(86400))
    @State private var dueDateHasError = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case course
        case dueDate
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.columnSpacing) {
            StatusDropdown(status: status) { value in
                status = value
            }
            .frame(width: AssignmentsListLayout.statusColumnWidth, alignment: .leading)

            TextField("New assignment…", text: $name)
                .font(Typography.assignmentName)
                .textFieldStyle(.plain)
                .foregroundColor(ColorPalette.textPrimary)
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

            TypeDropdown(type: type) { value in
                type = value
            }
            .frame(width: AssignmentsListLayout.typeColumnWidth, alignment: .leading)

            TextField("MM/DD/YYYY-HH:MM", text: $dueDateText)
                .font(Typography.body)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .dueDate)
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
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
        name = ""
        course = ""
        type = .homework
        dueDateText = DateInputField.editFormatter.string(from: Date().addingTimeInterval(86400))
        focusedField = .name
    }
}
