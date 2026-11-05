import Foundation
import Testing
@testable import NexusTravel

struct AuthLinkRouteTests {
    @Test(arguments: [
        ("https://api.travelwithnexus.com/auth/email/verify?token=opaque-token", AuthLinkRoute.verifyEmail(token: "opaque-token")),
        ("https://api.travelwithnexus.com/auth/password/reset?token=opaque-token", AuthLinkRoute.resetPassword(token: "opaque-token"))
    ])
    func acceptsConfiguredAuthLinks(_ input: (String, AuthLinkRoute)) throws {
        let url = try #require(URL(string: input.0))
        #expect(AuthLinkRoute(url: url) == input.1)
    }

    @Test(arguments: [
        "http://api.travelwithnexus.com/auth/email/verify?token=x",
        "https://evil.example/auth/email/verify?token=x",
        "https://api.travelwithnexus.com/auth/other?token=x",
        "https://api.travelwithnexus.com/auth/email/verify?token=x&token=y",
        "https://api.travelwithnexus.com/auth/email/verify",
        "https://api.travelwithnexus.com/auth/email/verify?token=%20",
        "https://api.travelwithnexus.com/auth/email/verify?token=%00",
        "https://api.travelwithnexus.com:443/auth/email/verify?token=opaque-token"
    ])
    func rejectsMalformedOrUntrustedLinks(_ input: String) throws {
        let url = try #require(URL(string: input))
        #expect(AuthLinkRoute(url: url) == nil)
    }
}
