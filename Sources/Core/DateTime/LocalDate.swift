import Foundation

/// Calendar date without time or time-zone state.
struct LocalDate: Equatable, Hashable, Codable, Sendable, Comparable {
    /// Gregorian year.
    let year: Int
    /// Gregorian month in `1...12`.
    let month: Int
    /// Gregorian day of month.
    let day: Int

    /// Creates a date when components form a valid Gregorian calendar day.
    init?(year: Int, month: Int, day: Int) {
        guard let date = Self.foundationDate(year: year, month: month, day: day) else {
            return nil
        }
        let components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        guard components.year == year, components.month == month, components.day == day else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses an exact ISO `yyyy-MM-dd` calendar date.
    init?(iso8601: String) {
        let parts = iso8601.split(separator: "-", omittingEmptySubsequences: false)
        guard iso8601.count == 10,
              parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        self.init(year: year, month: month, day: day)
    }

    /// Stable ISO `yyyy-MM-dd` representation.
    var iso8601: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var foundationDate: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    init?(date: Date) {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// Returns date offset by given number of Gregorian calendar days.
    func addingDays(_ days: Int) -> LocalDate? {
        guard let date = Self.foundationDate(year: year, month: month, day: day),
              let result = Self.calendar.date(byAdding: .day, value: days, to: date) else {
            return nil
        }
        let components = Self.calendar.dateComponents([.year, .month, .day], from: result)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return nil
        }
        return LocalDate(year: year, month: month, day: day)
    }

    /// Orders dates chronologically by year, month, then day.
    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Encodes date as one ISO date string.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso8601)
    }

    /// Decodes date from one valid ISO date string.
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let date = LocalDate(iso8601: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected valid ISO yyyy-MM-dd date"
            )
        }
        self = date
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = utc
        }
        return calendar
    }

    private static func foundationDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }
}
