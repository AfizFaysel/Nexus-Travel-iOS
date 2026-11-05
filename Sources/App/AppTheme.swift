import Observation
import SwiftUI

@MainActor
@Observable
final class AppTheme {
    private static let key = "nexus.appearance"
    private let defaults: UserDefaults
    private(set) var preference: ThemePreference

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: Self.key),
           let preference = ThemePreference(rawValue: rawValue) {
            self.preference = preference
        } else {
            let previous = ProfilePreferencesStore.cachedValue(in: defaults).theme
            preference = previous
            defaults.set(previous.rawValue, forKey: Self.key)
        }
    }

    var colorScheme: ColorScheme? {
        switch preference {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func select(_ preference: ThemePreference) {
        guard self.preference != preference else { return }
        defaults.set(preference.rawValue, forKey: Self.key)
        self.preference = preference
    }
}
