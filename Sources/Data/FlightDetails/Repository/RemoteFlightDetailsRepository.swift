import Foundation

/// Remote adapter for pricing and revalidating selected flight offers.
struct RemoteFlightDetailsRepository: FlightDetailsRepository {
    let transport: HTTPTransport

    func priceOffer(reference: FlightOfferReference) async throws -> FlightDetailsResult {
        do {
            let body = try JSONEncoder().encode(PriceOfferRequestDTO(searchSessionId: reference.searchId, offerId: reference.offerId))
            let response = try await transport.send(HTTPRequest(target: .mobile(FlightDetailsEndpoints.details), method: .post, body: body))
            switch response.statusCode {
            case 200..<300:
                return try FlightDetailsResponseMapper.map(JSONDecoder().decode(PriceOfferResponseDTO.self, from: response.data), reference: reference)
            case 401: return .authRequired
            case 404: return .offerUnavailable
            case 503:
                return errorCode(in: response.data) == "OFFER_UNAVAILABLE" ? .offerUnavailable : .confirmationUnavailable
            case 410: return .offerExpired
            default: return .unknownError
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HTTPTransportError {
            switch error { case .timedOut, .networkUnavailable: return .networkUnavailable; default: return .unknownError }
        } catch {
            return .unknownError
        }
    }

    private func errorCode(in data: Data) -> String? {
        (try? JSONDecoder().decode(FlightDetailsErrorResponse.self, from: data))?.code
    }
}

private struct FlightDetailsErrorResponse: Decodable { let code: String }
