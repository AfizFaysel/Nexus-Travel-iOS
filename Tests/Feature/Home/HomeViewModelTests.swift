import Foundation
import Testing
@testable import NexusTravel

@MainActor
struct HomeViewModelTests {
    private var today: LocalDate {
        guard let date = LocalDate(year: 2026, month: 8, day: 29) else {
            preconditionFailure("Fixture date must be valid.")
        }
        return date
    }
    private let add = Airport(code: "ADD", city: "Addis Ababa", name: "Bole", country: "Ethiopia")
    private let dxb = Airport(code: "DXB", city: "Dubai", name: "Dubai International", country: "UAE")

    @Test func loadSuccessUsesGreetingDatesAndContent() async throws {
        let content = HomeContent(origin: add, destination: dxb, departureDate: "ignored", returnDate: "ignored",
                                  travelersLabel: "ignored", cabinClass: "ignored", trendingEscapes: [])
        let model = makeModel(homeResult: .success(content), displayName: "  Afiz Mohamed  ")

        try await model.load()

        #expect(model.uiState.userName == "Afiz")
        #expect(model.uiState.departureDate == today.addingDays(7))
        #expect(model.uiState.returnDate == today.addingDays(14))
        #expect(model.uiState.origin == add)
        #expect(model.uiState.destination == dxb)
        #expect(!model.uiState.isLoading)
    }

    @Test(arguments: [
        (HomeResult<HomeContent>.networkUnavailable, "You are offline. Check your connection and try again."),
        (.unknownError, "We could not load your home page. Please try again.")
    ])
    func loadFailureUsesAirportFallback(_ result: HomeResult<HomeContent>, _ message: String) async throws {
        let model = makeModel(homeResult: result)
        try await model.load()
        #expect(model.uiState.origin == add)
        #expect(model.uiState.destination == dxb)
        #expect(model.uiState.message == message)
    }

    @Test func reloadPreservesServiceAndSheet() async throws {
        let model = makeModel()
        await model.onEvent(.flightClicked)
        await model.onEvent(.originClicked)
        try await model.load()
        #expect(model.uiState.selectedService == .flight)
        #expect(model.uiState.activeSheet == .originAirport)
    }

    @Test func loadIfNeededKeepsEditedFormStateAfterInitialLoad() async throws {
        let model = makeModel()

        try await model.loadIfNeeded()
        await model.onEvent(.tripTypeChanged(.roundTrip))
        try await model.loadIfNeeded()

        #expect(model.uiState.tripType == .roundTrip)
    }

    @Test func retryReplacesLoadErrorWithContent() async throws {
        let content = HomeContent(origin: add, destination: dxb, departureDate: "", returnDate: "",
                                  travelersLabel: "", cabinClass: "", trendingEscapes: [])
        let repository = RetryHomeRepository(results: [.unknownError, .success(content)])
        let model = HomeViewModel(
            homeRepository: repository,
            airportRepository: StubAirportRepository(airports: [add, dxb]),
            flightSearchRepository: StubFlightSearchRepository(result: .unknownError),
            authRepository: StubAuthRepository(displayName: nil),
            today: { self.today }
        )
        try await model.load()
        #expect(model.uiState.loadPhase == .error)
        await model.retry()
        #expect(model.uiState.loadPhase == .empty)
        #expect(model.uiState.message == nil)
    }

    @Test func thrownHomeFailureBecomesStableErrorState() async throws {
        let model = HomeViewModel(
            homeRepository: ThrowingHomeRepository(),
            airportRepository: StubAirportRepository(airports: [add, dxb]),
            flightSearchRepository: StubFlightSearchRepository(result: .unknownError),
            authRepository: StubAuthRepository(displayName: nil),
            today: { self.today }
        )
        try await model.load()
        #expect(model.uiState.loadPhase == .error)
        #expect(model.uiState.message == "We could not load your home page. Please try again.")
    }

