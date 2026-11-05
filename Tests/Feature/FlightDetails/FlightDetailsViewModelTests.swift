import Testing
@testable import NexusTravel

@MainActor
struct FlightDetailsViewModelTests {
    @Test func loadSuccessPublishesContent() async throws {
        let details = try makeDetails()
        let model = FlightDetailsViewModel(
            reference: details.reference,
            repository: StubFlightDetailsRepository(result: .success(details: details))
        )

        try await model.load()

        #expect(!model.uiState.isLoading)
        #expect(model.uiState.details == details)
        #expect(model.uiState.display != nil)
        #expect(model.uiState.errorMessage == nil)
    }

    @Test(arguments: [
        FlightDetailsResult.offerExpired,
        .offerUnavailable,
        .networkUnavailable,
        .confirmationUnavailable,
        .authRequired,
        .unknownError
    ])
    func loadFailuresPublishStableError(_ result: FlightDetailsResult) async throws {
        let details = try makeDetails()
        let model = FlightDetailsViewModel(
            reference: details.reference,
            repository: StubFlightDetailsRepository(result: result)
        )

        try await model.load()

        #expect(!model.uiState.isLoading)
        #expect(model.uiState.errorMessage != nil)
        #expect(model.uiState.canRetryLoad == (result == .networkUnavailable || result == .confirmationUnavailable || result == .unknownError))
    }

    @Test func unavailableOnContinueInvalidatesStaleFare() async throws {
        let details = try makeDetails()
        let repository = SequencedFlightDetailsRepository(results: [.success(details: details), .offerUnavailable])
        let model = FlightDetailsViewModel(reference: details.reference, repository: repository)
        try await model.load()
        try await model.onEvent(.continueClicked)
        #expect(model.uiState.details == nil)
        #expect(model.uiState.errorMessage != nil)
        #expect(!model.uiState.canRetryLoad)
        #expect(model.consumeNavigationEvent() == nil)
    }

    @Test func temporaryFailureKeepsFareButRequiresFreshConfirmation() async throws {
        let details = try makeDetails()
        let repository = SequencedFlightDetailsRepository(results: [.success(details: details), .confirmationUnavailable, .offerUnavailable])
        let model = FlightDetailsViewModel(reference: details.reference, repository: repository)
        try await model.load()
        try await model.onEvent(.continueClicked)
        #expect(model.uiState.details == details)
        #expect(model.uiState.requiresRevalidation)
        #expect(model.consumeNavigationEvent() == nil)
        try await model.onEvent(.retryClicked)
        #expect(model.uiState.details == nil)
        #expect(model.uiState.errorMessage != nil)
        #expect(await repository.callCount == 3)
    }

    @Test func retryLoadsNextResult() async throws {
        let details = try makeDetails()
        let repository = SequencedFlightDetailsRepository(results: [.unknownError, .success(details: details)])
        let model = FlightDetailsViewModel(reference: details.reference, repository: repository)
        try await model.load()

        try await model.onEvent(.retryClicked)

        #expect(model.uiState.details == details)
        #expect(await repository.callCount == 2)
    }

    @Test func continueIsDuplicateSafeAndNavigatesOnce() async throws {
        let details = try makeDetails()
        let repository = ControlledFlightDetailsRepository()
        let model = FlightDetailsViewModel(reference: details.reference, repository: repository)
        let first = Task { try await model.onEvent(.continueClicked) }
        await repository.waitUntilStarted()

        try await model.onEvent(.continueClicked)
        await repository.finish(with: .success(details: details))
        try await first.value

        #expect(await repository.callCount == 1)
        #expect(model.consumeNavigationEvent() == .toPassengerDetails)
        #expect(model.consumeNavigationEvent() == nil)
    }

    @Test func priceChangeRequiresExplicitAcceptance() async throws {
        let details = try makeDetails()
        let previous = Money(amount: 50_000, currency: "ETB", formatted: "ETB 50,000")
        let model = FlightDetailsViewModel(
            reference: details.reference,
            repository: StubFlightDetailsRepository(
                result: .priceChanged(previousTotal: previous, updatedDetails: details)
            )
        )

        try await model.onEvent(.continueClicked)
        #expect(model.uiState.pendingPriceChange != nil)
        #expect(model.consumeNavigationEvent() == nil)
        try await model.onEvent(.acceptPriceChangeClicked)
        #expect(model.uiState.pendingPriceChange == nil)
        #expect(model.consumeNavigationEvent() == .toPassengerDetails)
    }

