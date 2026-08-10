import SwiftUI

struct AssignmentsListView: View {
    @ObservedObject var viewModel: AssignmentsListViewModel
    var onLogout: () -> Void = {}
    @State private var isQuickAddVisible = false
    @State private var isShortcutHelpVisible = false
    @FocusState private var isSearchFocused: Bool
    private let dropdownCommitNotification = Notification.Name("CairnDropdownCommit")
    private let showQuickAddNotification = Notification.Name("CairnShowQuickAddRow")
    private let showShortcutHelpNotification = Notification.Name("CairnShowShortcutHelp")
    private let focusSearchNotification = Notification.Name("CairnFocusSearch")

    var body: some View {
        ZStack(alignment: .top) {
            ColorPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if !viewModel.assignments.isEmpty {
                    searchField
                }
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

                        ForEach(viewModel.displayedAssignments) { assignment in
                            AssignmentRowView(
                                assignment: assignment,
                                isSelected: viewModel.selectedAssignmentID == assignment.id,
                                selectedField: viewModel.selectedAssignmentID == assignment.id ? viewModel.selectedField : nil,
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
                    .padding(.top, 28)
                    .padding(.bottom, Spacing.contentPadding)
                }
            }

            if !isQuickAddVisible {
                if viewModel.assignments.isEmpty {
                    emptyStateView
                } else if viewModel.displayedAssignments.isEmpty {
                    noResultsView
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
        .background(
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
        .onReceive(NotificationCenter.default.publisher(for: focusSearchNotification)) { _ in
            guard !viewModel.assignments.isEmpty else { return }
            isSearchFocused = true
        }
    }

    private func showQuickAddRow() {
        isQuickAddVisible = false
        viewModel.createAssignmentAndBeginEditingName()
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ColorPalette.textSecondary)
            TextField("Search assignments", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .focused($isSearchFocused)
                .onExitCommand {
                    viewModel.searchQuery = ""
                    isSearchFocused = false
                }
            if viewModel.hasActiveSearch {
                Button {
                    viewModel.searchQuery = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .font(Typography.body)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ColorPalette.rowSelection)
        .cornerRadius(8)
        .padding(.horizontal, Spacing.contentPadding)
        .padding(.top, 12)
    }

    private var noResultsView: some View {
        VStack(spacing: 10) {
            Text("No matches")
                .font(Typography.assignmentName)
                .foregroundColor(.white)
            Text("No assignments match “\(viewModel.searchQuery)”.")
                .font(Typography.secondary)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .allowsHitTesting(false)
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Text("No assignments yet")
                .font(Typography.assignmentName)
                .foregroundColor(.white)
            Text("Press ⌘N to add one, or ⌘I to import from a screenshot, photo, URL, or text.")
                .font(Typography.secondary)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .allowsHitTesting(false)
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

                shortcutRow("↑ / ↓ · K / J", "Move selection between assignments while keeping the current column.")
                shortcutRow("← / → · H / L", "Move across fields in the selected row. Wraps at both ends.")
                shortcutRow("Enter", "Start editing selected field, or save changes and exit edit mode.")
                shortcutRow("Esc", "Exit edit mode without saving changes.")
                shortcutRow("Delete", "Delete the selected assignment when not in edit mode.")
                shortcutRow("Cmd + N", "Create a new assignment.")
                shortcutRow("Cmd + I", "Import assignments from a screenshot, photo, URL, or text.")
                shortcutRow("Cmd + Z", "Undo the last action.")
                shortcutRow("Cmd + Y", "Redo the last undone action.")
                shortcutRow("Cmd + ,", "Open this shortcuts help dialog.")

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.vertical, 4)

                Button("Log Out") {
                    isShortcutHelpVisible = false
                    onLogout()
                }
                .buttonStyle(.plain)
                .font(Typography.secondary)
                .foregroundColor(ColorPalette.dueSoon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(ColorPalette.rowSelection)
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

        if isSearchFocused {
            viewModel.searchQuery = ""
            isSearchFocused = false
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
        if isShortcutHelpVisible || isQuickAddVisible || isSearchFocused {
            return false
        }
        return viewModel.editingContext == nil
    }
}
