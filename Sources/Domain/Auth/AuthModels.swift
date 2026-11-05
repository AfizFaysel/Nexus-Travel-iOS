import Foundation

/// Authentication data associated with one signed-in app session.
public struct AuthSession: Equatable, Sendable {
    /// Stable session identifier.
    public let sessionId: String
    /// User authenticated by this session.
    public let user: AuthUser
    /// Bearer tokens returned for this session, when available.
    public let tokens: AuthTokenSet?
    /// Time after which this session is no longer usable.
    public let expiresAt: Date

    /// Creates an authentication session.
    public init(sessionId: String, user: AuthUser, tokens: AuthTokenSet?, expiresAt: Date) {
        self.sessionId = sessionId
        self.user = user
        self.tokens = tokens
        self.expiresAt = expiresAt
    }
}

/// Profile data for an authenticated user.
public struct AuthUser: Equatable, Sendable {
    /// Stable user identifier.
    public let id: String
    /// Name shown throughout the app.
    public let displayName: String
    /// User email address.
    public let email: String
    /// Optional remote avatar location.
    public let avatarUrl: String?

    /// Creates an authenticated user profile.
    public init(id: String, displayName: String, email: String, avatarUrl: String?) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.avatarUrl = avatarUrl
    }
}

/// Tokens issued for an authenticated session.
public struct AuthTokenSet: Equatable, Sendable {
    /// Bearer token used for authenticated requests.
    public let accessToken: String
    /// Optional refresh token returned as data without implying refresh support.
    public let refreshToken: String?

    /// Creates an authentication token set.
    public init(accessToken: String, refreshToken: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

/// Credentials submitted for email sign-in.
public struct SignInRequest: Equatable, Sendable {
    /// Email entered by the user.
    public let email: String
    /// Password entered by the user.
    public let password: String

    /// Creates an email sign-in request.
    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// Account details submitted for email sign-up.
public struct SignUpRequest: Equatable, Sendable {
    /// Full name entered by the user.
    public let fullName: String
    /// Email entered by the user.
    public let email: String
    /// Password entered by the user.
    public let password: String
    /// Whether required terms were accepted.
    public let acceptedTerms: Bool

    /// Creates an email sign-up request.
    public init(fullName: String, email: String, password: String, acceptedTerms: Bool) {
        self.fullName = fullName
        self.email = email
        self.password = password
        self.acceptedTerms = acceptedTerms
    }
}

/// User-input fields that can receive authentication validation errors.
public enum AuthField: Equatable, Hashable, Sendable {
    /// Full-name input.
    case fullName
    /// Email input.
    case email
    /// Password input.
    case password
    /// Password-confirmation input.
    case confirmPassword
    /// Terms-acceptance input.
    case terms
}

/// Domain failures produced by supported email authentication flows.
public enum AuthError: Equatable, Sendable {
    /// One or more fields failed local or server validation.
    case validation([AuthField: String])
    /// Submitted credentials were rejected.
    case invalidCredentials
    /// Submitted email already belongs to an account.
    case emailAlreadyUsed
    /// Account email must be verified before authentication can continue.
    case emailNotVerified
    /// Authentication could not reach the service.
    case networkUnavailable
    /// Authentication attempts exceeded the allowed rate.
    case rateLimited
    /// Submitted email code does not match.
    case invalidCode
    /// Submitted email code has expired.
    case expiredCode
    /// Submitted email code has exhausted allowed attempts.
    case tooManyCodeAttempts
    /// No authenticated session exists.
    case unauthenticated
    /// Existing authentication session expired.
    case sessionExpired
    /// Authentication failed for an unclassified reason.
    case unknown
}
