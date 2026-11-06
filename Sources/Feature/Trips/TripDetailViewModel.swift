import Foundation
import Observation

enum TripDetailRetryAction: Equatable, Sendable { case refresh, ticket }

struct TripDetailUiState: Equatable, Sendable {
    var loading = true; var refreshing = false; var downloadingTicket = false; var trip: CustomerTrip?
    var ticketSavedVersionWarning = false
    var primaryAction: TripAction?
    var retryAction: TripDetailRetryAction?
    var error: String?; var notice = ""; var primaryActionLabel: String?; var secondaryActionLabel: String?; var ticketToOpen: URL?
}
@MainActor @Observable final class TripDetailViewModel {
    private(set) var state = TripDetailUiState()
    private let bookingId: String
    private let repository: any TripsRepository
    private let requestStatusCheck: (String) async throws -> BookingStatusResult
    private var reading = false

    init(
        bookingId: String,
        repository: any TripsRepository,
        requestStatusCheck: @escaping (String) async throws -> BookingStatusResult = { _ in .unknownError }
    ) {
        self.bookingId = bookingId
        self.repository = repository
        self.requestStatusCheck = requestStatusCheck
    }
    func load(forceRefresh: Bool = false) async throws {
        guard !reading, !state.downloadingTicket else { return }
        reading = true
        let prior = state
        state.loading = state.trip == nil
        state.refreshing = state.trip != nil
        state.error = nil
        state.retryAction = nil
        defer { reading = false }

        do {
            var pending = false
            var abandonmentState = prior.trip?.abandonmentState
            let presentation = prior.trip?.summary?.presentation?.state
            if forceRefresh, ["ABANDONED", "CONFIRMING", "HOLD_CHANGED"].contains(presentation ?? "") {
                let status = try await requestStatusCheck(bookingId)
                try Task.checkCancellation()
                if presentation == "ABANDONED", case let .success(snapshot) = status {
                    abandonmentState = snapshot.abandonmentState ?? abandonmentState
                }
                pending = presentation != "ABANDONED"
            } else if forceRefresh {
                do {
                    let status = try await repository.requestSupplierRefresh(bookingIDs: [bookingId])
                    try Task.checkCancellation()
                    switch status {
                    case let .accepted(waiting): pending = waiting
                    case .authRequired, .unavailable:
                        state = TripDetailUiState(loading: false, error: "This trip is unavailable. Sign in again or return to Trips.")
                        return
                    case .failed: break
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    try Task.checkCancellation()
                }
            }

            let result = try await repository.tripDetail(id: bookingId, forceRefresh: true)
            try Task.checkCancellation()
            apply(result, abandonmentState: abandonmentState)
            if forceRefresh, pending || state.trip?.detail?.seatState == .checking {
                for delay in [Duration.seconds(2), .seconds(3), .seconds(5)] {
                    guard state.trip?.summary?.supplierCheckPending == true || state.trip?.detail?.seatState == .checking else {
                        break
                    }
                    try await Task.sleep(for: delay)
                    let updated = try await repository.tripDetail(id: bookingId, forceRefresh: true)
                    try Task.checkCancellation()
                    apply(updated, abandonmentState: abandonmentState)
                    guard case .success = updated else { break }
                }
            }
        } catch is CancellationError {
            if state.loading || state.refreshing { state = prior }
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                if state.loading || state.refreshing { state = prior }
                throw CancellationError()
            }
            apply(.failed)
        }
    }

    private func apply(_ result: TripDetailResult, abandonmentState: BookingAbandonmentState? = nil) {
        switch result {
        case var .success(trip):
            trip.abandonmentState = abandonmentState ?? trip.abandonmentState
            state = trip.uiState
        case .authRequired, .notFound:
            state = TripDetailUiState(loading: false, error: "This trip is unavailable. Sign in again or return to Trips.")
        case .networkUnavailable, .failed:
            state.trip?.offline = result == .networkUnavailable
            if state.primaryAction == .uploadPaymentProof {
                state.primaryAction = nil
                state.primaryActionLabel = nil
            }
            fail("Could not refresh trip. Try again.")
        }
    }

