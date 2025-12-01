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
            Group {
                if hasCompletedAuth {
                    AssignmentsListView(
                        viewModel: appState.assignmentsListViewModel,
                        onLogout: {
                            appState.handleLogout()
                            hasCompletedAuth = false
                        }
                    )
                        .frame(minWidth: 720, minHeight: 480)
                } else {
                    AuthFlowView(
                        isAuthenticated: $hasCompletedAuth,
                        authService: appState.authService,
                        onAuthSuccess: { session in
                            appState.handleAuthentication(session: session)
                            hasCompletedAuth = true
                        }
                    )
                }
            }
            .font(Typography.body)
            .foregroundColor(.white)
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
