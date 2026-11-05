import Foundation
import Testing
@testable import NexusTravel

struct AuthMappersTests {
    @Test func tokenEnvelopeUsesBodyBeforeHeaderAndAndroidFallbacks() throws {
        let dto = try JSONDecoder().decode(AuthTokenEnvelopeDTO.self, from: AuthContractFixtures.tokenEnvelope)
        let session = try AuthMapper.session(
            from: dto,
            responseHeaderToken: "header-token",
            now: AuthContractFixtures.now
        )

        #expect(session.sessionId == "user-1")
        #expect(session.tokens?.accessToken == "body-token")
        #expect(session.tokens?.refreshToken == nil)
        #expect(session.expiresAt == AuthContractFixtures.now.addingTimeInterval(30 * 24 * 60 * 60))
    }

    @Test func blankBodyTokenFallsBackToHeaderAndMissingTokenIsUnauthenticated() throws {
        var dto = try JSONDecoder().decode(AuthTokenEnvelopeDTO.self, from: AuthContractFixtures.tokenEnvelopeWithoutToken)
        #expect(try AuthMapper.session(from: dto, responseHeaderToken: "header-token", now: .distantPast)
            .tokens?.accessToken == "header-token")

        dto = AuthTokenEnvelopeDTO(token: "  ", user: dto.user)
        #expect(throws: AuthMappingError.missingToken) {
            try AuthMapper.session(from: dto, responseHeaderToken: "\n", now: .distantPast)
        }
    }

    @Test func sessionEnvelopeUsesServerIdentityTokenAndFractionalExpiry() throws {
        let dto = try JSONDecoder().decode(AuthSessionEnvelopeDTO.self, from: AuthContractFixtures.sessionEnvelope)
        let session = try AuthMapper.session(from: dto)

        #expect(session.sessionId == "session-1")
        #expect(session.tokens?.accessToken == "session-token")
        #expect(session.expiresAt == ISO8601DateFormatter().date(from: "2026-09-04T12:00:00Z"))
    }

    @Test func sessionEnvelopeAcceptsExpiryWithoutFractionalSeconds() throws {
        let data = Data(#"{"session":{"id":"session-1","userId":"user-1","token":"token","expiresAt":"2026-09-04T12:00:00Z"},"user":{"id":"user-1","name":"Selam","email":"selam@example.com","emailVerified":true,"image":null}}"#.utf8)
        let dto = try JSONDecoder().decode(AuthSessionEnvelopeDTO.self, from: data)
        #expect(try AuthMapper.session(from: dto).sessionId == "session-1")
    }

    @Test func additiveFieldsDecodeButMissingRequiredUserFails() throws {
        _ = try JSONDecoder().decode(AuthTokenEnvelopeDTO.self, from: AuthContractFixtures.tokenEnvelope)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AuthTokenEnvelopeDTO.self, from: AuthContractFixtures.tokenEnvelopeMissingUser)
        }
    }

    @Test(arguments: [
        ("INVALID_EMAIL_OR_PASSWORD", AuthError.invalidCredentials),
        ("INVALID_CREDENTIALS", AuthError.invalidCredentials),
        ("USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL", AuthError.emailAlreadyUsed),
        ("USER_ALREADY_EXISTS", AuthError.emailAlreadyUsed),
        ("EMAIL_ALREADY_EXISTS", AuthError.emailAlreadyUsed),
        ("EMAIL_NOT_VERIFIED", AuthError.emailNotVerified),
        ("UNAUTHENTICATED", AuthError.unauthenticated),
        ("SESSION_EXPIRED", AuthError.sessionExpired),
        ("INVALID_OTP", AuthError.invalidCode),
        ("OTP_EXPIRED", AuthError.expiredCode),
        ("TOO_MANY_ATTEMPTS", AuthError.tooManyCodeAttempts)
    ])
    func mapsBackendErrorCodes(_ code: String, _ expected: AuthError) {
        #expect(AuthMapper.error(AuthErrorDTO(code: code, message: "message", fieldErrors: nil), statusCode: 400) == expected)
    }

    @Test func mapsValidationRateLimitAndUnknownFieldsSafely() {
        let validation = AuthErrorDTO(
            code: "VALIDATION",
            message: "invalid",
            fieldErrors: ["name": "Name", "email": "Email", "future": "Ignore"]
        )
        #expect(AuthMapper.error(validation, statusCode: 422) == .validation([.fullName: "Name", .email: "Email"]))
        #expect(AuthMapper.error(.init(code: "INVALID_EMAIL", message: "Invalid email", fieldErrors: nil), statusCode: 400)
            == .validation([.email: "Enter a valid email address."]))
        #expect(AuthMapper.error(.init(code: "PASSWORD_TOO_SHORT", message: "Short", fieldErrors: nil), statusCode: 400)
            == .validation([.password: "Password must be at least 8 characters."]))
        #expect(AuthMapper.error(.init(code: "PASSWORD_TOO_LONG", message: "Long", fieldErrors: nil), statusCode: 400)
            == .validation([.password: "Password is too long."]))
        #expect(AuthMapper.error(.init(code: "INVALID_PASSWORD", message: "Bad", fieldErrors: nil), statusCode: 400)
            == .validation([.password: "Enter a valid password."]))
        #expect(AuthMapper.error(.init(code: "WHATEVER", message: "x", fieldErrors: nil), statusCode: 429) == .rateLimited)
        #expect(AuthMapper.error(.init(code: "RESET_PASSWORD_DISABLED", message: "x", fieldErrors: nil), statusCode: 400) == .unknown)
    }
}
