import Foundation

/// HTTP verb supported by Nexus API requests.
enum HTTPMethod: String, Equatable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Location used to construct a request URL.
enum HTTPRequestTarget: Equatable, Sendable {
    case mobile(String)
    case root(String)
    case absolute(URL)
}

/// Optional request authorization behavior.
enum HTTPAuthorization: Equatable, Sendable {
    case none
    case bearer(String)
}

/// Complete input for one HTTP operation.
struct HTTPRequest: Equatable, Sendable {
    let target: HTTPRequestTarget
    let queryItems: [URLQueryItem]
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let authorization: HTTPAuthorization
    let timeout: TimeInterval

    /// Creates a request with safe JSON defaults.
    init(target: HTTPRequestTarget, queryItems: [URLQueryItem] = [], method: HTTPMethod = .get,
         headers: [String: String] = [:], body: Data? = nil,
         authorization: HTTPAuthorization = .none, timeout: TimeInterval = 30) {
        self.target = target
        self.queryItems = queryItems
        self.method = method
        self.headers = headers
        self.body = body
        self.authorization = authorization
        self.timeout = timeout
    }

    /// Builds native request while protecting authorization headers.
    func urlRequest(origin: URL = AppConfiguration.productionOrigin) throws -> URLRequest {
        guard timeout > 0 else { throw HTTPTransportError.invalidRequest }
        let url = try AppConfiguration.url(for: target, queryItems: queryItems, origin: origin)
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpShouldHandleCookies = false
        request.httpMethod = method.rawValue
        request.httpBody = body
        for (name, value) in headers where name.caseInsensitiveCompare("Authorization") != .orderedSame {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        if body != nil, request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        switch authorization {
        case .none:
            request.setValue(nil, forHTTPHeaderField: "Authorization")
        case let .bearer(token):
            guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HTTPTransportError.invalidRequest
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
