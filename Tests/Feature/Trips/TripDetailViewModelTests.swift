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
    @Test func serverActionPolicyOverridesStalePaymentAction() async throws {
        var trip = Self.trip.with(status: "BOOKING_HELD", nextAction: "UPLOAD_PAYMENT_PROOF", paymentProofStatus: "MISSING")
        trip.summary = TripSummary(
            presentation: .init(
                state: "PAID_NEEDS_ATTENTION",
                section: .attention,
                primaryAction: "GET_HELP",
                allowedActions: ["GET_HELP", "VIEW_TRIP"],
                progress: .init(booking: "COMPLETE", payment: "COMPLETE", ticket: "PENDING")
            ),
            route: .init(origin: "ADD", destination: "DXB"),
            departureDate: nil,
            returnDate: nil,
            carrier: nil,
            airline: nil,
            logoURL: nil,
            tripType: nil,
            verification: nil,
            supplierCheckState: nil
        )
        let viewModel = TripDetailViewModel(bookingId: "b-1", repository: TripsFakeRepository(detail: .success(trip)))

        try await viewModel.load()

        #expect(viewModel.state.primaryActionLabel == "Get help")
        #expect(!trip.canUploadReceipt)
    }

    @Test func abandonedTripUsesBookingStatusAndOffersSupport() async throws {
        var trip = Self.trip
        trip.summary = TripSummary(
            presentation: .init(
                state: "ABANDONED", section: .attention, primaryAction: "CHECK_STATUS",
                allowedActions: ["CHECK_STATUS"],
                progress: .init(booking: "PENDING", payment: "PENDING", ticket: "PENDING")
            ),
            route: .init(origin: "ADD", destination: "DXB"),
            departureDate: nil, returnDate: nil, carrier: nil, airline: nil, logoURL: nil,
            tripType: nil, verification: nil, supplierCheckState: nil
        )
        let repository = TripsFakeRepository(detail: .success(trip))
        let viewModel = TripDetailViewModel(bookingId: trip.id, repository: repository) { bookingID in
            #expect(bookingID == "b-1")
            return .success(.init(outcome: .unknown, bookingReference: nil, abandonmentState: .supportReview))
        }

        try await viewModel.load()
        try await viewModel.load(forceRefresh: true)

        #expect(viewModel.state.trip?.offersDetailSupport == true)
        #expect(viewModel.state.notice.contains("couldn’t confirm the reservation’s cancellation"))
        #expect(await repository.supplierRefreshCount == 0)
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
    func trips(view: TripView, forceRefresh: Bool, cursor: String?) async throws -> TripPageState { .loading }
    private(set) var supplierRefreshCount = 0
    func requestSupplierRefresh(bookingIDs: [String]) async throws -> TripSupplierRefreshResult {
        supplierRefreshCount += 1
        return .accepted(pending: false)
    }
    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult { detail }
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult { .unavailable }
    func cachedTicketPdf(id: String, version: String?) async throws -> CachedTicketResult? { nil }
    func cacheTicketPdf(id: String, downloadURL: URL, version: String?) async throws -> CachedTicketResult { .unknownError }
}
