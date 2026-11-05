import Foundation
import Observation

enum PassengerDetailsNavigationEvent: Equatable, Sendable { case back, authenticate, seats(String), editSearch }

@MainActor
@Observable
final class PassengerDetailsViewModel {
    var forms: [PassengerDetailsFormState]
    private(set) var passengerTypes: [PassengerType]
    private(set) var activePassengerIndex = 0
    private(set) var validations: [PassengerValidationState]
    var validation: PassengerValidationState { validations[activePassengerIndex] }
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    let details: FlightDetails
    private let repository: any PassengerDetailsRepository
    private let today: () -> LocalDate
    private let clientSessionId: String
    private var navigationEvents: [PassengerDetailsNavigationEvent] = []

    init(details: FlightDetails, repository: any PassengerDetailsRepository,
         clientSessionId: String = "ios_\(UUID().uuidString)", today: @escaping () -> LocalDate) {
        self.details = details; self.repository = repository; self.clientSessionId = clientSessionId; self.today = today
        let counts = details.travelers
        let types = Array(repeating: PassengerType.adult, count: max(0, counts.adults))
            + Array(repeating: .child, count: max(0, counts.children))
            + Array(repeating: .infant, count: max(0, counts.infants))
        let entries = types.isEmpty ? [.adult] : types
        passengerTypes = entries
        forms = entries.map { _ in PassengerDetailsFormState() }
        validations = entries.map { _ in PassengerValidationState() }
    }

    func selectPassenger(_ index: Int) {
        guard passengerTypes.indices.contains(index) else { return }
        activePassengerIndex = index
    }

    func submit(authenticated: Bool) async throws {
        validations = forms.enumerated().map { index, form in
            PassengerDetailsValidator.validate(form: form, details: details, includeContact: index == 0,
                                               passengerType: passengerTypes[index], today: today())
        }
        if let invalidIndex = validations.firstIndex(where: \.hasErrors) {
            activePassengerIndex = invalidIndex
            return
        }
        guard authenticated else { navigationEvents.append(.authenticate); return }
        isSubmitting = true; errorMessage = nil
        defer { isSubmitting = false }
        let request = SubmitPassengerDetailsRequest(
            offerReference: details.reference,
            passengers: zip(passengerTypes, forms).map { type, form in
                .init(passengerType: type, title: form.title, gender: form.gender,
                               firstName: form.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                               lastName: form.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                               dateOfBirth: form.dateOfBirth, nationalityCountryCode: form.nationalityCountryCode,
                               passportNumber: form.passportNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                               passportExpiryDate: form.passportExpiryDate,
                               passportIssuingCountryCode: form.passportIssuingCountryCode, document: form.passportDocument)
            },
            contact: .init(email: forms[0].email.trimmingCharacters(in: .whitespacesAndNewlines),
                           countryDialCode: forms[0].countryDialCode,
                           phoneNumber: forms[0].phoneNumber.filter(\.isNumber)),
            clientSessionId: clientSessionId
        )
        switch try await repository.submitPassengerDetails(request) {
        case let .success(reviewId, _): navigationEvents.append(.seats(reviewId))
        case .authRequired:
            errorMessage = "Your session expired. Sign in again to continue. Your passenger details are saved."
            navigationEvents.append(.authenticate)
        case .networkUnavailable: errorMessage = "Connection lost. Check your internet and try again."
        case .offerExpired: errorMessage = "This fare expired. Please choose the flight again."
        case .offerUnavailable: errorMessage = "This fare is no longer available."
        case let .validationRejected(errors):
            errorMessage = errors.first?.message ?? "Check passenger details and try again."
        case .unknownError: errorMessage = "We couldn’t save passenger details. Please try again."
        }
    }

    func consumeNavigationEvent() -> PassengerDetailsNavigationEvent? {
        navigationEvents.isEmpty ? nil : navigationEvents.removeFirst()
    }
}
