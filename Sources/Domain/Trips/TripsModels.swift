import Foundation

enum TripGroup: String, CaseIterable, Codable, Sendable {
    case actionRequired = "ACTION_REQUIRED", upcoming = "UPCOMING", past = "PAST", cancelled = "CANCELLED"
    var label: String { switch self { case .actionRequired: "In progress"; case .upcoming: "Upcoming"; case .past: "Past"; case .cancelled: "Cancelled" } }
}

enum TripView: String, CaseIterable, Sendable {
    case active = "ACTIVE"
    case history = "HISTORY"

    var title: String {
        switch self {
        case .active: "Active"
        case .history: "History"
        }
    }
}

enum TripSection: String, Decodable, Sendable {
    case attention = "ATTENTION"
    case inProgress = "IN_PROGRESS"
    case upcoming = "UPCOMING"
    case history = "HISTORY"

    var title: String? {
        switch self {
        case .attention: "Needs attention"
        case .inProgress: "In progress"
        case .upcoming: "Upcoming"
        case .history: nil
        }
    }
}

struct CustomerTrip: Equatable, Sendable {
    let id: String; let group: TripGroup; let status, paymentStatus, paymentProofStatus, ticketingStatus: String
    let amountMinor: Int?; let currency, holdExpiresAt: String?; let ticketDocumentAvailable: Bool
    let nextAction, createdAt: String; var updatedAt: String? = nil; let itineraryLabel: String
    var segments: [TripSegment] = []; var seats: [TripSeatAssignment] = []; var tickets: [TripTicket] = []
    var summary: TripSummary?
    var detail: TripDetail?
    var abandonmentState: BookingAbandonmentState?
    var offline = false; var fetchedAt: Date? = nil
}
struct TripPage: Equatable, Sendable { let items: [CustomerTrip]; let nextCursor: String? }
enum TripPageState: Equatable, Sendable { case loading; case authRequired; case content(TripPage, offline: Bool, lastUpdated: Date?); case error(String, cached: TripPage? = nil, lastUpdated: Date? = nil) }
struct TripSegment: Equatable, Sendable {
    let origin, destination, departureTime, arrivalTime, carrier, flightNumber: String?
    var id: String?
    var legID: String?
    var legIndex: Int?
    var originCity: String?
    var destinationCity: String?
    var departureDate: String?
    var arrivalDate: String?
    var airline: String?
    var operatingCarrier: String?
    var operatingAirline: String?
    var durationMinutes: Int?
    var departureTerminal: String?
    var arrivalTerminal: String?
    var baggage: String?

    var flightLabel: String {
        [carrier, flightNumber].compactMap { $0 }.joined(separator: " ").nilIfEmpty ?? "Flight"
    }
}

struct TripSeatAssignment: Equatable, Sendable {
    let passengerIndex: Int?
    let segmentId: String?
    let seatNumber: String
}

struct TripTicket: Equatable, Sendable {
    let ticketNumber: String?
    var passengerIndices: [Int] = []
    var associationConfidence: String?
    var status: String?
}

struct TripDetail: Equatable, Sendable {
    struct Traveler: Decodable, Equatable, Sendable {
        let passengerIndex: Int
        let displayName: String?
    }

    struct ItineraryChange: Equatable, Sendable {
        let previous: [TripSegment]
        let current: [TripSegment]
    }

    struct TicketDocument: Decodable, Equatable, Sendable {
        let version: String?
        let available: Bool
    }

    enum SeatState: String, Decodable, Equatable, Sendable {
        case notRequested = "NOT_REQUESTED"
        case confirmed = "CONFIRMED"
        case checking = "CHECKING"
        case unresolved = "UNRESOLVED"
    }

    enum ResumeTarget: String, Decodable, Equatable, Sendable {
        case passengers = "PASSENGERS"
        case review = "REVIEW"
        case search = "SEARCH"
    }

    let reference: String?
    let travelerCount: Int?
    let travelers: [Traveler]
    let seatState: SeatState?
    let confirmedChange: ItineraryChange?
    let ticketDocument: TicketDocument?
    let lastSupplierCheckedAt: String?
    let ticketEmailStatus: String?
    let abandonedAt: String?
    var originCode: String?
    var destinationCode: String?
    let resumeTarget: ResumeTarget?
}
enum TripSupplierRefreshResult: Equatable, Sendable {
    case accepted(pending: Bool)
    case authRequired
    case unavailable
    case failed
}

enum TripDetailResult: Equatable, Sendable { case success(CustomerTrip); case authRequired, notFound, networkUnavailable, failed }
enum TicketDocumentResult: Equatable, Sendable { case success(URL); case authRequired, unavailable, networkUnavailable, unknownError }
enum CachedTicketResult: Equatable, Sendable { case success(URL); case previousVersion(URL); case networkUnavailable, storageUnavailable, unknownError }

protocol TripsRepository: Sendable {
    func trips(view: TripView, forceRefresh: Bool, cursor: String?) async throws -> TripPageState
    func requestSupplierRefresh(bookingIDs: [String]) async throws -> TripSupplierRefreshResult
    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult
    func cachedTicketPdf(id: String, version: String?) async throws -> CachedTicketResult?
    func cacheTicketPdf(id: String, downloadURL: URL, version: String?) async throws -> CachedTicketResult
}
private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
