/// Airport used by home search and discovery content.
struct Airport: Equatable, Hashable, Codable, Sendable {
    let code: String
    let city: String
    let name: String
    let country: String
    let displayName: String

    /// Creates airport with Android-equivalent default display name.
    init(code: String, city: String, name: String, country: String, displayName: String? = nil) {
        self.code = code
        self.city = city
        self.name = name
        self.country = country
        self.displayName = displayName ?? "\(city) (\(code))"
    }
}

/// Integer monetary amount with server-provided display text.
struct Money: Equatable, Hashable, Codable, Sendable {
    let amount: Int
    let currency: String
    let formatted: String
}

/// Destination promoted on home.
struct TrendingEscape: Equatable, Hashable, Codable, Sendable {
    let id: String
    let airport: Airport
    let tags: [String]
    let startingPrice: Money
    let imageName: String
}

/// Supported flight itinerary shapes.
enum TripType: String, Equatable, Hashable, Codable, Sendable {
    case oneWay
    case roundTrip
    case multiCity
}

/// Supported flight cabin classes.
enum CabinClass: String, Equatable, Hashable, Codable, Sendable {
    case economy
    case premiumEconomy
    case business
    case first

    /// User-facing Android-equivalent cabin label.
    var label: String {
        switch self {
        case .economy: "Economy"
        case .premiumEconomy: "Premium Economy"
        case .business: "Business"
        case .first: "First"
        }
    }
}

/// Adult, child, and infant counts for one flight search.
struct TravelerCounts: Equatable, Hashable, Codable, Sendable {
    /// Maximum travelers accepted by flight search.
    static let maxTravelers = 9

    let adults: Int
    let children: Int
    let infants: Int

    /// Creates traveler counts without implicit normalization.
    init(adults: Int = 1, children: Int = 0, infants: Int = 0) {
        self.adults = adults
        self.children = children
        self.infants = infants
    }

    /// Raw total before normalization.
    var total: Int {
        adults + children + infants
    }

    /// Returns counts constrained using Android ordering and limits.
    func normalized() -> TravelerCounts {
        let safeAdults = min(max(adults, 1), Self.maxTravelers)
        let safeChildren = min(max(children, 0), Self.maxTravelers - safeAdults)
        let remainingSeats = Self.maxTravelers - safeAdults - safeChildren
        let safeInfants = min(min(max(infants, 0), safeAdults), remainingSeats)
        return TravelerCounts(adults: safeAdults, children: safeChildren, infants: safeInfants)
    }

    /// Returns exact adult-first traveler summary copy.
    func summary() -> String {
        var parts = ["\(adults) \(adults == 1 ? "Adult" : "Adults")"]
        if children > 0 {
            parts.append("\(children) \(children == 1 ? "Child" : "Children")")
        }
        if infants > 0 {
            parts.append("\(infants) \(infants == 1 ? "Infant" : "Infants")")
        }
        return parts.joined(separator: " · ")
    }
}

/// Validated top-level flight search query used by home.
struct FlightSearchQuery: Equatable, Hashable, Codable, Sendable {
    let tripType: TripType
    let origin: Airport
    let destination: Airport
    let departureDate: LocalDate
    let returnDate: LocalDate?
    let travelers: TravelerCounts
    let cabinClass: CabinClass
}

/// Home repository content with display-ready strings from Android contract.
struct HomeContent: Equatable, Hashable, Codable, Sendable {
    let origin: Airport
    let destination: Airport
    let departureDate: String
    let returnDate: String
    let travelersLabel: String
    let cabinClass: String
    let trendingEscapes: [TrendingEscape]
}
