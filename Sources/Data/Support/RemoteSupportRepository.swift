import Foundation

struct SupportContact: Identifiable {
    enum Kind: String, Hashable {
        case call = "Call"
        case whatsApp = "WhatsApp"
        case email = "Email"
    }

    let kind: Kind
    let detail: String
    let url: URL

    var id: Kind { kind }
}

@MainActor
struct RemoteSupportRepository {
    private static let cacheKey = "nexus.support-contacts"
    private let transport: HTTPTransport
    private let defaults: UserDefaults

    init(transport: HTTPTransport, defaults: UserDefaults = .standard) {
        self.transport = transport
        self.defaults = defaults
    }

    func cached() -> [SupportContact] {
        guard let data = defaults.data(forKey: Self.cacheKey) else { return [] }
        return (try? JSONDecoder().decode(SupportContactsDTO.self, from: data))?.options ?? []
    }

    func refresh() async throws -> [SupportContact] {
        let response = try await transport.send(HTTPRequest(target: .mobile("support")))
        try Task.checkCancellation()
        guard (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let contacts = try JSONDecoder().decode(SupportContactsDTO.self, from: response.data)
        defaults.set(response.data, forKey: Self.cacheKey)
        return contacts.options
    }
}

private struct SupportContactsDTO: Decodable {
    let phoneNumber: String?
    let whatsappNumber: String?
    let emailAddress: String?

    var options: [SupportContact] {
        var options: [SupportContact] = []
        if let phone = validPhone(phoneNumber), let url = URL(string: "tel:\(phone)") {
            options.append(SupportContact(kind: .call, detail: phone, url: url))
        }
        if let phone = validPhone(whatsappNumber), let url = URL(string: "https://wa.me/\(phone.dropFirst())") {
            options.append(SupportContact(kind: .whatsApp, detail: phone, url: url))
        }
        if let emailAddress,
           emailAddress.range(of: #"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#,
                              options: .regularExpression) != nil {
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = emailAddress
            if let url = components.url {
                options.append(SupportContact(kind: .email, detail: emailAddress, url: url))
            }
        }
        return options
    }

    private func validPhone(_ value: String?) -> String? {
        guard let value, value.range(of: #"^\+[1-9]\d{6,14}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return value
    }
}
