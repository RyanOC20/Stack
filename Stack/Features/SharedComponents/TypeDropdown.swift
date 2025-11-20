import SwiftUI

struct TypeDropdown: View {
    let type: AssignmentType
    let onSelect: (AssignmentType) -> Void

    var body: some View {
        Menu {
            ForEach(AssignmentType.allCases) { value in
                Button(value.displayName) {
                    onSelect(value)
                }
            }
        } label: {
            Text(type.displayName)
                .font(Typography.body)
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(ColorPalette.pillBackground)
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
