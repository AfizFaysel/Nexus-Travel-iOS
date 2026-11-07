import Testing
@testable import NexusTravel

@MainActor
struct SeatSelectionViewModelTests {
    @Test func selectingReplacesPassengerSeatAndPreventsDuplicateSeat() async throws {
        let repository = FakeFlightSeatsRepository(map: Self.map)
        let viewModel = SeatSelectionViewModel(bookingId: "booking-1", passengerCount: 2, repository: repository)
        try await viewModel.load()

        viewModel.select(Self.seat("1A"))
        viewModel.selectPassenger(1)
        viewModel.select(Self.seat("1A"))
        viewModel.select(Self.seat("1C"))

        #expect(viewModel.state.assignments == [
            SeatAssignment(passengerIndex: 1, segmentId: "segment-1", seatNumber: "1C", price: nil)
        ])
    }

    @Test func unavailableSeatIsIgnored() async throws {
        let viewModel = SeatSelectionViewModel(
            bookingId: "booking-1", passengerCount: 1, repository: FakeFlightSeatsRepository(map: Self.map)
        )
        try await viewModel.load()
        viewModel.select(Self.seat("1B", status: .occupied))
        #expect(viewModel.state.assignments.isEmpty)
    }

    @Test func onlyTemporarySeatMapFailureOffersRetry() async throws {
        let temporary = SeatSelectionViewModel(
            bookingId: "booking-1", passengerCount: 1,
            repository: SeatLoadResultRepository(result: .temporarilyUnavailable)
        )
        let unavailable = SeatSelectionViewModel(
            bookingId: "booking-1", passengerCount: 1,
            repository: SeatLoadResultRepository(result: .offerUnavailable)
        )
        try await temporary.load()
        try await unavailable.load()
        #expect(temporary.state.canRetryLoad)
        #expect(!unavailable.state.canRetryLoad)
    }

    @Test func serverEligibilityKeepsOriginalIndicesAndBlocksInfants() async throws {
        let map = FlightSeatMap(
            availability: .available, segments: Self.map.segments, currency: "ETB",
            travelers: [.init(passengerIndex: 0, seatEligible: true),
                        .init(passengerIndex: 1, seatEligible: false),
                        .init(passengerIndex: 2, seatEligible: true)]
        )
        let model = SeatSelectionViewModel(
            bookingId: "booking-1", passengerCount: 3, repository: FakeFlightSeatsRepository(map: map)
        )
        try await model.load()
        #expect(model.state.eligiblePassengerIndices == [0, 2])
        model.selectPassenger(2)
        model.selectPassenger(1)
        #expect(model.state.activePassengerIndex == 2)
        model.select(Self.seat("1A"))
        #expect(model.state.assignments.first?.passengerIndex == 2)
        #expect(model.state.feeTotalLabel == "ETB 0.00")
    }

    @Test func emptyEligibilityNeverAllowsSeatAssignment() async throws {
        let map = FlightSeatMap(
            availability: .available, segments: Self.map.segments, currency: "ETB",
            travelers: [.init(passengerIndex: 0, seatEligible: false)]
        )
        let model = SeatSelectionViewModel(
            bookingId: "booking-1", passengerCount: 1, repository: FakeFlightSeatsRepository(map: map)
        )
        try await model.load()
        model.select(Self.seat("1A"))
        #expect(model.state.assignments.isEmpty)
    }

    private static let map = FlightSeatMap(
        availability: .available,
        segments: [.init(id: "segment-1", airlineName: "Nexus Air", aircraftName: "A320", cabins: [
            .init(name: "Economy", columns: ["A", "B", "C"], rows: [
                .init(number: 1, seats: [seat("1A"), seat("1B", status: .occupied), seat("1C")])
            ])
        ])]
    )

    private static func seat(_ number: String, status: FlightSeatStatus = .available) -> FlightSeat {
        FlightSeat(number: number, status: status, position: .window, features: [], price: nil)
    }
}

private actor SeatLoadResultRepository: FlightSeatsRepository {
    let result: FlightSeatsResult
    init(result: FlightSeatsResult) { self.result = result }
    func load(bookingId: String) async throws -> FlightSeatsResult { result }
    func save(bookingId: String, assignments: [SeatAssignment]) async throws -> SaveSeatsResult { .unknownError }
    func clear(bookingId: String) async throws -> SaveSeatsResult { .unknownError }
}

private actor FakeFlightSeatsRepository: FlightSeatsRepository {
    let map: FlightSeatMap
    init(map: FlightSeatMap) { self.map = map }
    func load(bookingId: String) async throws -> FlightSeatsResult { .success(map) }
    func save(bookingId: String, assignments: [SeatAssignment]) async throws -> SaveSeatsResult {
        .success(SeatSelection(assignments: assignments,
                               feeTotal: Money(amount: 0, currency: "USD", formatted: "USD 0.00")))
    }
    func clear(bookingId: String) async throws -> SaveSeatsResult {
        .success(SeatSelection(assignments: [], feeTotal: Money(amount: 0, currency: "USD", formatted: "USD 0.00")))
    }
}
