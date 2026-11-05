import Foundation

/// Validates email authentication input using Android-compatible rules.
public enum AuthValidator {
    /// Returns field errors for an email sign-in request.
    public static func validateSignIn(request: SignInRequest) -> [AuthField: String] {
        var errors: [AuthField: String] = [:]
        if !isValidEmail(request.email) {
            errors[.email] = invalidEmailMessage
        }
        if request.password.utf16.count < minimumPasswordLength {
            errors[.password] = invalidPasswordMessage
        }
        return errors
    }

    /// Returns field errors for an email sign-up request.
    public static func validateSignUp(request: SignUpRequest) -> [AuthField: String] {
        var errors: [AuthField: String] = [:]
        if request.fullName.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count < 2 {
            errors[.fullName] = "Please enter your full name."
        }
        if !isValidEmail(request.email) {
            errors[.email] = invalidEmailMessage
        }
        if request.password.utf16.count < minimumPasswordLength {
            errors[.password] = invalidPasswordMessage
        }
        if !request.acceptedTerms {
            errors[.terms] = "Accept the terms to create your account."
        }
        return errors
    }

    /// Returns an email field error when password-reset input is invalid.
    public static func validatePasswordReset(email: String) -> [AuthField: String] {
        isValidEmail(email) ? [:] : [.email: invalidEmailMessage]
    }

    /// Returns a password field error when a replacement password is too short.
    public static func validateNewPassword(_ password: String) -> String? {
        password.utf16.count >= minimumPasswordLength ? nil : invalidPasswordMessage
    }

    private static let minimumPasswordLength = 8
    private static let invalidEmailMessage = "Please enter a valid email address."
    private static let invalidPasswordMessage = "Password must be at least 8 characters."

    private static func isValidEmail(_ email: String) -> Bool {
        let codeUnits = Array(email.trimmingCharacters(in: .whitespacesAndNewlines).utf16)
        guard
            let atIndex = codeUnits.firstIndex(of: 64),
            let dotIndex = codeUnits.lastIndex(of: 46)
        else {
            return false
        }
        return atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < codeUnits.count - 2
    }
}
