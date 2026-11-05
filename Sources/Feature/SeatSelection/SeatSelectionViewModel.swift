import Observation

struct SeatSelectionUiState: Equatable, Sendable {
    var loading = true; var saving = false; var segments: [SeatMapSegment] = []
    var activeSegmentIndex = 0; var activePassengerIndex = 0; let passengerCount: Int
    var assignments: [SeatAssignment] = []; var message: String?; var canRetryLoad = false
}
enum SeatSelectionNavigation: Equatable, Sendable { case back, review(String) }

@MainActor @Observable
final class SeatSelectionViewModel {
    private(set) var state: SeatSelectionUiState
    private let bookingId: String
    private let repository: any FlightSeatsRepository
    private var navigation: [SeatSelectionNavigation] = []

    init(bookingId: String, passengerCount: Int, repository: any FlightSeatsRepository) {
        self.bookingId = bookingId; self.repository = repository
        state = .init(passengerCount: max(passengerCount, 1))
    }

    func load() async throws {
        state.loading = true; state.message = nil; state.canRetryLoad = false
        switch try await repository.load(bookingId: bookingId) {
        case let .success(map):
            state.loading = false; state.segments = map.segments
            state.canRetryLoad = map.availability == .temporarilyUnavailable
            if map.segments.isEmpty {
                state.message = state.canRetryLoad
                    ? "Seat map temporarily unavailable. You can continue without choosing seats."
                    : "Seat selection is unavailable. Airline can assign seats."
            }
        case .temporarilyUnavailable:
            state.loading = false; state.canRetryLoad = true
            state.message = "Seat map unavailable. You can continue without choosing seats."
        case .offerUnavailable:
            state.loading = false; state.message = "This fare is no longer available. Choose another flight."
        default:
            state.loading = false; state.message = "Seat map unavailable. You can continue without choosing seats."
        }
    }

    func selectSegment(_ index: Int) { if state.segments.indices.contains(index) { state.activeSegmentIndex = index } }
    func selectPassenger(_ index: Int) { if (0..<state.passengerCount).contains(index) { state.activePassengerIndex = index } }
    func select(_ seat: FlightSeat) {
        guard seat.status == .available || seat.status == .selected,
              state.segments.indices.contains(state.activeSegmentIndex) else { return }
        let segment = state.segments[state.activeSegmentIndex]
        let passengerIndex = state.activePassengerIndex
        state.assignments.removeAll {
            ($0.passengerIndex == passengerIndex && $0.segmentId == segment.id) ||
            ($0.segmentId == segment.id && $0.seatNumber.caseInsensitiveCompare(seat.number) == .orderedSame)
        }
        state.assignments.append(.init(passengerIndex: passengerIndex, segmentId: segment.id,
                                       seatNumber: seat.number, price: seat.price))
        state.message = nil
    }

    func continueToReview() async throws { try await persist(clear: false) }
    func skip() async throws { try await persist(clear: true) }
    func back() { navigation.append(.back) }
    func consumeNavigation() -> SeatSelectionNavigation? { navigation.isEmpty ? nil : navigation.removeFirst() }

    private func persist(clear: Bool) async throws {
        state.saving = true; state.message = nil; state.canRetryLoad = false
        let result = try await (clear ? repository.clear(bookingId: bookingId) :
                                repository.save(bookingId: bookingId, assignments: state.assignments))
        switch result {
        case .success: navigation.append(.review(bookingId))
        case .offerUnavailable: state.saving = false; state.message = "This fare is no longer available. Choose another flight."
        case .seatUnavailable: state.saving = false; state.message = "Selected seat is no longer available. Choose another seat."
        default: state.saving = false; state.message = clear ? "Could not continue. Please try again." : "Could not save seats. Try again or skip seat selection."
        }
    }
}
