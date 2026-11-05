import Foundation
import Testing
@testable import NexusTravel

struct RemoteFlightSearchRepositoryTests {
    @Test func endpointMethodNoAuthAndSuccessfulCacheWrite() async throws {
        let loader = SearchStubLoader([.response(201, SearchContractFixtures.success)])
        let cache = SearchResultsCache()
        let result = try await RemoteFlightSearchRepository(transport: HTTPTransport(loader: loader), cache: cache).createSearch(request: request())
        #expect(result == .success(searchId: "session-1"))
        let sent = try #require(await loader.requests.first)
        #expect(sent.url?.path == "/api/v1/mobile/flights/search")
        #expect(sent.httpMethod == "POST" && sent.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(sent.timeoutInterval == 60)
        #expect(await cache.result(for: "session-1") != nil)
    }

    @Test func mapsAggregateCarrierMoneySeatsAndExpiry() async throws {
        let dto = try JSONDecoder().decode(SearchResponseDTO.self, from: SearchContractFixtures.success)
        let mapped = try SearchResponseMapper.map(dto, request: request())
        let offer = try #require(mapped.offers.first)
        #expect(offer.airline == AirlineBrand(code: "XY", name: "Example Air", logoAssetName: "example",
            logoURL: URL(string: "https://signed.example/airlines/example.png")))
        #expect(offer.price.amount == 15875 && offer.price.currency == "USD" && offer.price.formatted.hasPrefix("USD "))
        #expect(offer.seatsLeft == 3 && offer.reference.searchId == "session-1")
        #expect(offer.reference.provider == .travelportGds && offer.source == "TRAVELPORT")
        #expect(offer.expiresAt != nil && offer.refundable == false && offer.badge == nil && offer.warnings.isEmpty)
    }

    @Test func mapsEveryLegAndUsesValidatingCarrierFallback() throws {
        let dto = try JSONDecoder().decode(SearchResponseDTO.self, from: SearchContractFixtures.multiCity)
        let mapped = try SearchResponseMapper.map(dto, request: request())
        let offer = try #require(mapped.offers.first)
        #expect(offer.legs.count == 3 && offer.outbound.departureAirportCode == "NBO")
        #expect(offer.inbound?.departureAirportCode == "DXB")
        #expect(offer.airline.code == "Airline")
    }

    @Test func strictRequiredFieldsRejectButAdditiveFieldsDecode() throws {
        _ = try JSONDecoder().decode(SearchResponseDTO.self, from: SearchContractFixtures.success)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(SearchResponseDTO.self, from: SearchContractFixtures.missingRequired) }
    }

    @Test func emptyOffersRemainCachedSuccessAndCacheMissIsEmpty() async throws {
        let cache = SearchResultsCache()
        let repository = RemoteFlightSearchRepository(transport: HTTPTransport(loader: SearchStubLoader([.response(201, SearchContractFixtures.empty)])), cache: cache)
        #expect(try await repository.createSearch(request: request()) == .success(searchId: "empty"))
        #expect(try await RemoteSearchResultsRepository(cache: cache).getSearchResults(searchId: "empty") != .empty)
        #expect(try await RemoteSearchResultsRepository(cache: cache).getSearchResults(searchId: "missing") == .empty)
    }

    @Test func moneyFormattingUsesCurrencyFractionDigits() throws {
        #expect(SearchResponseMapper.formattedMoney(15_875, currency: "USD") == "USD 158.75")
        #expect(SearchResponseMapper.formattedMoney(15_875, currency: "JPY") == "JPY 15,875")
        #expect(SearchResponseMapper.formattedMoney(15_875, currency: "BHD") == "BHD 15.875")
    }

    @Test(arguments: [HTTPTransportError.networkUnavailable, .timedOut])
    func transportFailuresMapNetworkUnavailable(_ error: HTTPTransportError) async throws {
        let repo = RemoteFlightSearchRepository(transport: HTTPTransport(loader: SearchStubLoader([.failure(error)])), cache: SearchResultsCache())
        #expect(try await repo.createSearch(request: request()) == .networkUnavailable)
    }

    @Test(arguments: [400, 401, 404, 500]) func statusesMapUnknownWithoutCacheWrite(_ status: Int) async throws {
        let cache = SearchResultsCache()
        let repo = RemoteFlightSearchRepository(transport: HTTPTransport(loader: SearchStubLoader([.response(status, SearchContractFixtures.success)])), cache: cache)
        #expect(try await repo.createSearch(request: request()) == .unknownError)
        #expect(await cache.result(for: "session-1") == nil)
    }

    @Test func malformedMapsUnknownAndCancellationRethrows() async throws {
        let malformed = RemoteFlightSearchRepository(
            transport: HTTPTransport(loader: SearchStubLoader([.response(201, Data("{}".utf8))])),
            cache: SearchResultsCache()
        )
        #expect(try await malformed.createSearch(request: request()) == .unknownError)
        let cancelled = RemoteFlightSearchRepository(transport: HTTPTransport(loader: SearchStubLoader([.cancel])), cache: SearchResultsCache())
        await #expect(throws: CancellationError.self) { try await cancelled.createSearch(request: request()) }
    }

    private func request() -> FlightSearchRequest {
        guard let date = LocalDate(year: 2026, month: 8, day: 1),
              let value = FlightSearchRequest.make(tripType: .oneWay, originCode: "JFK", destinationCode: "LHR", departureDate: date, returnDate: nil, travelers: .init(), cabinClass: .economy) else {
            preconditionFailure("Valid fixture request")
        }
        return value
    }
}

private actor SearchStubLoader: HTTPDataLoading {
    enum Outcome: Sendable { case response(Int, Data); case failure(HTTPTransportError); case cancel }
    private var outcomes: [Outcome]
    private(set) var requests: [URLRequest] = []
    init(_ outcomes: [Outcome]) { self.outcomes = outcomes }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        switch outcomes.removeFirst() {
        case let .response(status, data):
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
                throw HTTPTransportError.nonHTTPResponse
            }
            return (data, response)
        case let .failure(error): throw error
        case .cancel: throw CancellationError()
        }
    }
}
