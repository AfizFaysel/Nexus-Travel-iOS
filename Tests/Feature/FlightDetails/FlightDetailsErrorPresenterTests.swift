import Testing
@testable import NexusTravel

struct FlightDetailsErrorPresenterTests {
    @Test func successfulResultsHaveNoError() throws {
        let details = try makeDetails()
        #expect(FlightDetailsErrorPresenter.present(result: .success(details: details)) == nil)
        #expect(FlightDetailsErrorPresenter.present(result: .priceChanged(previousTotal: details.price, updatedDetails: details)) == nil)
    }

    @Test func mapsEveryFailureToExactCopyAndAction() {
        let cases: [(FlightDetailsResult, FlightDetailsErrorUi)] = [
            (.networkUnavailable, FlightDetailsErrorUi(title: "Connection lost", message: "Check your network and retry.", primaryAction: .retry)),
            (.confirmationUnavailable, FlightDetailsErrorUi(title: "Fare not confirmed", message: "We couldn’t confirm this fare. Try again.", primaryAction: .retry)),
            (.unknownError, FlightDetailsErrorUi(title: "Could not load flight details", message: "Try again.", primaryAction: .retry)),
            (.offerExpired, FlightDetailsErrorUi(title: "Fare expired", message: "This fare expired. Choose another flight.", primaryAction: .chooseAnotherFlight)),
            (.offerUnavailable, FlightDetailsErrorUi(title: "Fare unavailable", message: "This fare is no longer available. Choose another flight.", primaryAction: .chooseAnotherFlight)),
            (.authRequired, FlightDetailsErrorUi(title: "Sign in again", message: "Sign in again to continue.", primaryAction: .signInAgain))
        ]
        for (result, expected) in cases {
            #expect(FlightDetailsErrorPresenter.present(result: result) == expected)
            #expect(expected.secondaryAction == nil)
        }
    }
}
