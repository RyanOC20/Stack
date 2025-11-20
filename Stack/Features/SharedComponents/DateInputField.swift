import SwiftUI

struct DateInputField: View {
    let date: Date
    let isEditing: Bool
    let placeholder: String
    let onCommit: (Date) -> Void
    let onCancel: () -> Void

    @State private var text: String = ""
    @State private var hasError = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField(placeholder, text: $text)
                    .font(Typography.body)
                    .textFieldStyle(.plain)
                    .foregroundColor(ColorPalette.textPrimary)
                    .focused($isFocused)
                    .onAppear {
                        text = Self.editFormatter.string(from: date)
                        DispatchQueue.main.async {
                            isFocused = true
                        }
                    }
                    .onSubmit { commit() }
                    .onExitCommand { cancel() }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(hasError ? Color.red : Color.clear, lineWidth: 1)
                    )
            } else {
                Text(Self.displayFormatter.string(from: date))
                    .font(Typography.body)
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .onChange(of: date) { newValue in
            if !isEditing {
                text = Self.editFormatter.string(from: newValue)
            }
        }
    }

    private func commit() {
        guard let parsedDate = Self.editFormatter.date(from: text) else {
            withAnimation { hasError = true }
            return
        }
        hasError = false
        onCommit(parsedDate)
    }

    private func cancel() {
        text = Self.editFormatter.string(from: date)
        hasError = false
        onCancel()
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d    h:mm a"
        return formatter
    }()

    static let editFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy-HH:mm"
        return formatter
    }()
}
