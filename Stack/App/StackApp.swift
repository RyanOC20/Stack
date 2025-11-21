import SwiftUI

@main
struct StackApp: App {
    @AppStorage("hasCompletedAuth") private var hasCompletedAuth = false
    @StateObject private var appState = AppState()

    init() {
        FontRegistrar.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedAuth {
                AssignmentsListView(viewModel: appState.assignmentsListViewModel)
                    .frame(minWidth: 720, minHeight: 480)
            } else {
                AuthFlowView(isAuthenticated: $hasCompletedAuth)
            }
        }
        .commands {
            if hasCompletedAuth {
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
}
