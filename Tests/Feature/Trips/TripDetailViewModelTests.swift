import Foundation
import Testing
@testable import NexusTravel

@MainActor struct TripDetailViewModelTests {
    @Test func ticketedTripExposesTicketActions() async throws {
        let repository = TripsFakeRepository(detail: .success(Self.trip))
        let viewModel = TripDetailViewModel(bookingId: "b-1", repository: repository)
        try await viewModel.load()
        #expect(viewModel.state.notice == "Your ticket is ready.")
        #expect(viewModel.state.primaryActionLabel == "View ticket")
        #expect(viewModel.state.secondaryActionLabel == "Download again")
    }
    @Test func unconfirmedHoldDoesNotRequestPayment() async throws {
        let trip = Self.trip.with(status: "HOLD_UNCONFIRMED", nextAction: "CONTACT_SUPPORT")
        let viewModel = TripDetailViewModel(bookingId: "b-1", repository: TripsFakeRepository(detail: .success(trip)))
        try await viewModel.load()
        #expect(viewModel.state.notice.contains("haven't confirmed"))
        #expect(viewModel.state.primaryActionLabel == "Check status")
        #expect(viewModel.state.secondaryActionLabel != "Upload payment receipt")
    }
    @Test func staleUploadActionCannotUnlockUnconfirmedOrChangedHold() {
        let unknown = Self.trip.with(status: "HOLD_UNCONFIRMED", nextAction: "UPLOAD_PAYMENT_PROOF")
        let changed = Self.trip.with(status: "HOLD_CHANGE_REVIEW", nextAction: "UPLOAD_PAYMENT_PROOF")
        #expect(!unknown.canUploadReceipt)
        #expect(!changed.canUploadReceipt)
        #expect(unknown.bookingStatusLabel == "Checking airline confirmation")
        #expect(changed.bookingStatusLabel == "Hold needs review")
    }
    @Test func ticketingDelayDoesNotClaimFundsAreSecure() async throws {
        let trip = Self.trip.with(status: "TICKETING_DELAYED", nextAction: "CONTACT_SUPPORT")
        let viewModel = TripDetailViewModel(bookingId: "b-1", repository: TripsFakeRepository(detail: .success(trip)))
        try await viewModel.load()
        #expect(!viewModel.state.notice.contains("funds are secure"))
    }
    @Test func heldReceiptAndTicketStatesHaveDistinctCopy() async throws {
        let held = Self.trip.with(status: "BOOKING_HELD", nextAction: "UPLOAD_PAYMENT_PROOF", paymentProofStatus: "MISSING")
        let receipt = Self.trip.with(status: "BOOKING_HELD", nextAction: "VIEW_STATUS", paymentProofStatus: "UPLOADED")
        let paid = Self.trip.with(status: "PAYMENT_CONFIRMED", nextAction: "VIEW_STATUS")
        for (trip, expected) in [(held, "Upload your payment receipt"),
                                 (receipt, "Receipt received"),
                                 (paid, "Payment verified")] {
            let viewModel = TripDetailViewModel(bookingId: "b-1", repository: TripsFakeRepository(detail: .success(trip)))
            try await viewModel.load()
            #expect(viewModel.state.notice.contains(expected))
        }
    }
    static let trip = CustomerTrip(id: "b-1", group: .upcoming, status: "TICKETED", paymentStatus: "PAID", paymentProofStatus: "VERIFIED", ticketingStatus: "TICKETED", amountMinor: 100, currency: "USD", holdExpiresAt: nil, ticketDocumentAvailable: true, nextAction: "DOWNLOAD_TICKET", createdAt: "2026-08-30", itineraryLabel: "ADD to DXB")
}

private extension CustomerTrip {
    func with(status: String, nextAction: String, paymentProofStatus: String? = nil) -> CustomerTrip {
        CustomerTrip(id: id, group: .actionRequired, status: status, paymentStatus: paymentStatus,
                     paymentProofStatus: paymentProofStatus ?? self.paymentProofStatus, ticketingStatus: ticketingStatus,
                     amountMinor: amountMinor, currency: currency, holdExpiresAt: holdExpiresAt,
                     ticketDocumentAvailable: ticketDocumentAvailable, nextAction: nextAction,
                     createdAt: createdAt, itineraryLabel: itineraryLabel)
    }
}

private actor TripsFakeRepository: TripsRepository {
    let detail: TripDetailResult
    init(detail: TripDetailResult) { self.detail = detail }
    func trips(group: TripGroup, forceRefresh: Bool) async throws -> TripPageState { .loading }
    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult { detail }
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult { .unavailable }
    func cacheTicketPdf(id: String, downloadURL: URL) async throws -> CachedTicketResult { .unknownError }
}
