import Foundation
import Testing
@testable import NexusTravel

@MainActor
struct AuthViewModelTests {
    @Test func sessionSuccessAuthenticatesAndEmitsEvent() async throws {
        let session = makeAuthSession()
        let model = AuthViewModel(repository: StubAuthRepository(sessionResult: .success(session)))
        try await model.checkExistingSession()
        #expect(model.gateState == .authenticated(session))
        #expect(model.consumeEvent() == .authenticated(session))
        #expect(model.consumeEvent() == nil)
    }

    @Test func missingSessionShowsForms() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(sessionResult: .failure(.unauthenticated)))
        try await model.checkExistingSession()
        #expect(model.gateState == .unauthenticated)
    }

    @Test func sessionCheckErrorShowsForms() async {
        let model = AuthViewModel(repository: StubAuthRepository(throwsOnSessionCheck: true))

        do {
            try await model.checkExistingSession()
            Issue.record("Expected session check to throw")
        } catch {}

        #expect(model.gateState == .unauthenticated)
    }

    @Test func editsClearOnlyRelatedErrorsAndModeSwitches() {
        let model = AuthViewModel(repository: StubAuthRepository())
        model.updateLoginEmail("a@example.com")
        model.updateLoginPassword("password")
        model.showSignup()
        model.updateSignupName("Selam")
        model.updateSignupEmail("s@example.com")
        model.updateSignupPassword("password")
        model.updateSignupConfirmPassword("password")
        model.updateTerms(true)
        #expect(model.mode == .signup)
        #expect(model.loginState.email == "a@example.com")
        #expect(model.signupState.acceptedTerms)
        model.showLogin()
        #expect(model.mode == .login)
    }

    @Test func loginFailureUsesPresenterAndPreservesInput() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(signInResult: .failure(.invalidCredentials)))
        model.updateLoginEmail(" selam@example.com ")
        model.updateLoginPassword("password123")
        try await model.submitLogin()
        #expect(model.loginState.message == "Email or password is incorrect.")
        #expect(model.loginState.email == " selam@example.com ")
        #expect(model.loginState.password == "password123")
        #expect(!model.loginState.isSubmitting)
    }

    @Test func submissionErrorsStopLoading() async {
        let repository = StubAuthRepository(throwsOnSubmission: true)
        let login = AuthViewModel(repository: repository)
        login.updateLoginEmail("selam@example.com")
        login.updateLoginPassword("password123")
        let signup = AuthViewModel(repository: repository)
        signup.updateSignupName("Selam Abebe")
        signup.updateSignupEmail("selam@example.com")
        signup.updateSignupPassword("password123")
        signup.updateSignupConfirmPassword("password123")
        signup.updateTerms(true)

        do { try await login.submitLogin() } catch {}
        do { try await signup.submitSignup() } catch {}

        #expect(!login.loginState.isSubmitting)
        #expect(!signup.signupState.isSubmitting)
    }

    @Test func signupRejectsPasswordMismatchWithoutRepositoryCall() async throws {
        let repository = AuthRepositorySpy()
        let model = AuthViewModel(repository: repository)
        model.updateSignupPassword("password123")
        model.updateSignupConfirmPassword("different")
        try await model.submitSignup()
        #expect(model.signupState.confirmPasswordError == "Passwords do not match.")
        #expect(await repository.signUpCallCount == 0)
    }

    @Test func loginAndSignupSuccessEmitAuthenticatedSession() async throws {
        let session = makeAuthSession()
        let login = AuthViewModel(repository: StubAuthRepository(signInResult: .success(session)))
        login.updateLoginEmail("selam@example.com")
        login.updateLoginPassword("password123")
        try await login.submitLogin()
        #expect(login.loginState.message == "Welcome back, Selam.")
        #expect(login.loginState.password.isEmpty)
        #expect(login.consumeEvent() == .authenticated(session))

        let signup = AuthViewModel(repository: StubAuthRepository(signUpResult: .success(.authenticated(session))))
        signup.updateSignupName("Selam Abebe")
        signup.updateSignupEmail("selam@example.com")
        signup.updateSignupPassword("password123")
        signup.updateSignupConfirmPassword("password123")
        signup.updateTerms(true)
        try await signup.submitSignup()
        #expect(signup.signupState.message == "Account ready for Selam.")
        #expect(signup.signupState.password.isEmpty)
        #expect(signup.signupState.confirmPassword.isEmpty)
        #expect(signup.consumeEvent() == .authenticated(session))
    }

    @Test func passwordResetValidatesThenReportsBackendFailureHonestly() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(resetResult: .failure(.unknown)))
        model.startPasswordCodeFlow()
        model.updatePasswordCodeEmail("bad")
        try await model.requestPasswordReset()
        #expect(model.passwordCodeState.emailError == "Please enter a valid email address.")
        model.updatePasswordCodeEmail("selam@example.com")
        try await model.requestPasswordReset()
        #expect(model.passwordCodeState.message == "We couldn’t confirm whether a code was sent. Check your inbox before requesting another.")
        #expect(model.passwordCodeState.messageIsError)
        #expect(model.passwordCodeState.step == .request)
    }

    @Test func signupWithoutSessionEntersVerificationPendingWithoutAuthenticatedEvent() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(signUpResult: .success(.verificationPending(email: "selam@example.com"))))
        model.updateSignupName("Selam Abebe")
        model.updateSignupEmail("selam@example.com")
        model.updateSignupPassword("password123")
        model.updateSignupConfirmPassword("password123")
        model.updateTerms(true)

        try await model.submitSignup()

        #expect(model.gateState == .verificationPending(email: "selam@example.com"))
        #expect(model.consumeEvent() == nil)
        #expect(model.signupState.password.isEmpty)
        #expect(model.signupState.confirmPassword.isEmpty)
    }

    @Test func unverifiedLoginUsesPendingStateAndCanResendWithoutDisclosingAddress() async throws {
        let repository = StubAuthRepository(signInResult: .failure(.emailNotVerified))
        let model = AuthViewModel(repository: repository)
        model.updateLoginEmail("selam@example.com")
        model.updateLoginPassword("password123")

        try await model.submitLogin()
        await model.resendVerificationEmail()

        #expect(model.gateState == .verificationPending(email: "selam@example.com"))
        #expect(model.loginState.password.isEmpty)
        #expect(model.verificationMessage == "Use the newest code you requested.")
        #expect(model.consumeEvent() == nil)
    }

    @Test func verificationCodeNeedsExplicitSubmitAndDoesNotCreateSession() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(
            signUpResult: .success(.verificationPending(email: "selam@example.com")),
            verifyCodeResult: .success(())
        ))
        model.showSignup()
        model.updateSignupName("Selam Abebe")
        model.updateSignupEmail("selam@example.com")
        model.updateSignupPassword("password123")
        model.updateSignupConfirmPassword("password123")
        model.updateTerms(true)
        try await model.submitSignup()
        model.updateVerificationCode("123456")
        #expect(model.gateState == .verificationPending(email: "selam@example.com"))
        try await model.submitVerificationCode()
        #expect(model.verificationSucceeded)
        #expect(model.verificationMessage == "Email verified.")
        model.finishVerificationFeedback()
        #expect(model.mode == .login)
        #expect(model.gateState == .unauthenticated)
        #expect(model.consumeEvent() == nil)
        #expect(model.verificationCode.isEmpty)
    }

    @Test func leavingSignupVerificationReturnsToSignIn() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(
            signUpResult: .success(.verificationPending(email: "selam@example.com"))
        ))
        model.showSignup()
        model.updateSignupName("Selam Abebe")
        model.updateSignupEmail("selam@example.com")
        model.updateSignupPassword("password123")
        model.updateSignupConfirmPassword("password123")
        model.updateTerms(true)
        try await model.submitSignup()
        model.showSignInForPendingVerification()
        #expect(model.mode == .login)
        #expect(model.gateState == .unauthenticated)
    }

    @Test func invalidVerificationCodeRemainsEditable() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(
            signInResult: .failure(.emailNotVerified),
            verifyCodeResult: .failure(.invalidCode)
        ))
        model.updateLoginEmail("selam@example.com")
        model.updateLoginPassword("password123")
        try await model.submitLogin()
        model.updateVerificationCode("123456")
        try await model.submitVerificationCode()
        #expect(model.verificationCodeError?.contains("newest code") == true)
        #expect(model.gateState == .verificationPending(email: "selam@example.com"))
        model.updateVerificationCode("654321")
        #expect(model.verificationCodeError == nil)
    }

    @Test func successfulResendClearsStaleCodeError() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(
            signInResult: .failure(.emailNotVerified),
            verifyCodeResult: .failure(.expiredCode)
        ))
        model.updateLoginEmail("selam@example.com")
        model.updateLoginPassword("password123")
        try await model.submitLogin()
        model.updateVerificationCode("123456")
        try await model.submitVerificationCode()
        #expect(model.verificationCodeError != nil)

        await model.resendVerificationEmail()

        #expect(model.verificationCode.isEmpty)
        #expect(model.verificationCodeError == nil)
        #expect(model.verificationMessage == "Use the newest code you requested.")
        #expect(!model.verificationMessageIsError)
    }

    @Test func exhaustedVerificationCodeRequiresResend() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(
            signInResult: .failure(.emailNotVerified),
            verifyCodeResult: .failure(.tooManyCodeAttempts)
        ))
        model.updateLoginEmail("selam@example.com")
        model.updateLoginPassword("password123")
        try await model.submitLogin()
        model.updateVerificationCode("123456")
        try await model.submitVerificationCode()
        #expect(model.verificationRequiresNewCode)
        #expect(model.verificationCode.isEmpty)
        model.updateVerificationCode("654321")
        #expect(model.verificationCode.isEmpty)

        await model.resendVerificationEmail()
        #expect(!model.verificationRequiresNewCode)
        #expect(model.verificationCodeError == nil)
    }

    @Test func resetCodeThenPasswordUsesOneFinalSubmission() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(
            resetResult: .success(()), updatePasswordResult: .success(())
        ))
        model.startPasswordCodeFlow()
        model.updatePasswordCodeEmail("selam@example.com")
        try await model.requestPasswordReset()
        #expect(model.passwordCodeState.step == .code)
        model.updatePasswordCode("123456")
        model.continuePasswordReset()
        #expect(model.passwordCodeState.step == .password)
        model.updatePasswordCodePassword("newpassword123")
        model.updatePasswordCodeConfirmation("newpassword123")
        try await model.submitPasswordCodeReset()
        #expect(model.passwordCodeState.step == .complete)
        #expect(model.passwordCodeState.code.isEmpty)
        #expect(model.passwordCodeState.password.isEmpty)
        #expect(model.consumeEvent() == nil)
    }

    @Test func resetNetworkLossHasUncertainOutcomeAndClearsSecrets() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(
            resetResult: .success(()), updatePasswordResult: .failure(.networkUnavailable)
        ))
        model.startPasswordCodeFlow()
        model.updatePasswordCodeEmail("selam@example.com")
        try await model.requestPasswordReset()
        model.updatePasswordCode("123456")
        model.continuePasswordReset()
        model.updatePasswordCodePassword("newpassword123")
        model.updatePasswordCodeConfirmation("newpassword123")
        try await model.submitPasswordCodeReset()
        #expect(model.passwordCodeState.step == .uncertain)
        #expect(model.passwordCodeState.code.isEmpty)
        #expect(model.passwordCodeState.password.isEmpty)
    }

    @Test func resetPasswordValidationStaysOnPasswordStep() async throws {
        let model = AuthViewModel(repository: StubAuthRepository(
            resetResult: .success(()),
            updatePasswordResult: .failure(.validation([.password: "Password is too long."]))
        ))
        model.startPasswordCodeFlow()
        model.updatePasswordCodeEmail("selam@example.com")
        try await model.requestPasswordReset()
        model.updatePasswordCode("123456")
        model.continuePasswordReset()
        model.updatePasswordCodePassword("newpassword123")
        model.updatePasswordCodeConfirmation("newpassword123")
        try await model.submitPasswordCodeReset()

        #expect(model.passwordCodeState.step == .password)
        #expect(model.passwordCodeState.passwordError == "Password is too long.")
        #expect(model.passwordCodeState.codeError == nil)
        #expect(model.passwordCodeState.code == "123456")
    }

    @Test func passwordResetValidTokenClearsFormAndRoutesToSignIn() async {
        let model = AuthViewModel(repository: StubAuthRepository(updatePasswordResult: .success(())))
        await model.openAuthLink(.resetPassword(token: "reset-token"))
        model.updateResetPassword("newpassword123")
        model.updateResetPasswordConfirmation("newpassword123")

        await model.submitPasswordReset()

        #expect(model.authLinkState == .resetComplete)
        #expect(model.passwordResetState.password.isEmpty)
        #expect(model.passwordResetState.confirmPassword.isEmpty)
    }

    @Test func passwordResetOfflineKeepsLinkForRetry() async {
        let model = AuthViewModel(repository: StubAuthRepository(updatePasswordResult: .failure(.networkUnavailable)))
        await model.openAuthLink(.resetPassword(token: "reset-token"))
        model.updateResetPassword("newpassword123")
        model.updateResetPasswordConfirmation("newpassword123")

        await model.submitPasswordReset()

        #expect(model.authLinkState == .resetForm)
        #expect(!model.passwordResetState.isSubmitting)
        #expect(model.passwordResetState.message?.contains("Check your connection") == true)
    }

    @Test func expiredPasswordResetTokenClearsCredentialsAndExplainsRecovery() async {
        let model = AuthViewModel(repository: StubAuthRepository(updatePasswordResult: .failure(.unauthenticated)))
        await model.openAuthLink(.resetPassword(token: "expired-token"))
        model.updateResetPassword("newpassword123")
        model.updateResetPasswordConfirmation("newpassword123")

        await model.submitPasswordReset()

        #expect(model.authLinkState == .resetFailed)
        #expect(model.passwordResetState.password.isEmpty)
        #expect(model.passwordResetState.confirmPassword.isEmpty)
        #expect(model.passwordResetState.message?.contains("expired or already been used") == true)
    }

    @Test func passwordResetUnexpectedErrorStopsLoading() async {
        let model = AuthViewModel(repository: ThrowingPasswordResetRepository())
        model.startPasswordCodeFlow()
        model.updatePasswordCodeEmail("selam@example.com")

        do {
            try await model.requestPasswordReset()
            Issue.record("Expected password reset to throw")
        } catch {}

        #expect(!model.passwordCodeState.isSubmitting)
        #expect(model.passwordCodeState.message == "Couldn’t send a code. Try again.")
    }
}

