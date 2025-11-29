import SwiftUI
import AppKit

struct KeyboardShortcutsHandler: NSViewRepresentable {
    struct Handlers {
        let onNew: () -> Void
        let onUndo: () -> Void
        let onDelete: () -> Void
        let onReturn: () -> Void
        let onMove: (MoveCommandDirection) -> Void
        let onEscape: (() -> Bool)?
        let onTab: ((Bool) -> Bool)?
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
                default:
                    break
                }
            }

            switch event.specialKey {
            case .delete, .deleteForward:
                handlers.onDelete()
                return true
            case .upArrow:
                handlers.onMove(.up)
                return true
            case .downArrow:
                handlers.onMove(.down)
                return true
            case .carriageReturn, .enter:
                handlers.onReturn()
                return true
            default:
                break
            }

            // Handle keys that aren't exposed via specialKey (or to avoid availability issues).
            switch event.keyCode {
            case 53: // Escape
                if handlers.onEscape?() == true {
                    return true
                }
                return false
            case 48: // Tab
                let isShiftHeld = event.modifierFlags.contains(.shift)
                if handlers.onTab?(isShiftHeld) == true {
                    return true
                }
                return false
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
                if event.keyCode == 48 { // Tab / Shift+Tab
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
