import Foundation
import OSLog

/// Raw HTTP response retained for repository-specific status mapping.
struct HTTPResponse: Equatable, Sendable {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
}

/// Failures shared across HTTP operations before domain mapping.
enum HTTPTransportError: Error, Equatable, Sendable {
    case invalidRequest
    case timedOut
    case networkUnavailable
    case nonHTTPResponse
}

/// Minimal async loading seam implemented by URLSession and deterministic tests.
protocol HTTPDataLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Native URLSession data loader.
struct URLSessionHTTPDataLoader: HTTPDataLoading {
    let session: URLSession

    /// Creates loader using provided native session.
    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// Executes requests and classifies transport-level failures.
struct HTTPTransport: Sendable {
    private let loader: any HTTPDataLoading
    private let origin: URL
    private let logger = Logger(subsystem: "com.nexustravel.NexusTravel", category: "HTTP")

    /// Creates transport using native URLSession loader by default.
    init(
        origin: URL = AppConfiguration.productionOrigin,
        loader: any HTTPDataLoading = URLSessionHTTPDataLoader()
    ) {
        self.origin = origin
        self.loader = loader
    }

    /// Executes one request while preserving status codes and cancellation.
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let correlationID = UUID().uuidString
        let urlRequest = try request.urlRequest(origin: origin)
        logger.debug("HTTP start correlation=\(correlationID, privacy: .private) method=\(request.method.rawValue, privacy: .public)")
        do {
            let (data, response) = try await loader.data(for: urlRequest)
            guard let response = response as? HTTPURLResponse else {
                throw HTTPTransportError.nonHTTPResponse
            }
            let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
                result[String(describing: item.key).lowercased()] = String(describing: item.value)
            }
            logger.debug("HTTP finish correlation=\(correlationID, privacy: .private) status=\(response.statusCode, privacy: .public)")
            return HTTPResponse(data: data, statusCode: response.statusCode, headers: headers)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw HTTPTransportError.timedOut
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
                 .networkConnectionLost, .internationalRoamingOff, .dataNotAllowed:
                throw HTTPTransportError.networkUnavailable
            default: throw error
            }
        }
    }
}
