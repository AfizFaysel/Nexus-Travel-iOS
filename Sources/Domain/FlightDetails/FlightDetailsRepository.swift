/// Prices one selected flight offer.
protocol FlightDetailsRepository: Sendable {
    /// Returns current pricing result for offer reference.
    func priceOffer(reference: FlightOfferReference) async throws -> FlightDetailsResult
}

/// Outcome of pricing selected flight offer.
enum FlightDetailsResult: Equatable, Sendable {
    case success(details: FlightDetails)
    case priceChanged(previousTotal: Money, updatedDetails: FlightDetails)
    case offerExpired
    case offerUnavailable
    case networkUnavailable
    case confirmationUnavailable
    case authRequired
    case unknownError
}
