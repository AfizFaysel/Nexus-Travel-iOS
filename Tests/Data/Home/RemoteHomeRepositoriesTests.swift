import Foundation
import Testing
@testable import NexusTravel

struct RemoteHomeRepositoriesTests {
    @Test func airportRoutesOriginalQueryLimitsNoAuthAndFreshCacheSkipsNetwork() async throws {
        let loader = HomeStubLoader([.response(200, HomeContractFixtures.airports), .response(200, HomeContractFixtures.airports)])
        let cache = AirportCache()
        let repository = RemoteAirportRepository(transport: HTTPTransport(loader: loader), cache: cache)
        _ = try await repository.searchAirports(query: "   ")
        _ = try await repository.searchAirports(query: " New York & JFK ")
        _ = try await repository.searchAirports(query: " new york & jfk ")
        let requests = await loader.requests
        #expect(requests.count == 2)
        #expect(requests[0].url?.path == "/api/v1/mobile/airports/popular" && requests[0].url?.query == "limit=60")
        let query = URLComponents(url: try #require(requests[1].url), resolvingAgainstBaseURL: false)?.queryItems
        #expect(query == [URLQueryItem(name: "q", value: " New York & JFK "), URLQueryItem(name: "limit", value: "30")])
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
    }

    @Test func airportFreshStaleAndFailureMatrix() async throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let staleCache = AirportCache(clock: { now })
        await staleCache.store([airport("OLD")], for: "popular", at: now.addingTimeInterval(-600))
        let status = RemoteAirportRepository(transport: HTTPTransport(loader: HomeStubLoader([.response(500, Data())])), cache: staleCache)
        #expect(try await status.searchAirports(query: "") == [airport("OLD")])
        let network = RemoteAirportRepository(transport: HTTPTransport(loader: HomeStubLoader([.failure(.networkUnavailable)])), cache: staleCache)
        #expect(try await network.searchAirports(query: "") == [airport("OLD")])
        let miss = RemoteAirportRepository(transport: HTTPTransport(loader: HomeStubLoader([.failure(.timedOut)])), cache: AirportCache())
        #expect(try await miss.searchAirports(query: "x").isEmpty)
    }

    @Test func airportStrictDecodeAdditiveFieldsAndCancellation() async throws {
        let success = RemoteAirportRepository(transport: HTTPTransport(loader: HomeStubLoader([.response(200, HomeContractFixtures.airports)])), cache: AirportCache())
        #expect(try await success.searchAirports(query: "").first?.displayName == "Addis Ababa (ADD)")
        let malformed = RemoteAirportRepository(transport: HTTPTransport(loader: HomeStubLoader([.response(200, HomeContractFixtures.missingAirportRequired)])), cache: AirportCache())
        await #expect(throws: DecodingError.self) { try await malformed.searchAirports(query: "") }
        let missingEnvelope = RemoteAirportRepository(transport: HTTPTransport(loader: HomeStubLoader([.response(200, HomeContractFixtures.missingAirportEnvelopeLimit)])), cache: AirportCache())
        await #expect(throws: DecodingError.self) { try await missingEnvelope.searchAirports(query: "") }
        let cancelled = RemoteAirportRepository(transport: HTTPTransport(loader: HomeStubLoader([.cancel])), cache: AirportCache())
        await #expect(throws: CancellationError.self) { try await cancelled.searchAirports(query: "") }
    }

    @Test func emptyAirportResponseIsNotCached() async throws {
        let loader = HomeStubLoader([.response(200, HomeContractFixtures.emptyAirports), .response(200, HomeContractFixtures.airports)])
        let repository = RemoteAirportRepository(transport: HTTPTransport(loader: loader), cache: AirportCache())
        #expect(try await repository.searchAirports(query: "").isEmpty)
        #expect(try await repository.searchAirports(query: "").first?.code == "ADD")
        #expect(await loader.requests.count == 2)
    }

    @Test func homeUsesAddDxbAndAndroidMapping() async throws {
        let loader = HomeStubLoader([.response(200, HomeContractFixtures.airports), .response(200, HomeContractFixtures.explore)])
        let result = try await RemoteHomeRepository(transport: HTTPTransport(loader: loader)).getHomeContent()
        guard case let .success(content) = result else { Issue.record("Expected success"); return }
        #expect(content.origin.code == "ADD" && content.destination.code == "DXB")
        #expect(content.departureDate == "Aug 1" && content.returnDate == "Add return")
        #expect(content.travelersLabel == "1 Adult" && content.cabinClass == "Economy")
        #expect(content.trendingEscapes.map(\.id) == ["d1", "d2", "d3"])
        #expect(content.trendingEscapes[0].airport.code == "NBO")
        #expect(content.trendingEscapes[1].airport.name == "Paris")
        #expect(content.trendingEscapes[2].tags == ["Night markets"])
        let requests = await loader.requests
        #expect(requests.map { $0.url?.path } == ["/api/v1/mobile/airports/popular", "/api/v1/mobile/explore"])
        #expect(requests[0].url?.query == "limit=20")
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
    }

