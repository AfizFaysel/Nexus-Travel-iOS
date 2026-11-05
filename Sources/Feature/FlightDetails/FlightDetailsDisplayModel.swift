/// Display-ready flight-details summary.
struct FlightDetailsDisplayModel: Equatable, Sendable {
    let title: String
    let airlineName: String
    let airlineLogo: AirlineVisual
    let flightMeta: String
    let dateTravelerMeta: String
    let totalPrice: PriceDisplay
    let legs: [FlightLegDisplay]
    let warning: FlightDetailsWarningDisplay?
}

/// Platform-independent airline visual reference.
enum AirlineVisual: Equatable, Sendable {
    case asset(name: String)
    case fallback
}

/// Display-ready currency and price strings.
struct PriceDisplay: Equatable, Sendable {
    let currency: String
    let amount: String
    let formatted: String
}

/// Display-ready itinerary leg.
struct FlightLegDisplay: Equatable, Sendable {
    let label: String
    let date: String
    let departureAirportCode: String
    let departureAirportName: String
    let arrivalAirportCode: String
    let arrivalAirportName: String
    let departureTime: String
    let arrivalTime: String
    let duration: String
    let stopLabel: String
    let segments: [FlightSegmentDisplay]
}

/// Display-ready segment for a vertical flight timeline.
struct FlightSegmentDisplay: Equatable, Sendable {
    let departureAirportCode: String
    let arrivalAirportCode: String
    let departureTime: String
    let arrivalTime: String
    let detail: String
    let layover: String?
}

/// Non-fatal warning shown with flight details.
struct FlightDetailsWarningDisplay: Equatable, Sendable {
    let message: String
}
