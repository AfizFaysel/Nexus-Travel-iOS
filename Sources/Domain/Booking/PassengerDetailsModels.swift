import Foundation

/// Passenger intake submission before transport mapping.
struct SubmitPassengerDetailsRequest: Equatable, Hashable, Codable, Sendable {
    let offerReference: FlightOfferReference
    let passengers: [PassengerDetailsDraft]
    let contact: PassengerContactDetails
    let clientSessionId: String
    var bookingId: String?
}

/// Unsubmitted identity and passport details for one passenger.
struct PassengerDetailsDraft: Equatable, Hashable, Codable, Sendable {
    let passengerType: PassengerType
    let title: String
    let gender: String
    let firstName: String
    let lastName: String
    let dateOfBirth: LocalDate?
    let nationalityCountryCode: String
    let passportNumber: String
    let passportExpiryDate: LocalDate?
    let passportIssuingCountryCode: String
    let document: PassengerDocumentAttachment?
    var passportUploadId: String?

    /// First and last names joined when each value is nonblank.
    var fullName: String {
        [firstName, lastName].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
    }
}

/// Persisted booking information required to resume a passenger draft.
struct PassengerResumeDraft: Equatable, Sendable {
    let flightDetails: FlightDetails
    let passengers: [PassengerDetailsDraft]
    let email: String?
    let phone: String?
}

/// Contact details attached to passenger intake.
struct PassengerContactDetails: Equatable, Hashable, Codable, Sendable {
    let email: String
    let countryDialCode: String
    let phoneNumber: String
}

/// Local passenger document selected before signed upload.
struct PassengerDocumentAttachment: Equatable, Hashable, Codable, Sendable {
    let uriString: String
    let displayName: String
    let mimeType: String?
}

/// Traveler age category used by booking intake.
enum PassengerType: String, Equatable, Hashable, Codable, Sendable {
    case adult
    case child
    case infant
}

/// Outcome of submitting passenger details.
enum PassengerDetailsResult: Equatable, Hashable, Sendable {
    case success(reviewId: String, total: Money)
    case validationRejected([PassengerDetailsRejectedField])
    case offerExpired
    case offerUnavailable
    case networkUnavailable
    case authRequired
    case unknownError
}

/// Server-rejected passenger field and its message.
struct PassengerDetailsRejectedField: Equatable, Hashable, Codable, Sendable {
    let field: String
    let message: String
}
