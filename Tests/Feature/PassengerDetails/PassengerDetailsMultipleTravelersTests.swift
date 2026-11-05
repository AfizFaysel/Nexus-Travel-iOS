import Testing
@testable import NexusTravel

@MainActor
struct PassengerDetailsMultipleTravelersTests {
    @Test func createsFormForEveryTravelerInAndroidOrder() throws {
        let today = try #require(LocalDate(year: 2026, month: 5, day: 28))
        let model = PassengerDetailsViewModel(
            details: try makeDetails(), repository: CapturingPassengerRepository(),
            today: { today }
        )

        #expect(model.passengerTypes == [.adult, .child, .infant])
        #expect(model.forms.count == 3)
        model.forms[1].firstName = "Child"
        #expect(model.forms[0].firstName.isEmpty)
    }

    @Test func invalidSecondTravelerSelectsItsFormBeforeAuthentication() async throws {
        let today = try #require(LocalDate(year: 2026, month: 5, day: 28))
        let model = PassengerDetailsViewModel(
            details: try makeDetails(), repository: CapturingPassengerRepository(),
            today: { today }
        )
        model.forms[0] = validPassengerForm()

        try await model.submit(authenticated: false)

        #expect(model.activePassengerIndex == 1)
        #expect(model.validation.hasErrors)
        #expect(model.consumeNavigationEvent() == nil)
    }

    @Test func submitsEachTravelerWithFirstTravelersContact() async throws {
        let today = try #require(LocalDate(year: 2026, month: 5, day: 28))
        let repository = CapturingPassengerRepository()
        let model = PassengerDetailsViewModel(details: try makeDetails(), repository: repository, today: { today })
        model.forms[0] = validPassengerForm()
        model.forms[1] = validPassengerForm(birthYear: 2018)
        model.forms[2] = validPassengerForm(birthYear: 2025)
        model.forms[1].firstName = "Child"
        model.forms[2].firstName = "Infant"
        model.forms[1].email = ""
        model.forms[2].phoneNumber = ""

        try await model.submit(authenticated: true)

        let request = await repository.request
        #expect(request?.passengers.map(\.passengerType) == [.adult, .child, .infant])
        #expect(request?.passengers.map(\.firstName) == ["Selam", "Child", "Infant"])
        #expect(request?.contact.email == "selam@example.com")
        #expect(request?.contact.phoneNumber == "911234567")
    }

    private func validPassengerForm(birthYear: Int = 1995) -> PassengerDetailsFormState {
        PassengerDetailsFormState(
            firstName: "Selam", lastName: "Tesfaye", dateOfBirth: LocalDate(year: birthYear, month: 1, day: 15),
            dateOfBirthDay: "15", dateOfBirthMonth: "1", dateOfBirthYear: String(birthYear),
            passportNumber: "EP123", passportExpiryDay: "1", passportExpiryMonth: "1",
            passportExpiryYear: "2030", passportExpiryDate: LocalDate(year: 2030, month: 1, day: 1),
            passportDocument: .init(uriString: "content://passport", displayName: "passport.pdf", mimeType: "application/pdf"),
            email: "selam@example.com", phoneNumber: "911234567"
        )
    }
}

private actor CapturingPassengerRepository: PassengerDetailsRepository {
    private(set) var request: SubmitPassengerDetailsRequest?

    func submitPassengerDetails(_ request: SubmitPassengerDetailsRequest) async throws -> PassengerDetailsResult {
        self.request = request
        return .unknownError
    }
}
