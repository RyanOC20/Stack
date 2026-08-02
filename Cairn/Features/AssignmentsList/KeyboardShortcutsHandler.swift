import AppKit
import SwiftUI

struct KeyboardShortcutsHandler: NSViewRepresentable {
    struct Handlers {
        let onNew: () -> Void
        let onUndo: () -> Void
        let onRedo: () -> Void
        let onShowShortcuts: () -> Void
        let onDelete: () -> Bool
        let onReturn: () -> Bool
        let onMoveRow: (MoveCommandDirection) -> Void
        let onMoveField: (MoveCommandDirection) -> Void
        let onEscape: (() -> Bool)?
        let shouldCaptureArrows: () -> Bool
    }

    let handlers: Handlers

    func makeNSView(context _: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.handlers = handlers
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context _: Context) {
        nsView.handlers = handlers
    }

    final class KeyCaptureView: NSView {
        var handlers: Handlers? {
            didSet { grabFocusIfEnteringNavigation() }
        }

        private var monitor: Any?
        private var wasNavigating = false

        override var acceptsFirstResponder: Bool {
            true
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else {
                stopMonitoring()
                return
            }
            startMonitoring()
            wasNavigating = false
            grabFocusIfEnteringNavigation()
        }

        override func removeFromSuperview() {
            super.removeFromSuperview()
            stopMonitoring()
        }

        deinit {
            stopMonitoring()
        }

        /// When the app enters navigation mode (not editing a field, quick-add, or the
        /// shortcuts overlay), take first responder so the keyboard works immediately —
        /// without a click — displacing any stray text-field focus left behind by login
        /// or a just-finished edit.
        private func grabFocusIfEnteringNavigation() {
            guard let handlers else { return }
            let navigating = handlers.shouldCaptureArrows()
            defer { wasNavigating = navigating }
            guard navigating, !wasNavigating else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window, window.isKeyWindow else { return }
                let responder = window.firstResponder
                if responder == nil || responder === window || responder is NSTextView {
                    window.makeFirstResponder(self)
                }
            }
        }

        override func keyDown(with _: NSEvent) {
            // Navigation keys are consumed by the local monitor before dispatch reaches
            // here; swallow the rest so navigation mode doesn't beep on stray keys.
        }

        private func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                if self.handle(event: event) {
                    return nil
                }
                return event
            }
        }

        private func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handle(event: NSEvent) -> Bool {
            guard let handlers else { return false }

            if shouldAllowEventToProceed(event) {
                return false
            }

            if handleCharacterKey(event, handlers: handlers) {
                return true
            }

            if handleSpecialKey(event, handlers: handlers) {
                return true
            }

            if event.keyCode == 53 { // Escape
                return handlers.onEscape?() == true
            }

            return false
        }

        /// ⌘-shortcuts and vim-style h/j/k/l navigation, keyed off the typed character.
        private func handleCharacterKey(_ event: NSEvent, handlers: Handlers) -> Bool {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard let character = event.charactersIgnoringModifiers?.lowercased() else { return false }

            if flags == .command {
                return handleCommandKey(character, handlers: handlers)
            }

            // Vim-style navigation: h/j/k/l mirror the arrow keys, but only when
            // we're navigating (not editing) so they don't swallow normal typing.
            if flags.isEmpty, handlers.shouldCaptureArrows() {
                return handleVimNavigationKey(character, handlers: handlers)
            }

            return false
        }

        private func handleCommandKey(_ character: String, handlers: Handlers) -> Bool {
            switch character {
            case "n": handlers.onNew()
            case "z": handlers.onUndo()
            case "y": handlers.onRedo()
            case ",": handlers.onShowShortcuts()
            default: return false
            }
            return true
        }

        private func handleVimNavigationKey(_ character: String, handlers: Handlers) -> Bool {
            switch character {
            case "k": handlers.onMoveRow(.up)
            case "j": handlers.onMoveRow(.down)
            case "h": handlers.onMoveField(.left)
            case "l": handlers.onMoveField(.right)
            default: return false
            }
            return true
        }

        /// Keys exposed through `specialKey`. Returns `false` when the event isn't one of them
        /// (or isn't consumed), so the caller can keep looking (e.g. for Escape by key code).
        private func handleSpecialKey(_ event: NSEvent, handlers: Handlers) -> Bool {
            switch event.specialKey {
            case .delete, .deleteForward:
                return handlers.onDelete()
            case .upArrow:
                return handleArrow(handlers: handlers) { $0.onMoveRow(.up) }
            case .downArrow:
                return handleArrow(handlers: handlers) { $0.onMoveRow(.down) }
            case .leftArrow:
                return handleArrow(handlers: handlers) { $0.onMoveField(.left) }
            case .rightArrow:
                return handleArrow(handlers: handlers) { $0.onMoveField(.right) }
            case .carriageReturn, .enter:
                return handlers.onReturn()
            default:
                return false
            }
        }

        /// Arrow keys only drive navigation when we're not editing a field.
        private func handleArrow(handlers: Handlers, _ action: (Handlers) -> Void) -> Bool {
            guard handlers.shouldCaptureArrows() else { return false }
            action(handlers)
            return true
        }

        private func shouldAllowEventToProceed(_ event: NSEvent) -> Bool {
            // In navigation mode nothing is being edited, so a lingering text-field
            // first responder (left over from a just-finished edit, a new-assignment
            // name entry, or login) must not swallow navigation keys. Capture
            // everything here so h/j/k/l and the arrows re-engage field selection
            // immediately — without first clicking a field.
            if handlers?.shouldCaptureArrows() == true {
                return false
            }

            guard let responder = window?.firstResponder else { return false }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if responder is NSTextView {
                if event.keyCode == 53 { // Escape
                    return false
                }

                // Let normal typing proceed.
                if flags.isEmpty || flags == .shift {
                    return true
                }
            }

            return false
        }
    }
}
