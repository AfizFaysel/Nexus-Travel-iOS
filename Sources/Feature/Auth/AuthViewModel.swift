import Foundation
import Observation

enum AuthEvent: Equatable, Sendable {
    case authenticated(AuthSession)
}

@MainActor
@Observable
final class AuthViewModel {
    private(set) var mode: AuthMode = .login
    private(set) var loginState = LoginUiState()
    private(set) var signupState = SignupUiState()
    private(set) var gateState: AuthGateState = .checking
    private(set) var verificationMessage: String?
    private(set) var verificationMessageIsError = false
    private(set) var isResendingVerification = false
    private(set) var verificationCode = ""
    private(set) var verificationCodeError: String?
    private(set) var verificationRequiresNewCode = false
    private(set) var verificationOutcomeUncertain = false
    private(set) var isVerifyingCode = false
    private(set) var verificationSucceeded = false
    private(set) var passwordCodeState = PasswordCodeUiState()
    private(set) var passwordResetState = PasswordResetUiState()
    private(set) var authLinkState: AuthLinkUiState = .idle

    private let repository: any AuthRepository
    private var events: [AuthEvent] = []
    private var authLinkToken: String?
    private var authLinkRequestID = UUID()
    private var codeRequestID = UUID()

    init(repository: any AuthRepository) {
        self.repository = repository
    }

    var isSubmitting: Bool { loginState.isSubmitting || signupState.isSubmitting }

    func checkExistingSession() async throws {
        let previous = gateState
        gateState = .checking
        do {
            switch try await repository.getSession() {
            case let .success(session): finishAuth(.session, session: session)
            case .failure: gateState = .unauthenticated
            }
        } catch is CancellationError {
            gateState = previous
            throw CancellationError()
        } catch {
            gateState = .unauthenticated
            throw error
        }
    }

    func showLogin() { mode = .login }
    func showSignup() { mode = .signup }

    func updateLoginEmail(_ email: String) {
        loginState.email = email
        loginState.emailError = nil
        loginState.message = nil
        loginState.isSuccess = false
    }

    func updateLoginPassword(_ password: String) {
        loginState.password = password
        loginState.passwordError = nil
        loginState.message = nil
        loginState.isSuccess = false
    }

    func updateSignupName(_ fullName: String) {
        signupState.fullName = fullName
        signupState.fullNameError = nil
        signupState.message = nil
    }

    func updateSignupEmail(_ email: String) {
        signupState.email = email
        signupState.emailError = nil
        signupState.message = nil
    }

    func updateSignupPassword(_ password: String) {
        signupState.password = password
        signupState.passwordError = nil
        signupState.confirmPasswordError = nil
        signupState.message = nil
    }

    func updateSignupConfirmPassword(_ password: String) {
        signupState.confirmPassword = password
        signupState.confirmPasswordError = nil
        signupState.message = nil
    }

    func updateTerms(_ accepted: Bool) {
        signupState.acceptedTerms = accepted
        signupState.termsError = nil
        signupState.message = nil
    }

    func submitLogin() async throws {
        guard !loginState.isSubmitting else { return }
        let previous = loginState
        loginState.isSubmitting = true
        loginState.emailError = nil
        loginState.passwordError = nil
        loginState.message = nil
        do {
            let request = SignInRequest(
                email: loginState.email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: loginState.password
            )
            switch try await repository.signInEmail(request: request) {
            case let .success(session): finishAuth(.login, session: session)
            case let .failure(error):
                loginState = AuthErrorPresenter.loginState(from: loginState, error: error)
                if error == .emailNotVerified {
                    loginState.password = ""
                    gateState = .verificationPending(email: request.email)
                    verificationRequiresNewCode = false
                    verificationCodeError = nil
                    verificationCode = ""
                }
            }
        } catch is CancellationError {
            loginState = previous
            throw CancellationError()
        } catch {
            loginState = AuthErrorPresenter.loginState(from: previous, error: .unknown)
            throw error
        }
    }

    func submitSignup() async throws {
        guard !signupState.isSubmitting else { return }
        let previous = signupState
        signupState.isSubmitting = true
        clearSignupFeedback()
        guard signupState.password == signupState.confirmPassword else {
            signupState.isSubmitting = false
            signupState.confirmPasswordError = "Passwords do not match."
            return
        }
        do {
            let request = SignUpRequest(
                fullName: signupState.fullName,
                email: signupState.email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: signupState.password,
                acceptedTerms: signupState.acceptedTerms
            )
            switch try await repository.signUpEmail(request: request) {
            case let .success(.authenticated(session)): finishAuth(.signup, session: session)
            case let .success(.verificationPending(email)):
                gateState = .verificationPending(email: email)
                verificationRequiresNewCode = false
                verificationCodeError = nil
                verificationCode = ""
                signupState.isSubmitting = false
                signupState.password = ""
                signupState.confirmPassword = ""
                verificationMessage = nil
            case let .failure(error): signupState = AuthErrorPresenter.signupState(from: signupState, error: error)
            }
        } catch is CancellationError {
            signupState = previous
            throw CancellationError()
        } catch {
            signupState = AuthErrorPresenter.signupState(from: previous, error: .unknown)
            throw error
        }
    }

