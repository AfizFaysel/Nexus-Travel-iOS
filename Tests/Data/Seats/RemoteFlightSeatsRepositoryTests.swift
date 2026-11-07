import Foundation
import Testing
@testable import NexusTravel

struct RemoteFlightSeatsRepositoryTests {
    @Test func loadsAndMapsSeatMapContract() async throws {
        let json = #"{"availability":"AVAILABLE","currency":"ETB","passengerCount":2,"travelers":[{"passengerIndex":0,"seatEligible":true},{"passengerIndex":1,"seatEligible":false}],"segments":[{"segmentId":"segment-1","airlineName":"Nexus Air","aircraftName":"A320","cabins":[{"name":"Economy","columns":["A"],"rows":[{"number":1,"seats":[{"number":"1A","status":"AVAILABLE","position":"WINDOW","features":["EXTRA_LEGROOM"],"price":{"amountMinor":2500,"currency":"USD"}}]}]}]}]}"#
        let loader = SeatRecordingLoader(responses: [Self.response(200, json)])
        let repository = Self.repository(loader)

        let result = try await repository.load(bookingId: "booking-1")

        let map = try #require(result.map)
        #expect(map.availability == .available)
        #expect(map.currency == "ETB")
        #expect(map.passengerCount == 2)
        #expect(map.travelers == [.init(passengerIndex: 0, seatEligible: true),
                                  .init(passengerIndex: 1, seatEligible: false)])
        #expect(map.segments[0].cabins[0].rows[0].seats[0].features == [.extraLegroom])
        #expect(map.segments[0].cabins[0].rows[0].seats[0].price?.amount == 2500)
        let requests = await loader.requests
        let request = try #require(requests.first)
        #expect(request.url?.path == "/api/v1/mobile/bookings/booking-1/seat-map")
    }

    @Test func conflictMapsToSeatUnavailable() async throws {
        let loader = SeatRecordingLoader(responses: [Self.response(409, "{}")])
        let result = try await Self.repository(loader).save(
            bookingId: "booking-1", assignments: [.init(passengerIndex: 0, segmentId: "segment-1", seatNumber: "1A", price: nil)]
        )
        #expect(result == .seatUnavailable)
        let requests = await loader.requests
        let request = try #require(requests.first)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/api/v1/mobile/bookings/booking-1/seats")
    }

    private static func repository(_ loader: SeatRecordingLoader) -> RemoteFlightSeatsRepository {
        .init(transport: HTTPTransport(loader: loader),
              tokenProvider: AuthTokenProvider(sessionStore: SeatSessionStore()))
    }
    private static func response(_ status: Int, _ body: String) -> (Data, URLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: URL(string: "https://api.travelwithnexus.com")!,
                                        statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private extension FlightSeatsResult {
    var map: FlightSeatMap? { if case let .success(value) = self { value } else { nil } }
}
private actor SeatRecordingLoader: HTTPDataLoading {
    private var responses: [(Data, URLResponse)]; private(set) var requests: [URLRequest] = []
    init(responses: [(Data, URLResponse)]) { self.responses = responses }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { requests.append(request); return responses.removeFirst() }
}
private struct SeatSessionStore: AuthSessionStore {
    func read() async throws -> StoredAuthSession? {
        .init(session: .init(sessionId: "s", user: .init(id: "u", displayName: "A", email: "a@b.com", avatarUrl: nil),
                             tokens: .init(accessToken: "secret", refreshToken: nil), expiresAt: .distantFuture))
    }
    func write(_ session: StoredAuthSession) async throws {}
    func clear() async throws {}
}
