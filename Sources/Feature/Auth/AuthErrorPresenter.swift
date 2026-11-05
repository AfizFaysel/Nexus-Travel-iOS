/// Maps authentication domain errors into login and signup presentation state.
public enum AuthErrorPresenter {
    /// Returns login state updated for a domain error.
    public static func loginState(from state: LoginUiState, error: AuthError) -> LoginUiState {
        var updated = state
        updated.isSubmitting = false

        switch error {
        case let .validation(fieldErrors):
            updated.emailError = fieldErrors[.email]
            updated.passwordError = fieldErrors[.password]
        case .invalidCredentials:
            updated.message = "Email or password is incorrect."
        case .emailAlreadyUsed:
            updated.message = emailAlreadyUsedMessage
        case .emailNotVerified:
            updated.message = "Verify your email before signing in."
        case .networkUnavailable:
            updated.message = offlineMessage
        case .rateLimited:
            updated.message = rateLimitedMessage
        case .invalidCode, .expiredCode, .tooManyCodeAttempts:
            updated.message = unknownMessage
        case .unauthenticated, .sessionExpired:
            updated.message = sessionExpiredMessage
        case .unknown:
            updated.message = unknownMessage
        }
        return updated
    }

    /// Returns signup state updated for a domain error.
    public static func signupState(from state: SignupUiState, error: AuthError) -> SignupUiState {
        var updated = state
        updated.isSubmitting = false

        switch error {
        case let .validation(fieldErrors):
            updated.fullNameError = fieldErrors[.fullName]
            updated.emailError = fieldErrors[.email]
            updated.passwordError = fieldErrors[.password]
            updated.confirmPasswordError = fieldErrors[.confirmPassword]
            updated.termsError = fieldErrors[.terms]
        case .emailAlreadyUsed:
            updated.emailError = emailAlreadyUsedMessage
        case .invalidCredentials:
            updated.message = "This account cannot be created. Try another email."
        case .emailNotVerified:
            updated.message = "Verify your email to continue."
        case .networkUnavailable:
            updated.message = signupOutcomeUncertainMessage
        case .rateLimited:
            updated.message = rateLimitedMessage
        case .invalidCode, .expiredCode, .tooManyCodeAttempts:
            updated.message = unknownMessage
        case .unauthenticated, .sessionExpired:
            updated.message = sessionExpiredMessage
        case .unknown:
            updated.message = signupOutcomeUncertainMessage
        }
        return updated
    }

    private static let emailAlreadyUsedMessage = "An account already exists for this email."
    private static let signupOutcomeUncertainMessage = "We couldn’t confirm whether your account was created. Check your inbox or try signing in before signing up again."
    private static let offlineMessage = "You appear to be offline. Check your connection and try again."
    private static let rateLimitedMessage = "Too many attempts. Try again later."
    private static let sessionExpiredMessage = "Your session expired. Sign in again."
    private static let unknownMessage = "Something went wrong. Please try again."
}
