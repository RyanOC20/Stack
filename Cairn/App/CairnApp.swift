import SwiftUI

@main
struct CairnApp: App {
    @AppStorage("hasCompletedAuth") private var hasCompletedAuth = false
    @StateObject private var appState = AppState()
    @State private var showImport = false

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
            .sheet(isPresented: $showImport) {
                if let importViewModel = appState.importViewModel {
                    ImportView(viewModel: importViewModel)
                        .onAppear { importViewModel.reset() }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            if isAuthenticated {
                CommandGroup(replacing: .newItem) {
                    Button("New Assignment") {
                        NotificationCenter.default.post(name: Notification.Name("CairnShowQuickAddRow"), object: nil)
                    }
                    .keyboardShortcut("n", modifiers: .command)

                    Button("Import from Screenshot…") {
                        showImport = true
                    }
                    .keyboardShortcut("i", modifiers: .command)
                    .disabled(appState.importViewModel == nil)
                }

                CommandGroup(after: .undoRedo) {
                    Button("Undo") {
                        appState.assignmentsListViewModel.undo()
                    }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!appState.assignmentsListViewModel.canUndo)

                    Button("Redo") {
                        appState.assignmentsListViewModel.redo()
                    }
                    .keyboardShortcut("y", modifiers: .command)
                    .disabled(!appState.assignmentsListViewModel.canRedo)
                }

                CommandGroup(replacing: .appSettings) {
                    Button("Keyboard Shortcuts") {
                        NotificationCenter.default.post(name: Notification.Name("CairnShowShortcutHelp"), object: nil)
                    }
                    .keyboardShortcut(",", modifiers: .command)
                }
            }
        }
    }
}
