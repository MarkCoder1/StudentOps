import SwiftUI

// MARK: - Student OPS onboarding theme adapter
// Bridges the design's SOPSTheme tokens to the existing StudentOPSTheme so screens can
// reference SOPSTheme.* while actually using the exact Student OPS brand colors.
// No duplicate hex values, no duplicate Color(hex:) helpers — single source remains StudentOPSTheme.

enum SOPSTheme {
    static var background: Color { StudentOPSTheme.background }
    static var surface: Color { StudentOPSTheme.surface }
    static var elevatedSurface: Color { StudentOPSTheme.surfaceElevated }

    static var textPrimary: Color { StudentOPSTheme.textPrimary }
    static var textSecondary: Color { StudentOPSTheme.textSecondary }
    static var textMuted: Color { StudentOPSTheme.mutedText }

    static var border: Color { StudentOPSTheme.border }

    // Brand primaries — map to existing Student OPS primaries (mint in light, blue in dark)
    // Keeps the whole onboarding in the exact brand palette, supports Light/Dark/System via StudentOPSTheme dynamics.
    static var primaryBlue: Color { StudentOPSTheme.primary }
    static var secondaryBlue: Color { StudentOPSTheme.primaryDark }
    static var success: Color { StudentOPSTheme.success }
    static var proAccent: Color { StudentOPSTheme.proAccent }

    static var danger: Color { StudentOPSTheme.error }
    // Additional helpers used in screens (traffic lights are hardcoded via Color(hex:))
}

enum SOPSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let screenPadding: CGFloat = 24
}

enum SOPSRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let pill: CGFloat = 999
}