    @Test func dismissToggleSeatAndBackUpdateOnlyOwnedState() async throws {
        let details = try makeDetails()
        let model = FlightDetailsViewModel(
            reference: details.reference,
            repository: StubFlightDetailsRepository(result: .success(details: details))
        )
        try await model.onEvent(.sectionToggled(.baggage))
        try await model.onEvent(.chooseSeatClicked)
        try await model.onEvent(.backClicked)

        #expect(model.uiState.expandedSections == [.baggage])
        #expect(model.uiState.actionMessage != nil)
        #expect(model.consumeNavigationEvent() == .back)
        try await model.onEvent(.sectionToggled(.baggage))
        #expect(model.uiState.expandedSections.isEmpty)
    }

    @Test func cancellationRestoresPreviousState() async throws {
        let details = try makeDetails()
        let repository = ControlledFlightDetailsRepository()
        let model = FlightDetailsViewModel(reference: details.reference, repository: repository)
        let task = Task { try await model.load() }
        await repository.waitUntilStarted()
        task.cancel()
        await repository.cancel()

        do {
            try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {} catch {
            Issue.record("Expected CancellationError, got \(error)")
        }
        #expect(model.uiState == FlightDetailsUiState())
    }

    @Test func priceChangedOnOpenStillRequiresConsentAfterContinueRecheck() async throws {
        let details = try makeDetails()
        let previous = Money(amount: 50_000, currency: "ETB", formatted: "ETB 50,000")
        let repository = SequencedFlightDetailsRepository(results: [
            .priceChanged(previousTotal: previous, updatedDetails: details),
            .success(details: details)
        ])
        let model = FlightDetailsViewModel(reference: details.reference, repository: repository)
        try await model.load()
        try await model.onEvent(.continueClicked)
        #expect(model.uiState.pendingPriceChange != nil)
        #expect(model.consumeNavigationEvent() == nil)
        try await model.onEvent(.acceptPriceChangeClicked)
        #expect(model.consumeNavigationEvent() == .toPassengerDetails)
    }

    @Test func laterFailureInvalidatesPendingPriceAcceptance() async throws {
        let details = try makeDetails()
        let previous = Money(amount: 50_000, currency: "ETB", formatted: "ETB 50,000")
        let repository = SequencedFlightDetailsRepository(results: [
            .success(details: details),
            .priceChanged(previousTotal: previous, updatedDetails: details),
            .offerExpired
        ])
        let model = FlightDetailsViewModel(reference: details.reference, repository: repository)
        try await model.load()
        try await model.onEvent(.continueClicked)
        try await model.onEvent(.retryClicked)
        try await model.onEvent(.acceptPriceChangeClicked)
        #expect(model.consumeNavigationEvent() == nil)
        #expect(model.uiState.canReturnToResults)
    }

    @Test func unexpectedLoadFailureStopsLoading() async {
        let details = try? makeDetails()
        guard let details else {
            Issue.record("Could not create flight details fixture")
            return
        }
        let model = FlightDetailsViewModel(
            reference: details.reference,
            repository: ThrowingFlightDetailsRepository()
        )

        try? await model.load()

        #expect(!model.uiState.isLoading)
        #expect(model.uiState.errorMessage != nil)
        #expect(model.uiState.canRetryLoad)
    }
}

private struct StubFlightDetailsRepository: FlightDetailsRepository {
    let result: FlightDetailsResult
    func priceOffer(reference: FlightOfferReference) async throws -> FlightDetailsResult { result }
}

private struct ThrowingFlightDetailsRepository: FlightDetailsRepository {
    func priceOffer(reference: FlightOfferReference) async throws -> FlightDetailsResult { throw FlightDetailsLoadError.failed }
}

private enum FlightDetailsLoadError: Error { case failed }

private actor SequencedFlightDetailsRepository: FlightDetailsRepository {
    private var results: [FlightDetailsResult]
    private(set) var callCount = 0
    init(results: [FlightDetailsResult]) { self.results = results }
    func priceOffer(reference: FlightOfferReference) async throws -> FlightDetailsResult {
        callCount += 1
        return results.removeFirst()
    }
}

private actor ControlledFlightDetailsRepository: FlightDetailsRepository {
    private(set) var callCount = 0
    private var completion: CheckedContinuation<FlightDetailsResult, Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func priceOffer(reference: FlightOfferReference) async throws -> FlightDetailsResult {
        callCount += 1
        waiters.forEach { $0.resume() }
        waiters.removeAll()
        return try await withCheckedThrowingContinuation { completion = $0 }
    }
    func waitUntilStarted() async {
        if callCount > 0 { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func finish(with result: FlightDetailsResult) {
        completion?.resume(returning: result)
        completion = nil
    }
    func cancel() {
        completion?.resume(throwing: CancellationError())
        completion = nil
    }
}
