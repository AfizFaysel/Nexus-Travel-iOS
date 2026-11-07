import Foundation
import Observation

struct SeatSelectionUiState: Equatable, Sendable {
    var loading = true; var saving = false; var segments: [SeatMapSegment] = []
    var activeSegmentIndex = 0; var activePassengerIndex = 0; var passengerCount: Int
    var assignments: [SeatAssignment] = []; var message: String?; var canRetryLoad = false
    var eligiblePassengerIndices: [Int] = []
    var currency: String?

    var feeTotalLabel: String? {
        let priced = assignments.compactMap(\.price)
        guard let currency = currency ?? priced.first?.currency else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let digits = formatter.maximumFractionDigits
        guard (0...6).contains(digits), priced.allSatisfy({ $0.currency == currency }) else { return nil }
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        let amount = Decimal(priced.reduce(0) { $0 + $1.amount }) / pow(Decimal(10), digits)
        return formatter.string(from: amount as NSDecimalNumber).map { "\(currency) \($0)" }
    }
}
enum SeatSelectionNavigation: Equatable, Sendable { case back, review(String) }

@MainActor @Observable
final class SeatSelectionViewModel {
    private(set) var state: SeatSelectionUiState
    private let bookingId: String
    private let repository: any FlightSeatsRepository
    private var navigation: [SeatSelectionNavigation] = []

    init(bookingId: String, passengerCount: Int, repository: any FlightSeatsRepository,
         eligiblePassengerIndices: [Int]? = nil, currency: String? = nil) {
        self.bookingId = bookingId; self.repository = repository
        let count = max(passengerCount, 1)
        state = .init(passengerCount: count)
        state.eligiblePassengerIndices = eligiblePassengerIndices ?? Array(0..<count)
        state.currency = currency
    }

    func load() async throws {
        state.loading = true; state.message = nil; state.canRetryLoad = false
        switch try await repository.load(bookingId: bookingId) {
        case let .success(map):
            state.loading = false; state.segments = map.segments
            state.currency = map.currency ?? state.currency
            if let count = map.passengerCount, count >= 0 { state.passengerCount = count }
            if let travelers = map.travelers {
                state.eligiblePassengerIndices = Array(Set(travelers.filter {
                    $0.seatEligible && $0.passengerIndex >= 0 && $0.passengerIndex < state.passengerCount
                }.map(\.passengerIndex))).sorted()
            }
            state.assignments.removeAll { !state.eligiblePassengerIndices.contains($0.passengerIndex) }
            if !state.eligiblePassengerIndices.contains(state.activePassengerIndex) {
                state.activePassengerIndex = state.eligiblePassengerIndices.first ?? 0
            }
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
    func selectPassenger(_ index: Int) { if state.eligiblePassengerIndices.contains(index) { state.activePassengerIndex = index } }
    func select(_ seat: FlightSeat) {
        guard seat.status == .available || seat.status == .selected,
              state.segments.indices.contains(state.activeSegmentIndex),
              state.eligiblePassengerIndices.contains(state.activePassengerIndex) else { return }
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
