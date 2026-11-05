import Testing
@testable import NexusTravel

@MainActor
struct ExploreViewModelReliabilityTests {
    @Test func destinationSearchCreatesDisplayedRoundTripAndReturnsSearchID() async throws {
        let flights = RecordingFlightSearchRepository(result: .success(searchId: "search-42"))
        let today = try #require(LocalDate(iso8601: "2026-09-20"))
        let viewModel = ExploreDetailViewModel(
            repository: ImmediateExploreRepository(),
            flightSearchRepository: flights,
            today: { today }
        )

        let departure = try #require(LocalDate(iso8601: "2026-09-24"))
        let returning = try #require(LocalDate(iso8601: "2026-09-30"))
        let searchID = await viewModel.searchFlights(to: "DXB", departureDate: departure, returnDate: returning, travelers: TravelerCounts(adults: 3))
        let request = await flights.lastRequest

        #expect(searchID == "search-42")
        #expect(request?.tripType == .roundTrip)
        #expect(request?.originCode == "ADD")
        #expect(request?.destinationCode == "DXB")
        #expect(request?.departureDate == departure)
        #expect(request?.returnDate == returning)
        #expect(request?.travelers == TravelerCounts(adults: 3))
        #expect(request?.cabinClass == .economy)
        #expect(viewModel.searchError == nil)
        #expect(!viewModel.isSearching)
    }

    @Test(arguments: ["DXB", "IST", "NBO"])
    func destinationSearchUsesSelectedAirportCode(_ code: String) async throws {
        let flights = RecordingFlightSearchRepository(result: .success(searchId: "search-42"))
        let today = try #require(LocalDate(iso8601: "2026-09-20"))
        let departure = try #require(LocalDate(iso8601: "2026-09-24"))
        let returning = try #require(LocalDate(iso8601: "2026-09-30"))
        let viewModel = ExploreDetailViewModel(repository: ImmediateExploreRepository(), flightSearchRepository: flights, today: { today })

        _ = await viewModel.searchFlights(to: code, departureDate: departure, returnDate: returning, travelers: TravelerCounts(adults: 3))

        #expect(await flights.lastRequest?.destinationCode == code)
    }

    @Test func loadIfNeededKeepsContentWithoutDuplicateRequest() async throws {
        let repository = ImmediateExploreRepository()
        let viewModel = ExploreViewModel(repository: repository)

        try await viewModel.loadIfNeeded()
        try await viewModel.loadIfNeeded()

        let callCount = await repository.callCount
        #expect(viewModel.state.content != nil)
        #expect(callCount == 1)
    }

    @Test func cancelledOlderLoadDoesNotOverwriteNewerContent() async throws {
        let repository = ControlledExploreRepository()
        let viewModel = ExploreViewModel(repository: repository)
        let first = Task { try await viewModel.load() }
        await repository.waitForCalls(1)
        let second = Task { try await viewModel.load(forceRefresh: true) }
        await repository.waitForCalls(2)

        let content = ExploreContent(banners: [], destinations: [], packages: [])
        await repository.complete(call: 1, with: .success(content))
        try await second.value
        await repository.cancel(call: 0)
        await #expect(throws: CancellationError.self) { try await first.value }

        #expect(viewModel.state.content == content)
        #expect(!viewModel.state.loading)
    }
}

private actor RecordingFlightSearchRepository: FlightSearchRepository {
    let result: FlightSearchResult
    private(set) var lastRequest: FlightSearchRequest?

    init(result: FlightSearchResult) { self.result = result }

    func createSearch(request: FlightSearchRequest) async throws -> FlightSearchResult {
        lastRequest = request
        return result
    }
}

private actor ImmediateExploreRepository: ExploreRepository {
    private(set) var callCount = 0

    func content(forceRefresh: Bool) async throws -> ExploreResult<ExploreContent> {
        callCount += 1
        return .success(ExploreContent(banners: [], destinations: [], packages: []))
    }

    func destination(id: String) async throws -> ExploreResult<ExploreDestinationDetail> { .failed }
    func travelPackage(id: String) async throws -> ExploreResult<ExplorePackageDetail> { .failed }
}

private actor ControlledExploreRepository: ExploreRepository {
    private var calls = 0
    private var completions: [Int: CheckedContinuation<ExploreResult<ExploreContent>, Error>] = [:]
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func content(forceRefresh: Bool) async throws -> ExploreResult<ExploreContent> {
        let call = calls
        calls += 1
        resumeWaiters()
        return try await withCheckedThrowingContinuation { completions[call] = $0 }
    }

    func destination(id: String) async throws -> ExploreResult<ExploreDestinationDetail> { .failed }
    func travelPackage(id: String) async throws -> ExploreResult<ExplorePackageDetail> { .failed }

    func waitForCalls(_ count: Int) async {
        if calls >= count { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func complete(call: Int, with result: ExploreResult<ExploreContent>) {
        completions.removeValue(forKey: call)?.resume(returning: result)
    }

    func cancel(call: Int) {
        completions.removeValue(forKey: call)?.resume(throwing: CancellationError())
    }

    private func resumeWaiters() {
        let ready = waiters.filter { calls >= $0.0 }
        waiters.removeAll { calls >= $0.0 }
        ready.forEach { $0.1.resume() }
    }
}
