import SwiftUI
import AppKit

struct KeyboardShortcutsHandler: NSViewRepresentable {
    struct Handlers {
        let onNew: () -> Void
        let onUndo: () -> Void
        let onDelete: () -> Void
        let onReturn: () -> Void
        let onMove: (MoveCommandDirection) -> Void
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
                return false
            }
        }

        private func shouldAllowEventToProceed(_ event: NSEvent) -> Bool {
            guard let responder = window?.firstResponder else { return false }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if responder is NSTextView && flags.isEmpty {
                return true
            }
            return false
        }
    }
}
