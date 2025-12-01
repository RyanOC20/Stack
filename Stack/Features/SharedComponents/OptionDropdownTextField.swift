import SwiftUI
import AppKit

struct OptionDropdownTextField: View {
    @Binding var text: String
    let options: [String]
    let placeholder: String
    let shouldFocus: Bool
    let isReadOnly: Bool
    let showAllOptions: Bool
    var allowsFreeText: Bool = false
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var isDropdownVisible = false
    @State private var hasError = false
    @State private var highlightedIndex: Int?
    @FocusState private var hasFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldView
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    Rectangle()
                        .stroke(hasError ? Color.red : Color.clear, lineWidth: 1)
                )

            if isDropdownVisible && !filteredOptions.isEmpty {
                dropdown
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StackDropdownCommit"))) { _ in
            if hasFocus {
                attemptCommit()
            }
        }
    }

    private var dropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredOptions, id: \.self) { option in
                let isHighlighted = highlightedOption == option
                Button {
                    commit(option)
                } label: {
                    Text(option)
                        .font(Typography.secondary)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isHighlighted ? ColorPalette.rowSelection : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .background(ColorPalette.rowHover)
        .shadow(radius: 4, y: 2)
    }

    @ViewBuilder
    private var fieldView: some View {
        if isReadOnly {
            readOnlyField
        } else {
            editableField
        }
    }

    private var editableField: some View {
        TextField(placeholder, text: $text)
            .font(Typography.body)
            .textFieldStyle(.plain)
            .foregroundColor(.white)
            .focused($hasFocus)
            .onAppear {
                if shouldFocus {
                    DispatchQueue.main.async {
                        hasFocus = true
                    }
                }
            }
            .onSubmit { attemptCommit() }
            .onChange(of: hasFocus) { newValue in
                withAnimation(.easeOut(duration: 0.15)) {
                    isDropdownVisible = newValue
                }
                if newValue {
                    setInitialHighlight()
                } else {
                    highlightedIndex = nil
                }
            }
            .onExitCommand {
                onCancel()
                hasFocus = false
                isDropdownVisible = false
            }
            .onChange(of: shouldFocus) { value in
                if value {
                    DispatchQueue.main.async {
                        hasFocus = true
                    }
                } else {
                    hasFocus = false
                    isDropdownVisible = false
                }
            }
            .onChange(of: text) { _ in
                hasError = false
                resetHighlightIfNeeded()
            }
            .background(
                ArrowKeyCaptureView(
                    isActive: Binding(
                        get: { hasFocus },
                        set: { _ in }
                    ),
                    onMove: { direction in
                        handleArrowKey(direction)
                    }
                )
            )
    }

    private var readOnlyField: some View {
        Text(displayText)
            .font(Typography.body)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .focusable(true)
            .focused($hasFocus)
            .onAppear {
                if shouldFocus {
                    DispatchQueue.main.async {
                        hasFocus = true
                        openDropdown()
                    }
                }
            }
            .onTapGesture {
                hasFocus = true
                openDropdown()
            }
            .onMoveCommand { direction in
                guard isDropdownVisible, !filteredOptions.isEmpty else { return }
                switch direction {
                case .up:
                    moveHighlight(by: -1)
                case .down:
                    moveHighlight(by: 1)
                default:
                    break
                }
            }
            .onSubmit {
                attemptCommit()
            }
            .onExitCommand {
                onCancel()
                hasFocus = false
                isDropdownVisible = false
            }
    }

    private var displayText: String {
        text.isEmpty ? placeholder : text
    }

    private func attemptCommit() {
        if let highlighted = highlightedOption {
            commit(highlighted)
        } else {
            commit(text)
        }
    }

    private func commit(_ value: String) {
        if allowsFreeText {
            let normalized = normalizedOption(for: value)
            hasError = false
            let finalValue = normalized ?? value
            text = finalValue
            onCommit(finalValue)
            withAnimation(.easeOut(duration: 0.1)) {
                isDropdownVisible = false
            }
            hasFocus = false
        } else {
            guard let normalized = normalizedOption(for: value) else {
                withAnimation {
                    hasError = true
                    isDropdownVisible = true
                }
                hasFocus = true
                return
            }

            hasError = false
            text = normalized
            onCommit(normalized)
            withAnimation(.easeOut(duration: 0.1)) {
                isDropdownVisible = false
            }
            hasFocus = false
        }
    }

    private func normalizedOption(for value: String) -> String? {
        options.first { $0.caseInsensitiveCompare(value) == .orderedSame }
    }

    private var filteredOptions: [String] {
        if showAllOptions {
            return options
        }
        guard !text.isEmpty else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(text) }
    }

    private var highlightedOption: String? {
        guard let index = highlightedIndex, filteredOptions.indices.contains(index) else { return nil }
        return filteredOptions[index]
    }

    private func setInitialHighlight() {
        highlightedIndex = filteredOptions.isEmpty ? nil : 0
    }

    private func resetHighlightIfNeeded() {
        if let index = highlightedIndex, !filteredOptions.indices.contains(index) {
            highlightedIndex = filteredOptions.isEmpty ? nil : 0
        }
    }

    private func moveHighlight(by delta: Int) {
        guard !filteredOptions.isEmpty else {
            highlightedIndex = nil
            return
        }
        let newIndex: Int
        if let current = highlightedIndex {
            newIndex = max(0, min(filteredOptions.count - 1, current + delta))
        } else {
            newIndex = delta > 0 ? 0 : filteredOptions.count - 1
        }
        highlightedIndex = newIndex
    }

    private func openDropdown() {
        withAnimation(.easeOut(duration: 0.15)) {
            isDropdownVisible = true
        }
        setInitialHighlight()
    }

    private func handleArrowKey(_ direction: MoveCommandDirection) {
        guard hasFocus else { return }

        if !isDropdownVisible {
            withAnimation(.easeOut(duration: 0.15)) {
                isDropdownVisible = true
            }
        }

        if highlightedIndex == nil {
            setInitialHighlight()
        }

        switch direction {
        case .up:
            moveHighlight(by: -1)
        case .down:
            moveHighlight(by: 1)
        default:
            break
        }
    }
}

private struct ArrowKeyCaptureView: NSViewRepresentable {
    @Binding var isActive: Bool
    let onMove: (MoveCommandDirection) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(isActive: isActive)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onMove: onMove)
    }

    final class Coordinator {
        private let onMove: (MoveCommandDirection) -> Void
        private var monitor: Any?
        private var isActive = false

        init(onMove: @escaping (MoveCommandDirection) -> Void) {
            self.onMove = onMove
        }

        func attach() {
            update(isActive: isActive)
        }

        func update(isActive: Bool) {
            guard self.isActive != isActive else { return }
            self.isActive = isActive
            if isActive {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }

        private func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                switch event.specialKey {
                case .upArrow:
                    onMove(.up)
                    return nil
                case .downArrow:
                    onMove(.down)
                    return nil
                default:
                    return event
                }
            }
        }

        private func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            stopMonitoring()
        }
    }
}