private struct StubAuthRepository: AuthRepository {
    var signInResult: AuthResult<AuthSession> = .failure(.unknown)
    var signUpResult: AuthResult<AuthSignUpResult> = .failure(.unknown)
    var sessionResult: AuthResult<AuthSession> = .failure(.unauthenticated)
    var resetResult: AuthResult<Void> = .failure(.unknown)
    var updatePasswordResult: AuthResult<Void> = .failure(.unknown)
    var verifyCodeResult: AuthResult<Void> = .failure(.unknown)
    var throwsOnSessionCheck = false
    var throwsOnSubmission = false
    func signInEmail(request: SignInRequest) async throws -> AuthResult<AuthSession> {
        if throwsOnSubmission { throw StubAuthError.submissionFailed }
        return signInResult
    }
    func signUpEmail(request: SignUpRequest) async throws -> AuthResult<AuthSignUpResult> {
        if throwsOnSubmission { throw StubAuthError.submissionFailed }
        return signUpResult
    }
    func getSession() async throws -> AuthResult<AuthSession> {
        if throwsOnSessionCheck { throw StubAuthError.sessionCheckFailed }
        return sessionResult
    }
    func getLocalSession() async throws -> AuthSession? { nil }
    func requestPasswordReset(email: String) async throws -> AuthResult<Void> { resetResult }
    func requestPasswordResetCode(email: String) async throws -> AuthResult<Void> { resetResult }
    func verifyEmailCode(email: String, code: String) async throws -> AuthResult<Void> { verifyCodeResult }
    func resetPasswordCode(email: String, code: String, newPassword: String) async throws -> AuthResult<Void> { updatePasswordResult }
    func sendVerificationCode(email: String) async throws -> AuthResult<Void> { .success(()) }
    func resendVerificationEmail(email: String) async throws -> AuthResult<Void> { .success(()) }
    func resetPassword(token: String, newPassword: String) async throws -> AuthResult<Void> { updatePasswordResult }
    func signOut() async throws -> AuthResult<Void> { .success(()) }
}

