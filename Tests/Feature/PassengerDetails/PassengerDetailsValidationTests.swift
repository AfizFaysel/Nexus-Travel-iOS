import Testing
@testable import NexusTravel

struct PassengerDetailsValidationTests {
    @Test func formDefaultsMatchAndroid() {
        let form = PassengerDetailsFormState()
        #expect(form.title == "Mr" && form.gender == "Male")
        #expect(form.firstName.isEmpty && form.lastName.isEmpty)
        #expect(form.dateOfBirth == nil && form.dateOfBirthDay.isEmpty)
        #expect(form.nationalityCountryCode == "ET" && form.nationalityLabel == "Ethiopian")
        #expect(form.passportIssuingCountryCode == "ET" && form.passportIssuingCountryLabel == "Ethiopia")
        #expect(form.countryDialCode == "+251" && form.phoneCountryCode == "ET")
        #expect(form.isPassportIssuingCountryEthiopia && form.isNationalityEthiopian)
    }

    @Test func selectiveDayValidationDoesNotValidateSiblingParts() throws {
        let result = PassengerDetailsValidator.validateFields(
            form: validForm().withDateOfBirth(PassengerDateInput(day: "", month: "1", year: "1995")),
            details: try details(), fields: [.dateOfBirthDay], today: try today()
        )
        #expect(result.error(for: .dateOfBirthDay) == "Day is required.")
        #expect(result.error(for: .dateOfBirthMonth) == nil)
        #expect(result.error(for: .dateOfBirthYear) == nil)
    }

    @Test func completeDatesRunCombinedValidationWithoutSubmit() throws {
        let future = PassengerDateInput(day: "29", month: "5", year: "2026")
        let result = PassengerDetailsValidator.validateFields(
            form: validForm().withDateOfBirth(future), details: try details(), fields: [], today: try today()
        )
        #expect(result.errors(for: .dateOfBirth) == ["Date of birth cannot be in the future."])
    }

    @Test func submitReportsEveryMissingDatePart() throws {
        let result = PassengerDetailsValidator.validate(
            form: validForm().withDateOfBirth(PassengerDateInput(day: "", month: "", year: "")),
            details: try details(), today: try today()
        )
        #expect(result.errors(for: .dateOfBirth) == ["Day is required.", "Month is required.", "Year is required."])
    }

