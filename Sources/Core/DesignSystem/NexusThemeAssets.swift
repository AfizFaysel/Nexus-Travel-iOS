/// Selects the same appearance-specific artwork as Android.
enum NexusThemeAssets {
    static func homeHero(dark: Bool) -> String {
        dark ? "home_hero_flight_wing_night" : "home_hero_flight_wing"
    }
}
