/// Result of an authentication repository operation.
enum AuthResult<Value: Sendable>: Sendable {
    case success(Value)
    case failure(AuthError)
}

/// Result of creating an account with email authentication.
enum AuthSignUpResult: Equatable, Sendable {
    case authenticated(AuthSession)
    case verificationPending(email: String)
}

/// Email authentication and persisted-session boundary.
protocol AuthRepository: Sendable {
    func signInEmail(request: SignInRequest) async throws -> AuthResult<AuthSession>
    func signUpEmail(request: SignUpRequest) async throws -> AuthResult<AuthSignUpResult>
    func getSession() async throws -> AuthResult<AuthSession>
    func getLocalSession() async throws -> AuthSession?
    func requestPasswordReset(email: String) async throws -> AuthResult<Void>
    func resendVerificationEmail(email: String) async throws -> AuthResult<Void>
    func verifyEmail(token: String) async throws -> AuthResult<Void>
    func resetPassword(token: String, newPassword: String) async throws -> AuthResult<Void>
    func sendVerificationCode(email: String) async throws -> AuthResult<Void>
    func verifyEmailCode(email: String, code: String) async throws -> AuthResult<Void>
    func requestPasswordResetCode(email: String) async throws -> AuthResult<Void>
    func resetPasswordCode(email: String, code: String, newPassword: String) async throws -> AuthResult<Void>
    func signOut() async throws -> AuthResult<Void>
}

extension AuthRepository {
    func resendVerificationEmail(email: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func verifyEmail(token: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func resetPassword(token: String, newPassword: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func sendVerificationCode(email: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func verifyEmailCode(email: String, code: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func requestPasswordResetCode(email: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func resetPasswordCode(email: String, code: String, newPassword: String) async throws -> AuthResult<Void> { .failure(.unknown) }
}
