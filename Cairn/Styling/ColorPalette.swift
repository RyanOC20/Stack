import SwiftUI

/// Cairn's visual system: a warm stone-neutral palette, dark mode only, with a
/// single restrained accent (muted lichen green) reserved for selection,
/// due-soon/urgency, and the AI extract action. Everything else stays neutral so
/// the accent reads as the one signature hue.
enum ColorPalette {
    // Warm stone neutrals (dark).
    static let background = Color(red: 28 / 255, green: 27 / 255, blue: 25 / 255)
    static let rowHover = Color(red: 37 / 255, green: 35 / 255, blue: 32 / 255)
    static let rowSelection = Color(red: 48 / 255, green: 45 / 255, blue: 41 / 255)

    // Limestone / bone off-white for primary text; muted stone for secondary.
    static let textPrimary = Color(red: 237 / 255, green: 233 / 255, blue: 225 / 255)
    static let textSecondary = Color(red: 168 / 255, green: 162 / 255, blue: 152 / 255)

    static let pillBackground = Color(red: 237 / 255, green: 233 / 255, blue: 225 / 255).opacity(0.08)

    /// Signature accent — muted lichen green. Use for selection emphasis, the
    /// extract affordance, and completed status.
    static let accent = Color(red: 150 / 255, green: 175 / 255, blue: 133 / 255)
    static let accentMuted = Color(red: 150 / 255, green: 175 / 255, blue: 133 / 255).opacity(0.16)

    // Status / urgency.
    static let statusInProgress = Color(red: 214 / 255, green: 173 / 255, blue: 108 / 255) // warm clay
    static let statusCompleted = accent
    /// Overdue / due-soon warmth (shares the clay tone).
    static let dueSoon = Color(red: 214 / 255, green: 173 / 255, blue: 108 / 255)
}