    @Test func eventsCoverTripAirportDateTravelerAndCabinTransitions() async throws {
        let model = makeModel()
        try await model.load()
        await model.onEvent(.tripTypeChanged(.roundTrip))
        await model.onEvent(.swapAirportsClicked)
        let newDeparture = try #require(today.addingDays(20))
        await model.onEvent(.departureDateSelected(newDeparture))
        await model.onEvent(.travelersChanged(TravelerCounts(adults: 2, children: 2, infants: 3), childAges: [4, 7], infantAges: [0, 1, 1]))
        await model.onEvent(.cabinClassChanged(.business))
        #expect(model.uiState.origin == dxb)
        #expect(model.uiState.destination == add)
        #expect(model.uiState.returnDate == today.addingDays(27))
        #expect(model.uiState.travelers == TravelerCounts(adults: 2, children: 2, infants: 2))
        #expect(model.uiState.infantAges == [0, 1])
        #expect(model.uiState.cabinClass == .business)
    }

    @Test func airportSelectionFlagsSameRouteAndDismissClearsQuery() async throws {
        let model = makeModel()
        try await model.load()
        await model.onEvent(.originClicked)
        await model.onEvent(.airportQueryChanged("dub"))
        await model.onEvent(.airportSelected(dxb))
        #expect(model.uiState.validationError == .sameOriginDestination)
        await model.onEvent(.destinationClicked)
        await model.onEvent(.dismissSheet)
        #expect(model.uiState.airportQuery.isEmpty)
        #expect(model.uiState.activeSheet == nil)
    }

    @Test func staleAirportResponseCannotOverwriteLatestQuery() async throws {
        let repository = ControllableAirportRepository(popular: [add, dxb])
        let content = HomeContent(origin: add, destination: dxb, departureDate: "", returnDate: "",
                                  travelersLabel: "", cabinClass: "", trendingEscapes: [])
        let model = HomeViewModel(
            homeRepository: StubHomeRepository(result: .success(content)),
            airportRepository: repository,
            flightSearchRepository: StubFlightSearchRepository(result: .unknownError),
            authRepository: StubAuthRepository(displayName: nil),
            today: { self.today }
        )
        try await model.load()
        let first = Task { await model.onEvent(.airportQueryChanged("a")) }
        await repository.waitUntilStarted(query: "a")
        let second = Task { await model.onEvent(.airportQueryChanged("ab")) }
        await repository.waitUntilStarted(query: "ab")
        await repository.resolve(query: "ab", airports: [dxb])
        await second.value
        await repository.resolve(query: "a", airports: [add])
        await first.value
        #expect(model.uiState.airports == [dxb])
    }

    @Test func successfulSearchEmitsTypedNavigationOnce() async throws {
        let model = makeModel(searchResult: .success(searchId: "search-42"))
        try await model.load()
        await model.onEvent(.searchClicked)
        #expect(model.consumeNavigationEvent() == .toSearchResults(searchId: "search-42"))
        #expect(model.consumeNavigationEvent() == nil)
        #expect(!model.uiState.isSearching)
    }

    @Test func searchAgainUsesSavedCriteriaAndReturnsNewSearchId() async throws {
        let repository = RequestSpySearchRepository()
        let model = makeModel(searchRepository: repository)
        try await model.load()
        await model.onEvent(.tripTypeChanged(.roundTrip))
        await model.onEvent(.travelersChanged(TravelerCounts(adults: 2, children: 1, infants: 1),
                                               childAges: [8], infantAges: [1]))
        await model.onEvent(.cabinClassChanged(.business))

        let searchId = await model.searchAgain()
        let capturedRequest = await repository.lastRequest
        let request = try #require(capturedRequest)

        #expect(searchId == "search-spy")
        #expect(request.tripType == .roundTrip)
        #expect(request.originCode == "ADD")
        #expect(request.destinationCode == "DXB")
        #expect(request.returnDate == today.addingDays(14))
        #expect(request.travelers == TravelerCounts(adults: 2, children: 1, infants: 1))
        #expect(request.childAges == [8])
        #expect(request.infantAges == [1])
        #expect(request.cabinClass == .business)
        #expect(model.consumeNavigationEvent() == nil)
        #expect(!model.uiState.isSearching)
    }

    @Test func searchAgainShowsLoadingAndOnlyReturnsIdAfterSuccess() async throws {
        let repository = BlockingSearchRepository()
        let model = makeModel(searchRepository: repository)
        try await model.load()

        let task = Task { await model.searchAgain() }
        await repository.waitUntilStarted()

        #expect(model.uiState.isSearching)
        #expect(model.consumeNavigationEvent() == nil)
        await repository.finish()
        #expect(await task.value == "search-blocked")
        #expect(!model.uiState.isSearching)
    }

