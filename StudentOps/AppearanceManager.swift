import SwiftUI
import Combine

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class AppearanceManager: ObservableObject {
    static let userDefaultsKey = "studentops.appearance"

    @Published var preference: AppearancePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: Self.userDefaultsKey)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.userDefaultsKey) ?? AppearancePreference.system.rawValue
        preference = AppearancePreference(rawValue: raw) ?? .system
    }
}
