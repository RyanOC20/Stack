import SwiftUI

struct AssignmentRowView: View {
    let assignment: Assignment
    let isSelected: Bool
    let availableCourses: [String]
    let editingContext: AssignmentsListViewModel.EditingContext?

    let onSelect: () -> Void
    let onBeginEditing: (AssignmentsListViewModel.EditingContext.Field) -> Void
    let onCancelEditing: () -> Void
    let onStatusChange: (AssignmentStatus) -> Void
    let onNameCommit: (String) -> Void
    let onCourseCommit: (String) -> Void
    let onTypeChange: (AssignmentType) -> Void
    let onDueDateCommit: (Date) -> Void

    @State private var nameDraft: String = ""
    @State private var courseDraft: String = ""
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case name
        case course
        case dueDate
    }

    private var isEditingName: Bool {
        editingContext?.assignmentID == assignment.id && editingContext?.field == .name
    }

    private var isEditingCourse: Bool {
        editingContext?.assignmentID == assignment.id && editingContext?.field == .course
    }

    private var isEditingDate: Bool {
        editingContext?.assignmentID == assignment.id && editingContext?.field == .dueDate
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.columnSpacing) {
            StatusDropdown(status: assignment.status) { status in
                onSelect()
                onStatusChange(status)
            }
            .frame(width: AssignmentsListLayout.statusColumnWidth, alignment: .leading)

            nameField
                .frame(minWidth: AssignmentsListLayout.nameMinWidth,
                       maxWidth: .infinity,
                       alignment: .leading)

            courseField
                .frame(width: AssignmentsListLayout.courseColumnWidth, alignment: .leading)

            TypeDropdown(type: assignment.type) { type in
                onSelect()
                onTypeChange(type)
            }
            .frame(width: AssignmentsListLayout.typeColumnWidth, alignment: .leading)

            dueDateField
                .frame(width: AssignmentsListLayout.dueDateColumnWidth, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .rowBackground(isSelected: isSelected, isDimmed: assignment.status.isCompleted)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onAppear {
            nameDraft = assignment.name
            courseDraft = assignment.course
        }
        .onChange(of: assignment.id) { _ in
            nameDraft = assignment.name
            courseDraft = assignment.course
        }
        .onChange(of: isEditingName) { editing in
            if editing {
                focusedField = .name
            }
        }
        .onChange(of: isEditingCourse) { editing in
            if editing {
                focusedField = .course
            }
        }
        .onChange(of: isEditingDate) { editing in
            if editing {
                focusedField = .dueDate
            }
        }
    }

    private var nameField: some View {
        Group {
            if isEditingName {
                TextField("Assignment name", text: $nameDraft)
                    .font(Typography.assignmentName)
                    .textFieldStyle(.plain)
                    .foregroundColor(ColorPalette.textPrimary)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        onNameCommit(nameDraft)
                        focusedField = nil
                    }
                    .onExitCommand {
                        nameDraft = assignment.name
                        focusedField = nil
                        onCancelEditing()
                    }
            } else {
                Text(assignment.name)
                    .font(Typography.assignmentName)
                    .foregroundColor(ColorPalette.textPrimary)
                    .onTapGesture {
                        onSelect()
                        onBeginEditing(.name)
                    }
            }
        }
    }

    private var courseField: some View {
        Group {
            if isEditingCourse {
                CourseTextField(
                    text: $courseDraft,
                    suggestions: availableCourses,
                    placeholder: "Course…",
                    shouldFocus: isEditingCourse,
                    onCommit: { value in
                        onCourseCommit(value)
                        focusedField = nil
                    },
                    onCancel: {
                        courseDraft = assignment.course
                        focusedField = nil
                        onCancelEditing()
                    }
                )
                .focused($focusedField, equals: .course)
            } else {
                Text(assignment.course.isEmpty ? "Course…" : assignment.course)
                    .font(Typography.body)
                    .foregroundColor(assignment.course.isEmpty ? ColorPalette.textSecondary.opacity(0.7) : ColorPalette.textSecondary)
                    .onTapGesture {
                        onSelect()
                        onBeginEditing(.course)
                    }
            }
        }
    }

    private var dueDateField: some View {
        DateInputField(
            date: assignment.dueAt,
            isEditing: isEditingDate,
            placeholder: "MM/DD/YYYY-HH:MM",
            onCommit: { date in
                onDueDateCommit(date)
                focusedField = nil
            },
            onCancel: {
                focusedField = nil
                onCancelEditing()
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
            onBeginEditing(.dueDate)
        }
    }
}
