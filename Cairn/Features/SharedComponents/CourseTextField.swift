import SwiftUI

struct CourseTextField: View {
    @Binding var text: String
    let suggestions: [String]
    let placeholder: String
    let shouldFocus: Bool
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        OptionDropdownTextField(
            text: $text,
            options: suggestions,
            placeholder: placeholder,
            shouldFocus: shouldFocus,
            isReadOnly: false,
            showAllOptions: false,
            allowsFreeText: true,
            onCommit: onCommit,
            onCancel: onCancel
        )
    }
}
