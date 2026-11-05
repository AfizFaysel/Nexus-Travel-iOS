import Foundation
import Observation

enum BookingReviewState: Equatable, Sendable { case loading, content, error, submitted }
enum BookingReviewRecoveryAction: Equatable, Sendable { case reviewUpdatedPrice, chooseAnotherFlight }
struct BookingReviewUiState: Equatable, Sendable {
    var screenState: BookingReviewState = .loading; var details: BookingReviewDetails?
    var message: String?; var isSubmitting = false; var isCheckingStatus = false
    var canRetryLoad = false; var bookingOutcomeUnknown = false; var canUploadProof = false
    var recoveryAction: BookingReviewRecoveryAction?
    var statusOutcome: BookingHoldOutcome?
    var reconciliationState: BookingReconciliationState = .notNeeded
    var lastSupplierCheckedAt: String?
    var allowedNextActions: [BookingStatusAction] = []
    var pendingPriceQuote: BookingPriceQuote?
    var isRepricing = false; var isAcceptingPrice = false
}
enum BookingReviewNavigation: Equatable, Sendable { case back, home, chooseAnotherFlight, payment(String), trip(String) }

@MainActor @Observable
final class BookingReviewViewModel {
    private(set) var state = BookingReviewUiState()
    private let reviewId: String; private let repository: any BookingRequestRepository
    private let idempotencyKeyOverride: String?; private var navigation: [BookingReviewNavigation] = []
    private let statusPollingLimit: Int
    private let statusPollingInterval: Duration
    init(reviewId: String, repository: any BookingRequestRepository,
         idempotencyKey: String? = nil, statusPollingLimit: Int = 5,
         statusPollingInterval: Duration = .seconds(1)) {
        self.reviewId = reviewId; self.repository = repository
        self.idempotencyKeyOverride = idempotencyKey
        self.statusPollingLimit = max(statusPollingLimit, 0)
        self.statusPollingInterval = statusPollingInterval
    }
    func load() async throws {
        let previous = state
        state.screenState = .loading; state.message = nil; state.canRetryLoad = false; state.recoveryAction = nil
        do {
            let result = try await repository.getReview(reviewId: reviewId)
            try Task.checkCancellation()
            switch result {
            case let .success(details):
                state.details = details
                switch details.status {
                case .holdPending, .holdUnconfirmed, .holdChangeReview, .holdFailed:
                    let priceChanged = details.status == .holdFailed && details.failureReasonCode == "PRICE_CHANGED"
                    state.bookingOutcomeUnknown = !priceChanged
                    state.canUploadProof = false
                    state.screenState = .content
                    state.statusOutcome = switch details.status {
                    case .holdPending: .pending
                    case .holdUnconfirmed: .unknown
                    case .holdChangeReview: .changedHoldReview
                    default: .notHeld
                    }
                    if priceChanged {
                        state.recoveryAction = details.updatedAt == nil ? .chooseAnotherFlight : .reviewUpdatedPrice
                        state.message = "Flight price changed. Review the current fare before continuing."
                    }
                case .submittedForManualReview:
                    if details.bookingReference != nil {
                        state.bookingOutcomeUnknown = true
                        state.canUploadProof = false
                        state.screenState = .content
                        state.message = "Checking that your airline hold is still active. Don't pay until this check finishes."
                        let status = try await repository.getStatus(reviewId: reviewId)
                        try Task.checkCancellation()
                        if case let .success(snapshot) = status { apply(snapshot) }
                        else { applyStatusFailure(status) }
                    } else {
                        state.bookingOutcomeUnknown = true
                        state.canUploadProof = false
                        state.screenState = .content
                        state.message = "We're checking the airline confirmation. Don't book or pay again yet."
                    }
                case .confirmed:
                    state.bookingOutcomeUnknown = false
                    state.canUploadProof = false
                    state.screenState = .submitted
                case .expired, .unavailable:
                    state.screenState = .content
                    state.canUploadProof = false
                    state.recoveryAction = .chooseAnotherFlight
                    state.message = details.status == .expired
                        ? "This fare expired. Search again for current flights."
                        : "This fare is no longer available. Search again for current flights."
                case .agentReviewing:
                    state.screenState = .content
                    state.bookingOutcomeUnknown = true
                    state.canUploadProof = false
                    state.message = "Our team is checking this booking. Don't book or pay again yet."
                default:
                    state.screenState = .content
                }
                if state.bookingOutcomeUnknown {
                    switch details.status {
                    case .holdChangeReview:
                        state.message = "The airline created a hold, but the price or flight details changed. Don't pay yet. Our team is reviewing it."
                    case .holdFailed:
                        state.message = "No flight was held. Your passenger details are saved. Search again for a current fare."
                    case .holdPending:
                        state.message = "Booking request in progress. Don't book or pay again yet."
                    default:
                        state.message = "We sent your request, but haven't confirmed whether the airline held the flight. Don't book or pay again yet."
                    }
                }
            case .expired:
                showError("This fare expired. Search again for current flights.")
                state.recoveryAction = .chooseAnotherFlight
            case .networkUnavailable: showError("Connection lost. Check your internet and retry.", canRetry: true)
            case .notFound: showError("Booking request was not found.")
            case .unavailable:
                showError("This fare is no longer available. Search again for current flights.")
                state.recoveryAction = .chooseAnotherFlight
            case .unknownError: showError("Could not load booking review. Please retry.", canRetry: true)
            }
        } catch is CancellationError {
            state = previous
            throw CancellationError()
        } catch {
            state = previous
            if state.details?.status == .submittedForManualReview {
                state.screenState = .content
                state.bookingOutcomeUnknown = true
                state.canUploadProof = false
            }
            state.message = "Could not check booking status. Try again. Don't book or pay again yet."
        }
    }
    func submit() async throws {
        guard !state.isSubmitting else { return }
        guard state.screenState == .content, state.details?.status == .draftSaved else { return }
        guard !state.bookingOutcomeUnknown else { return }
        guard state.recoveryAction == nil, state.pendingPriceQuote == nil,
              !state.isRepricing, !state.isAcceptingPrice else { return }
        state.isSubmitting = true; state.message = nil; state.recoveryAction = nil
        do {
            let result = try await repository.submitReview(reviewId: reviewId, idempotencyKey: holdKey)
            try Task.checkCancellation()
            switch result {
        case let .success(_, reference, status):
            guard let details = state.details else { showError("Booking request was not found."); return }
            state.details = .init(reviewId: details.reviewId, bookingReference: reference, status: status,
                                  passengers: details.passengers, contact: details.contact, seats: details.seats,
                                  fareTotal: details.fareTotal)
            state.screenState = .submitted; state.isSubmitting = false; state.canUploadProof = true
        case .expired:
            showSubmitError("This fare expired. Search again for current flights.")
            state.recoveryAction = .chooseAnotherFlight
        case let .priceChanged(message):
            showSubmitError(message)
            state.recoveryAction = state.details?.updatedAt == nil ? .chooseAnotherFlight : .reviewUpdatedPrice
        case let .fareUnavailable(message):
            showSubmitError(message)
            state.recoveryAction = .chooseAnotherFlight
        case .networkUnavailable:
            showSubmitError("Connection lost after your request. Check booking status before trying again.")
            state.bookingOutcomeUnknown = true
        case .outcomeUnknown:
            showSubmitError("We could not confirm whether the airline secured this booking. Your details are saved. Check booking status before trying again.")
            state.bookingOutcomeUnknown = true
        case .changedHoldReview:
            showSubmitError("The airline created a hold, but the price or flight details changed. Don't pay yet. Our team is reviewing it.")
            state.bookingOutcomeUnknown = true
            state.canUploadProof = false
            state.statusOutcome = .changedHoldReview
        case .notFound: showSubmitError("Booking request was not found.")
        case .unavailable:
            showSubmitError("This fare is no longer available. Search again for current flights.")
            state.recoveryAction = .chooseAnotherFlight
        case .unknownError:
            showSubmitError("We couldn't confirm this booking. Check booking status before trying again.")
            state.bookingOutcomeUnknown = true
        }
        } catch is CancellationError {
            state.isSubmitting = false
            state.bookingOutcomeUnknown = true
            state.message = "Booking request may have reached the airline. Check status before booking or paying again."
            throw CancellationError()
        }
        catch {
            showSubmitError("We couldn't confirm this booking. Check booking status before trying again.")
            state.bookingOutcomeUnknown = true
        }
    }
    func back() { navigation.append(.back) }
    func home() { navigation.append(.home) }
    func chooseAnotherFlight() { navigation.append(.chooseAnotherFlight) }
    func dismissPriceQuote() { state.pendingPriceQuote = nil }
    private var holdKey: String {
        if let idempotencyKeyOverride { return idempotencyKeyOverride }
        return "ios-hold-\(reviewId)-\(state.details?.acceptedQuoteRevision ?? "initial")"
    }
    func reviewUpdatedPrice() async throws {
        guard !state.isRepricing, let version = state.details?.updatedAt else {
            state.recoveryAction = .chooseAnotherFlight
            return
        }
        state.isRepricing = true
        defer { state.isRepricing = false }
        do {
            let result = try await repository.reprice(reviewId: reviewId, expectedUpdatedAt: version)
            try Task.checkCancellation()
            switch result {
            case let .success(quote) where !quote.requiresNewFlight && quote.itineraryChanged == false:
                state.pendingPriceQuote = quote
                state.message = "Review the current price before continuing. No new hold has been requested."
            case .success, .expired, .unavailable:
                state.recoveryAction = .chooseAnotherFlight
                state.message = "This flight needs a new search. Your passenger details remain saved."
            case .networkUnavailable:
                state.message = "Connection lost. Could not check the current fare. Try again when online."
            case .unknownError:
                state.message = "Could not check the current fare. Try again."
            }
        } catch is CancellationError { throw CancellationError() }
        catch { state.message = "Could not check the current fare. Try again." }
    }
    func acceptUpdatedPrice() async throws {
        guard !state.isAcceptingPrice, let quote = state.pendingPriceQuote else { return }
        state.isAcceptingPrice = true
        defer { state.isAcceptingPrice = false }
        do {
            let result = try await repository.acceptQuote(
                reviewId: reviewId, expectedUpdatedAt: quote.updatedAt, quoteRevision: quote.quoteRevision
            )
            try Task.checkCancellation()
            switch result {
            case let .success(details) where details.acceptedQuoteRevision == quote.quoteRevision:
                state.details = details
                state.pendingPriceQuote = nil
                state.bookingOutcomeUnknown = false
                state.statusOutcome = nil
                state.recoveryAction = nil
                state.message = quote.seatSelectionWillBeCleared
                    ? "Updated price accepted. Flight-specific seat selections were cleared. Review the total and choose seats again before requesting a hold."
                    : "Updated price accepted. Review the total before requesting a hold."
            case .success, .unavailable, .expired, .notFound:
                state.pendingPriceQuote = nil
                state.recoveryAction = .chooseAnotherFlight
                state.message = "This fare changed again. Search current flights before booking."
            case .networkUnavailable, .unknownError:
                state.message = "Could not confirm the updated price. Check again before booking."
            }
        } catch is CancellationError { throw CancellationError() }
        catch { state.message = "Could not confirm the updated price. Check again before booking." }
    }
    func payment() { if state.canUploadProof, let id = state.details?.reviewId { navigation.append(.payment(id)) } }
    func trip() { if let id = state.details?.reviewId { navigation.append(.trip(id)) } }
    func consumeNavigation() -> BookingReviewNavigation? { navigation.isEmpty ? nil : navigation.removeFirst() }
    private func showError(_ message: String, canRetry: Bool = false) {
        state.screenState = .error; state.isSubmitting = false; state.message = message; state.canRetryLoad = canRetry
    }
    func checkStatus() async throws {
        guard !state.isCheckingStatus else { return }
        state.isCheckingStatus = true
        defer { state.isCheckingStatus = false }
        do {
            var result = try await repository.requestStatusCheck(reviewId: reviewId)
            try Task.checkCancellation()
            guard case let .success(initialSnapshot) = result else {
                applyStatusFailure(result)
                return
            }
            var snapshot = initialSnapshot
            updateStatusMetadata(snapshot)
            if snapshot.reconciliationState == .queued || snapshot.reconciliationState == .checking {
                for _ in 0..<statusPollingLimit {
                    try await Task.sleep(for: statusPollingInterval)
                    try Task.checkCancellation()
                    result = try await repository.getStatus(reviewId: reviewId)
                    try Task.checkCancellation()
                    guard case let .success(updated) = result else {
                        applyStatusFailure(result)
                        return
                    }
                    snapshot = updated
                    updateStatusMetadata(snapshot)
                    if snapshot.reconciliationState != .queued && snapshot.reconciliationState != .checking { break }
                }
            }
            apply(snapshot)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            state.bookingOutcomeUnknown = true
            state.canUploadProof = false
            state.message = "Could not check booking status. Don't book or pay again yet."
        }
    }

