import Foundation
import Testing
@testable import NexusTravel

@MainActor
struct SearchResultsViewModelTests {
    @Test func defaultsMatchAndroid() {
        let model = SearchResultsViewModel(searchId: "search", repository: StubSearchResultsRepository(result: .empty))
        #expect(model.uiState.isInitialLoading)
        #expect(model.uiState.resultState == .loading)
        #expect(model.uiState.sortOption == .recommended)
        #expect(model.uiState.selectedFilters.isEmpty)
        #expect(model.uiState.resultCountLabel() == "0 flights found")
    }

    @Test func successMapsOffersAndUsesSingularCount() async throws {
        let model = makeModel(result: .success(querySummary: try summary(), offers: [try offer(id: "one")]))
        try await model.loadResults()
        #expect(model.uiState.resultState == .content)
        #expect(model.uiState.visibleFlights.map(\.id) == ["one"])
        #expect(model.uiState.resultCountLabel() == "1 flight found")
    }

    @Test func unavailableOfferIsRemovedWithoutResettingSearchPreferences() async throws {
        let model = makeModel(result: .success(querySummary: try summary(), offers: [try offer(id: "stale"), try offer(id: "good")]))
        try await model.loadResults()
        await model.onEvent(.sortChanged(.bestPrice))
        model.markOfferUnavailable(try offer(id: "stale").reference)
        #expect(model.uiState.visibleFlights.map(\.id) == ["good"])
        #expect(model.uiState.sortOption == .bestPrice)
        #expect(model.uiState.unavailableOfferNotice != nil)
    }

    @Test(arguments: [
        (SearchResultsResult.empty, SearchResultsState.empty, nil),
        (.networkUnavailable, .error, "Connection lost. Check your network and retry."),
        (.timeout, .error, "Search timed out. Retry when connection is stable."),
        (.unknownError, .error, "Could not load flights. Please retry.")
    ])
    func loadOutcomesUseExactAndroidStateAndCopy(
        _ result: SearchResultsResult,
        _ state: SearchResultsState,
        _ message: String?
    ) async throws {
        let model = makeModel(result: result)
        try await model.loadResults()
        #expect(model.uiState.resultState == state)
        #expect(model.uiState.errorMessage == message)
        #expect(!model.uiState.isInitialLoading)
    }

    @Test func thrownFailureUsesStableUnknownCopy() async throws {
        let model = SearchResultsViewModel(searchId: "search", repository: ThrowingSearchResultsRepository())
        try await model.loadResults()
        #expect(model.uiState.resultState == .error)
        #expect(model.uiState.errorMessage == "Could not load flights. Please retry.")
    }

    @Test func cheapestFirstAddsFilterAndSortsByPrice() async throws {
        let query = try summary(cheapestFirst: true)
        let model = makeModel(result: .success(querySummary: query, offers: [
            try offer(id: "high", price: 300), try offer(id: "low", price: 100)
        ]))
        try await model.loadResults()
        #expect(model.uiState.selectedFilters == [.bestPrice])
        #expect(model.uiState.sortOption == .bestPrice)
        #expect(model.uiState.visibleFlights.map(\.id) == ["low", "high"])
    }

    @Test func filtersComposeRemoveAndRecoverFromFilteredEmpty() async throws {
        let model = makeModel(result: .success(querySummary: try summary(), offers: [
            try offer(id: "direct", departure: "05:00", stops: 0),
            try offer(id: "one", departure: "12:00", stops: 1)
        ]))
        try await model.loadResults()
        await model.onEvent(.filterToggled(.nonStop))
        await model.onEvent(.filterToggled(.oneStop))
        #expect(model.uiState.resultState == .empty)
        await model.onEvent(.filterToggled(.oneStop))
        #expect(model.uiState.visibleFlights.map(\.id) == ["direct"])
        await model.onEvent(.clearFiltersClicked)
        #expect(model.uiState.selectedFilters.isEmpty)
        #expect(model.uiState.visibleFlights.map(\.id) == ["direct", "one"])
    }

