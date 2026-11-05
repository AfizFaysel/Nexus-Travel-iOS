import Testing
@testable import NexusTravel

struct AuthErrorPresenterTests {
    @Test func loginValidationReplacesFieldsAndPreservesUnrelatedState() {
        let state = LoginUiState(
            email: "saved@example.com",
            password: "saved-password",
            emailError: "Old email",
            passwordError: "Old password",
            message: "Keep banner",
            isSubmitting: true,
            isSuccess: true
        )

        let updated = AuthErrorPresenter.loginState(
            from: state,
            error: .validation([.email: "Bad email"])
        )

        #expect(updated.email == state.email)
        #expect(updated.password == state.password)
        #expect(updated.emailError == "Bad email")
        #expect(updated.passwordError == nil)
        #expect(updated.message == state.message)
        #expect(updated.isSubmitting == false)
        #expect(updated.isSuccess == true)
    }

    @Test func signupValidationReplacesEveryFieldAndPreservesUnrelatedState() {
        let state = SignupUiState(
            fullName: "Saved Name",
            email: "saved@example.com",
            password: "saved-password",
            confirmPassword: "saved-confirmation",
            acceptedTerms: true,
            fullNameError: "Old name",
            emailError: "Old email",
            passwordError: "Old password",
            confirmPasswordError: "Old confirmation",
            termsError: "Old terms",
            message: "Keep banner",
            isSubmitting: true,
            isSuccess: true
        )

        let updated = AuthErrorPresenter.signupState(
            from: state,
            error: .validation([
                .fullName: "Bad name",
                .confirmPassword: "Bad confirmation"
            ])
        )

        #expect(updated.fullName == state.fullName)
        #expect(updated.email == state.email)
        #expect(updated.password == state.password)
        #expect(updated.confirmPassword == state.confirmPassword)
        #expect(updated.acceptedTerms == true)
        #expect(updated.fullNameError == "Bad name")
        #expect(updated.emailError == nil)
        #expect(updated.passwordError == nil)
        #expect(updated.confirmPasswordError == "Bad confirmation")
        #expect(updated.termsError == nil)
        #expect(updated.message == state.message)
        #expect(updated.isSubmitting == false)
        #expect(updated.isSuccess == true)
    }

    @Test(arguments: [
        (AuthError.invalidCredentials, "Email or password is incorrect."),
        (AuthError.emailAlreadyUsed, "An account already exists for this email."),
        (AuthError.emailNotVerified, "Verify your email before signing in."),
        (AuthError.networkUnavailable, "You appear to be offline. Check your connection and try again."),
        (AuthError.rateLimited, "Too many attempts. Try again later."),
        (AuthError.unauthenticated, "Your session expired. Sign in again."),
        (AuthError.sessionExpired, "Your session expired. Sign in again."),
        (AuthError.unknown, "Something went wrong. Please try again.")
    ])
    func loginMessagesMatchAndroid(_ error: AuthError, _ message: String) {
        let state = LoginUiState(
            email: "saved@example.com",
            password: "saved-password",
            emailError: "Keep email",
            passwordError: "Keep password",
            isSubmitting: true,
            isSuccess: true
        )

        let updated = AuthErrorPresenter.loginState(from: state, error: error)

        #expect(updated.message == message)
        #expect(updated.emailError == state.emailError)
        #expect(updated.passwordError == state.passwordError)
        #expect(updated.email == state.email)
        #expect(updated.password == state.password)
        #expect(updated.isSubmitting == false)
        #expect(updated.isSuccess == true)
    }

    @Test(arguments: [
        (AuthError.invalidCredentials, "This account cannot be created. Try another email."),
        (AuthError.emailNotVerified, "Verify your email to continue."),
        (AuthError.networkUnavailable, "We couldn’t confirm whether your account was created. Check your inbox or try signing in before signing up again."),
        (AuthError.rateLimited, "Too many attempts. Try again later."),
        (AuthError.unauthenticated, "Your session expired. Sign in again."),
        (AuthError.sessionExpired, "Your session expired. Sign in again."),
        (AuthError.unknown, "We couldn’t confirm whether your account was created. Check your inbox or try signing in before signing up again.")
    ])
    func signupMessagesMatchAndroid(_ error: AuthError, _ message: String) {
        let state = SignupUiState(
            emailError: "Keep email",
            passwordError: "Keep password",
            message: "Old banner",
            isSubmitting: true,
            isSuccess: true
        )

        let updated = AuthErrorPresenter.signupState(from: state, error: error)

        #expect(updated.message == message)
        #expect(updated.emailError == state.emailError)
        #expect(updated.passwordError == state.passwordError)
        #expect(updated.isSubmitting == false)
        #expect(updated.isSuccess == true)
    }

    @Test func signupEmailAlreadyUsedChangesEmailFieldOnly() {
        let state = SignupUiState(
            fullNameError: "Keep name",
            passwordError: "Keep password",
            message: "Keep banner",
            isSubmitting: true,
            isSuccess: true
        )

        let updated = AuthErrorPresenter.signupState(from: state, error: .emailAlreadyUsed)

        #expect(updated.emailError == "An account already exists for this email.")
        #expect(updated.fullNameError == state.fullNameError)
        #expect(updated.passwordError == state.passwordError)
        #expect(updated.message == state.message)
        #expect(updated.isSubmitting == false)
        #expect(updated.isSuccess == true)
    }
}
