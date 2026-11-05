import Foundation

/// A validated verification or password-reset link delivered to the app.
enum AuthLinkRoute: Equatable, Hashable, Identifiable, Sendable {
    case verifyEmail(token: String)
    case resetPassword(token: String)

    var id: String {
        switch self {
        case let .verifyEmail(token): "verify:\(token)"
        case let .resetPassword(token): "reset:\(token)"
        }
    }

    /// Parses only supported HTTPS auth links for the configured API host.
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == AppConfiguration.productionOrigin.host?.lowercased(),
              components.port == nil,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              let items = components.queryItems,
              items.count == 1,
              items[0].name == "token",
              let token = items[0].value,
              Self.accepts(token: token) else {
            return nil
        }
        switch components.percentEncodedPath {
        case "/auth/email/verify": self = .verifyEmail(token: token)
        case "/auth/password/reset": self = .resetPassword(token: token)
        default: return nil
        }
    }

    static func accepts(token: String) -> Bool {
        !token.isEmpty && token.utf8.count <= 1024
            && token.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
            && token.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}
