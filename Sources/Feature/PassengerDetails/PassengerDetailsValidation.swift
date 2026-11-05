import Foundation

/// Validates passenger form fields against travel and current dates.
enum PassengerDetailsValidator {
    static func validate(form: PassengerDetailsFormState, details: FlightDetails,
                         includeContact: Bool = true, passengerType: PassengerType = .adult,
                         today: LocalDate) -> PassengerValidationState {
        validateFields(form: form, details: details, fields: Set(PassengerDetailsField.allCases),
                       isSubmit: true, includeContact: includeContact, passengerType: passengerType, today: today)
    }

    static func validateFields(
        form: PassengerDetailsFormState, details: FlightDetails, fields: Set<PassengerDetailsField>,
        isSubmit: Bool = false, includeContact: Bool = true,
        passengerType: PassengerType = .adult, today: LocalDate
    ) -> PassengerValidationState {
        var fieldErrors: [PassengerDetailsField: String] = [:]
        var fieldMessages: [String] = []
        var groupErrors: [PassengerDateGroup: [String]] = [:]

        func addField(_ field: PassengerDetailsField, _ message: String) {
            fieldErrors[field] = message
            fieldMessages.append(message)
        }
        let required: [(PassengerDetailsField, String, String)] = [
            (.title, form.title, "Title is required."), (.gender, form.gender, "Gender is required."),
            (.firstName, form.firstName, "First name is required."),
            (.lastName, form.lastName, "Last name is required."),
            (.nationality, form.nationalityCountryCode, "Nationality is required."),
            (.passportNumber, form.passportNumber, "Passport number is required."),
            (.passportIssuingCountry, form.passportIssuingCountryCode, "Passport issuing country is required.")
        ]
        for (field, value, message) in required where fields.contains(field) && value.isBlank {
            addField(field, message)
        }

        let birth = validateDate(
            input: form.dateOfBirthInput(), touchedFields: fields, isSubmit: isSubmit,
            dayField: .dateOfBirthDay, monthField: .dateOfBirthMonth, yearField: .dateOfBirthYear,
            groupField: .dateOfBirth, requiredMessage: "Date of birth is required."
        ) { date in
            guard let date else { return "Enter a valid date of birth." }
            if date > today { return "Date of birth cannot be in the future." }
            let years = details.departureDate.year - date.year
                - ((details.departureDate.month, details.departureDate.day) < (date.month, date.day) ? 1 : 0)
            switch passengerType {
            case .adult where years < 12: return "Adult must be age 12 or older on departure."
            case .child where !(2...11).contains(years): return "Child must be age 2–11 on departure."
            case .infant where !(0...1).contains(years): return "Infant must be under age 2 on departure."
            default: return nil
            }
        }
        birth.fieldErrors.forEach { fieldErrors[$0.key] = $0.value }
        fieldMessages.append(contentsOf: birth.fieldMessages)
        if !birth.groupErrors.isEmpty { groupErrors[.dateOfBirth] = birth.groupErrors }

        let expiry = validateDate(
            input: form.passportExpiryInput(), touchedFields: fields, isSubmit: isSubmit,
            dayField: .passportExpiryDay, monthField: .passportExpiryMonth, yearField: .passportExpiryYear,
            groupField: .passportExpiryDate, requiredMessage: "Passport expiry date is required."
        ) { date in
            guard let date else { return "Enter a valid passport expiry date." }
            if date < today { return "Passport expiry date cannot be in the past." }
            if date <= details.departureDate { return "Passport expiry date must be after travel date." }
            return nil
        }
        expiry.fieldErrors.forEach { fieldErrors[$0.key] = $0.value }
        fieldMessages.append(contentsOf: expiry.fieldMessages)
        if !expiry.groupErrors.isEmpty { groupErrors[.passportExpiry] = expiry.groupErrors }

        if fields.contains(.passportDocument), form.passportDocument == nil {
            addField(.passportDocument, "Passport document is required.")
        }
        if includeContact, fields.contains(.email), let message = PassengerContactValidator.emailError(form.email) {
            addField(.email, message)
        }
        if includeContact, fields.contains(.phoneCountry), form.countryDialCode.isBlank {
            addField(.phoneCountry, "Select phone country code.")
        }
        if includeContact, fields.contains(.phoneNumber),
           let message = PassengerContactValidator.phoneError(dialCode: form.countryDialCode, value: form.phoneNumber) {
            addField(.phoneNumber, message)
        }

        let groupMessages = [PassengerDateGroup.dateOfBirth, .passportExpiry]
            .flatMap { groupErrors[$0] ?? [] }
        return PassengerValidationState(fieldErrors: fieldErrors, dateGroupErrors: groupErrors,
                                        summaryErrors: (fieldMessages + groupMessages).stableUnique)
    }

