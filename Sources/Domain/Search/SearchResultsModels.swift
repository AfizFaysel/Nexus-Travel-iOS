import Foundation

/// Airline identity and optional logo asset name.
struct AirlineBrand: Equatable, Hashable, Codable, Sendable {
    let code: String
    let name: String
    let logoAssetName: String?
    let logoURL: URL?

    /// Creates airline identity.
    init(code: String, name: String, logoAssetName: String? = nil, logoURL: URL? = nil) {
        self.code = code
        self.name = name
        self.logoAssetName = logoAssetName
        self.logoURL = logoURL
    }
}

/// Stable provider reference required to continue from an offer.
struct FlightOfferReference: Equatable, Hashable, Codable, Sendable {
    let searchId: String
    let offerId: String
    let offerToken: String
    let provider: FlightProvider
    let contentSource: String?
    let responseId: String?
    let productIds: [String]
    let termsAndConditionsId: String?
    let brandRef: String?
    let expiresAt: Date?
}

/// Provider that supplied a flight offer.
enum FlightProvider: String, Equatable, Hashable, Codable, Sendable {
    case nexusFake
    case travelportGds
    case travelportNdc
    case unknown
}

/// Search criteria returned with flight offers.
struct SearchResultsQuerySummary: Equatable, Hashable, Codable, Sendable {
    let searchId: String
    let tripType: TripType
    let originCode: String
    let destinationCode: String
    let departureDate: LocalDate
    let returnDate: LocalDate?
    let travelers: TravelerCounts
    let cabinClass: CabinClass
    let cheapestFirst: Bool
    let legs: [FlightSearchLeg]

    /// Creates query summary with Android-equivalent defaults.
    init(searchId: String, tripType: TripType, originCode: String, destinationCode: String,
         departureDate: LocalDate, returnDate: LocalDate?, travelers: TravelerCounts,
         cabinClass: CabinClass, cheapestFirst: Bool = false, legs: [FlightSearchLeg] = []) {
        self.searchId = searchId
        self.tripType = tripType
        self.originCode = originCode
        self.destinationCode = destinationCode
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.travelers = travelers
        self.cabinClass = cabinClass
        self.cheapestFirst = cheapestFirst
        self.legs = legs
    }
}

/// One priced flight offer.
struct FlightOffer: Equatable, Hashable, Codable, Sendable {
    let id: String
    let reference: FlightOfferReference
    let offerToken: String
    let source: String?
    let airline: AirlineBrand
    let flightNumber: String
    let outbound: FlightLeg
    let inbound: FlightLeg?
    let legs: [FlightLeg]
    let price: Money
    let oldPrice: Money?
    let seatsLeft: Int?
    let badge: FlightOfferBadge?
    let refundable: Bool
    let expiresAt: Date?
    let warnings: [SearchWarning]

    /// Creates offer with Android-equivalent derived defaults.
    init(id: String, reference: FlightOfferReference, offerToken: String? = nil, source: String? = nil,
         airline: AirlineBrand, flightNumber: String, outbound: FlightLeg, inbound: FlightLeg?,
         legs: [FlightLeg]? = nil, price: Money, oldPrice: Money? = nil, seatsLeft: Int?,
         badge: FlightOfferBadge? = nil, refundable: Bool = false, expiresAt: Date? = nil,
         warnings: [SearchWarning] = []) {
        self.id = id
        self.reference = reference
        self.offerToken = offerToken ?? id
        self.source = source
        self.airline = airline
        self.flightNumber = flightNumber
        self.outbound = outbound
        self.inbound = inbound
        self.legs = legs ?? [outbound] + (inbound.map { [$0] } ?? [])
        self.price = price
        self.oldPrice = oldPrice
        self.seatsLeft = seatsLeft
        self.badge = badge
        self.refundable = refundable
        self.expiresAt = expiresAt
        self.warnings = warnings
    }
}

/// One flight segment group between displayed airports.
struct FlightLeg: Equatable, Hashable, Codable, Sendable {
    let departureAirportCode: String
    let arrivalAirportCode: String
    let departureTime: LocalTime
    let arrivalTime: LocalTime
    let durationMinutes: Int
    let stops: [FlightStop]
    let reportedStopCount: Int?

    /// Creates leg with optional reported stop count.
    init(departureAirportCode: String, arrivalAirportCode: String, departureTime: LocalTime,
         arrivalTime: LocalTime, durationMinutes: Int, stops: [FlightStop] = [], reportedStopCount: Int? = nil) {
        self.departureAirportCode = departureAirportCode
        self.arrivalAirportCode = arrivalAirportCode
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.durationMinutes = durationMinutes
        self.stops = stops
        self.reportedStopCount = reportedStopCount
    }

    /// Reported stop count when available, otherwise actual stop count.
    var stopCount: Int { reportedStopCount ?? stops.count }
}

/// Airport stop and layover duration.
struct FlightStop: Equatable, Hashable, Codable, Sendable {
    let airportCode: String
    let layoverMinutes: Int
}

/// Highlight attached to a flight offer.
enum FlightOfferBadge: String, Equatable, Hashable, Codable, Sendable {
    case bestValue
    case lowestFare
    case fastest

    /// User-facing Android-equivalent label.
    var label: String {
        switch self {
        case .bestValue: "Best Value"
        case .lowestFare: "Lowest Fare"
        case .fastest: "Fastest"
        }
    }
}

/// Non-fatal warning attached to search output.
struct SearchWarning: Equatable, Hashable, Codable, Sendable {
    let code: String
    let message: String
}

/// Available search-result filter.
enum SearchFilter: String, Equatable, Hashable, Codable, Sendable {
    case nonStop
    case oneStop
    case morning
    case bestPrice

    /// User-facing Android-equivalent label.
    var label: String {
        switch self {
        case .nonStop: "Non-stop"
        case .oneStop: "1 Stop"
        case .morning: "Morning"
        case .bestPrice: "Best price"
        }
    }
}

/// Available search-result ordering.
enum SortOption: String, Equatable, Hashable, Codable, Sendable {
    case recommended
    case bestPrice
    case fastest
    case departureEarly

    /// User-facing Android-equivalent label.
    var label: String {
        switch self {
        case .recommended: "Sort"
        case .bestPrice: "Best price"
        case .fastest: "Fastest"
        case .departureEarly: "Earliest"
        }
    }

    /// Returns next option in Android cycle order.
    func next() -> SortOption {
        switch self {
        case .recommended: .bestPrice
        case .bestPrice: .fastest
        case .fastest: .departureEarly
        case .departureEarly: .recommended
        }
    }
}

/// Result of loading search offers.
enum SearchResultsResult: Equatable, Sendable {
    case success(querySummary: SearchResultsQuerySummary, offers: [FlightOffer])
    case empty
    case networkUnavailable
    case timeout
    case unknownError
}
