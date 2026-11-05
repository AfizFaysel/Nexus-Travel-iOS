import Foundation
import Testing
@testable import NexusTravel

struct RemoteFlightDetailsRepositoryTests {
    @Test func sendsAnonymousDetailsRequestAndMapsCanonicalResponse() async throws {
        let loader = FlightDetailsStubLoader(.response(201, FlightDetailsContractFixtures.confirmed))
        let result = try await RemoteFlightDetailsRepository(transport: HTTPTransport(loader: loader)).priceOffer(reference: reference())
        guard case let .success(details) = result else { Issue.record("Expected success"); return }
        #expect(details.tripType == .oneWay && details.price.amount == 15_875)
        #expect(details.legs.first?.segments.first?.equipment == "789")
        #expect(details.fareRules.sections.first?.items == ["Fee applies"])
        #expect(details.fareAvailability?.remainingSeats == 3)
        let request = try #require(await loader.request)
        #expect(request.url?.path == "/api/v1/mobile/flights/details")
        #expect(request.timeoutInterval == 30)
        #expect(request.httpMethod == "POST" && request.value(forHTTPHeaderField: "Authorization") == nil)
        let body = try #require(request.httpBody)
        #expect(String(decoding: body, as: UTF8.self).contains(#""searchSessionId":"session-1""#))
        #expect(String(decoding: body, as: UTF8.self).contains(#""offerId":"offer-1""#))
    }

    @Test func mapsPriceChangeWithPreviousTotal() async throws {
        let repo = RemoteFlightDetailsRepository(transport: HTTPTransport(loader: FlightDetailsStubLoader(.response(201, FlightDetailsContractFixtures.priceChanged))))
        guard case let .priceChanged(previous, details) = try await repo.priceOffer(reference: reference()) else { Issue.record("Expected price change"); return }
        #expect(previous.amount == 15_000 && details.price.amount == 15_875)
    }

    @Test func mapsFareRulesWhenBackendOmitsOptionalSections() async throws {
        let repository = RemoteFlightDetailsRepository(
            transport: HTTPTransport(
                loader: FlightDetailsStubLoader(.response(201, FlightDetailsContractFixtures.withoutFareRuleSections))
            )
        )

        guard case let .success(details) = try await repository.priceOffer(reference: reference()) else {
            Issue.record("Expected success")
            return
        }

        #expect(details.fareRules.sections.isEmpty)
    }

    @Test(arguments: [(401, FlightDetailsResult.authRequired), (404, .offerUnavailable), (410, .offerExpired), (503, .confirmationUnavailable), (500, .unknownError)])
    func statusMatrix(status: Int, expected: FlightDetailsResult) async throws {
        let repo = RemoteFlightDetailsRepository(transport: HTTPTransport(loader: FlightDetailsStubLoader(.response(status, Data()))))
        #expect(try await repo.priceOffer(reference: reference()) == expected)
    }

    @Test func decodesStructuredBaggageWithoutBreakingLegacyPayloads() throws {
        let legacy = try JSONDecoder().decode(BaggageSummaryDTO.self, from: Data(
            #"{"cabin":"1 piece","checked":"30 kg","included":true,"detail":""}"#.utf8
        ))
        #expect(legacy.allowances?.isEmpty != false)
        let structured = try JSONDecoder().decode(BaggageSummaryDTO.self, from: Data(
            #"{"cabin":"1 piece · 7 kg","checked":"30 kg","included":true,"detail":"Cabin bag: up to 115 cm total dimensions.","allowances":[{"baggageType":"CarryOn","inclusion":"UNKNOWN","quantity":1,"weight":null,"passengerTypeCodes":["ADT"],"segmentSequences":[]}] }"#.utf8
        ))
        #expect(structured.allowances?.first?.baggageType == "CarryOn")
        #expect(structured.cabin == "1 piece · 7 kg")
    }

    @Test func distinguishesUnavailableFromTemporaryConfirmationFailure() async throws {
        let unavailable = RemoteFlightDetailsRepository(transport: HTTPTransport(loader: FlightDetailsStubLoader(
            .response(503, Data(#"{"code":"OFFER_UNAVAILABLE"}"#.utf8))
        )))
        let temporary = RemoteFlightDetailsRepository(transport: HTTPTransport(loader: FlightDetailsStubLoader(
            .response(503, Data(#"{"code":"FARE_CONFIRMATION_FAILED"}"#.utf8))
        )))
        #expect(try await unavailable.priceOffer(reference: reference()) == .offerUnavailable)
        #expect(try await temporary.priceOffer(reference: reference()) == .confirmationUnavailable)
    }

    @Test(arguments: [HTTPTransportError.networkUnavailable, .timedOut])
    func connectivityMapsNetworkUnavailable(_ error: HTTPTransportError) async throws {
        let repo = RemoteFlightDetailsRepository(transport: HTTPTransport(loader: FlightDetailsStubLoader(.failure(error))))
        #expect(try await repo.priceOffer(reference: reference()) == .networkUnavailable)
    }

    @Test func malformedIsUnknownAndCancellationPropagates() async throws {
        let malformed = RemoteFlightDetailsRepository(transport: HTTPTransport(loader: FlightDetailsStubLoader(.response(201, Data("{}".utf8)))))
        #expect(try await malformed.priceOffer(reference: reference()) == .unknownError)
        let cancelled = RemoteFlightDetailsRepository(transport: HTTPTransport(loader: FlightDetailsStubLoader(.cancel)))
        await #expect(throws: CancellationError.self) { try await cancelled.priceOffer(reference: reference()) }
    }

    private func reference() -> FlightOfferReference {
        .init(searchId: "session-1", offerId: "offer-1", offerToken: "offer-1", provider: .travelportGds,
            contentSource: "TRAVELPORT", responseId: nil, productIds: [], termsAndConditionsId: nil, brandRef: nil, expiresAt: nil)
    }
}

private actor FlightDetailsStubLoader: HTTPDataLoading {
    enum Outcome: Sendable { case response(Int, Data); case failure(HTTPTransportError); case cancel }
    let outcome: Outcome
    private(set) var request: URLRequest?
    init(_ outcome: Outcome) { self.outcome = outcome }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        switch outcome {
        case let .response(status, data):
            guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { throw HTTPTransportError.nonHTTPResponse }
            return (data, response)
        case let .failure(error): throw error
        case .cancel: throw CancellationError()
        }
    }
}
