import Foundation

/// Complete priced flight offer used by flight details.
struct FlightDetails: Equatable, Hashable, Codable, Sendable {
    let searchId: String
    let offerId: String
    let reference: FlightOfferReference
    let offerToken: String
    let source: String?
    let tripType: TripType
    let originCode: String
    let destinationCode: String
    let departureDate: LocalDate
    let returnDate: LocalDate?
    let travelers: TravelerCounts
    let cabinLabel: String
    let airline: AirlineBrand
    let flightNumber: String
    let badge: FlightOfferBadge?
    let price: Money
    let oldPrice: Money?
    let legs: [FlightDetailsLeg]
    let baggage: BaggageSummary
    let fareRules: FareRulesSummary
    let priceBreakdown: PriceBreakdown
    let aircraft: AircraftSummary
    let seat: SeatSummary
    let expiresAt: Date?
    let warnings: [SearchWarning]
    let fareAvailability: FareAvailability?

    /// Creates flight details with optional fare availability.
    init(searchId: String, offerId: String, reference: FlightOfferReference, offerToken: String,
         source: String?, tripType: TripType, originCode: String, destinationCode: String,
         departureDate: LocalDate, returnDate: LocalDate?, travelers: TravelerCounts,
         cabinLabel: String, airline: AirlineBrand, flightNumber: String, badge: FlightOfferBadge?,
         price: Money, oldPrice: Money?, legs: [FlightDetailsLeg], baggage: BaggageSummary,
         fareRules: FareRulesSummary, priceBreakdown: PriceBreakdown, aircraft: AircraftSummary,
         seat: SeatSummary, expiresAt: Date?, warnings: [SearchWarning],
         fareAvailability: FareAvailability? = nil) {
        self.searchId = searchId
        self.offerId = offerId
        self.reference = reference
        self.offerToken = offerToken
        self.source = source
        self.tripType = tripType
        self.originCode = originCode
        self.destinationCode = destinationCode
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.travelers = travelers
        self.cabinLabel = cabinLabel
        self.airline = airline
        self.flightNumber = flightNumber
        self.badge = badge
        self.price = price
        self.oldPrice = oldPrice
        self.legs = legs
        self.baggage = baggage
        self.fareRules = fareRules
        self.priceBreakdown = priceBreakdown
        self.aircraft = aircraft
        self.seat = seat
        self.expiresAt = expiresAt
        self.warnings = warnings
        self.fareAvailability = fareAvailability
    }
}

/// Current availability information for priced fare.
struct FareAvailability: Equatable, Hashable, Codable, Sendable {
    let status: String
    let remainingSeats: Int?
}

/// Displayable itinerary leg and its underlying segments.
struct FlightDetailsLeg: Equatable, Hashable, Codable, Sendable {
    let label: String
    let date: LocalDate
    let departureAirportCode: String
    let departureAirportName: String
    let arrivalAirportCode: String
    let arrivalAirportName: String
    let departureTime: LocalTime
    let arrivalTime: LocalTime
    let durationMinutes: Int
    let stopLabel: String
    let segments: [FlightDetailsSegment]
}

/// One operating segment within flight-details leg.
struct FlightDetailsSegment: Equatable, Hashable, Codable, Sendable {
    let departureAirportCode: String
    let arrivalAirportCode: String
    let layoverMinutes: Int?
    let departureDate: LocalDate?
    let arrivalDate: LocalDate?
    let departureTime: LocalTime?
    let arrivalTime: LocalTime?
    let durationMinutes: Int
    let marketingAirlineName: String
    let operatingAirlineName: String?
    let flightNumber: String
    let operatingFlightNumber: String?
    let equipment: String?
    let cabin: String?
    let bookingClass: String?

    /// Creates segment with Android-equivalent optional-detail defaults.
    init(departureAirportCode: String, arrivalAirportCode: String, layoverMinutes: Int?,
         departureDate: LocalDate? = nil, arrivalDate: LocalDate? = nil,
         departureTime: LocalTime? = nil, arrivalTime: LocalTime? = nil,
         durationMinutes: Int = 0, marketingAirlineName: String = "",
         operatingAirlineName: String? = nil, flightNumber: String = "",
         operatingFlightNumber: String? = nil, equipment: String? = nil,
         cabin: String? = nil, bookingClass: String? = nil) {
        self.departureAirportCode = departureAirportCode
        self.arrivalAirportCode = arrivalAirportCode
        self.layoverMinutes = layoverMinutes
        self.departureDate = departureDate
        self.arrivalDate = arrivalDate
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.durationMinutes = durationMinutes
        self.marketingAirlineName = marketingAirlineName
        self.operatingAirlineName = operatingAirlineName
        self.flightNumber = flightNumber
        self.operatingFlightNumber = operatingFlightNumber
        self.equipment = equipment
        self.cabin = cabin
        self.bookingClass = bookingClass
    }
}

/// Cabin and checked-baggage allowance summary.
struct BaggageSummary: Equatable, Hashable, Codable, Sendable {
    let cabin: String
    let checked: String
    let included: Bool
    let detail: String
    let allowances: [BaggageAllowance]

    init(cabin: String, checked: String, included: Bool, detail: String, allowances: [BaggageAllowance] = []) {
        self.cabin = cabin
        self.checked = checked
        self.included = included
        self.detail = detail
        self.allowances = allowances
    }
}

struct BaggageAllowance: Equatable, Hashable, Codable, Sendable {
    let baggageType: String?
    let inclusion: String
    let quantity: Int?
    let weight: BaggageWeight?
    let passengerTypeCodes: [String]
    let segmentSequences: [Int]
}

struct BaggageWeight: Equatable, Hashable, Codable, Sendable {
    let unit: String
    let value: Double
}

/// Refund, change, cancellation, and detailed fare-rule summary.
struct FareRulesSummary: Equatable, Hashable, Codable, Sendable {
    let refundableLabel: String
    let changeLabel: String
    let cancellationLabel: String
    let sections: [FareRuleSection]

    /// Creates fare rules with no detailed sections by default.
    init(refundableLabel: String, changeLabel: String, cancellationLabel: String,
         sections: [FareRuleSection] = []) {
        self.refundableLabel = refundableLabel
        self.changeLabel = changeLabel
        self.cancellationLabel = cancellationLabel
        self.sections = sections
    }
}

/// Titled group of fare-rule statements.
struct FareRuleSection: Equatable, Hashable, Codable, Sendable {
    let title: String
    let items: [String]
}

/// Itemized monetary total for flight offer.
struct PriceBreakdown: Equatable, Hashable, Codable, Sendable {
    let baseFare: Money
    let taxesAndFees: Money
    let serviceFee: Money?
    let total: Money
}

/// Aircraft and operating-airline summary.
struct AircraftSummary: Equatable, Hashable, Codable, Sendable {
    let aircraftName: String
    let operatingAirline: String
    let note: String
}

/// Current seat choice and availability summary.
struct SeatSummary: Equatable, Hashable, Codable, Sendable {
    let selectedSeat: String?
    let availabilityLabel: String
    let extraLegroomAvailable: Bool
}
