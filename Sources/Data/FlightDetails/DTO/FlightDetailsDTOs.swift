import Foundation

struct PriceOfferRequestDTO: Encodable, Sendable {
    let searchSessionId: String
    let offerId: String
}

struct PriceOfferResponseDTO: Decodable, Sendable {
    let status: String
    let details: FlightDetailsDTO?
    let previousTotal: MoneyDTO?
}

struct FlightDetailsDTO: Decodable, Sendable {
    let tripType: String
    let originCode: String
    let destinationCode: String
    let departureDate: String
    let returnDate: String?
    let adults: Int
    let children: Int
    let infants: Int
    let cabinClass: String
    let airlineName: String?
    let airlineLogoKey: String?
    let airlineLogoUrl: String?
    let flightNumber: String
    let badge: String?
    let price: MoneyDTO
    let oldPrice: MoneyDTO?
    let legs: [FlightDetailsLegDTO]
    let baggage: BaggageSummaryDTO
    let fareRules: FareRulesSummaryDTO
    let priceBreakdown: PriceBreakdownDTO
    let aircraft: AircraftSummaryDTO
    let seat: SeatSummaryDTO
    let fareAvailability: FareAvailabilityDTO?
    let warnings: [SearchWarningDTO]
}

struct MoneyDTO: Decodable, Sendable { let amount: Int; let currency: String; let formatted: String }
struct SearchWarningDTO: Decodable, Sendable { let code: String; let message: String }
struct FareAvailabilityDTO: Decodable, Sendable { let status: String; let remainingSeats: Int? }
struct BaggageSummaryDTO: Decodable, Sendable {
    let cabin: String
    let checked: String
    let included: Bool
    let detail: String
    let allowances: [BaggageAllowanceDTO]?
}
struct BaggageAllowanceDTO: Decodable, Sendable {
    let baggageType: String?
    let inclusion: String?
    let quantity: Int?
    let weight: BaggageWeightDTO?
    let passengerTypeCodes: [String]?
    let segmentSequences: [Int]?
}
struct BaggageWeightDTO: Decodable, Sendable { let unit: String; let value: Double }
struct FareRuleSectionDTO: Decodable, Sendable { let title: String; let items: [String] }
struct FareRulesSummaryDTO: Decodable, Sendable {
    let refundableLabel: String; let changeLabel: String; let cancellationLabel: String; let sections: [FareRuleSectionDTO]

    private enum CodingKeys: String, CodingKey {
        case refundableLabel, changeLabel, cancellationLabel, sections
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        refundableLabel = try container.decode(String.self, forKey: .refundableLabel)
        changeLabel = try container.decode(String.self, forKey: .changeLabel)
        cancellationLabel = try container.decode(String.self, forKey: .cancellationLabel)
        sections = try container.decodeIfPresent([FareRuleSectionDTO].self, forKey: .sections) ?? []
    }
}
struct PriceBreakdownDTO: Decodable, Sendable { let baseFare: MoneyDTO; let taxesAndFees: MoneyDTO; let serviceFee: MoneyDTO?; let total: MoneyDTO }
struct AircraftSummaryDTO: Decodable, Sendable { let aircraftName: String; let operatingAirline: String?; let note: String }
struct SeatSummaryDTO: Decodable, Sendable { let selectedSeat: String?; let availabilityLabel: String; let extraLegroomAvailable: Bool }

struct FlightDetailsLegDTO: Decodable, Sendable {
    let label: String; let date: String
    let departureAirportCode: String; let departureAirportName: String
    let arrivalAirportCode: String; let arrivalAirportName: String
    let departureTime: String; let arrivalTime: String
    let durationMinutes: Int; let stopLabel: String; let segments: [FlightDetailsSegmentDTO]
}

struct FlightDetailsSegmentDTO: Decodable, Sendable {
    let departureAirportCode: String; let arrivalAirportCode: String; let layoverAfterMinutes: Int?
    let departureDate: String?; let arrivalDate: String?; let departureTime: String?; let arrivalTime: String?
    let durationMinutes: Int; let marketingAirlineName: String?; let operatingAirlineName: String?
    let flightNumber: String; let operatingFlightNumber: String?; let equipment: String?; let cabin: String?; let bookingClass: String?
}
