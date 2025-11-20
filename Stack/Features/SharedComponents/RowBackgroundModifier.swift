import SwiftUI

struct RowBackgroundModifier: ViewModifier {
    let isSelected: Bool
    let isDimmed: Bool

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(background)
            .opacity(isDimmed ? 0.55 : 1)
            .onHover { hovering in
                isHovering = hovering
            }
    }

    private var background: some View {
        let color: Color
        if isSelected {
            color = ColorPalette.rowSelection
        } else if isHovering {
            color = ColorPalette.rowHover
        } else {
            color = .clear
        }

        return RoundedRectangle(cornerRadius: Spacing.rowCornerRadius, style: .continuous)
            .fill(color)
    }
}

extension View {
    func rowBackground(isSelected: Bool, isDimmed: Bool) -> some View {
        modifier(RowBackgroundModifier(isSelected: isSelected, isDimmed: isDimmed))
    }
}
