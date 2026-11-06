import Foundation
import Testing
@testable import NexusTravel

struct RemotePassportUploadRepositoryTests {
    @Test func signedUploadOmitsBearerAndReplaysRequiredHeaders() async throws {
        let loader = PassportUploadRecordingLoader(responses: [
            Self.response(201, #"{"uploadId":"up-1","status":"PENDING","uploadUrl":"https://signed.example/upload","requiredHeaders":{"x-amz-meta-kind":"passport","Content-Type":"image/png"}}"#),
            Self.response(200, ""),
            Self.response(200, #"{"uploadId":"up-1","status":"COMPLETED"}"#)
        ])
        let repository = RemotePassportUploadRepository(
            transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: PassportSessionStore()),
            documentLoader: { _ in Data([1, 2, 3]) }
        )

        let result = try await repository.upload(
            document: PassengerDocumentAttachment(uriString: "file:///passport.png", displayName: "passport.png", mimeType: "image/png"),
            idempotencyKey: "operation:passport:0"
        )

        #expect(result == .success(CompletedPassportUpload(uploadId: "up-1")))
        let requests = await loader.requests
        #expect(requests.count == 3)
        #expect(requests[0].value(forHTTPHeaderField: "Idempotency-Key") == "operation:passport:0")
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == nil)
        #expect(requests[1].value(forHTTPHeaderField: "x-amz-meta-kind") == "passport")
        #expect(requests[1].value(forHTTPHeaderField: "Content-Type") == "image/png")
    }

    @Test func resumingDraftPatchesExistingBookingWithSavedPassport() async throws {
        let loader = PassportUploadRecordingLoader(responses: [
            Self.response(200, #"{"id":"saved-trip","status":"READY_TO_HOLD","amountMinor":100,"currency":"ETB"}"#)
        ])
        let transport = HTTPTransport(loader: loader)
        let tokens = AuthTokenProvider(sessionStore: PassportSessionStore())
        let repository = RemotePassengerDetailsRepository(
            transport: transport, tokenProvider: tokens,
            passportUploadRepository: RemotePassportUploadRepository(transport: transport, tokenProvider: tokens)
        )
        let reference = FlightOfferReference(
            searchId: "saved-search", offerId: "saved-offer", offerToken: "saved-ref", provider: .unknown,
            contentSource: nil, responseId: nil, productIds: [], termsAndConditionsId: nil, brandRef: nil, expiresAt: nil
        )
        let passenger = PassengerDetailsDraft(
            passengerType: .adult, title: "Mr", gender: "Male", firstName: "Avery", lastName: "Morgan",
            dateOfBirth: LocalDate(iso8601: "1992-01-15"), nationalityCountryCode: "ET", passportNumber: "example",
            passportExpiryDate: LocalDate(iso8601: "2030-02-15"), passportIssuingCountryCode: "ET",
            document: nil, passportUploadId: "saved-passport"
        )
        _ = try await repository.submitPassengerDetails(.init(
            offerReference: reference, passengers: [passenger],
            contact: .init(email: "avery@example.test", countryDialCode: "+251", phoneNumber: "911223344"),
            clientSessionId: "saved-operation", bookingId: "saved-trip"
        ))

        let requests = await loader.requests
        let request = try #require(requests.first)
        let body = try #require(request.httpBody)
        #expect(requests.count == 1)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path.hasSuffix("/bookings/saved-trip/passengers") == true)
        #expect(String(decoding: body, as: UTF8.self).contains("saved-passport"))
    }

    @Test func rejectsUnsupportedDocumentBeforeNetwork() async throws {
        let loader = PassportUploadRecordingLoader(responses: [])
        let repository = RemotePassportUploadRepository(
            transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: PassportSessionStore()),
            documentLoader: { _ in Data([1]) }
        )
        let result = try await repository.upload(
            document: PassengerDocumentAttachment(uriString: "file:///a.txt", displayName: "a.txt", mimeType: "text/plain"),
            idempotencyKey: "stable"
        )
        #expect(result == .invalidDocument)
        let requests = await loader.requests
        #expect(requests.isEmpty)
    }

    private static func response(_ status: Int, _ body: String) -> (Data, URLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: URL(string: "https://api.travelwithnexus.com")!, statusCode: status,
                                        httpVersion: nil, headerFields: nil)!)
    }
}

private actor PassportUploadRecordingLoader: HTTPDataLoading {
    private var responses: [(Data, URLResponse)]
    private(set) var requests: [URLRequest] = []
    init(responses: [(Data, URLResponse)]) { self.responses = responses }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return responses.removeFirst()
    }
}

private struct PassportSessionStore: AuthSessionStore {
    func read() async throws -> StoredAuthSession? {
        StoredAuthSession(session: AuthSession(
            sessionId: "s", user: AuthUser(id: "u", displayName: "A", email: "a@b.com", avatarUrl: nil),
            tokens: AuthTokenSet(accessToken: "secret", refreshToken: nil), expiresAt: .distantFuture
        ))
    }
    func write(_ session: StoredAuthSession) async throws {}
    func clear() async throws {}
}
