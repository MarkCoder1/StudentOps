import SwiftUI

// DashColor removed — migrated to StudentOPSTheme. Kept file for DashFont only.

enum DashFont {
    // Hero 22-24, section 10 mono, card 15 medium, body 13, secondary 11
    static func heroTitle() -> Font { .system(size: 22, weight: .heavy, design: .rounded) }
    static func headlineLgMobile() -> Font { .system(size: 22, weight: .semibold) }
    static func headlineSm() -> Font { .system(size: 18, weight: .semibold) }
    static func titleMd() -> Font { .system(size: 15, weight: .semibold) }
    static func bodyMd() -> Font { .system(size: 14) }
    static func bodySm() -> Font { .system(size: 13) }
    static func labelMd() -> Font { .system(size: 11, weight: .semibold) }
    static func labelMono() -> Font { .system(size: 10, weight: .semibold) }
    static func captionMono() -> Font { .system(size: 10, weight: .medium) }
}
