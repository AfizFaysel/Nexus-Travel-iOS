import Observation

enum BookingPassengerSubmissionTransition: Equatable, Sendable {
    case unavailable
    case authenticate
    case submit
}

@MainActor
@Observable
final class BookingFlowState {
    private(set) var authenticated: Bool
    private(set) var offerReference: FlightOfferReference?
    private(set) var passengerDetails: FlightDetails?
    private(set) var submitPassengerDetailsAfterAuth = false

    private var awaitsAuthenticationForPassengerSubmission = false

    init(authenticated: Bool = false) {
        self.authenticated = authenticated
    }

    func selectOffer(_ reference: FlightOfferReference) {
        guard offerReference != reference else { return }
        offerReference = reference
        passengerDetails = nil
        submitPassengerDetailsAfterAuth = false
        awaitsAuthenticationForPassengerSubmission = false
    }

    @discardableResult
    func acceptPassengerDetails(_ details: FlightDetails) -> Bool {
        guard details.reference == offerReference else { return false }
        passengerDetails = details
        submitPassengerDetailsAfterAuth = false
        awaitsAuthenticationForPassengerSubmission = false
        return true
    }

    func beginPassengerSubmission() -> BookingPassengerSubmissionTransition {
        guard passengerDetails != nil else { return .unavailable }
        guard !authenticated else { return .submit }
        awaitsAuthenticationForPassengerSubmission = true
        return .authenticate
    }

    func preparePassengerSubmissionAuthentication() {
        authenticated = false
        submitPassengerDetailsAfterAuth = false
        awaitsAuthenticationForPassengerSubmission = true
    }

    @discardableResult
    func completeAuthentication() -> Bool {
        authenticated = true
        guard awaitsAuthenticationForPassengerSubmission else { return false }
        awaitsAuthenticationForPassengerSubmission = false
        submitPassengerDetailsAfterAuth = true
        return true
    }

    func completeLogout() {
        authenticated = false
        submitPassengerDetailsAfterAuth = false
        awaitsAuthenticationForPassengerSubmission = false
    }

    func consumePassengerSubmissionAfterAuthentication() -> Bool {
        guard submitPassengerDetailsAfterAuth else { return false }
        submitPassengerDetailsAfterAuth = false
        return true
    }

    func clear() {
        offerReference = nil
        passengerDetails = nil
        submitPassengerDetailsAfterAuth = false
        awaitsAuthenticationForPassengerSubmission = false
    }
}