    @Test func addingBestPriceChangesSortRemovingItDoesNot() async throws {
        let model = makeModel(result: .success(querySummary: try summary(), offers: [try offer()]))
        try await model.loadResults()
        await model.onEvent(.filterToggled(.bestPrice))
        #expect(model.uiState.sortOption == .bestPrice)
        await model.onEvent(.sortChanged(.fastest))
        await model.onEvent(.filterToggled(.bestPrice))
        #expect(model.uiState.sortOption == .fastest)
    }

    @Test func sortModesPreserveTiesAndUseCorrectKeys() async throws {
        let model = makeModel(result: .success(querySummary: try summary(), offers: [
            try offer(id: "late", price: 200, departure: "09:00", duration: 100),
            try offer(id: "firstTie", price: 100, departure: "08:00", duration: 200),
            try offer(id: "secondTie", price: 100, departure: "08:00", duration: 200)
        ]))
        try await model.loadResults()
        await model.onEvent(.sortChanged(.bestPrice))
        #expect(model.uiState.visibleFlights.map(\.id) == ["firstTie", "secondTie", "late"])
        await model.onEvent(.sortChanged(.fastest))
        #expect(model.uiState.visibleFlights.map(\.id) == ["late", "firstTie", "secondTie"])
        await model.onEvent(.sortChanged(.departureEarly))
        #expect(model.uiState.visibleFlights.map(\.id) == ["firstTie", "secondTie", "late"])
    }

    @Test func retryLoadsNextResult() async throws {
        let repository = SequencedSearchResultsRepository(results: [.unknownError, .success(querySummary: try summary(), offers: [try offer()])])
        let model = SearchResultsViewModel(searchId: "search", repository: repository)
        try await model.loadResults()
        await model.onEvent(.retryClicked)
        #expect(model.uiState.resultState == .content)
        #expect(await repository.callCount == 2)
    }

    @Test func duplicateLoadStartsOnlyOneRepositoryCall() async throws {
        let repository = BlockingSearchResultsRepository()
        let model = SearchResultsViewModel(searchId: "search", repository: repository)
        let first = Task { try await model.loadResults() }
        await repository.waitUntilStarted()
        try await model.loadResults()
        #expect(await repository.callCount == 1)
        await repository.finish(with: .empty)
        try await first.value
    }

