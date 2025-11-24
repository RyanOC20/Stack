import SwiftUI

struct AssignmentsListView: View {
    @ObservedObject var viewModel: AssignmentsListViewModel
    var onLogout: () -> Void = {}
    @State private var isQuickAddVisible = false

    var body: some View {
        ZStack(alignment: .top) {
            ColorPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    logoMenu
                    Spacer()
                    addButton
                }
                .padding(.horizontal, Spacing.contentPadding)
                .padding(.top, Spacing.contentPadding)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.rowSpacing) {
                        if isQuickAddVisible {
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
                                isQuickAddVisible = false
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
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
                                    viewModel.deselect()
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
                    onNew: { showQuickAddRow() },
                    onUndo: { viewModel.undoDelete() },
                    onDelete: { viewModel.deleteSelectedAssignment() },
                    onReturn: { viewModel.beginEditingSelectedAssignmentName() },
                    onMove: { direction in viewModel.moveSelection(direction) }
                )
            )
            .allowsHitTesting(false)
        )
        .onExitCommand {
            guard viewModel.selectedAssignmentID != nil || viewModel.editingContext != nil else { return }
            viewModel.deselect()
        }
    }

    private var addButton: some View {
        Button(action: { showQuickAddRow() }) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(ColorPalette.textPrimary)
                .padding(10)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Add assignment")
    }

    private var logoMenu: some View {
        Menu {
            Button("Log Out") {
                onLogout()
            }
        } label: {
            appIcon
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .padding(10)
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityLabel("Account menu")
    }

    private func showQuickAddRow() {
        withAnimation {
            isQuickAddVisible = true
        }
        viewModel.focusQuickAddRow()
    }

    private var appIcon: Image {
        Image("Medium")
    }
}