    func startPasswordCodeFlow() {
        codeRequestID = UUID()
        passwordCodeState = PasswordCodeUiState(email: loginState.email)
    }

    func updatePasswordCodeEmail(_ email: String) {
        passwordCodeState.email = email
        passwordCodeState.emailError = nil
        passwordCodeState.message = nil
        passwordCodeState.messageIsError = false
    }

    func updatePasswordCode(_ input: String) {
        guard !passwordCodeState.requiresNewCode else { return }
        passwordCodeState.code = String(input.filter(\.isNumber).prefix(6))
        passwordCodeState.codeError = nil
        passwordCodeState.message = nil
        passwordCodeState.messageIsError = false
    }

    func updatePasswordCodePassword(_ value: String) {
        passwordCodeState.password = value
        passwordCodeState.passwordError = nil
        passwordCodeState.message = nil
        passwordCodeState.messageIsError = false
    }

    func updatePasswordCodeConfirmation(_ value: String) {
        passwordCodeState.confirmPassword = value
        passwordCodeState.confirmPasswordError = nil
    }

    func cancelCodeFlow() {
        codeRequestID = UUID()
        passwordCodeState = PasswordCodeUiState()
    }

    func requestPasswordReset() async throws {
        guard !passwordCodeState.isSubmitting else { return }
        let email = passwordCodeState.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let validation = AuthValidator.validatePasswordReset(email: email)
        guard validation.isEmpty else {
            passwordCodeState.emailError = validation[.email]
            return
        }
        let requestID = UUID()
        codeRequestID = requestID
        passwordCodeState.isSubmitting = true
        passwordCodeState.codeError = nil
        defer { if codeRequestID == requestID { passwordCodeState.isSubmitting = false } }
        do {
            let result = try await repository.requestPasswordResetCode(email: email)
            guard codeRequestID == requestID else { return }
            switch result {
            case .success:
                passwordCodeState.email = email
                passwordCodeState.code = ""
                passwordCodeState.codeError = nil
                passwordCodeState.requiresNewCode = false
                passwordCodeState.step = .code
                passwordCodeState.message = "If an account uses this email, we’ll send a code."
                passwordCodeState.messageIsError = false
            case let .failure(error):
                passwordCodeState.emailError = Self.emailError(for: error)
                passwordCodeState.message = Self.codeDeliveryMessage(for: error)
                passwordCodeState.messageIsError = true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard codeRequestID == requestID else { return }
            passwordCodeState.message = "Couldn’t send a code. Try again."
            throw error
        }
    }

    func continuePasswordReset() {
        guard !passwordCodeState.requiresNewCode else { return }
        guard passwordCodeState.code.count == 6 else {
            passwordCodeState.codeError = "Enter the six-digit code."
            return
        }
        passwordCodeState.step = .password
    }

    func submitPasswordCodeReset() async throws {
        guard !passwordCodeState.isSubmitting else { return }
        guard !passwordCodeState.requiresNewCode else { return }
        passwordCodeState.passwordError = AuthValidator.validateNewPassword(passwordCodeState.password)
        passwordCodeState.confirmPasswordError = passwordCodeState.password == passwordCodeState.confirmPassword
            ? nil : "Passwords do not match."
        guard passwordCodeState.passwordError == nil, passwordCodeState.confirmPasswordError == nil else { return }
        let requestID = UUID()
        codeRequestID = requestID
        passwordCodeState.isSubmitting = true
        defer { if codeRequestID == requestID { passwordCodeState.isSubmitting = false } }
        do {
            let result = try await repository.resetPasswordCode(
                email: passwordCodeState.email,
                code: passwordCodeState.code,
                newPassword: passwordCodeState.password
            )
            guard codeRequestID == requestID else { return }
            passwordCodeState.isSubmitting = false
            switch result {
            case .success:
                passwordCodeState.password = ""
                passwordCodeState.confirmPassword = ""
                passwordCodeState.code = ""
                passwordCodeState.step = .complete
                gateState = .unauthenticated
            case let .failure(error):
                if error == .networkUnavailable {
                    passwordCodeState.password = ""
                    passwordCodeState.confirmPassword = ""
                    passwordCodeState.code = ""
                    passwordCodeState.step = .uncertain
                } else if case let .validation(fields) = error {
                    passwordCodeState.passwordError = fields[.password]
                    passwordCodeState.emailError = fields[.email]
                } else if error == .rateLimited {
                    passwordCodeState.message = "Too many requests. Try again later."
                    passwordCodeState.messageIsError = true
                } else if error == .unknown {
                    passwordCodeState.password = ""
                    passwordCodeState.confirmPassword = ""
                    passwordCodeState.code = ""
                    passwordCodeState.step = .uncertain
                } else {
                    passwordCodeState.codeError = Self.codeMessage(for: error)
                    if error == .invalidCode || error == .expiredCode || error == .tooManyCodeAttempts {
                        passwordCodeState.step = .code
                        passwordCodeState.requiresNewCode = error == .expiredCode || error == .tooManyCodeAttempts
                        if passwordCodeState.requiresNewCode { passwordCodeState.code = "" }
                    }
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard codeRequestID == requestID else { return }
            passwordCodeState.password = ""
            passwordCodeState.confirmPassword = ""
            passwordCodeState.code = ""
            passwordCodeState.step = .uncertain
            throw error
        }
    }

    func preparePasswordResetEmail() async {
        guard passwordCodeState.email.isEmpty else { return }
        do {
            passwordCodeState.email = try await repository.getLocalSession()?.user.email ?? ""
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    func showSignInForPendingVerification() {
        mode = .login
        if case let .verificationPending(email) = gateState { loginState.email = email }
        loginState.password = ""
        gateState = .unauthenticated
        codeRequestID = UUID()
        verificationCode = ""
        verificationCodeError = nil
        verificationRequiresNewCode = false
        verificationMessage = nil
        verificationMessageIsError = false
        verificationSucceeded = false
        verificationOutcomeUncertain = false
        isVerifyingCode = false
        isResendingVerification = false
    }

    func resendVerificationEmail() async {
        guard case let .verificationPending(email) = gateState,
              !isResendingVerification, !isVerifyingCode, !verificationSucceeded else { return }
        isResendingVerification = true
        verificationCodeError = nil
        verificationMessage = nil
        verificationMessageIsError = false
        let requestID = codeRequestID
        defer { isResendingVerification = false }
        do {
            let result = try await repository.sendVerificationCode(email: email)
            guard codeRequestID == requestID else { return }
            switch result {
            case .success:
                verificationCode = ""
                verificationCodeError = nil
                verificationRequiresNewCode = false
                verificationMessage = "Use the newest code you requested."
                verificationMessageIsError = false
            case let .failure(error):
                verificationMessage = Self.codeDeliveryMessage(for: error)
                verificationMessageIsError = true
            }
        } catch is CancellationError {
            return
        } catch {
            guard codeRequestID == requestID else { return }
            verificationMessage = "Couldn’t send a code. Check your connection and try again."
            verificationMessageIsError = true
        }
    }

    func updateVerificationCode(_ input: String) {
        guard !verificationRequiresNewCode else { return }
        verificationCode = String(input.filter(\.isNumber).prefix(6))
        verificationCodeError = nil
        verificationOutcomeUncertain = false
    }

    func submitVerificationCode() async throws {
        guard case let .verificationPending(email) = gateState,
              !isVerifyingCode, !isResendingVerification, !verificationSucceeded,
              !verificationRequiresNewCode else { return }
        guard verificationCode.count == 6 else {
            verificationCodeError = "Enter the six-digit code."
            return
        }
        let requestID = UUID()
        codeRequestID = requestID
        isVerifyingCode = true
        defer { if codeRequestID == requestID { isVerifyingCode = false } }
        do {
            let result = try await repository.verifyEmailCode(email: email, code: verificationCode)
            guard codeRequestID == requestID else { return }
            switch result {
            case .success:
                verificationCode = ""
                verificationCodeError = nil
                verificationMessage = "Email verified."
                verificationSucceeded = true
            case let .failure(error):
                verificationCodeError = Self.codeMessage(for: error)
                verificationRequiresNewCode = error == .expiredCode || error == .tooManyCodeAttempts
                if verificationRequiresNewCode { verificationCode = "" }
                verificationOutcomeUncertain = error == .networkUnavailable
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard codeRequestID == requestID else { return }
            verificationCodeError = "Couldn’t verify the code. Try again."
            throw error
        }
    }

    func finishVerificationFeedback() {
        guard verificationSucceeded, case let .verificationPending(email) = gateState else { return }
        mode = .login
        verificationSucceeded = false
        loginState.email = email
        loginState.message = "Email verified. Sign in to continue."
        loginState.isSuccess = true
        gateState = .unauthenticated
    }

    private static func codeMessage(for error: AuthError) -> String {
        switch error {
        case .invalidCode: "That code didn’t work. Check the newest code and try again."
        case .expiredCode: "Code expired. Send a new code to continue."
        case .tooManyCodeAttempts: "Too many incorrect codes. Send a new code to continue."
        case .rateLimited: "Too many requests. Try again later."
        case .networkUnavailable: "We couldn’t confirm. Try signing in before requesting another code."
        default: "Couldn’t verify the code. Try again."
        }
    }

    private static func emailError(for error: AuthError) -> String? {
        guard case let .validation(fields) = error else { return nil }
        return fields[.email]
    }

    private static func codeDeliveryMessage(for error: AuthError) -> String {
        switch error {
        case .rateLimited: "Too many requests. Try again later."
        case .networkUnavailable, .unknown: "We couldn’t confirm whether a code was sent. Check your inbox before requesting another."
        case .validation: "Check your email address and try again."
        default: "We couldn’t send a code right now. Try again later."
        }
    }

    func openAuthLink(_ route: AuthLinkRoute) async {
        authLinkRequestID = UUID()
        let requestID = authLinkRequestID
        switch route {
        case let .verifyEmail(token):
            authLinkToken = token
            authLinkState = .verifying
            do {
                let result = try await repository.verifyEmail(token: token)
                guard requestID == authLinkRequestID else { return }
                switch result {
                case .success:
                    authLinkToken = nil
                    authLinkState = .verified
                case .failure(.networkUnavailable):
                    authLinkState = .verificationOffline
                case .failure:
                    authLinkToken = nil
                    authLinkState = .verificationFailed
                }
            } catch is CancellationError {
                return
            } catch {
                guard requestID == authLinkRequestID else { return }
                authLinkState = .verificationFailed
            }
        case let .resetPassword(token):
            authLinkToken = token
            passwordResetState = PasswordResetUiState()
            authLinkState = .resetForm
        }
    }

    func updateResetPassword(_ password: String) {
        passwordResetState.password = password
        passwordResetState.passwordError = nil
        passwordResetState.message = nil
    }

    func updateResetPasswordConfirmation(_ password: String) {
        passwordResetState.confirmPassword = password
        passwordResetState.confirmPasswordError = nil
        passwordResetState.message = nil
    }

    func submitPasswordReset() async {
        guard let token = authLinkToken, !passwordResetState.isSubmitting else { return }
        passwordResetState.passwordError = AuthValidator.validateNewPassword(passwordResetState.password)
        passwordResetState.confirmPasswordError = passwordResetState.password == passwordResetState.confirmPassword
            ? nil : "Passwords do not match."
        guard passwordResetState.passwordError == nil, passwordResetState.confirmPasswordError == nil else { return }
        let requestID = authLinkRequestID
        passwordResetState.isSubmitting = true
        do {
            let result = try await repository.resetPassword(token: token, newPassword: passwordResetState.password)
            guard requestID == authLinkRequestID else { return }
            passwordResetState.isSubmitting = false
            if result.isSuccess {
                authLinkToken = nil
                passwordResetState.password = ""
                passwordResetState.confirmPassword = ""
                passwordResetState.isSuccess = true
                passwordResetState.message = "Password updated. Sign in with your new password."
                authLinkState = .resetComplete
            } else if case .failure(.networkUnavailable) = result {
                passwordResetState.message = "We couldn’t reset your password. Check your connection and try again."
            } else {
                passwordResetState.password = ""
                passwordResetState.confirmPassword = ""
                passwordResetState.message = "This reset link may have expired or already been used. Request a new link and try again."
                authLinkToken = nil
                authLinkState = .resetFailed
            }
        } catch is CancellationError {
            return
        } catch {
            guard requestID == authLinkRequestID else { return }
            passwordResetState.isSubmitting = false
            passwordResetState.message = "We couldn’t reset your password. Check your connection and try again."
        }
    }

    func consumeEvent() -> AuthEvent? {
        events.isEmpty ? nil : events.removeFirst()
    }

    private func clearSignupFeedback() {
        signupState.fullNameError = nil
        signupState.emailError = nil
        signupState.passwordError = nil
        signupState.confirmPasswordError = nil
        signupState.termsError = nil
        signupState.message = nil
    }

    private func finishAuth(_ completion: AuthCompletion, session: AuthSession) {
        gateState = .authenticated(session)
        switch completion {
        case .session: break
        case .login:
            loginState.isSubmitting = false
            loginState.isSuccess = true
            loginState.message = "Welcome back, \(session.user.displayName)."
            loginState.password = ""
        case .signup:
            signupState.isSubmitting = false
            signupState.isSuccess = true
            signupState.message = "Account ready for \(session.user.displayName)."
            signupState.password = ""
            signupState.confirmPassword = ""
        }
        events.append(.authenticated(session))
    }
}

private enum AuthCompletion {
    case session
    case login
    case signup
}

private extension AuthResult where Value == Void {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

enum AuthLinkUiState: Equatable, Sendable {
    case idle
    case verifying
    case verified
    case verificationFailed
    case verificationOffline
    case resetForm
    case resetComplete
    case resetFailed
}
