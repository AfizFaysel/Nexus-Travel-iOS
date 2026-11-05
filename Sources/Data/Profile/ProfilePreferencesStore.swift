import Foundation

actor ProfilePreferencesStore {
    private static let key = "profile_preferences"
    private let defaults: UserDefaults

    init(suiteName: String? = nil) { defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard }

    func value() -> CustomerPreferences { Self.cachedValue(in: defaults) }

    func save(_ value: CustomerPreferences) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Self.key)
        }
    }

    static func cachedValue(in defaults: UserDefaults) -> CustomerPreferences {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(CustomerPreferences.self, from: data) else {
            return CustomerPreferences()
        }
        return value
    }
}
