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
                    .monospacedDigit()
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
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
                        Rectangle()
                            .stroke(hasError ? Color.red : Color.clear, lineWidth: 1)
                    )
            } else {
                Text(Self.displayString(from: date))
                    .font(Typography.body)
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
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

    private static func displayString(from date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        let datePart = displayDateFormatter.string(from: date)
        let timePart = displayTimeFormatter.string(from: date)
        let spacerCount = day < 10 ? 4 : 3
        let spacer = String(repeating: " ", count: spacerCount)
        return datePart + spacer + timePart
    }

    static let editFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy-HH:mm"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private static let displayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}