private enum StubAuthError: Error { case sessionCheckFailed, submissionFailed }

private struct ThrowingPasswordResetRepository: AuthRepository {
    func signInEmail(request: SignInRequest) async throws -> AuthResult<AuthSession> { .failure(.unknown) }
    func signUpEmail(request: SignUpRequest) async throws -> AuthResult<AuthSignUpResult> { .failure(.unknown) }
    func getSession() async throws -> AuthResult<AuthSession> { .failure(.unauthenticated) }
    func getLocalSession() async throws -> AuthSession? { nil }
    func requestPasswordReset(email: String) async throws -> AuthResult<Void> { throw StubAuthError.submissionFailed }
    func requestPasswordResetCode(email: String) async throws -> AuthResult<Void> { throw StubAuthError.submissionFailed }
    func signOut() async throws -> AuthResult<Void> { .success(()) }
}

private actor AuthRepositorySpy: AuthRepository {
    private(set) var signUpCallCount = 0
    func signInEmail(request: SignInRequest) async throws -> AuthResult<AuthSession> { .failure(.unknown) }
    func signUpEmail(request: SignUpRequest) async throws -> AuthResult<AuthSignUpResult> {
        signUpCallCount += 1
        return .failure(.unknown)
    }
    func getSession() async throws -> AuthResult<AuthSession> { .failure(.unauthenticated) }
    func getLocalSession() async throws -> AuthSession? { nil }
    func requestPasswordReset(email: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func signOut() async throws -> AuthResult<Void> { .success(()) }
}

private func makeAuthSession() -> AuthSession {
    AuthSession(
        sessionId: "session",
        user: AuthUser(id: "user", displayName: "Selam", email: "selam@example.com", avatarUrl: nil),
        tokens: nil,
        expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
    )
}
