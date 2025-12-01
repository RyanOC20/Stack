import SwiftUI

struct AssignmentsListView: View {
    @ObservedObject var viewModel: AssignmentsListViewModel
    var onLogout: () -> Void = {}
    @State private var isQuickAddVisible = false
    @State private var isAccountMenuVisible = false
    @State private var accountMenuHighlightedIndex: Int = 0
    private let accountMenuOptions: [String] = ["Log Out"]
    private let dropdownCommitNotification = Notification.Name("StackDropdownCommit")

    var body: some View {
        ZStack(alignment: .top) {
            ColorPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
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
                                    if viewModel.isNavigatingViaTab {
                                        viewModel.isNavigatingViaTab = false
                                    } else {
                                        viewModel.clearEditingContext()
                                    }
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
                    onNew: { showQuickAddRow() },
                    onUndo: { viewModel.undoDelete() },
                    onDelete: { viewModel.deleteSelectedAssignment() },
                    onReturn: { handleReturnKey() },
                    onMove: { direction in viewModel.moveSelection(direction) },
                    onEscape: { handleEscapeKey() },
                    onTab: { isShiftHeld in handleTabKey(isShiftHeld: isShiftHeld) },
                    shouldCaptureArrows: { shouldCaptureArrowKeys() },
                    onAccountMenu: { toggleAccountMenu() },
                    onArrowNavigation: { direction in handleArrowNavigation(direction) }
                )
            )
            .allowsHitTesting(false)
        )
        .onExitCommand {
            handleEscapeKey()
        }
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
                ForEach(Array(accountMenuOptions.enumerated()), id: \.offset) { index, option in
                    Button {
                        selectAccountMenuOption(at: index)
                    } label: {
                        Text(option)
                            .font(Typography.body)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(accountMenuHighlightedIndex == index ? ColorPalette.rowSelection : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
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
            if !isAccountMenuVisible {
                accountMenuHighlightedIndex = 0
            }
            isAccountMenuVisible.toggle()
        }
    }

    private func moveAccountMenuHighlight(by delta: Int) {
        guard !accountMenuOptions.isEmpty else { return }
        let newIndex = max(0, min(accountMenuOptions.count - 1, accountMenuHighlightedIndex + delta))
        accountMenuHighlightedIndex = newIndex
    }

    private func selectAccountMenuOption(at index: Int) {
        guard accountMenuOptions.indices.contains(index) else { return }
        let option = accountMenuOptions[index]
        switch option {
        case "Log Out":
            isAccountMenuVisible = false
            onLogout()
        default:
            break
        }
    }

    private func handleEscapeKey() -> Bool {
        if isAccountMenuVisible {
            isAccountMenuVisible = false
        }
        viewModel.cancelAllSelectionsAndEditing()
        return true
    }

    private func handleReturnKey() -> Bool {
        if isAccountMenuVisible {
            selectAccountMenuOption(at: accountMenuHighlightedIndex)
            return true
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

        viewModel.beginEditingSelectedAssignmentStatus()
        return true
    }

    private func handleTabKey(isShiftHeld: Bool) -> Bool {
        if viewModel.editingContext != nil {
            if isShiftHeld {
                viewModel.isNavigatingViaTab = true
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
        if isAccountMenuVisible {
            return false
        }
        guard let field = viewModel.editingContext?.field else { return true }
        switch field {
        case .course, .status, .type:
            return false
        default:
            return true
        }
    }

    private func handleArrowNavigation(_ direction: MoveCommandDirection) -> Bool {
        if isAccountMenuVisible {
            switch direction {
            case .up:
                moveAccountMenuHighlight(by: -1)
            case .down:
                moveAccountMenuHighlight(by: 1)
            default:
                break
            }
            return true
        }
        return false
    }
}