    @Test func searchAgainPreservesOrderedMultiCityCriteria() async throws {
        let repository = RequestSpySearchRepository()
        let model = makeModel(searchRepository: repository)
        try await model.load()
        await model.onEvent(.tripTypeChanged(.multiCity))
        await model.onEvent(.multiCityDestinationClicked(index: 1))
        await model.onEvent(.airportSelected(add))
        await model.onEvent(.travelersChanged(TravelerCounts(adults: 2, children: 1, infants: 0),
                                               childAges: [8], infantAges: []))
        await model.onEvent(.cabinClassChanged(.business))

        let searchId = await model.searchAgain()
        let capturedRequest = await repository.lastRequest
        let request = try #require(capturedRequest)

        #expect(searchId == "search-spy")
        #expect(request.tripType == .multiCity)
        #expect(request.legs.map(\.originCode) == ["ADD", "DXB"])
        #expect(request.legs.map(\.destinationCode) == ["DXB", "ADD"])
        #expect(request.travelers == TravelerCounts(adults: 2, children: 1, infants: 0))
        #expect(request.childAges == [8])
        #expect(request.cabinClass == .business)
        #expect(model.consumeNavigationEvent() == nil)
    }

    @Test func failedSearchAgainDoesNotReturnOrNavigateToOldResults() async throws {
        let model = makeModel(searchResult: .networkUnavailable)
        try await model.load()

        let searchId = await model.searchAgain()

        #expect(searchId == nil)
        #expect(model.uiState.message == "We lost the connection. Try again.")
        #expect(model.consumeNavigationEvent() == nil)
    }

    @Test func featuredDestinationOpensItsDetailWithoutStartingFlightSearch() async throws {
        let searchRepository = RequestSpySearchRepository()
        let model = makeModel(searchRepository: searchRepository)
        let escape = TrendingEscape(
            id: "destination-dubai",
            airport: dxb,
            tags: ["City highlights"],
            startingPrice: Money(amount: 0, currency: "", formatted: ""),
            imageName: "https://example.com/dubai.jpg"
        )

        await model.onEvent(.trendingEscapeClicked(escape))

        #expect(model.consumeNavigationEvent() == .toDestinationDetail(destinationId: "destination-dubai"))
        #expect(await searchRepository.lastRequest == nil)
    }

    @Test func oneWaySearchBuildsExactRequestShape() async throws {
        let repository = RequestSpySearchRepository()
        let model = makeModel(searchRepository: repository)
        try await model.load()
        await model.onEvent(.searchClicked)
        let capturedRequest = await repository.lastRequest
        let request = try #require(capturedRequest)
        #expect(request.tripType == .oneWay)
        #expect(request.originCode == "ADD")
        #expect(request.destinationCode == "DXB")
        #expect(request.returnDate == nil)
        #expect(request.legs.isEmpty)
        #expect(!request.cheapestFirst)
    }

    @Test func roundTripSearchIncludesOnlyReturnDate() async throws {
        let repository = RequestSpySearchRepository()
        let model = makeModel(searchRepository: repository)
        try await model.load()
        await model.onEvent(.tripTypeChanged(.roundTrip))
        await model.onEvent(.searchClicked)

        let capturedRequest = await repository.lastRequest
        let request = try #require(capturedRequest)
        #expect(request.tripType == .roundTrip)
        #expect(request.returnDate == today.addingDays(14))
        #expect(request.legs.isEmpty)
    }

    @Test func multiCitySearchUsesOrderedLegsWithoutRootReturnDate() async throws {
        let repository = RequestSpySearchRepository()
        let model = makeModel(searchRepository: repository)
        try await model.load()
        await model.onEvent(.tripTypeChanged(.multiCity))
        await model.onEvent(.multiCityDestinationClicked(index: 1))
        await model.onEvent(.airportSelected(add))
        await model.onEvent(.searchClicked)

        let capturedRequest = await repository.lastRequest
        let request = try #require(capturedRequest)
        #expect(request.tripType == .multiCity)
        #expect(request.originCode == "ADD")
        #expect(request.destinationCode == "ADD")
        #expect(request.returnDate == nil)
        #expect(request.legs.map(\.originCode) == ["ADD", "DXB"])
        #expect(request.legs.map(\.destinationCode) == ["DXB", "ADD"])
    }

