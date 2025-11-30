import SwiftUI

struct AssignmentsListView: View {
    @ObservedObject var viewModel: AssignmentsListViewModel
    var onLogout: () -> Void = {}
    @State private var isQuickAddVisible = false
    @State private var isAccountMenuVisible = false

    var body: some View {
        ZStack(alignment: .top) {
            ColorPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
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
                                    viewModel.clearEditingContext()
                                },
                                onStatusChange: { status in
                                    viewModel.updateStatus(status, for: assignment)
                                    viewModel.clearEditingContext()
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
                                    viewModel.clearEditingContext()
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

            if isAccountMenuVisible {
                accountMenuOverlay
            }
        }
        .background(ColorPalette.background)
        .overlay(
            KeyboardShortcutsHandler(
                handlers: .init(
                    onNew: { toggleAccountMenu() },
                    onUndo: { viewModel.undoDelete() },
                    onDelete: { viewModel.deleteSelectedAssignment() },
                    onReturn: { handleReturnKey() },
                    onMove: { direction in viewModel.moveSelection(direction) },
                    onEscape: { handleEscapeKey() },
                    onTab: { isShiftHeld in handleTabKey(isShiftHeld: isShiftHeld) },
                    shouldCaptureArrows: { shouldCaptureArrowKeys() }
                )
            )
            .allowsHitTesting(false)
        )
        .onExitCommand {
            handleEscapeKey()
        }
    }

    private var addButton: some View {
        Button(action: { showQuickAddRow() }) {
            Image(systemName: "plus.circle.fill")
                .font(Typography.assignmentName)
                .foregroundColor(.white)
                .padding(10)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Add assignment")
    }

    private func showQuickAddRow() {
        withAnimation {
            isQuickAddVisible = true
        }
        viewModel.focusQuickAddRow()
    }

    private var accountMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isAccountMenuVisible = false
                }

            VStack(spacing: 0) {
                Button {
                    isAccountMenuVisible = false
                    onLogout()
                } label: {
                    Text("Log Out")
                        .font(Typography.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 220)
            .padding(12)
            .background(ColorPalette.rowHover)
            .shadow(radius: 6, y: 3)
        }
        .transition(.opacity)
    }

    private func toggleAccountMenu() {
        withAnimation {
            isAccountMenuVisible.toggle()
        }
    }

    private func handleEscapeKey() -> Bool {
        if isAccountMenuVisible {
            isAccountMenuVisible = false
        }
        viewModel.cancelAllSelectionsAndEditing()
        return true
    }

    private func handleReturnKey() {
        if let editingField = viewModel.editingContext?.field {
            if editingField == .status || editingField == .type {
                viewModel.clearEditingContext()
            }
            return
        }

        if viewModel.selectedAssignmentID == nil {
            viewModel.selectFirstAssignment()
        } else {
            viewModel.beginEditingSelectedAssignmentStatus()
        }
    }

    private func handleTabKey(isShiftHeld: Bool) -> Bool {
        if viewModel.editingContext != nil {
            if isShiftHeld {
                viewModel.beginEditingPreviousField()
            } else {
                viewModel.beginEditingNextField()
            }
            return true
        }

        if viewModel.selectedAssignmentID != nil {
            return true
        }

        return false
    }

    private func shouldCaptureArrowKeys() -> Bool {
        guard let field = viewModel.editingContext?.field else { return true }
        switch field {
        case .course, .status, .type:
            return false
        default:
            return true
        }
    }
}
