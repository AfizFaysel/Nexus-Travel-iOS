import Foundation
import Testing
@testable import NexusTravel

struct SupportOptionsTests {
    @Test func unsetConfigurationShowsNoDeadLinks() {
        #expect(SupportOptions(values: [:]).destinations.isEmpty)
    }

    @Test func onlyVerifiedChannelURLsAreExposed() {
        let options = SupportOptions(values: [
            "NexusSupportWhatsAppURL": "https://wa.me/251900000000",
            "NexusSupportTelegramURL": "https://example.com/fake-support",
            "NexusSupportEmail": "support@example.com"
        ])
        #expect(options.destinations.map(\.label) == ["WhatsApp", "Email"])
    }
}
