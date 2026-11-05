import Foundation
import Testing
@testable import NexusTravel

struct RemoteAuthRepositoryTests {
    @Test func endpointsAreRootAuthPaths() {
        #expect(AuthEndpoints.signInEmail == "/api/auth/sign-in/email")
        #expect(AuthEndpoints.signUpEmail == "/api/auth/sign-up/email")
        #expect(AuthEndpoints.session == "/api/auth/get-session")
        #expect(AuthEndpoints.passwordResetRequest == "/api/auth/request-password-reset")
        #expect(AuthEndpoints.verifyEmail == "/api/auth/verify-email")
        #expect(AuthEndpoints.passwordReset == "/api/auth/reset-password")
        #expect(AuthEndpoints.resendVerificationEmail == "/api/auth/send-verification-email")
        #expect(AuthEndpoints.sendVerificationCode == "/api/auth/email-otp/send-verification-otp")
        #expect(AuthEndpoints.verifyEmailCode == "/api/auth/email-otp/verify-email")
        #expect(AuthEndpoints.requestPasswordResetCode == "/api/auth/email-otp/request-password-reset")
        #expect(AuthEndpoints.resetPasswordCode == "/api/auth/email-otp/reset-password")
        #expect(AuthEndpoints.signOut == "/api/auth/sign-out")
    }

    @Test func signInTrimsEmailPreservesPasswordAndStoresSession() async throws {
        let loader = AuthStubLoader(responses: [.response(200, AuthContractFixtures.tokenEnvelope, ["set-auth-token": "header-token"])])
        let store = AuthFakeSessionStore()
        let repository = makeRepository(loader: loader, store: store)

        let result = try await repository.signInEmail(request: .init(email: "  selam@example.com ", password: " password123 "))

        #expect(successSession(result)?.tokens?.accessToken == "body-token")
        let request = try #require(await loader.requests.first)
        #expect(request.url?.path == AuthEndpoints.signInEmail)
        #expect(request.httpMethod == "POST")
        let body = try #require(request.httpBody)
        let json = try JSONDecoder().decode(SignInBody.self, from: body)
        #expect(json == .init(email: "selam@example.com", password: " password123 "))
        #expect(await store.current?.session.tokens?.accessToken == "body-token")
    }

    @Test func successfulAuthDoesNotRequireVerificationField() async throws {
        let loader = AuthStubLoader(responses: [.response(200, AuthContractFixtures.tokenEnvelopeWithoutVerificationField, [:])])

        let result = try await makeRepository(loader: loader)
            .signInEmail(request: .init(email: "selam@example.com", password: "password123"))

        #expect(successSession(result)?.tokens?.accessToken == "body-token")
    }

    @Test func signUpTrimsNameAndEmailWithoutSerializingTerms() async throws {
        let loader = AuthStubLoader(responses: [.response(200, AuthContractFixtures.tokenEnvelope, [:])])
        let repository = makeRepository(loader: loader)

        _ = try await repository.signUpEmail(request: .init(
            fullName: "  Selam Abebe  ", email: " selam@example.com ", password: "password123", acceptedTerms: true
        ))

        let request = try #require(await loader.requests.first)
        let body = try #require(request.httpBody)
        let json = try JSONDecoder().decode(SignUpBody.self, from: body)
        #expect(json.name == "Selam Abebe")
        #expect(json.email == "selam@example.com")
        #expect(json.password == "password123")
        #expect(json.acceptedTerms == nil)
    }

    @Test func signupWithNullTokenReturnsPendingAndDoesNotWriteSession() async throws {
        let loader = AuthStubLoader(responses: [.response(200, AuthContractFixtures.signupPending, [:])])
        let store = AuthFakeSessionStore()

        let result = try await makeRepository(loader: loader, store: store).signUpEmail(request: .init(
            fullName: "Selam Abebe", email: "selam@example.com", password: "password123", acceptedTerms: true
        ))

        guard case let .success(signupResult) = result else {
            Issue.record("Expected verification-pending account result")
            return
        }
        #expect(signupResult == .verificationPending(email: "selam@example.com"))
        #expect(await store.writeCount == 0)
        #expect(await loader.requests.count == 1)
    }

