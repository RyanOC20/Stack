import SwiftUI

struct RowBackgroundModifier: ViewModifier {
    let isSelected: Bool
    let isDimmed: Bool

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(fullWidthBackground)
            .opacity(isDimmed ? 0.55 : 1)
            .onHover { hovering in
                isHovering = hovering
            }
    }

    // Extend the highlight beyond the list's horizontal padding so it reaches the screen edges.
    private var fullWidthBackground: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(backgroundColor)
                .frame(
                    width: proxy.size.width + (Spacing.contentPadding * 2),
                    height: proxy.size.height
                )
                .offset(x: -Spacing.contentPadding)
        }
        .allowsHitTesting(false)
    }

    private var backgroundColor: Color {
        if isSelected {
            return ColorPalette.rowSelection
        } else if isHovering {
            return ColorPalette.rowHover
        } else {
            return .clear
        }
    }
}

extension View {
    func rowBackground(isSelected: Bool, isDimmed: Bool) -> some View {
        modifier(RowBackgroundModifier(isSelected: isSelected, isDimmed: isDimmed))
    }
}
