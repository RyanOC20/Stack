import SwiftUI

struct CourseTextField: View {
    @Binding var text: String
    let suggestions: [String]
    let placeholder: String
    let shouldFocus: Bool
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var isDropdownVisible = false
    @FocusState private var hasFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $text)
                .font(Typography.body)
                .textFieldStyle(.plain)
                .foregroundColor(ColorPalette.textSecondary)
                .focused($hasFocus)
                .onAppear {
                    if shouldFocus {
                        DispatchQueue.main.async {
                            hasFocus = true
                        }
                    }
                }
                .onSubmit { onCommit(text) }
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

            if isDropdownVisible && !filteredSuggestions.isEmpty {
                dropdown
            }
        }
    }

    private var dropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredSuggestions, id: \.self) { suggestion in
                Button {
                    text = suggestion
                    onCommit(suggestion)
                    hasFocus = false
                    withAnimation(.easeOut(duration: 0.1)) {
                        isDropdownVisible = false
                    }
                } label: {
                    Text(suggestion)
                        .font(Typography.secondary)
                        .foregroundColor(ColorPalette.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .background(ColorPalette.rowHover)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(radius: 4, y: 2)
    }

    private var filteredSuggestions: [String] {
        guard !text.isEmpty else { return suggestions }
        return suggestions.filter { $0.localizedCaseInsensitiveContains(text) }
    }
}
