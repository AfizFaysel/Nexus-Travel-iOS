import Foundation

enum AppConfiguration {
    static let productionOrigin: URL = {
        guard let origin = URL(string: "https://api.travelwithnexus.com") else {
            preconditionFailure("Production API origin must be a valid URL.")
        }

        return origin
    }()

    static let mobileBasePath = "/api/v1/mobile"
    static let healthPath = "/api/v1/health"

    static var origin: URL {
        #if NEXUS_VISUAL_EVIDENCE && targetEnvironment(simulator)
        guard let value = ProcessInfo.processInfo.environment["NEXUS_VISUAL_ORIGIN"],
              let components = URLComponents(string: value),
              components.scheme == "http",
              components.host == "127.0.0.1",
              let port = components.port, (1...65535).contains(port),
              components.user == nil, components.password == nil, components.path.isEmpty,
              components.query == nil, components.fragment == nil,
              let origin = components.url else {
            preconditionFailure("Visual evidence requires a loopback API origin with a port.")
        }
        return origin
        #else
        return productionOrigin
        #endif
    }

    /// Resolves configured or absolute request target without path traversal.
    static func url(
        for target: HTTPRequestTarget,
        queryItems: [URLQueryItem] = [],
        origin: URL = productionOrigin
    ) throws -> URL {
        let url: URL
        switch target {
        case let .absolute(url):
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
                throw HTTPTransportError.invalidRequest
            }
            guard queryItems.isEmpty else { throw HTTPTransportError.invalidRequest }
            return url
        case let .mobile(path):
            url = try configuredURL(origin: origin, prefix: mobileBasePath, path: path)
        case let .root(path):
            url = try configuredURL(origin: origin, prefix: "", path: path)
        }
        guard !queryItems.isEmpty else { return url }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw HTTPTransportError.invalidRequest
        }
        components.queryItems = queryItems
        guard let queriedURL = components.url else { throw HTTPTransportError.invalidRequest }
        return queriedURL
    }

    private static func configuredURL(origin: URL, prefix: String, path: String) throws -> URL {
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        guard !components.contains("..") else { throw HTTPTransportError.invalidRequest }
        let normalizedPath = components.joined(separator: "/")
        let base = origin.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPrefix = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pieces = [base, normalizedPrefix, normalizedPath].filter { !$0.isEmpty }
        guard let url = URL(string: pieces.joined(separator: "/")) else {
            throw HTTPTransportError.invalidRequest
        }
        return url
    }
}
