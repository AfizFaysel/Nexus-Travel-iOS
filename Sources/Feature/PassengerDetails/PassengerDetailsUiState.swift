/// Editable passenger and contact form values.
struct PassengerDetailsFormState: Equatable, Hashable, Sendable {
    var title: String
    var gender: String
    var firstName: String
    var lastName: String
    var dateOfBirth: LocalDate?
    var dateOfBirthDay: String
    var dateOfBirthMonth: String
    var dateOfBirthYear: String
    var nationalityCountryCode: String
    var nationalityLabel: String
    var passportNumber: String
    var passportExpiryDay: String
    var passportExpiryMonth: String
    var passportExpiryYear: String
    var passportExpiryDate: LocalDate?
    var passportIssuingCountryCode: String
    var passportIssuingCountryLabel: String
    var passportDocument: PassengerDocumentAttachment?
    var passportUploadId: String?
    var email: String
    var countryDialCode: String
    var phoneCountryCode: String
    var phoneCountryLabel: String
    var phoneNumber: String
    var isPassportIssuingCountryEthiopia: Bool
    var isNationalityEthiopian: Bool

    /// Creates form using Android passenger-intake defaults.
    init(
        title: String = "Mr", gender: String = "Male", firstName: String = "", lastName: String = "",
        dateOfBirth: LocalDate? = nil, dateOfBirthDay: String = "", dateOfBirthMonth: String = "",
        dateOfBirthYear: String = "", nationalityCountryCode: String = "ET",
        nationalityLabel: String = "Ethiopian", passportNumber: String = "",
        passportExpiryDay: String = "", passportExpiryMonth: String = "", passportExpiryYear: String = "",
        passportExpiryDate: LocalDate? = nil, passportIssuingCountryCode: String = "ET",
        passportIssuingCountryLabel: String = "Ethiopia", passportDocument: PassengerDocumentAttachment? = nil,
        email: String = "", countryDialCode: String = "+251", phoneCountryCode: String = "ET",
        phoneCountryLabel: String = "Ethiopia", phoneNumber: String = "",
        isPassportIssuingCountryEthiopia: Bool = true, isNationalityEthiopian: Bool = true
    ) {
        self.title = title; self.gender = gender; self.firstName = firstName; self.lastName = lastName
        self.dateOfBirth = dateOfBirth; self.dateOfBirthDay = dateOfBirthDay
        self.dateOfBirthMonth = dateOfBirthMonth; self.dateOfBirthYear = dateOfBirthYear
        self.nationalityCountryCode = nationalityCountryCode; self.nationalityLabel = nationalityLabel
        self.passportNumber = passportNumber; self.passportExpiryDay = passportExpiryDay
        self.passportExpiryMonth = passportExpiryMonth; self.passportExpiryYear = passportExpiryYear
        self.passportExpiryDate = passportExpiryDate
        self.passportIssuingCountryCode = passportIssuingCountryCode
        self.passportIssuingCountryLabel = passportIssuingCountryLabel
        self.passportDocument = passportDocument; self.email = email; self.countryDialCode = countryDialCode
        self.phoneCountryCode = phoneCountryCode; self.phoneCountryLabel = phoneCountryLabel
        self.phoneNumber = phoneNumber
        self.isPassportIssuingCountryEthiopia = isPassportIssuingCountryEthiopia
        self.isNationalityEthiopian = isNationalityEthiopian
    }
}

/// Passenger validation errors grouped for field and summary presentation.
struct PassengerValidationState: Equatable, Sendable {
    let fieldErrors: [PassengerDetailsField: String]
    let dateGroupErrors: [PassengerDateGroup: [String]]
    let summaryErrors: [String]

    /// Creates empty validation state by default.
    init(fieldErrors: [PassengerDetailsField: String] = [:],
         dateGroupErrors: [PassengerDateGroup: [String]] = [:], summaryErrors: [String] = []) {
        self.fieldErrors = fieldErrors
        self.dateGroupErrors = dateGroupErrors
        self.summaryErrors = summaryErrors
    }

    /// Returns error for field.
    func error(for field: PassengerDetailsField) -> String? { fieldErrors[field] }

    /// Returns errors for date group.
    func errors(for group: PassengerDateGroup) -> [String] { dateGroupErrors[group] ?? [] }

    /// Whether any validation error exists.
    var hasErrors: Bool { !fieldErrors.isEmpty || !dateGroupErrors.isEmpty || !summaryErrors.isEmpty }

    /// Returns state without named field and group errors and with cleared summary.
    func removing(fields: Set<PassengerDetailsField>, groups: Set<PassengerDateGroup> = []) -> Self {
        Self(fieldErrors: fieldErrors.filter { !fields.contains($0.key) },
             dateGroupErrors: dateGroupErrors.filter { !groups.contains($0.key) })
    }
}

/// Date input group receiving validation errors.
enum PassengerDateGroup: String, Equatable, Hashable, Codable, Sendable {
    case dateOfBirth
    case passportExpiry
}

/// Passenger form field receiving validation state.
enum PassengerDetailsField: String, CaseIterable, Equatable, Hashable, Codable, Sendable {
    case title, gender, firstName, lastName, dateOfBirth, dateOfBirthDay, dateOfBirthMonth, dateOfBirthYear
    case nationality, passportNumber, passportExpiryDate, passportExpiryDay, passportExpiryMonth
    case passportExpiryYear, passportIssuingCountry, passportDocument, email, phoneCountry, phoneNumber
}
