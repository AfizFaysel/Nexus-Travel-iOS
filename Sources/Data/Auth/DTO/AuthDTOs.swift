import Foundation

struct SignInEmailRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
}

struct SignUpEmailRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
    let name: String
}

struct PasswordResetRequestDTO: Encodable, Sendable {
    let email: String
}

struct PasswordUpdateDTO: Encodable, Sendable {
    let token: String
    let newPassword: String
}

struct VerificationCodeRequestDTO: Encodable, Sendable {
    let email: String
    let type = "email-verification"
}

struct VerifyEmailCodeDTO: Encodable, Sendable {
    let email: String
    let otp: String
}

struct ResetPasswordCodeDTO: Encodable, Sendable {
    let email: String
    let otp: String
    let password: String
}

struct AuthTokenEnvelopeDTO: Codable, Sendable {
    let token: String?
    let user: BetterAuthUserDTO
}

struct AuthSessionEnvelopeDTO: Decodable, Sendable {
    let session: BetterAuthSessionDTO
    let user: BetterAuthUserDTO
}

struct BetterAuthSessionDTO: Decodable, Sendable {
    let id: String
    let userId: String
    let token: String
    let expiresAt: String
}

struct BetterAuthUserDTO: Codable, Sendable {
    let id: String
    let name: String
    let email: String
    let emailVerified: Bool?
    let image: String?
}

struct AuthErrorDTO: Codable, Sendable {
    let code: String
    let message: String
    let fieldErrors: [String: String]?
}
