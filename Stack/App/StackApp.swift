import SwiftUI

@main
struct StackApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AssignmentsListView(viewModel: appState.assignmentsListViewModel)
                .frame(minWidth: 720, minHeight: 480)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Assignment") {
                    appState.assignmentsListViewModel.focusQuickAddRow()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .undoRedo) {
                Button("Undo Delete") {
                    appState.assignmentsListViewModel.undoDelete()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!appState.assignmentsListViewModel.canUndoDelete)
            }
        }
    }
}
