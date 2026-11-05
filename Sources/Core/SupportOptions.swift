import Foundation
import SwiftUI

struct SupportDestination: Equatable {
    let label: String
    let url: URL
}

struct SupportOptions {
    let destinations: [SupportDestination]

    init(values: [String: String]) {
        var links: [SupportDestination] = []
        for (key, label, host) in [
            ("NexusSupportWhatsAppURL", "WhatsApp", "wa.me"),
            ("NexusSupportTelegramURL", "Telegram", "t.me")
        ] {
            if let raw = values[key], let url = URL(string: raw),
               url.scheme == "https", url.host?.lowercased() == host {
                links.append(.init(label: label, url: url))
            }
        }
        if let email = values["NexusSupportEmail"],
           email.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil,
           let url = URL(string: "mailto:\(email)") {
            links.append(.init(label: "Email", url: url))
        }
        destinations = links
    }

    static var configured: SupportOptions {
        let keys = ["NexusSupportWhatsAppURL", "NexusSupportTelegramURL", "NexusSupportEmail"]
        return SupportOptions(values: Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            (Bundle.main.object(forInfoDictionaryKey: key) as? String).map { (key, $0) }
        }))
    }
}

struct SupportOptionsView: View {
    let bookingId: String
    private let options = SupportOptions.configured

    init(bookingId: String) { self.bookingId = bookingId }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space8) {
            Text("Booking ID: \(bookingId)")
                .textSelection(.enabled)
            if options.destinations.isEmpty {
                Text("Support channels are being set up. You can still check your booking status here.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Support options").font(.headline)
                ForEach(options.destinations, id: \.label) { destination in
                    Link(destination.label, destination: destination.url)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
