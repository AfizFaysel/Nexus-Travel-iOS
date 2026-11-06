import Foundation
import Testing
@testable import NexusTravel

struct RemotePaymentProofRepositoryTests {
    @Test func loadsCurrentInstructionsFromTheCustomerTripRoute() async throws {
        let loader = PaymentProofLoader(responses: [
            Self.response(200, #"{"canSubmitProof":true,"amountMinor":12345,"currency":"ETB","paymentReason":"ABC123","deadline":null,"accounts":[{"id":"bank-1","bankName":"Test Bank","identifier":"0001","legalName":"Test Account"}]}"#)
        ])
        let repository = RemotePaymentProofRepository(
            transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: PaymentProofSessionStore())
        )

        let result = try await repository.instructions(bookingId: "b-1")
        guard case let .available(instructions) = result else {
            Issue.record("Expected customer payment instructions")
            return
        }
        #expect(instructions.amountMinor == 12345)
        #expect(instructions.accounts.first?.identifier == "0001")
        let request = try #require(await loader.requests.first)
        #expect(request.url?.path == "/api/v1/mobile/trips/b-1/payment-instructions")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func submitsReceiptLinkToAuthenticatedMobileRoute() async throws {
        let loader = PaymentProofLoader(responses: [Self.response(201, #"{"id":"proof-1"}"#)])
        let repository = RemotePaymentProofRepository(
            transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: PaymentProofSessionStore())
        )
        let link = "https://receipts.example.test/payment/123"
        let result = try await repository.submitLink(bookingId: "b-1", url: link)

        #expect(result == .success)
        let request = try #require(await loader.requests.first)
        #expect(request.url?.path == "/api/v1/mobile/bookings/b-1/payment-proof-link")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        let body = try #require(request.httpBody)
        #expect(try JSONDecoder().decode([String: String].self, from: body) == ["url": link])
    }

    @Test func uploadUsesMobileHandshakeAndBearerFreeSignedPut() async throws {
        let loader = PaymentProofLoader(responses: [
            Self.response(201, #"{"uploadId":"up-1","status":"PENDING","uploadUrl":"https://signed.example/proof","requiredHeaders":{"Content-Type":"application/pdf","x-meta":"proof"}}"#),
            Self.response(200, ""), Self.response(201, #"{"id":"file-1"}"#)
        ])
        let repository = RemotePaymentProofRepository(
            transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: PaymentProofSessionStore()),
            documentLoader: { _ in Data([1, 2, 3]) }
        )
        let result = try await repository.upload(
            bookingId: "b-1", document: .init(uriString: "file:///receipt.pdf", displayName: "receipt.pdf", mimeType: "application/pdf")
        )
        #expect(result == .success)
        let requests = await loader.requests
        #expect(requests.map { $0.url?.path } == ["/api/v1/mobile/bookings/b-1/payment-proof-upload", "/proof", "/api/v1/mobile/bookings/b-1/payment-proof-upload/up-1/complete"])
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == nil)
        #expect(requests[1].value(forHTTPHeaderField: "x-meta") == "proof")
    }

    @Test func unsupportedDocumentIsRejectedBeforeNetwork() async throws {
        let loader = PaymentProofLoader(responses: [])
        let repository = RemotePaymentProofRepository(
            transport: HTTPTransport(loader: loader), tokenProvider: AuthTokenProvider(sessionStore: PaymentProofSessionStore()),
            documentLoader: { _ in Data([1]) }
        )
        let result = try await repository.upload(
            bookingId: "b-1", document: .init(uriString: "file:///receipt.txt", displayName: "receipt.txt", mimeType: "text/plain")
        )
        #expect(result == .invalidDocument)
        let requests = await loader.requests
        #expect(requests.isEmpty)
    }
}

private actor PaymentProofLoader: HTTPDataLoading {
    private var responses: [(Data, URLResponse)]; private(set) var requests: [URLRequest] = []
    init(responses: [(Data, URLResponse)]) { self.responses = responses }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { requests.append(request); return responses.removeFirst() }
}
private struct PaymentProofSessionStore: AuthSessionStore {
    func read() async throws -> StoredAuthSession? {
        .init(session: .init(sessionId: "s", user: .init(id: "u", displayName: "A", email: "a@b.com", avatarUrl: nil),
                             tokens: .init(accessToken: "secret", refreshToken: nil), expiresAt: .distantFuture))
    }
    func write(_ session: StoredAuthSession) async throws {}
    func clear() async throws {}
}
private extension RemotePaymentProofRepositoryTests {
    static func response(_ status: Int, _ body: String) -> (Data, URLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: URL(string: "https://api.travelwithnexus.com")!, statusCode: status,
                                        httpVersion: nil, headerFields: nil)!)
    }
}
