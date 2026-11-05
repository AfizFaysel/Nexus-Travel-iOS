import Foundation

enum TripGroup: String, CaseIterable, Codable, Sendable {
    case actionRequired = "ACTION_REQUIRED", upcoming = "UPCOMING", past = "PAST", cancelled = "CANCELLED"
    var label: String { switch self { case .actionRequired: "In progress"; case .upcoming: "Upcoming"; case .past: "Past"; case .cancelled: "Cancelled" } }
}

struct CustomerTrip: Equatable, Sendable {
    let id: String; let group: TripGroup; let status, paymentStatus, paymentProofStatus, ticketingStatus: String
    let amountMinor: Int?; let currency, holdExpiresAt: String?; let ticketDocumentAvailable: Bool
    let nextAction, createdAt: String; var updatedAt: String? = nil; let itineraryLabel: String
    var segments: [TripSegment] = []; var seats: [TripSeatAssignment] = []; var tickets: [TripTicket] = []
    var offline = false; var fetchedAt: Date? = nil
}
struct TripPage: Equatable, Sendable { let items: [CustomerTrip]; let nextCursor: String? }
enum TripPageState: Equatable, Sendable { case loading; case content(TripPage, offline: Bool, lastUpdated: Date?); case error(String, cached: TripPage? = nil, lastUpdated: Date? = nil) }
struct TripSegment: Equatable, Sendable { let origin, destination, departureTime, arrivalTime, carrier, flightNumber: String?; var flightLabel: String { [carrier, flightNumber].compactMap { $0 }.joined(separator: " ").nilIfEmpty ?? "Flight" } }
struct TripSeatAssignment: Equatable, Sendable { let passengerIndex: Int?; let segmentId: String?; let seatNumber: String }
struct TripTicket: Equatable, Sendable { let ticketNumber: String? }
enum TripDetailResult: Equatable, Sendable { case success(CustomerTrip); case authRequired, notFound, networkUnavailable, failed }
enum TicketDocumentResult: Equatable, Sendable { case success(URL); case authRequired, unavailable, networkUnavailable, unknownError }
enum CachedTicketResult: Equatable, Sendable { case success(URL); case networkUnavailable, storageUnavailable, unknownError }

protocol TripsRepository: Sendable {
    func trips(group: TripGroup, forceRefresh: Bool) async throws -> TripPageState
    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult
    func cacheTicketPdf(id: String, downloadURL: URL) async throws -> CachedTicketResult
}
private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