    @Test func duplicateSubmitDoesNotStartSecondSearch() async throws {
        let repository = BlockingSearchRepository()
        let model = makeModel(searchRepository: repository)
        try await model.load()
        let first = Task { await model.onEvent(.searchClicked) }
        await repository.waitUntilStarted()
        await model.onEvent(.searchClicked)
        let calls = await repository.callCount
        #expect(calls == 1)
        await repository.finish()
        await first.value
    }

    @Test(arguments: [
        (FlightSearchResult.networkUnavailable, "We lost the connection. Try again."),
        (.unknownError, "Could not check flights right now. Try again.")
    ])
    func searchFailureShowsExactMessage(_ result: FlightSearchResult, _ message: String) async throws {
        let model = makeModel(searchResult: result)
        try await model.load()
        await model.onEvent(.searchClicked)
        #expect(model.uiState.message == message)
        #expect(model.consumeNavigationEvent() == nil)
    }

    @Test func prefillAndMultiCityTransitionsMatchAndroid() async throws {
        let model = makeModel()
        try await model.load()
        try await model.prefillDestination(airportCode: "add")
        #expect(model.uiState.destination == add)
        await model.onEvent(.tripTypeChanged(.multiCity))
        await model.onEvent(.addMultiCityLeg)
        #expect(model.uiState.multiCityLegs.count == 3)
        await model.onEvent(.removeMultiCityLeg(index: 1))
        #expect(model.uiState.multiCityLegs.count == 2)
    }

    @Test func cancellingAirportSearchCancelsRepositoryWorkAndPreventsMutation() async throws {
        let repository = CancellationAwareAirportRepository(popular: [add, dxb])
        let content = HomeContent(origin: add, destination: dxb, departureDate: "", returnDate: "",
                                  travelersLabel: "", cabinClass: "", trendingEscapes: [])
        let model = HomeViewModel(
            homeRepository: StubHomeRepository(result: .success(content)),
            airportRepository: repository,
            flightSearchRepository: StubFlightSearchRepository(result: .unknownError),
            authRepository: StubAuthRepository(displayName: nil),
            today: { self.today }
        )
        try await model.load()
        let search = Task { await model.onEvent(.airportQueryChanged("slow")) }
        await repository.waitUntilStarted()

        model.cancelAirportSearch()
        await search.value

        #expect(await repository.wasCancelled)
        #expect(model.uiState.airports == [add, dxb])
    }

    private func makeModel(
        homeResult: HomeResult<HomeContent>? = nil,
        searchResult: FlightSearchResult = .success(searchId: "search-1"),
        displayName: String? = nil
    ) -> HomeViewModel {
        let content = HomeContent(origin: add, destination: dxb, departureDate: "", returnDate: "",
                                  travelersLabel: "", cabinClass: "", trendingEscapes: [])
        return HomeViewModel(
            homeRepository: StubHomeRepository(result: homeResult ?? .success(content)),
            airportRepository: StubAirportRepository(airports: [add, dxb]),
            flightSearchRepository: StubFlightSearchRepository(result: searchResult),
            authRepository: StubAuthRepository(displayName: displayName),
            today: { self.today }
        )
    }

    private func makeModel(searchRepository: any FlightSearchRepository) -> HomeViewModel {
        let content = HomeContent(origin: add, destination: dxb, departureDate: "", returnDate: "",
                                  travelersLabel: "", cabinClass: "", trendingEscapes: [])
        return HomeViewModel(
            homeRepository: StubHomeRepository(result: .success(content)),
            airportRepository: StubAirportRepository(airports: [add, dxb]),
            flightSearchRepository: searchRepository,
            authRepository: StubAuthRepository(displayName: nil),
            today: { self.today }
        )
    }
}

private struct StubHomeRepository: HomeRepository {
    let result: HomeResult<HomeContent>
    func getHomeContent() async throws -> HomeResult<HomeContent> { result }
}

private actor RetryHomeRepository: HomeRepository {
    private var results: [HomeResult<HomeContent>]
    init(results: [HomeResult<HomeContent>]) { self.results = results }
    func getHomeContent() async throws -> HomeResult<HomeContent> {
        results.isEmpty ? .unknownError : results.removeFirst()
    }
}

