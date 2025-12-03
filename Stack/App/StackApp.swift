import SwiftUI

@main
struct StackApp: App {
    @AppStorage("hasCompletedAuth") private var hasCompletedAuth = false
    @StateObject private var appState = AppState()

    private var isAuthenticated: Bool {
        if appState.authService != nil {
            return appState.hasSupabaseSession
        }
        return hasCompletedAuth
    }

    init() {
        FontRegistrar.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
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
            .background(WindowAppearanceConfigurator())
        }
        .commands {
            if isAuthenticated {
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
