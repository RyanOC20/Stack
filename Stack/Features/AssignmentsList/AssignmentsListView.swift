import SwiftUI

struct AssignmentsListView: View {
    @ObservedObject var viewModel: AssignmentsListViewModel

    var body: some View {
        ZStack(alignment: .top) {
            ColorPalette.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.rowSpacing) {
                    QuickAddRowView(
                        availableCourses: viewModel.availableCourses,
                        focusTrigger: viewModel.quickAddFocusTrigger
                    ) { status, name, course, type, dueDate in
                        viewModel.addAssignment(
                            name: name,
                            course: course,
                            type: type,
                            dueAt: dueDate,
                            status: status
                        )
                    }

                    ForEach(viewModel.assignments) { assignment in
                        AssignmentRowView(
                            assignment: assignment,
                            isSelected: viewModel.selectedAssignmentID == assignment.id,
                            availableCourses: viewModel.availableCourses,
                            editingContext: viewModel.editingContext,
                            onSelect: {
                                viewModel.select(assignment.id)
                            },
                            onBeginEditing: { field in
                                viewModel.requestEditing(for: assignment, field: field)
                            },
                            onCancelEditing: {
                                viewModel.clearEditingContext()
                            },
                            onStatusChange: { status in
                                viewModel.updateStatus(status, for: assignment)
                            },
                            onNameCommit: { newName in
                                viewModel.updateName(newName, for: assignment)
                                viewModel.clearEditingContext()
                            },
                            onCourseCommit: { course in
                                viewModel.updateCourse(course, for: assignment)
                                viewModel.clearEditingContext()
                            },
                            onTypeChange: { type in
                                viewModel.updateType(type, for: assignment)
                            },
                            onDueDateCommit: { date in
                                viewModel.updateDueDate(date, for: assignment)
                                viewModel.clearEditingContext()
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.contentPadding)
                .padding(.vertical, Spacing.contentPadding)
            }

            if let message = viewModel.errorMessage {
                ErrorBannerView(message: message)
                    .padding(.top, 12)
                    .onTapGesture {
                        viewModel.dismissError()
                    }
            }
        }
        .background(ColorPalette.background)
        .overlay(
            KeyboardShortcutsHandler(
                handlers: .init(
                    onNew: { viewModel.focusQuickAddRow() },
                    onUndo: { viewModel.undoDelete() },
                    onDelete: { viewModel.deleteSelectedAssignment() },
                    onReturn: { viewModel.beginEditingSelectedAssignmentName() },
                    onMove: { direction in viewModel.moveSelection(direction) }
                )
            )
            .allowsHitTesting(false)
        )
    }
}