    @Test func dateBoundariesAndPrecedenceMatchAndroid() throws {
        let invalidDOB = validForm().withDateOfBirth(PassengerDateInput(day: "31", month: "2", year: "1995"))
        #expect(PassengerDetailsValidator.validate(form: invalidDOB, details: try details(), today: try today())
            .errors(for: .dateOfBirth) == ["Enter a valid date of birth."])
        let todayDOB = validForm().withDateOfBirth(PassengerDateInput(day: "28", month: "5", year: "2026"))
        #expect(PassengerDetailsValidator.validate(form: todayDOB, details: try details(), today: try today())
            .errors(for: .dateOfBirth) == ["Adult must be age 12 or older on departure."])
        let pastExpiry = validForm().withPassportExpiry(PassengerDateInput(day: "27", month: "5", year: "2026"))
        #expect(PassengerDetailsValidator.validate(form: pastExpiry, details: try details(), today: try today())
            .errors(for: .passportExpiry) == ["Passport expiry date cannot be in the past."])
        let travelExpiry = validForm().withPassportExpiry(PassengerDateInput(day: "1", month: "6", year: "2026"))
        #expect(PassengerDetailsValidator.validate(form: travelExpiry, details: try details(), today: try today())
            .errors(for: .passportExpiry) == ["Passport expiry date must be after travel date."])
    }

    @Test func requiredTextMessages() throws {
        let expected: [(PassengerDetailsField, String)] = [
            (.title, "Title is required."), (.gender, "Gender is required."),
            (.firstName, "First name is required."), (.lastName, "Last name is required."),
            (.nationality, "Nationality is required."), (.passportNumber, "Passport number is required."),
            (.passportIssuingCountry, "Passport issuing country is required.")
        ]
        for (field, message) in expected {
            let result = PassengerDetailsValidator.validateFields(
                form: formWithBlank(field), details: try details(), fields: [field], today: try today()
            )
            #expect(result.error(for: field) == message)
        }
    }

    @Test func passportDocumentIsRequired() throws {
        let result = PassengerDetailsValidator.validateFields(
            form: validForm(passportDocument: nil), details: try details(), fields: [.passportDocument], today: try today()
        )
        #expect(result.error(for: .passportDocument) == "Passport document is required.")
    }

    @Test func validFormHasNoErrors() throws {
        #expect(!PassengerDetailsValidator.validate(form: validForm(), details: try details(), today: try today()).hasErrors)
    }

    @Test(arguments: ["selam@example.com", " selam@example.com "])
    func acceptsValidEmails(_ email: String) {
        #expect(PassengerContactValidator.emailError(email) == nil)
    }

    @Test(arguments: ["", "selam", "a@@b.com", "@b.com", "a@", "a@b", "a@b..com", "a@b.c", "a @b.com"])
    func rejectsInvalidEmails(_ email: String) {
        #expect(PassengerContactValidator.emailError(email) == "Enter a valid email address.")
    }

    @Test func phoneValidationMatchesDialCodePrecedence() {
        #expect(PassengerContactValidator.phoneError(dialCode: "+251", value: "911 234 567") == nil)
        #expect(PassengerContactValidator.phoneError(dialCode: "+251", value: "123456789") == "Enter a valid Ethiopian mobile number.")
        #expect(PassengerContactValidator.phoneError(dialCode: "", value: "") == "Select phone country code.")
        #expect(PassengerContactValidator.phoneError(dialCode: "+1", value: "") == "Enter a mobile number.")
        #expect(PassengerContactValidator.phoneError(dialCode: "+1", value: "1234567") == nil)
        #expect(PassengerContactValidator.phoneError(dialCode: "+1", value: "123456789012345") == nil)
        #expect(PassengerContactValidator.phoneError(dialCode: "+1", value: "123456") == "Enter a valid phone number.")
        #expect(PassengerContactValidator.phoneError(dialCode: "+1", value: "1234567890123456") == "Enter a valid phone number.")
    }

    @Test func summaryOrderDeduplicationAndRemovalAreStable() throws {
        let result = PassengerDetailsValidator.validateFields(
            form: PassengerDetailsFormState(), details: try details(),
            fields: [.firstName, .lastName, .dateOfBirthDay], today: try today()
        )
        #expect(result.summaryErrors == ["First name is required.", "Last name is required.", "Day is required."])
        let removed = result.removing(fields: [.firstName], groups: [.dateOfBirth])
        #expect(removed.error(for: .firstName) == nil)
        #expect(removed.errors(for: .dateOfBirth).isEmpty)
        #expect(removed.summaryErrors.isEmpty)
    }

    @Test func countryCatalogDefaultsAndFallbacksMatchAndroid() {
        #expect(CountryCatalog.defaultCountry.isoCode == "ET")
        #expect(CountryCatalog.countries.first?.isoCode == "ET")
        #expect(CountryCatalog.byIsoCode("ke").dialCode == "+254")
        #expect(CountryCatalog.byCountryName("ethiopian").isoCode == "ET")
        #expect(CountryCatalog.byIsoCode("unknown") == CountryCatalog.defaultCountry)
        #expect(CountryCatalog.selectedIndex(options: CountryCatalog.countries, selectedIsoCode: "ET") == 0)
    }

    private func validForm(
        title: String = "Mr", gender: String = "Male", firstName: String = "Selam",
        lastName: String = "Tesfaye", nationalityCountryCode: String = "ET",
        passportNumber: String = "EP123", passportIssuingCountryCode: String = "ET",
        passportDocument: PassengerDocumentAttachment? = .init(
        uriString: "content://passport", displayName: "passport.pdf", mimeType: "application/pdf"
        )
    ) -> PassengerDetailsFormState {
        PassengerDetailsFormState(
            title: title, gender: gender, firstName: firstName, lastName: lastName,
            dateOfBirth: LocalDate(year: 1995, month: 1, day: 15),
            dateOfBirthDay: "15", dateOfBirthMonth: "1", dateOfBirthYear: "1995",
            nationalityCountryCode: nationalityCountryCode, passportNumber: passportNumber,
            passportExpiryDay: "1", passportExpiryMonth: "1",
            passportExpiryYear: "2030", passportExpiryDate: LocalDate(year: 2030, month: 1, day: 1),
            passportIssuingCountryCode: passportIssuingCountryCode,
            passportDocument: passportDocument, email: "selam@example.com", phoneNumber: "911234567"
        )
    }

    private func formWithBlank(_ field: PassengerDetailsField) -> PassengerDetailsFormState {
        switch field {
        case .title: return validForm(title: "")
        case .gender: return validForm(gender: "")
        case .firstName: return validForm(firstName: "")
        case .lastName: return validForm(lastName: "")
        case .nationality: return validForm(nationalityCountryCode: "")
        case .passportNumber: return validForm(passportNumber: "")
        case .passportIssuingCountry: return validForm(passportIssuingCountryCode: "")
        default: return validForm()
        }
    }

    private func details() throws -> FlightDetails {
        try makeDetails()
    }

    private func today() throws -> LocalDate {
        try #require(LocalDate(year: 2026, month: 5, day: 28))
    }
}
