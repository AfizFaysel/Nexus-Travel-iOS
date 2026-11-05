import Foundation
import Testing
@testable import NexusTravel

struct RemoteBookingRequestRepositoryTests {
    @Test func holdSendsStableKeyAndAcceptsConfirmedSupplierReference() async throws {
        let loader = BookingRequestLoader(responses: [Self.response(201, Self.heldJSON)])
        let result = try await Self.repository(loader).submitReview(reviewId: "b-1", idempotencyKey: "stable-key")
        #expect(result == .success(reviewId: "b-1", bookingReference: "ABC123", status: .submittedForManualReview))
        let requests = await loader.requests
        #expect(requests[0].url?.path == "/api/v1/mobile/bookings/b-1/hold")
        #expect(requests[0].value(forHTTPHeaderField: "Idempotency-Key") == "stable-key")
    }

    @Test(arguments: ["UNKNOWN", "FAKE123", "LOCAL-1"])
    func placeholderSupplierReferenceIsUnavailable(_ reference: String) async throws {
        let body = Self.heldJSON.replacingOccurrences(of: "ABC123", with: reference)
        let result = try await Self.repository(BookingRequestLoader(responses: [Self.response(201, body)]))
            .submitReview(reviewId: "b-1", idempotencyKey: "stable")
        #expect(result == .unavailable)
    }

    @Test func unconfirmedHoldIsOutcomeUnknown() async throws {
        let body = Self.heldJSON.replacingOccurrences(of: "BOOKING_HELD", with: "HOLD_UNCONFIRMED")
        let result = try await Self.repository(BookingRequestLoader(responses: [Self.response(201, body)]))
            .submitReview(reviewId: "b-1", idempotencyKey: "stable")
        #expect(result == .outcomeUnknown)
    }

    @Test func changedHoldIsNotRetryableOrPayable() async throws {
        let body = Self.heldJSON.replacingOccurrences(of: "BOOKING_HELD", with: "HOLD_CHANGE_REVIEW")
        let result = try await Self.repository(BookingRequestLoader(responses: [Self.response(201, body)]))
            .submitReview(reviewId: "b-1", idempotencyKey: "stable")
        #expect(result == .changedHoldReview)
    }