    private static func validateDate(
        input: PassengerDateInput, touchedFields: Set<PassengerDetailsField>, isSubmit: Bool,
        dayField: PassengerDetailsField, monthField: PassengerDetailsField,
        yearField: PassengerDetailsField, groupField: PassengerDetailsField,
        requiredMessage: String, validateCombined: (LocalDate?) -> String?
    ) -> DateValidationResult {
        var result = DateValidationResult()
        func checkPart(_ field: PassengerDetailsField, value: String, maximum: Int, label: String) {
            guard isSubmit || touchedFields.contains(field) else { return }
            let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
            let message: String?
            if value.isBlank {
                message = "\(label) is required."
            } else if let number, (1...maximum).contains(number) {
                message = nil
            } else {
                message = "\(label) is incorrect."
            }
            if let message { result.add(field: field, message: message) }
        }
        checkPart(dayField, value: input.day, maximum: 31, label: "Day")
        checkPart(monthField, value: input.month, maximum: 12, label: "Month")
        if isSubmit || touchedFields.contains(yearField) {
            let message: String?
            if input.year.isBlank {
                message = "Year is required."
            } else if Int(input.year.trimmingCharacters(in: .whitespacesAndNewlines)) == nil || input.year.count != 4 {
                message = "Year is incorrect."
            } else {
                message = nil
            }
            if let message { result.add(field: yearField, message: message) }
        }
        let shouldCombine = isSubmit || touchedFields.contains(groupField) || input.complete
        if shouldCombine {
            if isSubmit, !input.complete, result.groupErrors.isEmpty { result.groupErrors.append(requiredMessage) }
            if input.complete, result.fieldErrors.isEmpty, let message = validateCombined(input.parsed) {
                result.groupErrors.append(message)
            }
        }
        result.groupErrors = result.groupErrors.stableUnique
        return result
    }
}

/// Validates passenger email and phone values.
enum PassengerContactValidator {
    static func emailError(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else { return invalidEmail }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard domain.count >= 2, domain.allSatisfy({ !$0.isEmpty }), (domain.last?.count ?? 0) >= 2,
              !trimmed.contains(".."), !trimmed.contains(where: \.isWhitespace) else { return invalidEmail }
        return nil
    }

    static func phoneError(dialCode: String, value: String) -> String? {
        let digits = value.compactMap(\.wholeNumberValue).map(String.init).joined()
        if dialCode.isBlank { return "Select phone country code." }
        if digits.isEmpty { return "Enter a mobile number." }
        if dialCode == CountryCatalog.defaultDialCode,
           !(digits.count == 9 && digits.first == "9") { return "Enter a valid Ethiopian mobile number." }
        if !(7...15).contains(digits.count) { return "Enter a valid phone number." }
        return nil
    }

    private static let invalidEmail = "Enter a valid email address."
}

private struct DateValidationResult {
    var fieldErrors: [PassengerDetailsField: String] = [:]
    var fieldMessages: [String] = []
    var groupErrors: [String] = []

    mutating func add(field: PassengerDetailsField, message: String) {
        fieldErrors[field] = message
        fieldMessages.append(message)
        groupErrors.append(message)
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

private extension Array where Element: Hashable {
    var stableUnique: [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
