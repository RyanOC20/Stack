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
    @State private var statusDraft: String = ""
    @State private var typeDraft: String = ""
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case name
        case course
        case dueDate
        case status
        case type
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

    private var isEditingStatus: Bool {
        editingContext?.assignmentID == assignment.id && editingContext?.field == .status
    }

    private var isEditingType: Bool {
        editingContext?.assignmentID == assignment.id && editingContext?.field == .type
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.columnSpacing) {
            statusField
                .frame(width: AssignmentsListLayout.statusColumnWidth, alignment: .leading)

            nameField
                .frame(minWidth: AssignmentsListLayout.nameMinWidth,
                       maxWidth: .infinity,
                       alignment: .leading)

            courseField
                .frame(width: AssignmentsListLayout.courseColumnWidth, alignment: .leading)

            typeField
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
            statusDraft = assignment.status.displayName
            typeDraft = assignment.type.displayName
        }
        .onChange(of: assignment.id) { _ in
            nameDraft = assignment.name
            courseDraft = assignment.course
            statusDraft = assignment.status.displayName
            typeDraft = assignment.type.displayName
        }
        .onChange(of: isEditingName) { editing in
            if editing {
                nameDraft = assignment.name
                focusedField = .name
            }
        }
        .onChange(of: isEditingCourse) { editing in
            if editing {
                courseDraft = assignment.course
                focusedField = .course
            }
        }
        .onChange(of: isEditingDate) { editing in
            if editing {
                focusedField = .dueDate
            }
        }
        .onChange(of: isEditingStatus) { editing in
            if editing {
                statusDraft = assignment.status.displayName
                focusedField = .status
            }
        }
        .onChange(of: isEditingType) { editing in
            if editing {
                typeDraft = assignment.type.displayName
                focusedField = .type
            }
        }
    }

    private var nameField: some View {
        Group {
            if isEditingName {
                TextField("Assignment name", text: $nameDraft)
                    .font(Typography.assignmentName)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)
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
                    .foregroundColor(assignment.course.isEmpty ? Color.white.opacity(0.7) : .white)
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

    private var statusField: some View {
        Group {
            if isEditingStatus {
                OptionDropdownTextField(
                    text: $statusDraft,
                    options: AssignmentStatus.allCases.map { $0.displayName },
                    placeholder: "Status…",
                    shouldFocus: isEditingStatus,
                    onCommit: { value in
                        if let status = AssignmentStatus.allCases.first(where: { $0.displayName.caseInsensitiveCompare(value) == .orderedSame }) {
                            onStatusChange(status)
                            focusedField = nil
                        }
                    },
                    onCancel: {
                        statusDraft = assignment.status.displayName
                        focusedField = nil
                        onCancelEditing()
                    }
                )
                .focused($focusedField, equals: .status)
            } else {
                Text(assignment.status.displayName)
                    .font(Typography.body)
                    .foregroundColor(.white)
                    .onTapGesture {
                        onSelect()
                        onBeginEditing(.status)
                    }
            }
        }
    }

    private var typeField: some View {
        Group {
            if isEditingType {
                OptionDropdownTextField(
                    text: $typeDraft,
                    options: AssignmentType.allCases.map { $0.displayName },
                    placeholder: "Type…",
                    shouldFocus: isEditingType,
                    onCommit: { value in
                        if let type = AssignmentType.allCases.first(where: { $0.displayName.caseInsensitiveCompare(value) == .orderedSame }) {
                            onTypeChange(type)
                            focusedField = nil
                        }
                    },
                    onCancel: {
                        typeDraft = assignment.type.displayName
                        focusedField = nil
                        onCancelEditing()
                    }
                )
                .focused($focusedField, equals: .type)
            } else {
                Text(assignment.type.displayName)
                    .font(Typography.body)
                    .foregroundColor(.white)
                    .onTapGesture {
                        onSelect()
                        onBeginEditing(.type)
                    }
            }
        }
    }
}
