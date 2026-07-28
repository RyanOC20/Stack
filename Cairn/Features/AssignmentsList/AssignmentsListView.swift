import SwiftUI

struct AssignmentsListView: View {
    @ObservedObject var viewModel: AssignmentsListViewModel
    var onLogout: () -> Void = {}
    @State private var isQuickAddVisible = false
    @State private var isShortcutHelpVisible = false
    @State private var headerHeight: CGFloat = 0
    private let dropdownCommitNotification = Notification.Name("CairnDropdownCommit")
    private let showQuickAddNotification = Notification.Name("CairnShowQuickAddRow")
    private let showShortcutHelpNotification = Notification.Name("CairnShowShortcutHelp")

    var body: some View {
        ZStack(alignment: .top) {
            ColorPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                }
                .frame(height: max(headerHeight - Spacing.contentPadding, 0))
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
                            .background(
                                Group {
                                    if assignment.id == viewModel.assignments.first?.id {
                                        GeometryReader { proxy in
                                            Color.clear.preference(
                                                key: AssignmentRowHeightPreferenceKey.self,
                                                value: proxy.size.height
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.contentPadding)
                    .padding(.bottom, Spacing.contentPadding)
                    .onPreferenceChange(AssignmentRowHeightPreferenceKey.self) { value in
                        if value > 0, headerHeight == 0 {
                            headerHeight = value
                        }
                    }
                }
            }

            if let message = viewModel.errorMessage {
                ErrorBannerView(message: message)
                    .padding(.top, 12)
                    .onTapGesture {
                        viewModel.dismissError()
                    }
            }

            if isShortcutHelpVisible {
                shortcutHelpOverlay
            }
        }
        .background(ColorPalette.background)
        .overlay(
            KeyboardShortcutsHandler(
                handlers: .init(
                    onNew: { showQuickAddRow() },
                    onUndo: { viewModel.undo() },
                    onRedo: { viewModel.redo() },
                    onShowShortcuts: { isShortcutHelpVisible = true },
                    onDelete: { handleDeleteKey() },
                    onReturn: { handleReturnKey() },
                    onMoveRow: { direction in viewModel.moveSelection(direction) },
                    onMoveField: { direction in viewModel.moveFieldSelection(direction) },
                    onEscape: { handleEscapeKey() },
                    shouldCaptureArrows: { shouldCaptureArrowKeys() }
                )
            )
            .allowsHitTesting(false)
        )
        .onExitCommand {
            handleEscapeKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: showQuickAddNotification)) { _ in
            showQuickAddRow()
        }
        .onReceive(NotificationCenter.default.publisher(for: showShortcutHelpNotification)) { _ in
            isShortcutHelpVisible = true
        }
    }

    private func showQuickAddRow() {
        isQuickAddVisible = false
        viewModel.createAssignmentAndBeginEditingName()
    }

    private var shortcutHelpOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isShortcutHelpVisible = false
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("Keyboard Shortcuts")
                    .font(Typography.body.weight(.semibold))
                    .foregroundColor(.white)

                shortcutRow("Up / Down", "Move selection between assignments while keeping the current column.")
                shortcutRow("Left / Right", "Move across fields in the selected row. Wraps at both ends.")
                shortcutRow("Enter", "Start editing selected field, or save changes and exit edit mode.")
                shortcutRow("Esc", "Exit edit mode without saving changes.")
                shortcutRow("Delete", "Delete the selected assignment when not in edit mode.")
                shortcutRow("Cmd + N", "Create a new assignment.")
                shortcutRow("Cmd + Z", "Undo the last action.")
                shortcutRow("Cmd + Y", "Redo the last undone action.")
                shortcutRow("Cmd + ,", "Open this shortcuts help dialog.")

                HStack {
                    Spacer()
                    Button("Close") {
                        isShortcutHelpVisible = false
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ColorPalette.rowSelection)
                }
            }
            .frame(width: 520)
            .padding(16)
            .background(ColorPalette.rowHover)
            .shadow(radius: 6, y: 3)
        }
        .transition(.opacity)
    }

    private func shortcutRow(_ key: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key)
                .font(Typography.secondary)
                .foregroundColor(.white)
                .frame(width: 96, alignment: .leading)
            Text(description)
                .font(Typography.secondary)
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private func handleDeleteKey() -> Bool {
        guard viewModel.editingContext == nil else { return false }
        guard !isQuickAddVisible else { return false }
        guard viewModel.selectedAssignmentID != nil else { return false }
        viewModel.deleteSelectedAssignment()
        return true
    }

    private func handleEscapeKey() -> Bool {
        if isShortcutHelpVisible {
            isShortcutHelpVisible = false
            return true
        }

        if viewModel.editingContext != nil {
            viewModel.clearEditingContext()
            return true
        }

        if isQuickAddVisible {
            // Keep the quick-add row intact so Esc doesn't discard a new assignment in progress.
            return true
        }

        return false
    }

    private func handleReturnKey() -> Bool {
        if isShortcutHelpVisible {
            isShortcutHelpVisible = false
            return true
        }

        if isQuickAddVisible {
            return false
        }

        if let editingField = viewModel.editingContext?.field {
            switch editingField {
            case .status, .type, .course:
                NotificationCenter.default.post(name: dropdownCommitNotification, object: nil)
                return true
            default:
                return false
            }
        }

        if viewModel.selectedAssignmentID == nil {
            viewModel.selectFirstAssignment()
            return true
        }

        viewModel.beginEditingSelectedField()
        return true
    }

    private func shouldCaptureArrowKeys() -> Bool {
        if isShortcutHelpVisible || isQuickAddVisible {
            return false
        }
        return viewModel.editingContext == nil
    }
}

private struct AssignmentRowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        guard value == 0 else { return }
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}
