import Foundation
import OSLog

/// Better Auth email repository backed by shared HTTP transport and Keychain storage.
struct RemoteAuthRepository: AuthRepository {
    private let transport: HTTPTransport
    private let sessionStore: any AuthSessionStore
    private let clock: @Sendable () -> Date
    private let logger = Logger(subsystem: "com.nexustravel.NexusTravel", category: "Auth")

    /// Creates remote authentication with explicit transport, storage, and time dependencies.
    init(
        transport: HTTPTransport,
        sessionStore: any AuthSessionStore,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.sessionStore = sessionStore
        self.clock = clock
    }

    func signInEmail(request: SignInRequest) async throws -> AuthResult<AuthSession> {
        let validation = AuthValidator.validateSignIn(request: request)
        guard validation.isEmpty else { return .failure(.validation(validation)) }
        let body = SignInEmailRequestDTO(
            email: request.email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: request.password
        )
        return try await authenticate(path: AuthEndpoints.signInEmail, body: body)
    }

    func signUpEmail(request: SignUpRequest) async throws -> AuthResult<AuthSignUpResult> {
        let validation = AuthValidator.validateSignUp(request: request)
        guard validation.isEmpty else { return .failure(.validation(validation)) }
        let body = SignUpEmailRequestDTO(
            email: request.email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: request.password,
            name: request.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let response = try await send(request: self.request(path: AuthEndpoints.signUpEmail, method: .post, body: body))
        guard case let .success(value) = response else {
            return try await mappedFailure(from: response)
        }
        let envelope: AuthTokenEnvelopeDTO
        do {
            envelope = try JSONDecoder().decode(AuthTokenEnvelopeDTO.self, from: value.data)
        } catch {
            return .failure(.unknown)
        }
        guard envelope.token?.isEmpty == false || value.headers["set-auth-token"]?.isEmpty == false else {
            return .success(.verificationPending(email: envelope.user.email))
        }
        do {
            let session = try AuthMapper.session(from: envelope, responseHeaderToken: value.headers["set-auth-token"], now: clock())
            try await sessionStore.write(StoredAuthSession(session: session))
            return .success(.authenticated(session))
        } catch AuthMappingError.missingToken {
            return .failure(.unauthenticated)
        }
    }

    func getSession() async throws -> AuthResult<AuthSession> {
        if let stored = try await sessionStore.read() {
            if isUsable(stored.session) { return .success(stored.session) }
            try await sessionStore.clear()
        }
        let response = try await send(
            path: AuthEndpoints.session,
            method: .get,
            authorization: try await authorization()
        )
        guard case let .success(value) = response else {
            return try await mappedFailure(from: response)
        }
        let envelope: AuthSessionEnvelopeDTO?
        do {
            envelope = try JSONDecoder().decode(AuthSessionEnvelopeDTO?.self, from: value.data)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .failure(.unknown)
        }
        guard let envelope else {
            try await sessionStore.clear()
            return .failure(.unauthenticated)
        }
        let session: AuthSession
        do {
            session = try AuthMapper.session(from: envelope)
        } catch AuthMappingError.missingToken {
            try await sessionStore.clear()
            return .failure(.unauthenticated)
        } catch {
            return .failure(.unknown)
        }
        try await sessionStore.write(StoredAuthSession(session: session))
        return .success(session)
    }

    func getLocalSession() async throws -> AuthSession? {
        guard let stored = try await sessionStore.read() else { return nil }
        guard isUsable(stored.session) else {
            try await sessionStore.clear()
            return nil
        }
        return stored.session
    }

    func requestPasswordReset(email: String) async throws -> AuthResult<Void> {
        let validation = AuthValidator.validatePasswordReset(email: email)
        guard validation.isEmpty else { return .failure(.validation(validation)) }
        let request = try request(
            path: AuthEndpoints.passwordResetRequest,
            method: .post,
            body: PasswordResetRequestDTO(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        )
        return try await unitResult(for: request)
    }

    func resendVerificationEmail(email: String) async throws -> AuthResult<Void> {
        let validation = AuthValidator.validatePasswordReset(email: email)
        guard validation.isEmpty else { return .failure(.validation(validation)) }
        let request = try request(
            path: AuthEndpoints.resendVerificationEmail,
            method: .post,
            body: PasswordResetRequestDTO(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        )
        return try await unitResult(for: request)
    }

    func verifyEmail(token: String) async throws -> AuthResult<Void> {
        guard AuthLinkRoute.accepts(token: token) else { return .failure(.unknown) }
        return try await unitResult(for: HTTPRequest(
            target: .root(AuthEndpoints.verifyEmail),
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
    }

    func resetPassword(token: String, newPassword: String) async throws -> AuthResult<Void> {
        guard AuthLinkRoute.accepts(token: token) else { return .failure(.unknown) }
        if let error = AuthValidator.validateNewPassword(newPassword) {
            return .failure(.validation([.password: error]))
        }
        let request = try request(
            path: AuthEndpoints.passwordReset,
            method: .post,
            body: PasswordUpdateDTO(token: token, newPassword: newPassword)
        )
        let result = try await unitResult(for: request)
        if case .success = result { try await sessionStore.clear() }
        return result
    }

    func sendVerificationCode(email: String) async throws -> AuthResult<Void> {
        let validation = AuthValidator.validatePasswordReset(email: email)
        guard validation.isEmpty else { return .failure(.validation(validation)) }
        return try await unitResult(for: request(
            path: AuthEndpoints.sendVerificationCode,
            method: .post,
            body: VerificationCodeRequestDTO(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        ))
    }

    func verifyEmailCode(email: String, code: String) async throws -> AuthResult<Void> {
        guard code.count == 6, code.allSatisfy(\.isNumber) else { return .failure(.invalidCode) }
        return try await unitResult(for: request(
            path: AuthEndpoints.verifyEmailCode,
            method: .post,
            body: VerifyEmailCodeDTO(email: email.trimmingCharacters(in: .whitespacesAndNewlines), otp: code)
        ))
    }

    func requestPasswordResetCode(email: String) async throws -> AuthResult<Void> {
        let validation = AuthValidator.validatePasswordReset(email: email)
        guard validation.isEmpty else { return .failure(.validation(validation)) }
        return try await unitResult(for: request(
            path: AuthEndpoints.requestPasswordResetCode,
            method: .post,
            body: PasswordResetRequestDTO(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        ))
    }

    func resetPasswordCode(email: String, code: String, newPassword: String) async throws -> AuthResult<Void> {
        guard code.count == 6, code.allSatisfy(\.isNumber) else { return .failure(.invalidCode) }
        if let error = AuthValidator.validateNewPassword(newPassword) {
            return .failure(.validation([.password: error]))
        }
        let result = try await unitResult(for: request(
            path: AuthEndpoints.resetPasswordCode,
            method: .post,
            body: ResetPasswordCodeDTO(email: email.trimmingCharacters(in: .whitespacesAndNewlines), otp: code, password: newPassword)
        ))
        if case .success = result { try await sessionStore.clear() }
        return result
    }

    func signOut() async throws -> AuthResult<Void> {
        let request = HTTPRequest(
            target: .root(AuthEndpoints.signOut),
            method: .post,
            authorization: try await authorization()
        )
        do {
            let result = try await unitResult(for: request)
            try await sessionStore.clear()
            return result
        } catch is CancellationError {
            try await sessionStore.clear()
            throw CancellationError()
        } catch {
            try await sessionStore.clear()
            throw error
        }
    }

    private func authenticate<Body: Encodable & Sendable>(
        path: String,
        body: Body
    ) async throws -> AuthResult<AuthSession> {
        let response = try await send(request: request(path: path, method: .post, body: body))
        guard case let .success(value) = response else {
            return try await mappedFailure(from: response)
        }
        let session: AuthSession
        do {
            let envelope = try JSONDecoder().decode(AuthTokenEnvelopeDTO.self, from: value.data)
            session = try AuthMapper.session(
                from: envelope,
                responseHeaderToken: value.headers["set-auth-token"],
                now: clock()
            )
        } catch AuthMappingError.missingToken {
            try await sessionStore.clear()
            return .failure(.unauthenticated)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DecodingError {
            logger.error("Auth success response decode failed: \(Self.decodeSummary(error), privacy: .public)")
            return .failure(.unknown)
        } catch {
            logger.error("Auth success response mapping failed: \(String(describing: type(of: error)), privacy: .public)")
            return .failure(.unknown)
        }
        do {
            try await sessionStore.write(StoredAuthSession(session: session))
        } catch let error as KeychainError {
            logger.error("Auth session Keychain write failed status=\(error.status, privacy: .public)")
            throw error
        } catch {
            logger.error("Auth session write failed: \(String(describing: type(of: error)), privacy: .public)")
            throw error
        }
        return .success(session)
    }

    private func unitResult(for request: HTTPRequest) async throws -> AuthResult<Void> {
        switch try await send(request: request) {
        case .success: return .success(())
        case let .failure(error): return .failure(error)
        }
    }

    private func request<Body: Encodable>(path: String, method: HTTPMethod, body: Body) throws -> HTTPRequest {
        HTTPRequest(target: .root(path), method: method, body: try JSONEncoder().encode(body))
    }

    private func send(
        path: String,
        method: HTTPMethod,
        authorization: HTTPAuthorization = .none
    ) async throws -> AuthHTTPResult {
        try await send(request: HTTPRequest(target: .root(path), method: method, authorization: authorization))
    }

    private func send(request: HTTPRequest) async throws -> AuthHTTPResult {
        do {
            let response = try await transport.send(request)
            guard (200...299).contains(response.statusCode) else {
                let dto = try? JSONDecoder().decode(AuthErrorDTO.self, from: response.data)
                let error = dto.map { AuthMapper.error($0, statusCode: response.statusCode) }
                    ?? AuthMapper.statusFallback(response.statusCode)
                return .failure(error)
            }
            return .success(response)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HTTPTransportError {
            switch error {
            case .timedOut, .networkUnavailable: return .failure(.networkUnavailable)
            case .invalidRequest, .nonHTTPResponse: return .failure(.unknown)
            }
        } catch {
            return .failure(.unknown)
        }
    }

    private func authorization() async throws -> HTTPAuthorization {
        guard let token = try await sessionStore.read()?.session.tokens?.accessToken,
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .none
        }
        return .bearer(token)
    }

    private func isUsable(_ session: AuthSession) -> Bool {
        session.expiresAt > clock()
            && !(session.tokens?.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private static func decodeSummary(_ error: DecodingError) -> String {
        switch error {
        case let .keyNotFound(key, context):
            "missing \((context.codingPath + [key]).map(\.stringValue).joined(separator: "."))"
        case let .typeMismatch(_, context):
            "type mismatch at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case let .valueNotFound(_, context):
            "missing value at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case let .dataCorrupted(context):
            "invalid JSON at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        @unknown default:
            "unknown decoding error"
        }
    }

    private func mappedFailure<Value: Sendable>(from result: AuthHTTPResult) async throws -> AuthResult<Value> {
        guard case let .failure(error) = result else { return .failure(.unknown) }
        if error == .unauthenticated || error == .sessionExpired {
            try await sessionStore.clear()
        }
        return .failure(error)
    }
}

private enum AuthHTTPResult: Sendable {
    case success(HTTPResponse)
    case failure(AuthError)
}