    @Test func cancellationPropagatesAndRestoresPreviousState() async {
        let repository = CancellingSearchResultsRepository()
        let model = SearchResultsViewModel(searchId: "search", repository: repository)
        let task = Task { try await model.loadResults() }
        await repository.waitUntilStarted()
        task.cancel()
        do {
            try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {}
        catch { Issue.record("Expected CancellationError, got \(error)") }
        #expect(model.uiState == SearchResultsUiState())
    }

    @Test func navigationEventsAreFIFOAndConsumedExactlyOnce() async throws {
        let model = makeModel(result: .empty)
        let reference = try offer(id: "chosen").reference
        await model.onEvent(.backClicked)
        await model.onEvent(.modifyClicked)
        await model.onEvent(.nearbyDatesClicked)
        await model.onEvent(.flightCardClicked(reference))
        #expect(model.consumeNavigationEvent() == .back)
        #expect(model.consumeNavigationEvent() == .toModifySearch)
        #expect(model.consumeNavigationEvent() == .toNearbyDates)
        #expect(model.consumeNavigationEvent() == .toFlightDetails(reference))
        #expect(model.consumeNavigationEvent() == nil)
    }

    @Test func expiredOfferCannotOpenFlightDetails() async throws {
        let model = makeModel(result: .empty)
        let original = try offer(id: "expired").reference
        let expired = FlightOfferReference(
            searchId: original.searchId, offerId: original.offerId, offerToken: original.offerToken,
            provider: original.provider, contentSource: original.contentSource, responseId: original.responseId,
            productIds: original.productIds, termsAndConditionsId: original.termsAndConditionsId,
            brandRef: original.brandRef, expiresAt: .distantPast
        )
        await model.onEvent(.flightCardClicked(expired))
        #expect(model.consumeNavigationEvent() == nil)
        #expect(model.uiState.unavailableOfferNotice?.contains("expired") == true)
    }

    @Test func resultFreshnessWarningUsesOfferExpiry() async throws {
        var state = SearchResultsUiState()
        let offer = try offer(id: "soon").toSearchResultUiOffer(tripType: .oneWay)
        state.visibleFlights = [offer]
        let expiry = try #require(offer.reference.expiresAt)
        #expect(state.freshnessWarning(at: expiry.addingTimeInterval(-60)) != nil)
        #expect(state.freshnessWarning(at: expiry.addingTimeInterval(-600)) == nil)
    }

    private func makeModel(result: SearchResultsResult) -> SearchResultsViewModel {
        SearchResultsViewModel(searchId: "search", repository: StubSearchResultsRepository(result: result))
    }

    private func summary(cheapestFirst: Bool = false) throws -> SearchResultsQuerySummary {
        let date = try #require(LocalDate(year: 2026, month: 9, day: 1))
        return SearchResultsQuerySummary(searchId: "search", tripType: .oneWay, originCode: "ADD",
            destinationCode: "DXB", departureDate: date, returnDate: nil,
            travelers: TravelerCounts(adults: 1, children: 0, infants: 0), cabinClass: .economy,
            cheapestFirst: cheapestFirst)
    }

    private func offer(
        id: String = "offer",
        price: Int = 200,
        departure: String = "09:00",
        duration: Int = 120,
        stops: Int = 0
    ) throws -> FlightOffer {
        let departureTime = try #require(LocalTime(hhmm: departure))
        let arrivalTime = try #require(LocalTime(hhmm: "14:00"))
        let leg = FlightLeg(departureAirportCode: "ADD", arrivalAirportCode: "DXB",
            departureTime: departureTime, arrivalTime: arrivalTime, durationMinutes: duration,
            reportedStopCount: stops)
        let reference = FlightOfferReference(searchId: "search", offerId: id, offerToken: "token-\(id)",
            provider: .travelportGds, contentSource: "GDS", responseId: "response", productIds: ["product"],
            termsAndConditionsId: "terms", brandRef: "brand", expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
        return FlightOffer(id: id, reference: reference, airline: AirlineBrand(code: "ET", name: "Ethiopian Airlines"),
            flightNumber: "ET600", outbound: leg, inbound: nil, price: Money(amount: price, currency: "USD", formatted: "USD \(price)"),
            oldPrice: Money(amount: price + 50, currency: "USD", formatted: "USD \(price + 50)"), seatsLeft: 3,
            badge: .bestValue, refundable: true)
    }
}

private struct StubSearchResultsRepository: SearchResultsRepository {
    let result: SearchResultsResult
    func getSearchResults(searchId: String) async throws -> SearchResultsResult { result }
}

private struct ThrowingSearchResultsRepository: SearchResultsRepository {
    func getSearchResults(searchId: String) async throws -> SearchResultsResult { throw SearchResultsTestFailure() }
}

private struct SearchResultsTestFailure: Error {}

private actor SequencedSearchResultsRepository: SearchResultsRepository {
    private var results: [SearchResultsResult]
    private(set) var callCount = 0
    init(results: [SearchResultsResult]) { self.results = results }
    func getSearchResults(searchId: String) async throws -> SearchResultsResult {
        callCount += 1
        return results.removeFirst()
    }
}

private actor BlockingSearchResultsRepository: SearchResultsRepository {
    private(set) var callCount = 0
    private var completion: CheckedContinuation<SearchResultsResult, Never>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func getSearchResults(searchId: String) async throws -> SearchResultsResult {
        callCount += 1
        waiters.forEach { $0.resume() }
        waiters.removeAll()
        return await withCheckedContinuation { completion = $0 }
    }
    func waitUntilStarted() async {
        if callCount > 0 { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func finish(with result: SearchResultsResult) {
        completion?.resume(returning: result)
        completion = nil
    }
}

private actor CancellingSearchResultsRepository: SearchResultsRepository {
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var completion: CheckedContinuation<SearchResultsResult, Error>?
    func getSearchResults(searchId: String) async throws -> SearchResultsResult {
        started = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { completion = $0 }
        } onCancel: {
            Task { await self.cancel() }
        }
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    private func cancel() {
        completion?.resume(throwing: CancellationError())
        completion = nil
    }
}
