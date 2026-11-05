import Foundation

enum AuthMappingError: Error, Equatable {
    case missingToken
    case invalidExpiry
}

enum AuthMapper {
    static func session(
        from envelope: AuthTokenEnvelopeDTO,
        responseHeaderToken: String?,
        now: Date
    ) throws -> AuthSession {
        guard let token = firstNonblank(envelope.token, responseHeaderToken) else {
            throw AuthMappingError.missingToken
        }
        return AuthSession(
            sessionId: envelope.user.id,
            user: user(from: envelope.user),
            tokens: AuthTokenSet(accessToken: token, refreshToken: nil),
            expiresAt: now.addingTimeInterval(30 * 24 * 60 * 60)
        )
    }

    static func session(from envelope: AuthSessionEnvelopeDTO) throws -> AuthSession {
        guard let expiresAt = date(from: envelope.session.expiresAt) else {
            throw AuthMappingError.invalidExpiry
        }
        guard let token = firstNonblank(envelope.session.token) else {
            throw AuthMappingError.missingToken
        }
        return AuthSession(
            sessionId: envelope.session.id,
            user: user(from: envelope.user),
            tokens: AuthTokenSet(accessToken: token, refreshToken: nil),
            expiresAt: expiresAt
        )
    }

    static func error(_ error: AuthErrorDTO, statusCode: Int) -> AuthError {
        if statusCode == 429 { return .rateLimited }
        switch error.code {
        case "VALIDATION", "VALIDATION_ERROR":
            return .validation(fieldErrors(from: error.fieldErrors ?? [:]))
        case "INVALID_EMAIL":
            return .validation([.email: "Enter a valid email address."])
        case "PASSWORD_TOO_SHORT":
            return .validation([.password: "Password must be at least 8 characters."])
        case "PASSWORD_TOO_LONG":
            return .validation([.password: "Password is too long."])
        case "INVALID_PASSWORD":
            return .validation([.password: "Enter a valid password."])
        case "TOO_MANY_REQUESTS":
            return .rateLimited
        case "INVALID_EMAIL_OR_PASSWORD", "INVALID_CREDENTIALS":
            return .invalidCredentials
        case "USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL", "USER_ALREADY_EXISTS", "EMAIL_ALREADY_EXISTS":
            return .emailAlreadyUsed
        case "EMAIL_NOT_VERIFIED":
            return .emailNotVerified
        case "INVALID_OTP":
            return .invalidCode
        case "OTP_EXPIRED":
            return .expiredCode
        case "TOO_MANY_ATTEMPTS":
            return .tooManyCodeAttempts
        case "UNAUTHENTICATED":
            return .unauthenticated
        case "SESSION_EXPIRED":
            return .sessionExpired
        default:
            return statusFallback(statusCode)
        }
    }

    static func statusFallback(_ statusCode: Int) -> AuthError {
        switch statusCode {
        case 401: .unauthenticated
        case 409: .emailAlreadyUsed
        case 429: .rateLimited
        default: .unknown
        }
    }

    private static func firstNonblank(_ values: String?...) -> String? {
        values.compactMap { value -> String? in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return value
        }.first
    }

    private static func user(from user: BetterAuthUserDTO) -> AuthUser {
        AuthUser(id: user.id, displayName: user.name, email: user.email, avatarUrl: user.image)
    }

    private static func date(from value: String) -> Date? {
        (try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
            ?? (try? Date(value, strategy: Date.ISO8601FormatStyle()))
    }

    private static func fieldErrors(from errors: [String: String]) -> [AuthField: String] {
        errors.reduce(into: [:]) { result, item in
            switch item.key {
            case "fullName", "name": result[.fullName] = item.value
            case "email": result[.email] = item.value
            case "password": result[.password] = item.value
            case "confirmPassword": result[.confirmPassword] = item.value
            case "terms", "acceptedTerms": result[.terms] = item.value
            default: break
            }
        }
    }
}
