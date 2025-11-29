import SwiftUI

struct OptionDropdownTextField: View {
    @Binding var text: String
    let options: [String]
    let placeholder: String
    let shouldFocus: Bool
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var isDropdownVisible = false
    @State private var hasError = false
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
                    }
                }
                .onSubmit { attemptCommit() }
                .onChange(of: hasFocus) { newValue in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isDropdownVisible = newValue
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
                }
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
    }

    private var dropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredOptions, id: \.self) { option in
                Button {
                    commit(option)
                } label: {
                    Text(option)
                        .font(Typography.secondary)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .background(ColorPalette.rowHover)
        .shadow(radius: 4, y: 2)
    }

    private func attemptCommit() {
        commit(text)
    }

    private func commit(_ value: String) {
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

    private func normalizedOption(for value: String) -> String? {
        options.first { $0.caseInsensitiveCompare(value) == .orderedSame }
    }

    private var filteredOptions: [String] {
        guard !text.isEmpty else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(text) }
    }
}
