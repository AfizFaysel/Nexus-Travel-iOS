import Testing
@testable import NexusTravel

@MainActor
struct BookingFlowStateTests {
    @Test func defaultsMatchAndroid() {
        let state = BookingFlowState()
        #expect(!state.authenticated)
        #expect(state.offerReference == nil)
        #expect(state.passengerDetails == nil)
        #expect(!state.submitPassengerDetailsAfterAuth)
    }

    @Test func selectingOfferStartsFlowAndReplacementClearsDownstreamState() throws {
        let first = try makeDetails()
        let second = FlightOfferReference(
            searchId: "search-2",
            offerId: "offer-2",
            offerToken: "token-2",
            provider: .nexusFake,
            contentSource: nil,
            responseId: nil,
            productIds: [],
            termsAndConditionsId: nil,
            brandRef: nil,
            expiresAt: nil
        )
        let state = BookingFlowState()
        state.selectOffer(first.reference)
        #expect(state.acceptPassengerDetails(first))

        state.selectOffer(second)

        #expect(state.offerReference == second)
        #expect(state.passengerDetails == nil)
        #expect(!state.submitPassengerDetailsAfterAuth)
    }

    @Test func passengerDetailsRequireMatchingSelectedOffer() throws {
        let details = try makeDetails()
        let state = BookingFlowState()
        #expect(!state.acceptPassengerDetails(details))
        state.selectOffer(details.reference)
        #expect(state.acceptPassengerDetails(details))
        #expect(state.passengerDetails == details)
    }

    @Test func unauthenticatedSubmitRequestsAuthAndResumesOnce() throws {
        let details = try makeDetails()
        let state = BookingFlowState()
        state.selectOffer(details.reference)
        #expect(state.acceptPassengerDetails(details))

        #expect(state.beginPassengerSubmission() == .authenticate)
        #expect(!state.submitPassengerDetailsAfterAuth)
        #expect(state.completeAuthentication())
        #expect(state.authenticated)
        #expect(state.submitPassengerDetailsAfterAuth)
        #expect(!state.completeAuthentication())
        #expect(state.consumePassengerSubmissionAfterAuthentication())
        #expect(!state.submitPassengerDetailsAfterAuth)
        #expect(!state.consumePassengerSubmissionAfterAuthentication())
    }

    @Test func passengerAuthenticationRequestPreservesSubmissionForResume() throws {
        let details = try makeDetails()
        let state = BookingFlowState()
        state.selectOffer(details.reference)
        #expect(state.acceptPassengerDetails(details))
        #expect(state.beginPassengerSubmission() == .authenticate)

        state.preparePassengerSubmissionAuthentication()

        #expect(state.passengerDetails == details)
        #expect(state.completeAuthentication())
        #expect(state.consumePassengerSubmissionAfterAuthentication())
        #expect(!state.consumePassengerSubmissionAfterAuthentication())
    }

    @Test func authenticatedSubmitContinuesWithoutAuth() throws {
        let details = try makeDetails()
        let state = BookingFlowState(authenticated: true)
        state.selectOffer(details.reference)
        #expect(state.acceptPassengerDetails(details))
        #expect(state.beginPassengerSubmission() == .submit)
        #expect(!state.submitPassengerDetailsAfterAuth)
    }

    @Test func submissionWithoutPassengerDetailsIsUnavailable() throws {
        let state = BookingFlowState(authenticated: true)
        state.selectOffer(try makeDetails().reference)
        #expect(state.beginPassengerSubmission() == .unavailable)
    }

    @Test func clearPreservesAuthenticationAndRemovesBookingData() throws {
        let details = try makeDetails()
        let state = BookingFlowState()
        state.selectOffer(details.reference)
        #expect(state.acceptPassengerDetails(details))
        #expect(state.beginPassengerSubmission() == .authenticate)
        _ = state.completeAuthentication()

        state.clear()

        #expect(state.authenticated)
        #expect(state.offerReference == nil)
        #expect(state.passengerDetails == nil)
        #expect(!state.submitPassengerDetailsAfterAuth)
    }

    @Test func logoutRequiresAuthenticationAgainWithoutDiscardingBookingData() throws {
        let details = try makeDetails()
        let state = BookingFlowState(authenticated: true)
        state.selectOffer(details.reference)
        #expect(state.acceptPassengerDetails(details))

        state.completeLogout()

        #expect(!state.authenticated)
        #expect(state.passengerDetails == details)
        #expect(state.beginPassengerSubmission() == .authenticate)
    }
}