private struct ThrowingHomeRepository: HomeRepository {
    func getHomeContent() async throws -> HomeResult<HomeContent> { throw TestFailure() }
}

private struct TestFailure: Error {}

private struct StubAirportRepository: AirportRepository {
    let airports: [Airport]
    func searchAirports(query: String) async throws -> [Airport] {
        query.isEmpty ? airports : airports.filter { $0.code.localizedCaseInsensitiveContains(query) }
    }
}

private actor ControllableAirportRepository: AirportRepository {
    let popular: [Airport]
    private var continuations: [String: CheckedContinuation<[Airport], Error>] = [:]
    private var startedWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    init(popular: [Airport]) { self.popular = popular }

    func searchAirports(query: String) async throws -> [Airport] {
        if query.isEmpty { return popular }
        let waiters = startedWaiters.removeValue(forKey: query) ?? []
        waiters.forEach { $0.resume() }
        return try await withCheckedThrowingContinuation { continuations[query] = $0 }
    }

    func waitUntilStarted(query: String) async {
        if continuations[query] != nil { return }
        await withCheckedContinuation { startedWaiters[query, default: []].append($0) }
    }

    func resolve(query: String, airports: [Airport]) {
        continuations.removeValue(forKey: query)?.resume(returning: airports)
    }
}

private actor CancellationAwareAirportRepository: AirportRepository {
    let popular: [Airport]
    private var started = false
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var wasCancelled = false
    private var completion: CheckedContinuation<[Airport], Error>?

    init(popular: [Airport]) { self.popular = popular }

    func searchAirports(query: String) async throws -> [Airport] {
        if query.isEmpty { return popular }
        started = true
        let waiters = startedWaiters
        startedWaiters.removeAll()
        waiters.forEach { $0.resume() }
        do {
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { completion = $0 }
            } onCancel: {
                Task { await self.cancel() }
            }
        } catch is CancellationError {
            wasCancelled = true
            throw CancellationError()
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }
    private func cancel() {
        wasCancelled = true
        completion?.resume(throwing: CancellationError())
        completion = nil
    }
}

private struct StubFlightSearchRepository: FlightSearchRepository {
    let result: FlightSearchResult
    func createSearch(request: FlightSearchRequest) async throws -> FlightSearchResult { result }
}

private actor RequestSpySearchRepository: FlightSearchRepository {
    private(set) var lastRequest: FlightSearchRequest?
    func createSearch(request: FlightSearchRequest) async throws -> FlightSearchResult {
        lastRequest = request
        return .success(searchId: "search-spy")
    }
}

private actor BlockingSearchRepository: FlightSearchRepository {
    private(set) var callCount = 0
    private var completion: CheckedContinuation<FlightSearchResult, Never>?
    private var started: [CheckedContinuation<Void, Never>] = []

    func createSearch(request: FlightSearchRequest) async throws -> FlightSearchResult {
        callCount += 1
        let waiters = started
        started.removeAll()
        waiters.forEach { $0.resume() }
        return await withCheckedContinuation { completion = $0 }
    }

    func waitUntilStarted() async {
        if callCount > 0 { return }
        await withCheckedContinuation { started.append($0) }
    }

    func finish() {
        completion?.resume(returning: .success(searchId: "search-blocked"))
        completion = nil
    }
}

private struct StubAuthRepository: AuthRepository {
    let displayName: String?
    func getLocalSession() async throws -> AuthSession? {
        guard let displayName else { return nil }
        return AuthSession(sessionId: "session", user: AuthUser(id: "user", displayName: displayName,
                           email: "a@example.com", avatarUrl: nil), tokens: nil, expiresAt: .distantFuture)
    }
    func signInEmail(request: SignInRequest) async throws -> AuthResult<AuthSession> { .failure(.unknown) }
    func signUpEmail(request: SignUpRequest) async throws -> AuthResult<AuthSignUpResult> { .failure(.unknown) }
    func getSession() async throws -> AuthResult<AuthSession> { .failure(.unauthenticated) }
    func requestPasswordReset(email: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func signOut() async throws -> AuthResult<Void> { .success(()) }
}
