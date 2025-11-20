import SwiftUI

struct StatusDropdown: View {
    let status: AssignmentStatus
    let onSelect: (AssignmentStatus) -> Void

    var body: some View {
        Menu {
            ForEach(AssignmentStatus.allCases) { value in
                Button(value.displayName) {
                    onSelect(value)
                }
            }
        } label: {
            Text(status.displayName)
                .font(Typography.body)
                .foregroundColor(status.textColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(ColorPalette.pillBackground)
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
