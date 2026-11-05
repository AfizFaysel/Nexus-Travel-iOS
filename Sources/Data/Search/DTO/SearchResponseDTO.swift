/// Backend search response with required session metadata and offers.
struct SearchResponseDTO: Decodable, Sendable {
    let sessionId: String
    let expiresAt: String
    let offers: [SearchOfferDTO]
}

/// Backend persisted offer response.
struct SearchOfferDTO: Decodable, Sendable {
    let id: String
    let currency: String
    let expiresAt: String
    let feeAmountMinor: Int
    let markupAmountMinor: Int
    let supplierAmountMinor: Int
    let totalAmountMinor: Int
    let validatingCarrier: String?
    let airline: SearchAirlineDTO?
    let fareAvailability: SearchFareAvailabilityDTO?
    let itinerary: SearchItineraryDTO?
}

struct SearchAirlineDTO: Decodable, Sendable { let name: String?; let logoKey: String?; let logoUrl: String? }
struct SearchFareAvailabilityDTO: Decodable, Sendable { let status: String; let remainingSeats: Int? }

struct SearchItineraryDTO: Decodable, Sendable {
    let departureAirportCode: String
    let arrivalAirportCode: String
    let departureTime: String
    let arrivalTime: String
    let durationMinutes: Int
    let marketingCarrier: String
    let flightNumber: String
    let stopCount: Int
    let legs: [SearchItineraryLegDTO]?
}

struct SearchItineraryLegDTO: Decodable, Sendable {
    let departureAirportCode: String
    let arrivalAirportCode: String
    let departureTime: String
    let arrivalTime: String
    let durationMinutes: Int
    let marketingCarrier: String
    let flightNumber: String
    let stopCount: Int
}
