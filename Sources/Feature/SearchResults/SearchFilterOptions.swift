import Foundation

/// Constraints applied locally to the current set of offers.
struct SearchFilterOptions: Equatable, Sendable {
    var maximumPriceMinor: Int?
    var departureWindow: FlightTimeWindow?
    var arrivalWindow: FlightTimeWindow?
    var maximumDurationMinutes: Int?

    static func priceMinor(_ text: String) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.wholeMatch(of: /[0-9]+(?:\.[0-9]{1,2})?/) != nil else { return nil }
        let parts = value.split(separator: ".")
        guard let units = Int(parts[0]), units <= (Int.max - 99) / 100 else { return nil }
        let fraction = parts.count == 2 ? Int(String(parts[1]).padding(toLength: 2, withPad: "0", startingAt: 0)) : 0
        let minor = units * 100 + (fraction ?? 0)
        return minor > 0 ? minor : nil
    }

    static func durationMinutes(_ text: String) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let hours = Int(value), hours > 0, hours <= Int.max / 60 else { return nil }
        return hours * 60
    }
}

enum FlightTimeWindow: String, CaseIterable, Sendable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"

    func contains(_ hour: Int) -> Bool {
        switch self {
        case .morning: (5...11).contains(hour)
        case .afternoon: (12...17).contains(hour)
        case .evening: (18...23).contains(hour)
        case .night: (0...4).contains(hour)
        }
    }
}