    @Test func definiteGdsPriceChangeIsNotHeld() async throws {
        let body = Self.heldJSON
            .replacingOccurrences(of: "BOOKING_HELD", with: "HOLD_FAILED")
            .replacingOccurrences(of: #""failureReason":null,"failureReasonCode":null"#,
                                  with: #""failureReason":"Flight price changed.","failureReasonCode":"PRICE_CHANGED""#)
        let result = try await Self.repository(BookingRequestLoader(responses: [Self.response(201, body)]))
            .submitReview(reviewId: "b-1", idempotencyKey: "stable")
        #expect(result == .priceChanged("Flight price changed."))
    }

    @Test func repriceDoesNotAcceptQuoteAndUsesBookingVersion() async throws {
        let body = #"{"previousAmountMinor":15875,"newAmountMinor":17200,"currency":"USD","quoteRevision":"revision-2","updatedAt":"2026-09-24T10:01:00.000Z","requiresNewFlight":false,"itineraryChanged":false,"seatSelectionWillBeCleared":true}"#
        let loader = BookingRequestLoader(responses: [Self.response(201, body)])
        let result = try await Self.repository(loader).reprice(reviewId: "b-1", expectedUpdatedAt: "2026-09-24T10:00:00.000Z")
        guard case let .success(quote) = result else { Issue.record("Expected quote"); return }
        #expect(quote.previousAmountMinor == 15875)
        #expect(quote.newAmountMinor == 17200)
        #expect(quote.seatSelectionWillBeCleared)
        let request = try #require(await loader.requests.first)
        #expect(request.url?.path == "/api/v1/mobile/bookings/b-1/reprice")
        #expect(String(decoding: request.httpBody ?? Data(), as: UTF8.self).contains("expectedUpdatedAt"))
    }

    @Test func statusEndpointMapsPendingWithoutTreatingItAsHeld() async throws {
        let body = #"{"bookingId":"b-1","status":"HOLD_UNCONFIRMED","outcomeCode":"UNKNOWN","updatedAt":"2026-09-24T10:00:00.000Z","travelportLocator":null,"allowedNextActions":["CHECK_STATUS","VIEW_TRIP"],"reconciliationState":"QUEUED","lastSupplierCheckedAt":null}"#
        let loader = BookingRequestLoader(responses: [Self.response(200, body)])
        let result = try await Self.repository(loader).getStatus(reviewId: "b-1")
        #expect(result == .success(.init(outcome: .unknown, bookingReference: nil,
                                         reconciliationState: .queued, lastSupplierCheckedAt: nil,
                                         allowedNextActions: [.checkStatus, .viewTrip])))
        #expect(await loader.requests.first?.url?.path == "/api/v1/mobile/bookings/b-1/status")
    }

    @Test func statusCheckRequestsReconciliationWithoutSubmittingHold() async throws {
        let body = #"{"bookingId":"b-1","status":"HOLD_UNCONFIRMED","outcomeCode":"UNKNOWN","updatedAt":"2026-09-24T10:00:00.000Z","travelportLocator":null,"allowedNextActions":["CHECK_STATUS","VIEW_TRIP"],"reconciliationState":"QUEUED","lastSupplierCheckedAt":null}"#
        let loader = BookingRequestLoader(responses: [Self.response(202, body)])

        let result = try await Self.repository(loader).requestStatusCheck(reviewId: "b-1")

        #expect(result == .success(.init(outcome: .unknown, bookingReference: nil,
                                         reconciliationState: .queued, lastSupplierCheckedAt: nil,
                                         allowedNextActions: [.checkStatus, .viewTrip])))
        let request = try #require(await loader.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/mobile/bookings/b-1/status-check")
    }

    @Test func statusDecoderMapsDraftAndSupplierCheckMetadata() async throws {
        let body = #"{"bookingId":"b-1","status":"DRAFT","outcomeCode":"DRAFT","updatedAt":"2026-09-24T10:00:00.000Z","travelportLocator":null,"allowedNextActions":["VIEW_TRIP"],"reconciliationState":"NOT_NEEDED","lastSupplierCheckedAt":"2026-09-24T09:59:00.000Z"}"#
        let loader = BookingRequestLoader(responses: [Self.response(200, body)])

        let result = try await Self.repository(loader).getStatus(reviewId: "b-1")

        #expect(result == .success(.init(outcome: .draft, bookingReference: nil,
                                         reconciliationState: .notNeeded,
                                         lastSupplierCheckedAt: "2026-09-24T09:59:00.000Z",
                                         allowedNextActions: [.viewTrip])))
    }

    @Test func reviewDecoderMapsBackendDraftStatus() async throws {
        let body = Self.heldJSON.replacingOccurrences(of: "BOOKING_HELD", with: "DRAFT")
            .replacingOccurrences(of: #""travelportLocator":"ABC123""#, with: #""travelportLocator":null"#)
        let result = try await Self.repository(BookingRequestLoader(responses: [Self.response(200, body)]))
            .getReview(reviewId: "b-1")

        guard case let .success(details) = result else { Issue.record("Expected booking review"); return }
        #expect(details.status == .draftSaved)
        #expect(details.bookingReference == nil)
    }

    @Test(arguments: [
        ("PRICE_CHANGED", "Flight price changed. Review the new price before continuing."),
        ("FARE_UNAVAILABLE", "This flight is no longer available. Choose another flight.")
    ])
    func holdConflictCodeMapsToSpecificResult(_ code: String, _ message: String) async throws {
        let body = #"{"code":"\#(code)","message":"\#(message)"}"#
        let result = try await Self.repository(BookingRequestLoader(responses: [Self.response(409, body)]))
            .submitReview(reviewId: "b-1", idempotencyKey: "stable")

        switch code {
        case "PRICE_CHANGED": #expect(result == .priceChanged(message))
        case "FARE_UNAVAILABLE": #expect(result == .fareUnavailable(message))
        default: Issue.record("Unexpected hold conflict code: \(code)")
        }
    }

    private static func repository(_ loader: BookingRequestLoader) -> RemoteBookingRequestRepository {
        .init(transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: BookingRequestSessionStore()))
    }
    private static func response(_ status: Int, _ body: String) -> (Data, URLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: URL(string: "https://api.travelwithnexus.com")!, statusCode: status,
                                        httpVersion: nil, headerFields: nil)!)
    }
    private static let heldJSON = #"{"amountMinor":15875,"currency":"USD","id":"b-1","status":"BOOKING_HELD","travelportLocator":"ABC123","failureReason":null,"failureReasonCode":null,"passengerDetailsSnapshot":{"passengers":[]},"contactSnapshot":{"email":"a@b.com","phone":"+2519"},"seatSelectionSnapshot":null}"#
}

private actor BookingRequestLoader: HTTPDataLoading {
    private var responses: [(Data, URLResponse)]; private(set) var requests: [URLRequest] = []
    init(responses: [(Data, URLResponse)]) { self.responses = responses }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { requests.append(request); return responses.removeFirst() }
}
private struct BookingRequestSessionStore: AuthSessionStore {
    func read() async throws -> StoredAuthSession? {
        .init(session: .init(sessionId: "s", user: .init(id: "u", displayName: "A", email: "a@b.com", avatarUrl: nil),
                             tokens: .init(accessToken: "secret", refreshToken: nil), expiresAt: .distantFuture))
    }
    func write(_ session: StoredAuthSession) async throws {}
    func clear() async throws {}
}
