import SwiftUI

struct CourseTextField: View {
    @Binding var text: String
    let suggestions: [String]
    let placeholder: String
    let shouldFocus: Bool
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var isDropdownVisible = false
    @State private var highlightedIndex: Int?
    @FocusState private var hasFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                        setInitialHighlight()
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
                        setInitialHighlight()
                    } else {
                        hasFocus = false
                        isDropdownVisible = false
                        highlightedIndex = nil
                    }
                }
                .onChange(of: text) { _ in
                    resetHighlightIfNeeded()
                }
                .onMoveCommand { direction in
                    guard isDropdownVisible, !filteredSuggestions.isEmpty else { return }
                    switch direction {
                    case .up:
                        moveHighlight(by: -1)
                    case .down:
                        moveHighlight(by: 1)
                    default:
                        break
                    }
                }

            if isDropdownVisible && !filteredSuggestions.isEmpty {
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
            ForEach(Array(filteredSuggestions.enumerated()), id: \.offset) { index, suggestion in
                let isHighlighted = highlightedIndex == index
                Button {
                    text = suggestion
                    onCommit(suggestion)
                    hasFocus = false
                    withAnimation(.easeOut(duration: 0.1)) {
                        isDropdownVisible = false
                    }
                    highlightedIndex = nil
                } label: {
                    Text(suggestion)
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

    private var filteredSuggestions: [String] {
        guard !text.isEmpty else { return suggestions }
        return suggestions.filter { $0.localizedCaseInsensitiveContains(text) }
    }

    private func attemptCommit() {
        if let index = highlightedIndex, filteredSuggestions.indices.contains(index) {
            let suggestion = filteredSuggestions[index]
            text = suggestion
            onCommit(suggestion)
        } else {
            onCommit(text)
        }
        hasFocus = false
        withAnimation(.easeOut(duration: 0.1)) {
            isDropdownVisible = false
        }
        highlightedIndex = nil
    }

    private func setInitialHighlight() {
        highlightedIndex = filteredSuggestions.isEmpty ? nil : 0
    }

    private func resetHighlightIfNeeded() {
        if let index = highlightedIndex, !filteredSuggestions.indices.contains(index) {
            highlightedIndex = filteredSuggestions.isEmpty ? nil : 0
        }
    }

    private func moveHighlight(by delta: Int) {
        guard !filteredSuggestions.isEmpty else {
            highlightedIndex = nil
            return
        }
        let newIndex: Int
        if let current = highlightedIndex {
            newIndex = max(0, min(filteredSuggestions.count - 1, current + delta))
        } else {
            newIndex = delta > 0 ? 0 : filteredSuggestions.count - 1
        }
        highlightedIndex = newIndex
    }
}
