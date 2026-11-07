/// Seat map returned for one booking.
struct FlightSeatMap: Equatable, Sendable {
    let availability: SeatMapAvailability
    let segments: [SeatMapSegment]
    var currency: String? = nil
    var travelers: [SeatMapTraveler]? = nil
    var passengerCount: Int? = nil
}

struct SeatMapTraveler: Equatable, Sendable {
    let passengerIndex: Int
    let seatEligible: Bool
}

enum SeatMapAvailability: Equatable, Sendable { case available, notProvided, notSupported, temporarilyUnavailable }
struct SeatMapSegment: Equatable, Identifiable, Sendable { let id, airlineName, aircraftName: String; let cabins: [SeatCabin] }
struct SeatCabin: Equatable, Sendable { let name: String; let columns: [String]; let rows: [SeatRow] }
struct SeatRow: Equatable, Identifiable, Sendable { let number: Int; let seats: [FlightSeat]; var id: Int { number } }
struct FlightSeat: Equatable, Identifiable, Sendable {
    let number: String; let status: FlightSeatStatus; let position: SeatPosition
    let features: Set<SeatFeature>; let price: Money?
    var id: String { number }
}
enum FlightSeatStatus: Equatable, Sendable { case available, selected, occupied, blocked, restricted }
enum SeatPosition: String, Equatable, Sendable { case window, aisle, middle }
enum SeatFeature: Hashable, Sendable { case extraLegroom, exitRow }
struct SeatAssignment: Equatable, Sendable {
    let passengerIndex: Int; let segmentId, seatNumber: String; let price: Money?
}
struct SeatSelection: Equatable, Sendable { let assignments: [SeatAssignment]; let feeTotal: Money }
enum FlightSeatsResult: Equatable, Sendable {
    case success(FlightSeatMap), authRequired, notFound, offerUnavailable, temporarilyUnavailable
}
enum SaveSeatsResult: Equatable, Sendable {
    case success(SeatSelection), seatUnavailable, offerUnavailable, authRequired, networkUnavailable, unknownError
}

/// Loads and persists optional seat assignments.
protocol FlightSeatsRepository: Sendable {
    func load(bookingId: String) async throws -> FlightSeatsResult
    func save(bookingId: String, assignments: [SeatAssignment]) async throws -> SaveSeatsResult
    func clear(bookingId: String) async throws -> SaveSeatsResult
}
