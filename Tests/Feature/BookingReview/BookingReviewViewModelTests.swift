import Testing
@testable import NexusTravel

@MainActor
struct BookingReviewViewModelTests {
    @Test func reviewReloadCannotUnlockUnknownHold() async throws {
        let repository = BookingReviewFakeRepository(
            review: .success(Self.details), submits: [.outcomeUnknown, .success(reviewId: "b-1", bookingReference: "ABC123", status: .submittedForManualReview)]
        )
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository, idempotencyKey: "stable-key")
        try await viewModel.load()
        try await viewModel.submit()
        try await viewModel.load()
        try await viewModel.submit()

        #expect(await repository.keys == ["stable-key"])
        #expect(viewModel.state.bookingOutcomeUnknown)
        #expect(viewModel.state.screenState == .content)
    }

    @Test func invalidReferenceCannotBecomeSuccess() async throws {
        let repository = BookingReviewFakeRepository(review: .success(Self.details), submits: [.unavailable])
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository, idempotencyKey: "stable")
        try await viewModel.load(); try await viewModel.submit()
        #expect(viewModel.state.screenState == .content)
        #expect(viewModel.state.message == "This fare is no longer available. Search again for current flights.")
    }

    @Test func holdKeySurvivesViewModelRecreation() async throws {
        let firstRepository = BookingReviewFakeRepository(review: .success(Self.details), submits: [.outcomeUnknown])
        let first = BookingReviewViewModel(reviewId: "b-1", repository: firstRepository)
        try await first.load()
        try await first.submit()

        let secondRepository = BookingReviewFakeRepository(review: .success(Self.details), submits: [.outcomeUnknown])
        let second = BookingReviewViewModel(reviewId: "b-1", repository: secondRepository)
        try await second.load()
        try await second.submit()

        let firstKeys = await firstRepository.keys
        let secondKeys = await secondRepository.keys
        #expect(firstKeys == secondKeys)
    }

    @Test func priceChangePreservesDraftAndRequiresFreshSearchUntilQuoteAcceptanceExists() async throws {
        let repository = BookingReviewFakeRepository(
            review: .success(Self.details),
            submits: [.priceChanged("Flight price changed. Review the new price before continuing.")]
        )
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        try await viewModel.submit()

        #expect(viewModel.state.screenState == .content)
        #expect(viewModel.state.details == Self.details)
        #expect(viewModel.state.recoveryAction == .chooseAnotherFlight)
        #expect(viewModel.state.message == "Flight price changed. Review the new price before continuing.")
        viewModel.chooseAnotherFlight()
        #expect(viewModel.consumeNavigation() == .chooseAnotherFlight)
    }

    @Test func verifiedPriceOnlyQuoteRequiresExplicitAcceptanceBeforeAnotherHold() async throws {
        var details = Self.details
        details.updatedAt = "2026-09-24T10:00:00.000Z"
        let quote = BookingPriceQuote(previousAmountMinor: 15_875, newAmountMinor: 17_200,
                                      currency: "USD", quoteRevision: "revision-2",
                                      updatedAt: "2026-09-24T10:01:00.000Z",
                                      requiresNewFlight: false, itineraryChanged: false,
                                      seatSelectionWillBeCleared: true)
        var accepted = BookingReviewDetails(
            reviewId: details.reviewId, bookingReference: nil, status: .draftSaved,
            passengers: details.passengers, contact: details.contact, seats: details.seats,
            fareTotal: .init(amount: 17_200, currency: "USD", formatted: "USD 172.00")
        )
        accepted.updatedAt = "2026-09-24T10:02:00.000Z"
        accepted.acceptedQuoteRevision = "revision-2"
        let repository = BookingReviewFakeRepository(
            review: .success(details), submits: [.priceChanged("Price changed."), .outcomeUnknown],
            repriceResult: .success(quote), acceptResult: .success(accepted)
        )
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        try await viewModel.submit()
        try await viewModel.reviewUpdatedPrice()
        #expect(viewModel.state.pendingPriceQuote == quote)
        #expect(viewModel.state.details?.fareTotal.amount == 15_875)
        try await viewModel.acceptUpdatedPrice()
        #expect(viewModel.state.pendingPriceQuote == nil)
        #expect(viewModel.state.details?.fareTotal.amount == 17_200)
        #expect(viewModel.state.message?.contains("seat selections were cleared") == true)
        try await viewModel.submit()
        let keys = await repository.keys
        #expect(keys.count == 2)
        #expect(keys[0] != keys[1])
    }

    @Test func reopenedPriceChangeCanRepriceUsingSavedBookingVersion() async throws {
        var failedHold = Self.details.with(status: .holdFailed)
        failedHold.failureReasonCode = "PRICE_CHANGED"
        failedHold.updatedAt = "2026-09-24T10:00:00.000Z"
        let quote = BookingPriceQuote(previousAmountMinor: 15_875, newAmountMinor: 17_200,
                                      currency: "USD", quoteRevision: "revision-2",
                                      updatedAt: "2026-09-24T10:01:00.000Z",
                                      requiresNewFlight: false, itineraryChanged: false,
                                      seatSelectionWillBeCleared: true)
        let repository = BookingReviewFakeRepository(review: .success(failedHold), submits: [],
                                                     repriceResult: .success(quote))
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository,
                                               statusPollingInterval: .zero)

        try await viewModel.load()

        #expect(viewModel.state.recoveryAction == .reviewUpdatedPrice)
        try await viewModel.reviewUpdatedPrice()
        #expect(viewModel.state.pendingPriceQuote == quote)
    }

    @Test func unavailableFarePreservesDraftAndOffersAnotherFlight() async throws {
        let message = "This flight is no longer available. Choose another flight."
        let repository = BookingReviewFakeRepository(review: .success(Self.details), submits: [.fareUnavailable(message)])
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        try await viewModel.submit()

        #expect(viewModel.state.screenState == .content)
        #expect(viewModel.state.details == Self.details)
        #expect(viewModel.state.recoveryAction == .chooseAnotherFlight)
        #expect(viewModel.state.message == message)
        viewModel.chooseAnotherFlight()
        #expect(viewModel.consumeNavigation() == .chooseAnotherFlight)
    }

    @Test func onlyTransientReviewLoadErrorsOfferRetry() async throws {
        let network = BookingReviewViewModel(
            reviewId: "b-1", repository: BookingReviewFakeRepository(review: .networkUnavailable, submits: [])
        )
        let expired = BookingReviewViewModel(
            reviewId: "b-1", repository: BookingReviewFakeRepository(review: .expired, submits: [])
        )
        try await network.load()
        try await expired.load()
        #expect(network.state.canRetryLoad)
        #expect(!expired.state.canRetryLoad)
    }

    @Test func unknownBookingOutcomeRequiresStatusCheckBeforeResubmission() async throws {
        let repository = BookingReviewFakeRepository(review: .success(Self.details), submits: [.outcomeUnknown])
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        try await viewModel.submit()
        #expect(viewModel.state.bookingOutcomeUnknown)
        #expect(!viewModel.state.isSubmitting)
    }

    @Test func pendingStatusKeepsBookAndPaymentLocked() async throws {
        let repository = BookingReviewFakeRepository(
            review: .success(Self.details), submits: [.outcomeUnknown],
            status: .success(.init(outcome: .pending, bookingReference: nil))
        )
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        try await viewModel.submit()
        try await viewModel.checkStatus()
        #expect(viewModel.state.bookingOutcomeUnknown)
        #expect(viewModel.state.screenState == .content)
        #expect(viewModel.state.message?.contains("still") == true)
    }

    @Test func changedHoldResponseLocksBookAndPayment() async throws {
        let repository = BookingReviewFakeRepository(review: .success(Self.details), submits: [.changedHoldReview])
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        try await viewModel.submit()
        viewModel.payment()
        #expect(viewModel.state.bookingOutcomeUnknown)
        #expect(!viewModel.state.canUploadProof)
        #expect(viewModel.consumeNavigation() == nil)
    }

    @Test func reopeningUnconfirmedHoldKeepsBookAndPaymentLocked() async throws {
        let unconfirmed = BookingReviewDetails(
            reviewId: Self.details.reviewId, bookingReference: nil, status: .holdUnconfirmed,
            passengers: Self.details.passengers, contact: Self.details.contact, seats: Self.details.seats,
            fareTotal: Self.details.fareTotal
        )
        let repository = BookingReviewFakeRepository(review: .success(unconfirmed), submits: [])
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        viewModel.payment()
        try await viewModel.submit()

        #expect(viewModel.state.bookingOutcomeUnknown)
        #expect(!viewModel.state.canUploadProof)
        #expect(viewModel.consumeNavigation() == nil)
        #expect(await repository.keys.isEmpty)
    }

    @Test func confirmedStatusUnlocksOnlyAfterSupplierReferenceExists() async throws {
        let repository = BookingReviewFakeRepository(
            review: .success(Self.details), submits: [.outcomeUnknown],
            status: .success(.init(outcome: .held, bookingReference: "ABC123",
                                   allowedNextActions: [.uploadPaymentProof, .viewTrip]))
        )
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        try await viewModel.submit()
        try await viewModel.checkStatus()
        #expect(!viewModel.state.bookingOutcomeUnknown)
        #expect(viewModel.state.screenState == .submitted)
        #expect(viewModel.state.details?.bookingReference == "ABC123")
    }

    @Test func statusCheckPostsOnceThenPollsUntilVerifiedHold() async throws {
        let queued = BookingStatusSnapshot(outcome: .unknown, bookingReference: nil,
                                           reconciliationState: .queued, allowedNextActions: [.checkStatus, .viewTrip])
        let checking = BookingStatusSnapshot(outcome: .unknown, bookingReference: nil,
                                             reconciliationState: .checking, allowedNextActions: [.checkStatus, .viewTrip])
        let held = BookingStatusSnapshot(outcome: .held, bookingReference: "ABC123",
                                         reconciliationState: .resolved,
                                         lastSupplierCheckedAt: "2026-09-24T10:02:00.000Z",
                                         allowedNextActions: [.uploadPaymentProof, .viewTrip])
        let unconfirmed = Self.details.with(status: .holdUnconfirmed)
        let repository = BookingReviewFakeRepository(
            review: .success(unconfirmed), submits: [],
            statusCheckResult: .success(queued),
            statusResults: [.success(checking), .success(held)]
        )
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository,
                                               statusPollingInterval: .zero)
        try await viewModel.load()

        try await viewModel.checkStatus()

        #expect(await repository.statusCheckCount == 1)
        #expect(await repository.statusReadCount == 2)
        #expect(viewModel.state.screenState == .submitted)
        #expect(viewModel.state.canUploadProof)
        #expect(viewModel.state.details?.bookingReference == "ABC123")
    }

    @Test func staffReviewStopsPollingAndKeepsPaymentLocked() async throws {
        let review = Self.details.with(status: .holdUnconfirmed)
        let staffReview = BookingStatusSnapshot(outcome: .unknown, bookingReference: nil,
                                                reconciliationState: .staffReview,
                                                allowedNextActions: [.viewTrip])
        let repository = BookingReviewFakeRepository(
            review: .success(review), submits: [], statusCheckResult: .success(staffReview)
        )
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository,
                                               statusPollingInterval: .zero)
        try await viewModel.load()

        try await viewModel.checkStatus()
        viewModel.payment()

        #expect(await repository.statusCheckCount == 1)
        #expect(await repository.statusReadCount == 0)
        #expect(viewModel.state.message == "Our team is reviewing this booking. Don't book or pay again yet.")
        #expect(!viewModel.state.canUploadProof)
        #expect(viewModel.consumeNavigation() == nil)
    }

    @Test func cancellationDuringStatusCheckLeavesUnknownBookingLocked() async throws {
        let review = Self.details.with(status: .holdUnconfirmed)
        let gate = BookingStatusCheckGate()
        let repository = BookingReviewFakeRepository(
            review: .success(review), submits: [], statusCheckResult: .success(.init(outcome: .unknown, bookingReference: nil)),
            statusCheckGate: gate
        )
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository,
                                               statusPollingInterval: .zero)
        try await viewModel.load()

        let task = Task { try await viewModel.checkStatus() }
        await gate.waitUntilEntered()
        task.cancel()
        await gate.release()
        await #expect(throws: CancellationError.self) { try await task.value }

        #expect(viewModel.state.bookingOutcomeUnknown)
        #expect(!viewModel.state.canUploadProof)
        #expect(!viewModel.state.isCheckingStatus)
    }

    @Test func statusCheckRecognizesSubmittedBooking() async throws {
        let confirmed = BookingReviewDetails(
            reviewId: Self.details.reviewId, bookingReference: "ABC123", status: .submittedForManualReview,
            passengers: Self.details.passengers, contact: Self.details.contact, seats: Self.details.seats,
            fareTotal: Self.details.fareTotal
        )
        let viewModel = BookingReviewViewModel(
            reviewId: "b-1", repository: BookingReviewFakeRepository(
                review: .success(confirmed), submits: [],
                status: .success(.init(outcome: .held, bookingReference: "ABC123",
                                       allowedNextActions: [.uploadPaymentProof, .viewTrip]))
            )
        )
        try await viewModel.load()
        #expect(viewModel.state.screenState == .submitted)
        #expect(viewModel.state.canUploadProof)
    }

    @Test func reopenedHeldReviewRequiresActiveBackendPaymentAction() async throws {
        let confirmed = BookingReviewDetails(
            reviewId: Self.details.reviewId, bookingReference: "ABC123", status: .submittedForManualReview,
            passengers: Self.details.passengers, contact: Self.details.contact, seats: Self.details.seats,
            fareTotal: Self.details.fareTotal
        )
        let expired = BookingStatusSnapshot(outcome: .expired, bookingReference: "ABC123",
                                            reconciliationState: .resolved,
                                            allowedNextActions: [.searchAgain, .viewTrip])
        let repository = BookingReviewFakeRepository(review: .success(confirmed), submits: [],
                                                     status: .success(expired))
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)

        try await viewModel.load()
        viewModel.payment()

        #expect(viewModel.state.screenState == .content)
        #expect(!viewModel.state.canUploadProof)
        #expect(viewModel.consumeNavigation() == nil)
    }

    @Test func submittedReviewWithoutLocatorCannotRequestAnotherHoldOrPayment() async throws {
        let missingLocator = BookingReviewDetails(
            reviewId: Self.details.reviewId, bookingReference: nil, status: .submittedForManualReview,
            passengers: Self.details.passengers, contact: Self.details.contact, seats: Self.details.seats,
            fareTotal: Self.details.fareTotal
        )
        let repository = BookingReviewFakeRepository(review: .success(missingLocator), submits: [])
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        try await viewModel.submit()
        viewModel.payment()
        #expect(viewModel.state.bookingOutcomeUnknown)
        #expect(!viewModel.state.canUploadProof)
        #expect(await repository.keys.isEmpty)
        #expect(viewModel.consumeNavigation() == nil)
    }

    @Test(arguments: [BookingRequestStatus.agentReviewing, .expired, .unavailable])
    func nonDraftReviewCannotRequestHold(_ status: BookingRequestStatus) async throws {
        let review = BookingReviewDetails(
            reviewId: Self.details.reviewId, bookingReference: nil, status: status,
            passengers: Self.details.passengers, contact: Self.details.contact, seats: Self.details.seats,
            fareTotal: Self.details.fareTotal
        )
        let repository = BookingReviewFakeRepository(review: .success(review), submits: [])
        let viewModel = BookingReviewViewModel(reviewId: "b-1", repository: repository)
        try await viewModel.load()
        try await viewModel.submit()
        #expect(await repository.keys.isEmpty)
    }

    private static let details = BookingReviewDetails(
        reviewId: "b-1", bookingReference: nil, status: .draftSaved,
        passengers: [.init(title: "MR", firstName: "Ada", lastName: "Lovelace", passportNumber: "P1", nationality: "GB")],
        contact: .init(email: "ada@example.com", phone: "+251900000000"), seats: [],
        fareTotal: .init(amount: 15_875, currency: "USD", formatted: "USD 158.75")
    )
}

