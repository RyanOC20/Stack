import SwiftUI
import AppKit

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

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.handlers = handlers
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.handlers = handlers
    }

    final class KeyCaptureView: NSView {
        var handlers: Handlers?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            startMonitoring()
        }

        override func removeFromSuperview() {
            super.removeFromSuperview()
            stopMonitoring()
        }

        deinit {
            stopMonitoring()
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

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command, let character = event.charactersIgnoringModifiers?.lowercased() {
                switch character {
                case "n":
                    handlers.onNew()
                    return true
                case "z":
                    handlers.onUndo()
                    return true
                case "y":
                    handlers.onRedo()
                    return true
                case ",":
                    handlers.onShowShortcuts()
                    return true
                default:
                    break
                }
            }

            switch event.specialKey {
            case .delete, .deleteForward:
                return handlers.onDelete()
            case .upArrow:
                guard handlers.shouldCaptureArrows() else { return false }
                handlers.onMoveRow(.up)
                return true
            case .downArrow:
                guard handlers.shouldCaptureArrows() else { return false }
                handlers.onMoveRow(.down)
                return true
            case .leftArrow:
                guard handlers.shouldCaptureArrows() else { return false }
                handlers.onMoveField(.left)
                return true
            case .rightArrow:
                guard handlers.shouldCaptureArrows() else { return false }
                handlers.onMoveField(.right)
                return true
            case .carriageReturn, .enter:
                return handlers.onReturn()
            default:
                break
            }

            // Handle keys that aren't exposed via specialKey (or to avoid availability issues).
            switch event.keyCode {
            case 53: // Escape
                return handlers.onEscape?() == true
            default:
                return false
            }
        }

        private func shouldAllowEventToProceed(_ event: NSEvent) -> Bool {
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