    @Test func signupWithTokenAuthenticatesDuringVerificationRollout() async throws {
        let loader = AuthStubLoader(responses: [.response(200, AuthContractFixtures.signupTokenForUnverifiedUser, [:])])
        let store = AuthFakeSessionStore()

        let result = try await makeRepository(loader: loader, store: store).signUpEmail(request: .init(
            fullName: "Selam Abebe", email: "selam@example.com", password: "password123", acceptedTerms: true
        ))

        guard case let .success(signupResult) = result else {
            Issue.record("Expected authenticated signup result")
            return
        }
        guard case let .authenticated(session) = signupResult else {
            Issue.record("Expected token-bearing signup to authenticate")
            return
        }
        #expect(session.tokens?.accessToken == "must-not-store")
        #expect(await store.writeCount == 1)
    }

    @Test func verificationUsesNativeAuthEndpointAndTokenQuery() async throws {
        let loader = AuthStubLoader(responses: [.response(200, Data(#"{"status":true}"#.utf8), [:])])
        let result = try await makeRepository(loader: loader).verifyEmail(token: "verification-token")
        let request = try #require(await loader.requests.first)
        guard case .success = result else {
            Issue.record("Expected verification success")
            return
        }
        #expect(request.url?.path == AuthEndpoints.verifyEmail)
        #expect(URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems == [URLQueryItem(name: "token", value: "verification-token")])
    }

    @Test func passwordResetUsesTokenBodyAndClearsLocalSessionOnSuccess() async throws {
        let loader = AuthStubLoader(responses: [.response(200, Data(#"{"status":true}"#.utf8), [:])])
        let store = AuthFakeSessionStore(session: storedSession(expiresAt: .distantFuture, token: "existing-token"))
        let result = try await makeRepository(loader: loader, store: store).resetPassword(token: "reset-token", newPassword: "newpassword123")
        let request = try #require(await loader.requests.first)
        let body = try #require(request.httpBody)
        let fields = try JSONDecoder().decode([String: String].self, from: body)
        guard case .success = result else {
            Issue.record("Expected password reset success")
            return
        }
        #expect(request.url?.path == AuthEndpoints.passwordReset)
        #expect(fields == ["token": "reset-token", "newPassword": "newpassword123"])
        #expect(await store.current == nil)
    }

    @Test func validationShortCircuitsTransportAndStorage() async throws {
        let loader = AuthStubLoader(responses: [])
        let store = AuthFakeSessionStore()
        let repository = makeRepository(loader: loader, store: store)

        let result = try await repository.signInEmail(request: .init(email: "bad", password: "short"))

        guard case .failure(.validation) = result else {
            Issue.record("Expected validation failure")
            return
        }
        #expect(await loader.requests.isEmpty)
        #expect(await store.writeCount == 0)
    }

    @Test func missingAuthenticationTokenClearsAndReturnsUnauthenticated() async throws {
        let loader = AuthStubLoader(responses: [
            .response(200, AuthContractFixtures.tokenEnvelopeWithoutToken, [:])
        ])
        let store = AuthFakeSessionStore(session: storedSession(expiresAt: .distantFuture, token: "old-token"))

        let result = try await makeRepository(loader: loader, store: store)
            .signInEmail(request: .init(email: "selam@example.com", password: "password123"))

        #expect(failure(result) == .unauthenticated)
        #expect(await store.current == nil)
    }

    @Test func getSessionReturnsUsableLocalWithoutNetwork() async throws {
        let loader = AuthStubLoader(responses: [])
        let stored = storedSession(expiresAt: AuthContractFixtures.now.addingTimeInterval(1), token: "token")
        let store = AuthFakeSessionStore(session: stored)
        let result = try await makeRepository(loader: loader, store: store).getSession()

        #expect(successSession(result) == stored.session)
        #expect(await loader.requests.isEmpty)
    }

    @Test(arguments: [0.0, -1.0])
    func expiredOrBoundaryLocalSessionClearsThenMapsRemoteNull(_ offset: TimeInterval) async throws {
        let loader = AuthStubLoader(responses: [.response(200, AuthContractFixtures.nullSession, [:])])
        let store = AuthFakeSessionStore(session: storedSession(
            expiresAt: AuthContractFixtures.now.addingTimeInterval(offset), token: "token"
        ))

        let result = try await makeRepository(loader: loader, store: store).getSession()

        #expect(failure(result) == .unauthenticated)
        #expect(await store.current == nil)
        #expect(await store.clearCount >= 1)
    }

    @Test func blankLocalTokenIsNotUsableAndRemoteSessionPersists() async throws {
        let loader = AuthStubLoader(responses: [.response(200, AuthContractFixtures.sessionEnvelope, [:])])
        let store = AuthFakeSessionStore(session: storedSession(expiresAt: .distantFuture, token: " \n"))

        let result = try await makeRepository(loader: loader, store: store).getSession()

        #expect(successSession(result)?.sessionId == "session-1")
        #expect(await store.current?.session.sessionId == "session-1")
    }

    @Test func sessionAndSignOutAttachStoredBearer() async throws {
        let loader = AuthStubLoader(responses: [
            .response(200, AuthContractFixtures.sessionEnvelope, [:]),
            .response(200, Data(#"{"success":true}"#.utf8), [:])
        ])
        let store = AuthFakeSessionStore()
        let repository = makeRepository(loader: loader, store: store)
        _ = try await repository.getSession()
        _ = try await repository.signOut()

        let requests = await loader.requests
        let first = try #require(requests.first)
        let last = try #require(requests.last)
        #expect(first.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(last.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
        #expect(await store.current == nil)
    }

    @Test func signOutClearsAfterRemoteFailure() async throws {
        let loader = AuthStubLoader(responses: [.response(500, Data(), [:])])
        let store = AuthFakeSessionStore(session: storedSession(expiresAt: .distantFuture, token: "token"))

        let result = try await makeRepository(loader: loader, store: store).signOut()

        #expect(failure(result) == .unknown)
        #expect(await store.current == nil)
    }

    @Test func unauthenticatedAndExpiredFailuresClearStoredSession() async throws {
        for code in ["UNAUTHENTICATED", "SESSION_EXPIRED"] {
            let loader = AuthStubLoader(responses: [.response(401, AuthContractFixtures.error(code: code), [:])])
            let store = AuthFakeSessionStore(session: storedSession(expiresAt: .distantFuture, token: "token"))
            let repository = makeRepository(loader: loader, store: store)
            _ = try await repository.signInEmail(request: .init(email: "selam@example.com", password: "password123"))
            #expect(await store.current == nil)
        }
    }

    @Test func mapsHTTPTransportAndMalformedResponses() async throws {
        let timeout = makeRepository(loader: AuthStubLoader(responses: [.transportError(.timedOut)]))
        #expect(failure(try await timeout.requestPasswordReset(email: "selam@example.com")) == .networkUnavailable)

        let offline = makeRepository(loader: AuthStubLoader(responses: [.transportError(.networkUnavailable)]))
        #expect(failure(try await offline.requestPasswordReset(email: "selam@example.com")) == .networkUnavailable)

        let server = makeRepository(loader: AuthStubLoader(responses: [.response(500, Data(), [:])]))
        #expect(failure(try await server.requestPasswordReset(email: "selam@example.com")) == .unknown)

        let malformed = makeRepository(loader: AuthStubLoader(responses: [.response(200, Data("{}".utf8), [:])]))
        #expect(failure(try await malformed.signInEmail(request: .init(email: "selam@example.com", password: "password123"))) == .unknown)
    }

    @Test func cancellationRethrowsAndSignOutStillClears() async throws {
        let loader = AuthStubLoader(responses: [.cancellation])
        let store = AuthFakeSessionStore(session: storedSession(expiresAt: .distantFuture, token: "token"))
        let repository = makeRepository(loader: loader, store: store)

        await #expect(throws: CancellationError.self) {
            try await repository.signOut()
        }
        #expect(await store.current == nil)
    }

    @Test func storageFailuresPropagate() async {
        let store = AuthFakeSessionStore(session: storedSession(expiresAt: .distantFuture, token: "token"))
        await store.setReadError(AuthStoreTestError.failed)
        await #expect(throws: AuthStoreTestError.self) {
            try await makeRepository(loader: AuthStubLoader(responses: []), store: store).getLocalSession()
        }

        let writeStore = AuthFakeSessionStore()
        await writeStore.setWriteError(.failed)
        await #expect(throws: AuthStoreTestError.self) {
            try await makeRepository(
                loader: AuthStubLoader(responses: [.response(200, AuthContractFixtures.tokenEnvelope, [:])]),
                store: writeStore
            ).signInEmail(request: .init(email: "selam@example.com", password: "password123"))
        }

        let clearStore = AuthFakeSessionStore(session: storedSession(expiresAt: .distantFuture, token: "token"))
        await clearStore.setClearError(.failed)
        await #expect(throws: AuthStoreTestError.self) {
            try await makeRepository(
                loader: AuthStubLoader(responses: [.response(200, Data(#"{"success":true}"#.utf8), [:])]),
                store: clearStore
            ).signOut()
        }
    }

    @Test func passwordResetRequestUsesGenericPrivacyPreservingContract() async throws {
        let loader = AuthStubLoader(responses: [
            .response(200, Data(#"{"status":true}"#.utf8), [:])
        ])

        let result = try await makeRepository(loader: loader).requestPasswordReset(email: " selam@example.com ")

        guard case .success = result else {
            Issue.record("Expected generic success response")
            return
        }
        let request = try #require(await loader.requests.first)
        #expect(request.url?.path == AuthEndpoints.passwordResetRequest)
        let body = try #require(request.httpBody)
        #expect(try JSONDecoder().decode([String: String].self, from: body) == ["email": "selam@example.com"])
    }

    @Test func verificationCodeUsesNativeOTPContractWithoutSessionWrite() async throws {
        let loader = AuthStubLoader(responses: [.response(200, Data(#"{"status":true}"#.utf8), [:])])
        let store = AuthFakeSessionStore()
        let result = try await makeRepository(loader: loader, store: store).verifyEmailCode(
            email: " selam@example.com ", code: "123456"
        )
        guard case .success = result else {
            Issue.record("Expected code verification success")
            return
        }
        let request = try #require(await loader.requests.first)
        #expect(request.url?.path == AuthEndpoints.verifyEmailCode)
        #expect(try JSONDecoder().decode([String: String].self, from: #require(request.httpBody)) == [
            "email": "selam@example.com", "otp": "123456"
        ])
        #expect(await store.writeCount == 0)
    }

    @Test func codeRequestUsesOnlyVerificationPurpose() async throws {
        let loader = AuthStubLoader(responses: [.response(200, Data(#"{"status":true}"#.utf8), [:])])
        _ = try await makeRepository(loader: loader).sendVerificationCode(email: "selam@example.com")
        let request = try #require(await loader.requests.first)
        #expect(request.url?.path == AuthEndpoints.sendVerificationCode)
        #expect(try JSONDecoder().decode([String: String].self, from: #require(request.httpBody)) == [
            "email": "selam@example.com", "type": "email-verification"
        ])
    }

    @Test func resetCodeRequestUsesEmailAndResetClearsSession() async throws {
        let loader = AuthStubLoader(responses: [
            .response(200, Data(#"{"status":true}"#.utf8), [:]),
            .response(200, Data(#"{"status":true}"#.utf8), [:])
        ])
        let store = AuthFakeSessionStore(session: storedSession(expiresAt: .distantFuture, token: "existing-token"))
        let repository = makeRepository(loader: loader, store: store)
        _ = try await repository.requestPasswordResetCode(email: " selam@example.com ")
        let result = try await repository.resetPasswordCode(
            email: "selam@example.com", code: "123456", newPassword: "newpassword123"
        )
        guard case .success = result else {
            Issue.record("Expected reset success")
            return
        }
        let requests = await loader.requests
        #expect(requests[0].url?.path == AuthEndpoints.requestPasswordResetCode)
        #expect(requests[1].url?.path == AuthEndpoints.resetPasswordCode)
        #expect(try JSONDecoder().decode([String: String].self, from: #require(requests[0].httpBody)) == ["email": "selam@example.com"])
        #expect(try JSONDecoder().decode([String: String].self, from: #require(requests[1].httpBody)) == [
            "email": "selam@example.com", "otp": "123456", "password": "newpassword123"
        ])
        #expect(await store.current == nil)
    }

    private func makeRepository(
        loader: AuthStubLoader,
        store: AuthFakeSessionStore = AuthFakeSessionStore()
    ) -> RemoteAuthRepository {
        RemoteAuthRepository(
            transport: HTTPTransport(loader: loader),
            sessionStore: store,
            clock: { AuthContractFixtures.now }
        )
    }

    private func storedSession(expiresAt: Date, token: String) -> StoredAuthSession {
        StoredAuthSession(session: AuthSession(
            sessionId: "stored-session",
            user: .init(id: "stored-user", displayName: "Stored", email: "stored@example.com", avatarUrl: nil),
            tokens: .init(accessToken: token, refreshToken: nil),
            expiresAt: expiresAt
        ))
    }

    private func successSession(_ result: AuthResult<AuthSession>) -> AuthSession? {
        guard case let .success(session) = result else { return nil }
        return session
    }

    private func failure<Value: Sendable>(_ result: AuthResult<Value>) -> AuthError? {
        guard case let .failure(error) = result else { return nil }
        return error
    }
}

private actor AuthStubLoader: HTTPDataLoading {
    enum Outcome: Sendable {
        case response(Int, Data, [String: String])
        case transportError(HTTPTransportError)
        case cancellation
    }

    private var outcomes: [Outcome]
    private(set) var requests: [URLRequest] = []

    init(responses: [Outcome]) {
        outcomes = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let outcome = outcomes.removeFirst()
        switch outcome {
        case let .response(status, data, headers):
            guard let response = HTTPURLResponse(
                url: request.url ?? AppConfiguration.productionOrigin,
                statusCode: status,
                httpVersion: nil,
                headerFields: headers
            ) else {
                throw HTTPTransportError.nonHTTPResponse
            }
            return (data, response)
        case let .transportError(error):
            throw error
        case .cancellation:
            throw CancellationError()
        }
    }
}

private actor AuthFakeSessionStore: AuthSessionStore {
    private(set) var current: StoredAuthSession?
    private(set) var writeCount = 0
    private(set) var clearCount = 0
    private var readError: AuthStoreTestError?
    private var writeError: AuthStoreTestError?
    private var clearError: AuthStoreTestError?

    init(session: StoredAuthSession? = nil) {
        current = session
    }

    func setReadError(_ error: AuthStoreTestError) {
        readError = error
    }

    func setWriteError(_ error: AuthStoreTestError) {
        writeError = error
    }

    func setClearError(_ error: AuthStoreTestError) {
        clearError = error
    }

    func read() async throws -> StoredAuthSession? {
        if let readError { throw readError }
        return current
    }

    func write(_ session: StoredAuthSession) async throws {
        if let writeError { throw writeError }
        writeCount += 1
        current = session
    }

    func clear() async throws {
        if let clearError { throw clearError }
        clearCount += 1
        current = nil
    }
}

private enum AuthStoreTestError: Error {
    case failed
}

private struct SignInBody: Codable, Equatable {
    let email: String
    let password: String
}

private struct SignUpBody: Decodable {
    let name: String
    let email: String
    let password: String
    let acceptedTerms: Bool?
}
