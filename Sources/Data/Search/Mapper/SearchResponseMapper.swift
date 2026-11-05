import Foundation

/// Fully mapped search payload before cache storage.
struct MappedSearchResponse: Sendable {
    let querySummary: SearchResultsQuerySummary
    let offers: [FlightOffer]
}

/// Strict backend search-response mapper.
enum SearchResponseMapper {
    /// Maps required backend data and rejects invalid timestamps, times, or missing itinerary aggregates.
    static func map(_ response: SearchResponseDTO, request: FlightSearchRequest) throws -> MappedSearchResponse {
        guard parseDate(response.expiresAt) != nil else { throw SearchMappingError.invalidRequiredData }
        let summary = SearchResultsQuerySummary(searchId: response.sessionId, tripType: request.tripType,
            originCode: request.originCode, destinationCode: request.destinationCode,
            departureDate: request.departureDate, returnDate: request.returnDate,
            travelers: request.travelers.normalized(), cabinClass: request.cabinClass,
            cheapestFirst: request.cheapestFirst, legs: request.legs)
        return MappedSearchResponse(querySummary: summary, offers: try response.offers.map { try offer($0, sessionID: response.sessionId) })
    }

    private static func offer(_ dto: SearchOfferDTO, sessionID: String) throws -> FlightOffer {
        guard let itinerary = dto.itinerary, let expiry = parseDate(dto.expiresAt) else {
            throw SearchMappingError.invalidRequiredData
        }
        let responseLegs = itinerary.legs ?? []
        let aggregate = try leg(itinerary)
        let legs = responseLegs.isEmpty ? [aggregate] : try responseLegs.map(leg)
        guard let outbound = legs.first else { throw SearchMappingError.invalidRequiredData }
        let marketing = itinerary.marketingCarrier.trimmingCharacters(in: .whitespacesAndNewlines)
        let validating = dto.validatingCarrier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let carrier = !marketing.isEmpty ? marketing : (!validating.isEmpty ? validating : "Airline")
        let reference = FlightOfferReference(searchId: sessionID, offerId: dto.id, offerToken: dto.id,
            provider: .travelportGds, contentSource: "TRAVELPORT", responseId: nil, productIds: [],
            termsAndConditionsId: nil, brandRef: nil, expiresAt: expiry)
        return FlightOffer(id: dto.id, reference: reference, offerToken: dto.id, source: "TRAVELPORT",
            airline: AirlineBrand(code: carrier, name: dto.airline?.name ?? "", logoAssetName: dto.airline?.logoKey,
                logoURL: dto.airline?.logoUrl.flatMap(URL.init(string:))),
            flightNumber: itinerary.flightNumber, outbound: outbound, inbound: legs.count > 1 ? legs[1] : nil,
            legs: legs, price: Money(amount: dto.totalAmountMinor, currency: dto.currency,
                formatted: formattedMoney(dto.totalAmountMinor, currency: dto.currency)), seatsLeft: dto.fareAvailability?.remainingSeats,
            refundable: false, expiresAt: expiry)
    }

    private static func leg(_ dto: SearchItineraryLegDTO) throws -> FlightLeg {
        guard let departure = parseTime(dto.departureTime), let arrival = parseTime(dto.arrivalTime) else { throw SearchMappingError.invalidRequiredData }
        return FlightLeg(departureAirportCode: dto.departureAirportCode, arrivalAirportCode: dto.arrivalAirportCode,
            departureTime: departure, arrivalTime: arrival, durationMinutes: dto.durationMinutes, reportedStopCount: dto.stopCount)
    }

    private static func leg(_ dto: SearchItineraryDTO) throws -> FlightLeg {
        guard let departure = parseTime(dto.departureTime), let arrival = parseTime(dto.arrivalTime) else { throw SearchMappingError.invalidRequiredData }
        return FlightLeg(departureAirportCode: dto.departureAirportCode, arrivalAirportCode: dto.arrivalAirportCode,
            departureTime: departure, arrivalTime: arrival, durationMinutes: dto.durationMinutes, reportedStopCount: dto.stopCount)
    }

    private static func parseTime(_ value: String) -> LocalTime? {
        guard value.count >= 5 else { return nil }
        return LocalTime(hhmm: String(value.prefix(5)))
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    static func formattedMoney(_ minor: Int, currency: String) -> String {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = currency
        let fractionDigits = currencyFormatter.maximumFractionDigits
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits; formatter.maximumFractionDigits = fractionDigits
        let divisor = NSDecimalNumber(mantissa: 1, exponent: Int16(fractionDigits), isNegative: false)
        let value = NSDecimalNumber(value: minor).dividing(by: divisor)
        return "\(currency) \(formatter.string(from: value) ?? value.stringValue)"
    }
}

enum SearchMappingError: Error { case invalidRequiredData }