private extension BookingReviewDetails {
    func with(status: BookingRequestStatus) -> BookingReviewDetails {
        BookingReviewDetails(reviewId: reviewId, bookingReference: bookingReference, status: status,
                             passengers: passengers, contact: contact, seats: seats, fareTotal: fareTotal)
    }
}

private actor BookingReviewFakeRepository: BookingRequestRepository {
    let review: BookingRequestResult
    private var submits: [BookingSubmitResult]
    private let status: BookingStatusResult
    private var statusResults: [BookingStatusResult]
    private let statusCheckResult: BookingStatusResult
    private let statusCheckGate: BookingStatusCheckGate?
    private(set) var statusCheckCount = 0
    private(set) var statusReadCount = 0
    private let repriceResult: BookingRepriceResult
    private let acceptResult: BookingRequestResult
    private(set) var keys: [String] = []
    init(review: BookingRequestResult, submits: [BookingSubmitResult], status: BookingStatusResult = .unknownError,
         statusCheckResult: BookingStatusResult? = nil, statusResults: [BookingStatusResult] = [],
         statusCheckGate: BookingStatusCheckGate? = nil, repriceResult: BookingRepriceResult = .unknownError,
         acceptResult: BookingRequestResult = .unknownError) {
        self.review = review; self.submits = submits; self.status = status
        self.statusCheckResult = statusCheckResult ?? status
        self.statusResults = statusResults
        self.statusCheckGate = statusCheckGate
        self.repriceResult = repriceResult; self.acceptResult = acceptResult
    }
    func getReview(reviewId: String) async throws -> BookingRequestResult { review }
    func requestStatusCheck(reviewId: String) async throws -> BookingStatusResult {
        statusCheckCount += 1
        await statusCheckGate?.pause()
        try Task.checkCancellation()
        return statusCheckResult
    }
    func getStatus(reviewId: String) async throws -> BookingStatusResult {
        statusReadCount += 1
        return statusResults.isEmpty ? status : statusResults.removeFirst()
    }
    func reprice(reviewId: String, expectedUpdatedAt: String) async throws -> BookingRepriceResult { repriceResult }
    func acceptQuote(reviewId: String, expectedUpdatedAt: String, quoteRevision: String) async throws -> BookingRequestResult { acceptResult }
    func submitReview(reviewId: String, idempotencyKey: String) async throws -> BookingSubmitResult {
        keys.append(idempotencyKey); return submits.removeFirst()
    }
}

private actor BookingStatusCheckGate {
    private var hasEntered = false
    private var entryContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func pause() async {
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
            hasEntered = true
            entryContinuation?.resume()
            entryContinuation = nil
        }
    }

    func waitUntilEntered() async {
        guard !hasEntered else { return }
        await withCheckedContinuation { entryContinuation = $0 }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
