import Foundation

enum FlightDetailsMappingError: Error { case invalidRequiredData }

enum FlightDetailsResponseMapper {
    static func map(_ response: PriceOfferResponseDTO, reference: FlightOfferReference) throws -> FlightDetailsResult {
        switch response.status.uppercased() {
        case "CONFIRMED":
            guard let details = response.details else { return .unknownError }
            return .success(details: try map(details, reference: reference))
        case "PRICE_CHANGED":
            guard let details = response.details, let previous = response.previousTotal else { return .unknownError }
            return .priceChanged(previousTotal: previous.money, updatedDetails: try map(details, reference: reference))
        case "EXPIRED": return .offerExpired
        case "UNAVAILABLE": return .offerUnavailable
        case "AUTH_REQUIRED": return .authRequired
        default: return .unknownError
        }
    }

    private static func map(_ dto: FlightDetailsDTO, reference: FlightOfferReference) throws -> FlightDetails {
        guard let departureDate = LocalDate(iso8601: dto.departureDate),
              let tripType = tripType(dto.tripType),
              let legs = try? dto.legs.map(map) else { throw FlightDetailsMappingError.invalidRequiredData }
        let returnDate = try dto.returnDate.map(requiredDate)
        return FlightDetails(searchId: reference.searchId, offerId: reference.offerId, reference: reference,
            offerToken: reference.offerToken, source: reference.contentSource, tripType: tripType,
            originCode: dto.originCode, destinationCode: dto.destinationCode, departureDate: departureDate,
            returnDate: returnDate, travelers: TravelerCounts(adults: dto.adults, children: dto.children, infants: dto.infants).normalized(),
            cabinLabel: cabinLabel(dto.cabinClass), airline: AirlineBrand(code: airlineCode(dto.flightNumber), name: dto.airlineName ?? "", logoAssetName: dto.airlineLogoKey,
                logoURL: dto.airlineLogoUrl.flatMap(URL.init(string:))),
            flightNumber: dto.flightNumber, badge: badge(dto.badge), price: dto.price.money, oldPrice: dto.oldPrice?.money,
            legs: legs, baggage: .init(cabin: dto.baggage.cabin, checked: dto.baggage.checked,
                included: dto.baggage.included, detail: dto.baggage.detail,
                allowances: (dto.baggage.allowances ?? []).map {
                    .init(baggageType: $0.baggageType, inclusion: $0.inclusion ?? "UNKNOWN",
                        quantity: $0.quantity, weight: $0.weight.map { .init(unit: $0.unit, value: $0.value) },
                        passengerTypeCodes: $0.passengerTypeCodes ?? [], segmentSequences: $0.segmentSequences ?? [])
                }),
            fareRules: .init(refundableLabel: dto.fareRules.refundableLabel, changeLabel: dto.fareRules.changeLabel,
                cancellationLabel: dto.fareRules.cancellationLabel, sections: dto.fareRules.sections.map { .init(title: $0.title, items: $0.items) }),
            priceBreakdown: .init(baseFare: dto.priceBreakdown.baseFare.money, taxesAndFees: dto.priceBreakdown.taxesAndFees.money,
                serviceFee: dto.priceBreakdown.serviceFee?.money, total: dto.priceBreakdown.total.money),
            aircraft: .init(aircraftName: dto.aircraft.aircraftName, operatingAirline: dto.aircraft.operatingAirline ?? "", note: dto.aircraft.note),
            seat: .init(selectedSeat: dto.seat.selectedSeat, availabilityLabel: dto.seat.availabilityLabel, extraLegroomAvailable: dto.seat.extraLegroomAvailable),
            expiresAt: reference.expiresAt, warnings: dto.warnings.map { .init(code: $0.code, message: $0.message) },
            fareAvailability: dto.fareAvailability.map { .init(status: $0.status, remainingSeats: $0.remainingSeats) })
    }

    private static func map(_ dto: FlightDetailsLegDTO) throws -> FlightDetailsLeg {
        guard let date = LocalDate(iso8601: dto.date), let departure = LocalTime(hhmm: String(dto.departureTime.prefix(5))),
              let arrival = LocalTime(hhmm: String(dto.arrivalTime.prefix(5))) else { throw FlightDetailsMappingError.invalidRequiredData }
        return .init(label: dto.label, date: date, departureAirportCode: dto.departureAirportCode, departureAirportName: dto.departureAirportName,
            arrivalAirportCode: dto.arrivalAirportCode, arrivalAirportName: dto.arrivalAirportName, departureTime: departure, arrivalTime: arrival,
            durationMinutes: dto.durationMinutes, stopLabel: dto.stopLabel, segments: try dto.segments.map(map))
    }

    private static func map(_ dto: FlightDetailsSegmentDTO) throws -> FlightDetailsSegment {
        .init(departureAirportCode: dto.departureAirportCode, arrivalAirportCode: dto.arrivalAirportCode, layoverMinutes: dto.layoverAfterMinutes,
            departureDate: try dto.departureDate.map(requiredDate), arrivalDate: try dto.arrivalDate.map(requiredDate),
            departureTime: try dto.departureTime.map(requiredTime), arrivalTime: try dto.arrivalTime.map(requiredTime), durationMinutes: dto.durationMinutes,
            marketingAirlineName: dto.marketingAirlineName ?? "", operatingAirlineName: dto.operatingAirlineName, flightNumber: dto.flightNumber,
            operatingFlightNumber: dto.operatingFlightNumber, equipment: dto.equipment, cabin: dto.cabin, bookingClass: dto.bookingClass)
    }

    private static func requiredDate(_ value: String) throws -> LocalDate { guard let date = LocalDate(iso8601: value) else { throw FlightDetailsMappingError.invalidRequiredData }; return date }
    private static func requiredTime(_ value: String) throws -> LocalTime { guard let time = LocalTime(hhmm: String(value.prefix(5))) else { throw FlightDetailsMappingError.invalidRequiredData }; return time }
    private static func tripType(_ value: String) -> TripType? { switch value.uppercased() { case "ONE_WAY": .oneWay; case "ROUND_TRIP": .roundTrip; case "MULTI_CITY": .multiCity; default: nil } }
    private static func cabinLabel(_ value: String) -> String { switch value.uppercased() { case "PREMIUM_ECONOMY": "Premium Economy"; case "BUSINESS": "Business"; case "FIRST": "First"; default: "Economy" } }
    private static func airlineCode(_ flightNumber: String) -> String { String(flightNumber.prefix { $0.isLetter }).isEmpty ? "AIR" : String(flightNumber.prefix { $0.isLetter }) }
    private static func badge(_ value: String?) -> FlightOfferBadge? { switch value?.uppercased() { case "BEST_VALUE": .bestValue; case "LOWEST_FARE": .lowestFare; case "FASTEST": .fastest; default: nil } }
}

private extension MoneyDTO { var money: Money { .init(amount: amount, currency: currency, formatted: formatted) } }