    private func updateStatusMetadata(_ snapshot: BookingStatusSnapshot) {
        state.statusOutcome = snapshot.outcome
        state.reconciliationState = snapshot.reconciliationState
        state.lastSupplierCheckedAt = snapshot.lastSupplierCheckedAt
        state.allowedNextActions = snapshot.allowedNextActions
    }

    private func apply(_ snapshot: BookingStatusSnapshot) {
        updateStatusMetadata(snapshot)
        state.canUploadProof = false
        switch snapshot.outcome {
        case .draft:
            state.bookingOutcomeUnknown = false
            state.message = "No hold was found. Review your details before requesting a hold."
        case .held, .paymentReview, .ticketPending, .ticketed:
            guard let reference = snapshot.bookingReference, let details = state.details else {
                state.bookingOutcomeUnknown = true
                state.message = "We're checking the airline confirmation. Don't book or pay again yet."
                return
            }
            state.details = .init(reviewId: details.reviewId, bookingReference: reference,
                                  status: .submittedForManualReview, passengers: details.passengers,
                                  contact: details.contact, seats: details.seats, fareTotal: details.fareTotal,
                                  updatedAt: details.updatedAt, acceptedQuoteRevision: details.acceptedQuoteRevision)
            state.bookingOutcomeUnknown = false
            state.canUploadProof = snapshot.outcome == .held &&
                snapshot.allowedNextActions.contains(.uploadPaymentProof)
            state.screenState = .submitted
            state.message = nil
        case .pending, .unknown:
            state.bookingOutcomeUnknown = true
            state.message = "We're still checking whether the airline held your flight. Don't book or pay again yet."
        case .changedHoldReview:
            state.bookingOutcomeUnknown = true
            state.message = "The airline created a hold, but the price or flight details changed. Don't pay yet. Our team is reviewing it."
        case .notHeld:
            state.bookingOutcomeUnknown = false
            state.message = "No flight was held. Your passenger details are saved."
        case .expired, .cancelled:
            state.bookingOutcomeUnknown = false
            state.message = "This hold is no longer active. Search again to choose a flight."
        }
        if snapshot.reconciliationState == .staffReview {
            state.bookingOutcomeUnknown = true
            state.canUploadProof = false
            state.message = "Our team is reviewing this booking. Don't book or pay again yet."
        }
    }

    private func applyStatusFailure(_ result: BookingStatusResult) {
        state.bookingOutcomeUnknown = true
        state.canUploadProof = false
        switch result {
        case .networkUnavailable:
            state.message = "Connection lost. Booking status may have changed. Check again when you're online."
        case .notFound, .unknownError, .success:
            state.message = "Could not check booking status. Don't book or pay again yet."
        }
    }
    private func showSubmitError(_ message: String) { state.isSubmitting = false; state.message = message }
}