    func downloadTicket() async throws {
        guard !reading, !state.downloadingTicket, let trip = state.trip, trip.ticketDocumentAvailable,
              trip.summary?.presentation == nil || trip.detailActions.contains(.downloadTicket) else { return }
        state.downloadingTicket = true
        state.error = nil
        state.retryAction = nil
        state.ticketToOpen = nil
        state.ticketSavedVersionWarning = false
        defer { state.downloadingTicket = false }

        let version = trip.detail?.ticketDocument?.version
        var previous: URL?
        do {
            let local = try await repository.cachedTicketPdf(id: bookingId, version: version)
            try Task.checkCancellation()
            switch local {
            case let .success(file): state.ticketToOpen = file; return
            case let .previousVersion(file): previous = file
            default: break
            }

            if trip.offline {
                ticketFallback(previous, message: "Connection lost. Retry when you’re online.")
                return
            }

            let document = try await repository.resolveTicketDocument(id: bookingId)
            try Task.checkCancellation()
            switch document {
            case let .success(url):
                let cached = try await repository.cacheTicketPdf(id: bookingId, downloadURL: url, version: version)
                try Task.checkCancellation()
                switch cached {
                case let .success(file): state.ticketToOpen = file
                case let .previousVersion(file): ticketFallback(file, message: "")
                case .networkUnavailable: ticketFallback(previous, message: "Connection lost. Retry when you’re online.")
                case .storageUnavailable: ticketFallback(previous, message: "Could not save ticket on this device. Try again.")
                case .unknownError: ticketFallback(previous, message: "Could not load your ticket PDF. Try again.")
                }
            case .authRequired: ticketError("Sign in again to open this ticket.")
            case .networkUnavailable: ticketFallback(previous, message: "Connection lost. Retry when you’re online.")
            case .unavailable: ticketError("Ticket document isn’t available. Check status or contact support.")
            case .unknownError: ticketFallback(previous, message: "Could not load your ticket PDF. Try again.")
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            ticketFallback(previous, message: "Could not load your ticket PDF. Try again.")
        }
    }

    private func ticketFallback(_ previous: URL?, message: String) {
        if let previous {
            state.ticketSavedVersionWarning = true
            state.ticketToOpen = previous
        } else {
            ticketError(message)
        }
    }

    func retry() async throws {
        if state.retryAction == .ticket {
            try await downloadTicket()
        } else {
            try await load(forceRefresh: true)
        }
    }

    func ticketOpened() {
        state.ticketToOpen = nil
        state.ticketSavedVersionWarning = false
    }
    private func fail(_ message: String) { state.loading = false; state.refreshing = false; state.error = message; state.retryAction = .refresh }
    private func ticketError(_ message: String) { state.downloadingTicket = false; state.error = message; state.retryAction = .ticket }
}
extension CustomerTrip {
    var canUploadReceipt: Bool {
        guard !offline, detail?.abandonedAt == nil else { return false }
        if let presentation = summary?.presentation {
            return ["PAYMENT_NEEDED", "PAYMENT_PROOF_REJECTED"].contains(presentation.state)
                && detailActions.contains(.uploadPaymentProof)
        }
        return status.uppercased() == "BOOKING_HELD" && nextAction == "UPLOAD_PAYMENT_PROOF"
    }

    var bookingStatusLabel: String {
        if status.uppercased() == "BOOKING_HELD", paymentProofStatus == "UPLOADED" {
            return "Receipt under review"
        }
        return switch status.uppercased() {
        case "HOLD_REQUESTED", "HOLDING_WITH_TRAVELPORT": "Booking request in progress"
        case "HOLD_UNCONFIRMED": "Checking airline confirmation"
        case "HOLD_CHANGE_REVIEW": "Hold needs review"
        case "HOLD_FAILED": "Booking not completed"
        case "BOOKING_HELD": "Flight held"
        case "HOLD_EXPIRED", "EXPIRED": "Hold expired"
        case "PAYMENT_PROOF_UPLOADED": "Receipt under review"
        case "PAYMENT_CONFIRMED", "TICKET_PENDING": "Ticket pending"
        case "TICKETED": "Ticket ready"
        case "CANCELLED": "Cancelled"
        default: "Booking status updating"
        }
    }

    var uiState: TripDetailUiState {
        if let copy = detailStatusCopy {
            let action = presentedDetailAction
            let title = action == .uploadPaymentProof && summary?.presentation?.state == "PAYMENT_NEEDED"
                ? "Make payment" : action?.label
            return TripDetailUiState(
                loading: false, trip: self, primaryAction: action, notice: copy.explanation, primaryActionLabel: title
            )
        }
        let policy: (String, String?, String?)
        if status.uppercased() == "TICKETED", ticketDocumentAvailable { policy = ("Your ticket is ready.", "View ticket", "Download again") }
        else if status.uppercased() == "TICKETED" { policy = ("Ticket issued. Document is being prepared.", "Refresh", nil) }
        else if status.uppercased() == "HOLD_UNCONFIRMED" { policy = ("We sent your request, but haven't confirmed whether the airline held the flight. Don't book or pay again yet.", "Check status", nil) }
        else if status.uppercased() == "HOLD_CHANGE_REVIEW" { policy = ("The airline created a hold, but the price or flight details changed. Don't pay yet. Our team is reviewing it.", "Check status", nil) }
        else if status.uppercased() == "HOLD_REQUESTED" || status.uppercased() == "HOLDING_WITH_TRAVELPORT" { policy = ("Your booking request is still being checked. Don't submit another request or pay yet.", "Check status", nil) }
        else if status.uppercased() == "HOLD_FAILED" { policy = ("No flight was held. Your passenger details are saved.", "Refresh", nil) }
        else if status.uppercased() == "TICKETING_DELAYED" || ["DELAYED", "OUTCOME_UNKNOWN"].contains(ticketingStatus.uppercased()) { policy = ("Payment verification or ticketing is delayed. Our team is reviewing the booking.", "Refresh", nil) }
        else if status.uppercased() == "TICKETING_FAILED" || ticketingStatus.uppercased() == "FAILED" { policy = ("We could not issue this ticket automatically. Our team is reviewing it.", "Check status", nil) }
        else if status.uppercased() == "BOOKING_HELD", paymentProofStatus == "MISSING" { policy = ("Upload your payment receipt so our team can verify payment and issue your ticket.", "Upload payment receipt", nil) }
        else if status.uppercased() == "BOOKING_HELD", paymentProofStatus == "UPLOADED" { policy = ("Receipt received. Payment has not been verified yet.", "Check status", nil) }
        else if status.uppercased() == "PAYMENT_CONFIRMED" { policy = ("Payment verified. Your ticket is being prepared.", "Check status", nil) }
        else if paymentStatus == "FAILED" { policy = ("Payment could not be verified. Check booking status before taking another step.", "Check status", nil) }
        else if status.uppercased() == "CANCELLED" { policy = ("This trip is cancelled.", ticketDocumentAvailable ? "View ticket" : nil, nil) }
        else { policy = ("Track your booking details here.", nil, nil) }
        return TripDetailUiState(loading: false, trip: self, notice: policy.0, primaryActionLabel: policy.1, secondaryActionLabel: policy.2)
    }
}