    @Test func composedHomeLoadReusesPopularAirportCache() async throws {
        let loader = HomeStubLoader([
            .response(200, HomeContractFixtures.airports),
            .response(200, HomeContractFixtures.explore)
        ])
        let transport = HTTPTransport(loader: loader)
        let airportRepository = RemoteAirportRepository(transport: transport, cache: AirportCache())
        _ = try await airportRepository.searchAirports(query: "")
        let repository = RemoteHomeRepository(
            transport: transport,
            airportRepository: airportRepository
        )

        guard case .success = try await repository.getHomeContent() else {
            Issue.record("Expected success")
            return
        }

        let requests = await loader.requests
        #expect(requests.map { $0.url?.path } == [
            "/api/v1/mobile/airports/popular",
            "/api/v1/mobile/explore"
        ])
    }

    @Test func homeFallbackPrecedenceAndEmptyContent() async throws {
        let airportsWithoutDefaults = Data(#"{"items":[{"iataCode":"NBO","name":"Jomo Kenyatta","city":"Nairobi","country":"Kenya"},{"iataCode":"JFK","name":"Kennedy","city":"New York","country":"USA"}],"limit":20}"#.utf8)
        let fallback = RemoteHomeRepository(transport: HTTPTransport(loader: HomeStubLoader([.response(200, airportsWithoutDefaults), .response(200, HomeContractFixtures.emptyExplore)])))
        guard case let .success(content) = try await fallback.getHomeContent() else { Issue.record("Expected success"); return }
        #expect(content.origin.code == "NBO" && content.destination.code == "JFK")
        let defaults = RemoteHomeRepository(transport: HTTPTransport(loader: HomeStubLoader([.response(200, HomeContractFixtures.emptyAirports), .response(200, HomeContractFixtures.emptyExplore)])))
        guard case let .success(empty) = try await defaults.getHomeContent() else { Issue.record("Expected success"); return }
        #expect(empty.origin.code == "ADD" && empty.destination.code == "DXB")
        #expect(empty.trendingEscapes.isEmpty)
    }

    @Test(arguments: [HTTPTransportError.networkUnavailable, .timedOut])
    func homeConnectivityMapsNetworkUnavailable(_ error: HTTPTransportError) async throws {
        let result = try await RemoteHomeRepository(transport: HTTPTransport(loader: HomeStubLoader([.failure(error)]))).getHomeContent()
        #expect(result == .networkUnavailable)
    }

    @Test func homeStatusesMalformedAndCancellationMatrix() async throws {
        let status = RemoteHomeRepository(transport: HTTPTransport(loader: HomeStubLoader([.response(500, Data())])))
        #expect(try await status.getHomeContent() == .unknownError)
        let malformed = RemoteHomeRepository(transport: HTTPTransport(loader: HomeStubLoader([.response(200, HomeContractFixtures.emptyAirports), .response(200, HomeContractFixtures.missingExploreRequired)])))
        #expect(try await malformed.getHomeContent() == .unknownError)
        let noPartial = RemoteHomeRepository(transport: HTTPTransport(loader: HomeStubLoader([.response(200, HomeContractFixtures.airports), .response(500, Data())])))
        #expect(try await noPartial.getHomeContent() == .unknownError)
        let cancelled = RemoteHomeRepository(transport: HTTPTransport(loader: HomeStubLoader([.cancel])))
        await #expect(throws: CancellationError.self) { try await cancelled.getHomeContent() }
    }

    private func airport(_ code: String) -> Airport {
        Airport(code: code, city: "City", name: "Airport", country: "Country")
    }
}

private actor HomeStubLoader: HTTPDataLoading {
    enum Outcome: Sendable { case response(Int, Data); case failure(HTTPTransportError); case cancel }
    private var outcomes: [Outcome]
    private(set) var requests: [URLRequest] = []
    init(_ outcomes: [Outcome]) { self.outcomes = outcomes }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        switch outcomes.removeFirst() {
        case let .response(status, data):
            guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { throw HTTPTransportError.nonHTTPResponse }
            return (data, response)
        case let .failure(error): throw error
        case .cancel: throw CancellationError()
        }
    }
}
