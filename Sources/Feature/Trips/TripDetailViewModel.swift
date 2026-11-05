import Foundation
import Observation

struct TripDetailUiState: Equatable, Sendable {
    var loading = true; var refreshing = false; var downloadingTicket = false; var trip: CustomerTrip?
    var error: String?; var notice = ""; var primaryActionLabel: String?; var secondaryActionLabel: String?; var ticketToOpen: URL?
}
@MainActor @Observable final class TripDetailViewModel {
    private(set) var state = TripDetailUiState()
    private let bookingId: String; private let repository: any TripsRepository
    init(bookingId: String, repository: any TripsRepository) { self.bookingId = bookingId; self.repository = repository }
    func load(forceRefresh: Bool = false) async throws {
        let prior = state; state.loading = state.trip == nil; state.refreshing = state.trip != nil; state.error = nil
        do {
            switch try await repository.tripDetail(id: bookingId, forceRefresh: forceRefresh) {
            case let .success(trip): state = trip.uiState
            case .authRequired: fail("Sign in again to view this trip.")
            case .notFound: fail("Trip not found.")
            case .networkUnavailable: fail("Connection lost. Retry when you are online.")
            case .failed: fail("Could not load trip.")
            }
        } catch is CancellationError { state = prior; throw CancellationError() }
    }
    func downloadTicket() async throws {
        guard !state.downloadingTicket, state.trip?.ticketDocumentAvailable == true else { return }
        state.downloadingTicket = true; state.error = nil; state.ticketToOpen = nil
        do {
            switch try await repository.resolveTicketDocument(id: bookingId) {
            case let .success(url):
                switch try await repository.cacheTicketPdf(id: bookingId, downloadURL: url) {
                case let .success(file): state.downloadingTicket = false; state.ticketToOpen = file
                case .networkUnavailable: ticketError("Connection lost. Retry when you are online.")
                case .storageUnavailable: ticketError("Could not save ticket on this device.")
                case .unknownError: ticketError("We couldn’t load your e-ticket PDF.")
                }
            case .authRequired: ticketError("Sign in again to open this ticket.")
            case .networkUnavailable: ticketError("Connection lost. Retry when you are online.")
            case .unavailable: ticketError("Ticket document is not ready yet.")
            case .unknownError: ticketError("We couldn’t load your e-ticket PDF.")
            }
        } catch is CancellationError { state.downloadingTicket = false; throw CancellationError() }
    }
    func ticketOpened() { state.ticketToOpen = nil }
    private func fail(_ message: String) { state.loading = false; state.refreshing = false; state.error = message }
    private func ticketError(_ message: String) { state.downloadingTicket = false; state.error = message }
}
extension CustomerTrip {
    var canUploadReceipt: Bool {
        status.uppercased() == "BOOKING_HELD" && nextAction == "UPLOAD_PAYMENT_PROOF"
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
