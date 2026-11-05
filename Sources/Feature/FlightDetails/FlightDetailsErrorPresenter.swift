/// Display copy and actions for flight-details failure.
struct FlightDetailsErrorUi: Equatable, Sendable {
    let title: String
    let message: String
    let primaryAction: FlightDetailsErrorAction
    let secondaryAction: FlightDetailsErrorAction?

    /// Creates error display with no secondary action by default.
    init(title: String, message: String, primaryAction: FlightDetailsErrorAction,
         secondaryAction: FlightDetailsErrorAction? = nil) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
}

/// Action offered for flight-details failure.
enum FlightDetailsErrorAction: Equatable, Sendable {
    case retry
    case chooseAnotherFlight
    case signInAgain
    case none
}

/// Maps repository outcomes to flight-details error copy.
enum FlightDetailsErrorPresenter {
    /// Returns matching failure presentation or nil for usable details.
    static func present(result: FlightDetailsResult) -> FlightDetailsErrorUi? {
        switch result {
        case .success, .priceChanged:
            nil
        case .networkUnavailable:
            FlightDetailsErrorUi(title: "Connection lost", message: "Check your network and retry.", primaryAction: .retry)
        case .confirmationUnavailable:
            FlightDetailsErrorUi(title: "Fare not confirmed", message: "We couldn’t confirm this fare. Try again.", primaryAction: .retry)
        case .unknownError:
            FlightDetailsErrorUi(title: "Could not load flight details", message: "Try again.", primaryAction: .retry)
        case .offerExpired:
            FlightDetailsErrorUi(title: "Fare expired", message: "This fare expired. Choose another flight.", primaryAction: .chooseAnotherFlight)
        case .offerUnavailable:
            FlightDetailsErrorUi(title: "Fare unavailable", message: "This fare is no longer available. Choose another flight.", primaryAction: .chooseAnotherFlight)
        case .authRequired:
            FlightDetailsErrorUi(title: "Sign in again", message: "Sign in again to continue.", primaryAction: .signInAgain)
        }
    }
}
