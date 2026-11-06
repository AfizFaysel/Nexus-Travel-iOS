import Foundation
import Testing
@testable import NexusTravel

struct RemoteTripsRepositoryTests {
    @Test func listUsesActiveHistoryViewAndCursorWithBearer() async throws {
        let loader = TripsLoader(responses: [Self.response(200, Self.pageFixture)])
        let repository = RemoteTripsRepository(
            transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: TripsSessionStore()),
            cache: TripCache(now: Date(timeIntervalSince1970: 100)), ticketStore: TicketPdfStore()
        )
        let result = try await repository.trips(view: .history, forceRefresh: true, cursor: "next-page")
        guard case let .content(page, offline, _) = result else { Issue.record("Expected content"); return }
        #expect(page.items.first?.itineraryLabel == "ADD to DXB")
        #expect(offline == false)
        let requests = await loader.requests
        #expect(requests.first?.url?.path == "/api/v1/mobile/trips")
        #expect(requests.first?.url?.query == "view=HISTORY&limit=20&cursor=next-page")
        #expect(requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func supplierRefreshPostsBookingIDsWithBearer() async throws {
        let bookingID = "96bc66f4-9c39-4c85-8a2b-84788dc49699"
        let body = #"{"items":[{"bookingId":"96bc66f4-9c39-4c85-8a2b-84788dc49699","status":"QUEUED"}]}"#
        let loader = TripsLoader(responses: [Self.response(202, body)])
        let repository = RemoteTripsRepository(
            transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: TripsSessionStore()),
            cache: TripCache(), ticketStore: TicketPdfStore()
        )

        let result = try await repository.requestSupplierRefresh(bookingIDs: [bookingID])

        #expect(result == .accepted(pending: true))
        let requests = await loader.requests
        let request = try #require(requests.first)
        let data = try #require(request.httpBody)
        let payload = try JSONDecoder().decode([String: [String]].self, from: data)
        #expect(payload == ["bookingIds": [bookingID]])
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/mobile/trips/refresh")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func ticketLookupIsAuthenticatedButDownloadIsNot() async throws {
        let loader = TripsLoader(responses: [
            Self.response(200, #"{"downloadUrl":"https://signed.example/ticket.pdf"}"#),
            Self.response(200, "%PDF")
        ])
        let store = TicketPdfStore(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let repository = RemoteTripsRepository(
            transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: TripsSessionStore()),
            cache: TripCache(), ticketStore: store
        )
        guard case let .success(url) = try await repository.resolveTicketDocument(id: "b-1") else { Issue.record("Expected URL"); return }
        guard case .success = try await repository.cacheTicketPdf(id: "b-1", downloadURL: url) else { Issue.record("Expected cached PDF"); return }
        let requests = await loader.requests
        #expect(requests.map { $0.url?.path } == ["/api/v1/mobile/bookings/b-1/ticket-document", "/ticket.pdf"])
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == nil)
    }

    private static let pageFixture = #"{"items":[{"id":"b-1","group":"ACTION_REQUIRED","status":"BOOKING_HELD","paymentStatus":"UNPAID","paymentProofStatus":"MISSING","ticketingStatus":"NOT_STARTED","amountMinor":15875,"currency":"USD","itinerary":{"origin":"ADD","destination":"DXB"},"holdExpiresAt":null,"ticketDocumentAvailable":false,"nextAction":"UPLOAD_PAYMENT_PROOF","createdAt":"2026-08-30T10:00:00.000Z","updatedAt":"2026-08-30T10:00:00.000Z","tickets":[]}],"nextCursor":null}"#
    private static func response(_ status: Int, _ body: String) -> (Data, URLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: URL(string: "https://api.travelwithnexus.com")!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private actor TripsLoader: HTTPDataLoading {
    private var responses: [(Data, URLResponse)]; private(set) var requests: [URLRequest] = []
    init(responses: [(Data, URLResponse)]) { self.responses = responses }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { requests.append(request); return responses.removeFirst() }
}
private struct TripsSessionStore: AuthSessionStore {
    func read() async throws -> StoredAuthSession? {
        .init(session: .init(sessionId: "s", user: .init(id: "u", displayName: "A", email: "a@b.com", avatarUrl: nil),
                            tokens: .init(accessToken: "secret", refreshToken: nil), expiresAt: .distantFuture))
    }
    func write(_ session: StoredAuthSession) async throws {}; func clear() async throws {}
}
