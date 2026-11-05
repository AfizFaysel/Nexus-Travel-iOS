import Testing
@testable import NexusTravel

struct AuthValidationTests {
    @Test(arguments: [
        "a@b.co",
        "  a@b.co\n",
        "a@@b.co"
    ])
    func signInAcceptsAndroidCompatibleEmails(_ email: String) {
        let errors = AuthValidator.validateSignIn(
            request: SignInRequest(email: email, password: "12345678")
        )

        #expect(errors.isEmpty)
    }

    @Test(arguments: [
        "ab.co",
        "@b.co",
        "a@bc",
        "a@.co",
        "a@b.c"
    ])
    func signInRejectsMalformedEmails(_ email: String) {
        let errors = AuthValidator.validateSignIn(
            request: SignInRequest(email: email, password: "12345678")
        )

        #expect(errors[.email] == "Please enter a valid email address.")
    }

    @Test func passwordUsesKotlinUTF16Boundary() {
        let sevenUnitErrors = AuthValidator.validateSignIn(
            request: SignInRequest(email: "a@b.co", password: "1234567")
        )
        let eightUnitErrors = AuthValidator.validateSignIn(
            request: SignInRequest(email: "a@b.co", password: "12345678")
        )
        let unicodeEightUnitErrors = AuthValidator.validateSignIn(
            request: SignInRequest(email: "a@b.co", password: "😀😀😀😀")
        )

        #expect(sevenUnitErrors[.password] == "Password must be at least 8 characters.")
        #expect(eightUnitErrors[.password] == nil)
        #expect(unicodeEightUnitErrors[.password] == nil)
    }

    @Test func signupEnforcesNameAndTermsBoundaries() {
        let invalid = AuthValidator.validateSignUp(
            request: SignUpRequest(
                fullName: " A ",
                email: "a@b.co",
                password: "12345678",
                acceptedTerms: false
            )
        )
        let valid = AuthValidator.validateSignUp(
            request: SignUpRequest(
                fullName: " AB ",
                email: "a@b.co",
                password: "12345678",
                acceptedTerms: true
            )
        )

        #expect(invalid[.fullName] == "Please enter your full name.")
        #expect(invalid[.terms] == "Accept the terms to create your account.")
        #expect(valid.isEmpty)
    }

    @Test func signupReturnsAllIndependentErrors() {
        let errors = AuthValidator.validateSignUp(
            request: SignUpRequest(
                fullName: "",
                email: "bad",
                password: "short",
                acceptedTerms: false
            )
        )

        #expect(errors.count == 4)
        #expect(errors[.fullName] == "Please enter your full name.")
        #expect(errors[.email] == "Please enter a valid email address.")
        #expect(errors[.password] == "Password must be at least 8 characters.")
        #expect(errors[.terms] == "Accept the terms to create your account.")
    }

    @Test func passwordResetValidatesEmailOnly() {
        #expect(AuthValidator.validatePasswordReset(email: "a@b.co").isEmpty)
        #expect(
            AuthValidator.validatePasswordReset(email: "bad") == [
                .email: "Please enter a valid email address."
            ]
        )
    }

    @Test func replacementPasswordUsesSameUtf16MinimumAsSignup() {
        #expect(AuthValidator.validateNewPassword("1234567") == "Password must be at least 8 characters.")
        #expect(AuthValidator.validateNewPassword("12345678") == nil)
    }
}
