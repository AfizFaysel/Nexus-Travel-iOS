/// Better Auth routes exposed from API root.
enum AuthEndpoints {
    static let signInEmail = "/api/auth/sign-in/email"
    static let signUpEmail = "/api/auth/sign-up/email"
    static let session = "/api/auth/get-session"
    static let passwordResetRequest = "/api/auth/request-password-reset"
    static let passwordReset = "/api/auth/reset-password"
    static let verifyEmail = "/api/auth/verify-email"
    static let resendVerificationEmail = "/api/auth/send-verification-email"
    static let sendVerificationCode = "/api/auth/email-otp/send-verification-otp"
    static let verifyEmailCode = "/api/auth/email-otp/verify-email"
    static let requestPasswordResetCode = "/api/auth/email-otp/request-password-reset"
    static let resetPasswordCode = "/api/auth/email-otp/reset-password"
    static let signOut = "/api/auth/sign-out"
}
