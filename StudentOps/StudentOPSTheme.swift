import SwiftUI
import UIKit

// MARK: - Student OPS Brand Theme
// Single source of truth for all colors — dynamic for Light + Dark.
// Dark palette: #0F172A bg, #1E293B surface, #263449 elevated, #F8FAFC primary text, #CBD5E1 secondary, #94A3B8 muted, #334155 border, #3B82F6 primary, #2563EB dark, #34D399 success, #FBBF24 warning, #F87171 error, #60A5FA pro.

extension Color {
    init(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let scanner = Scanner(string: h)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: h).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}

private func dynamicColor(lightHex: String, darkHex: String) -> Color {
    Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: darkHex) : UIColor(hex: lightHex)
    })
}

private func dynamicColor(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { trait in trait.userInterfaceStyle == .dark ? dark : light })
}

enum StudentOPSTheme {
    // MARK: Primary — mint in light, blue in dark (per dark spec)
    static let primary       = dynamicColor(lightHex: "00C896", darkHex: "3B82F6")
    static let primaryDark   = dynamicColor(lightHex: "087F5B", darkHex: "2563EB")
    static let primaryPressed = dynamicColor(lightHex: "087F5B", darkHex: "2563EB")

    // MARK: Surfaces — per dark palette
    static let background    = dynamicColor(lightHex: "F8FAF9", darkHex: "0F172A")
    static let surface       = dynamicColor(lightHex: "FFFFFF", darkHex: "1E293B")
    static let surfaceHigh   = dynamicColor(lightHex: "F8FAF9", darkHex: "1E293B")
    static let surfaceElevated = dynamicColor(lightHex: "F1F5F9", darkHex: "263449")

    // MARK: Text — per palette
    static let textPrimary   = dynamicColor(lightHex: "17201D", darkHex: "F8FAFC")
    static let textSecondary = dynamicColor(lightHex: "68756F", darkHex: "CBD5E1")
    static let mutedText     = dynamicColor(lightHex: "94A3B8", darkHex: "94A3B8")
    static let textOnPrimary = dynamicColor(light: UIColor(hex: "17201D"), dark: UIColor(hex: "F8FAFC"))
    static let textOnDark    = Color(hex: "F8FAFC")
    static let textOnLime    = Color(hex: "17201D")
    static let textOnWarning = Color(hex: "17201D")
    static let textOnSuccess = Color(hex: "17201D")

    // MARK: Accents
    static let lime          = dynamicColor(lightHex: "B8F36B", darkHex: "B8F36B")
    static let warning       = dynamicColor(lightHex: "FF9F43", darkHex: "FBBF24")
    static let success       = dynamicColor(lightHex: "00A878", darkHex: "34D399")
    static let error         = dynamicColor(lightHex: "E53E3E", darkHex: "F87171")

    // MARK: Borders / Shadows / Disabled
    static let border        = dynamicColor(lightHex: "E6EDEA", darkHex: "334155")
    static let borderSubtle  = dynamicColor(light: UIColor(hex: "E6EDEA").withAlphaComponent(0.6), dark: UIColor(hex: "334155").withAlphaComponent(0.6))
    static let borderStrong  = dynamicColor(lightHex: "E6EDEA", darkHex: "334155")
    static let shadow        = dynamicColor(light: UIColor.black.withAlphaComponent(0.04), dark: UIColor.black.withAlphaComponent(0.2))
    static let shadowMedium  = dynamicColor(light: UIColor.black.withAlphaComponent(0.06), dark: UIColor.black.withAlphaComponent(0.3))
    static let disabled      = dynamicColor(light: UIColor(hex: "68756F").withAlphaComponent(0.4), dark: UIColor(hex: "94A3B8").withAlphaComponent(0.4))

    // MARK: Pro
    static let proAccent     = dynamicColor(lightHex: "60A5FA", darkHex: "60A5FA")

    // MARK: Layout
    static let gutter: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let baseSpacing: CGFloat = 12
    static let heroSpacing: CGFloat = 20
    static let cardSpacing: CGFloat = 12
    static let radiusHero: CGFloat = 16
    static let radiusCard: CGFloat = 12
    static let radiusPill: CGFloat = 8
}

// MARK: - Shared card modifiers
extension View {
    func heroCard() -> some View {
        self.background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusHero))
            .shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
            .overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusHero).stroke(StudentOPSTheme.border.opacity(0.45)))
    }
    func standardCard() -> some View {
        self.background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard).stroke(StudentOPSTheme.border.opacity(0.4)))
    }
    func subtleCard() -> some View {
        self.background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard).stroke(StudentOPSTheme.border.opacity(0.25)))
    }
}

// MARK: - Shared pills
struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text.uppercased())
            .font(DashFont.labelMono())
            .foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct TaxonomyChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DashFont.labelMono())
            .foregroundColor(StudentOPSTheme.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(StudentOPSTheme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(StudentOPSTheme.border.opacity(0.5)))
    }
}
