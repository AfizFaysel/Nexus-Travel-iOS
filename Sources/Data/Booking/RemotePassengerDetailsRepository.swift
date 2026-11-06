import Foundation

/// Remote booking adapter coordinating passport uploads and passenger submission.
struct RemotePassengerDetailsRepository: PassengerDetailsRepository {
    private let transport: HTTPTransport
    private let tokenProvider: AuthTokenProvider
    private let passportUploadRepository: any PassportUploadRepository

    /// Creates remote adapter from shared transport, auth, and upload boundary.
    init(transport: HTTPTransport, tokenProvider: AuthTokenProvider,
         passportUploadRepository: any PassportUploadRepository) {
        self.transport = transport; self.tokenProvider = tokenProvider
        self.passportUploadRepository = passportUploadRepository
    }

    func submitPassengerDetails(_ request: SubmitPassengerDetailsRequest) async throws -> PassengerDetailsResult {
        var uploadIds: [String] = []
        for (index, passenger) in request.passengers.enumerated() {
            guard let document = passenger.document else {
                guard request.bookingId != nil, let savedUpload = passenger.passportUploadId else {
                    return .validationRejected([.init(field: "passportDocument", message: "Passport document required")])
                }
                uploadIds.append(savedUpload)
                continue
            }
            switch try await passportUploadRepository.upload(
                document: document, idempotencyKey: "\(request.clientSessionId):passport:\(index)"
            ) {
            case let .success(upload): uploadIds.append(upload.uploadId)
            case .invalidDocument:
                return .validationRejected([.init(field: "passportDocument", message: "Use JPEG, PNG or PDF up to 10 MB")])
            case .authRequired: return .authRequired
            case .networkUnavailable: return .networkUnavailable
            case .failed: return .unknownError
            }
        }
        do {
            guard let token = try await tokenProvider.accessToken() else { return .authRequired }
            let bookingId: String
            if let savedBooking = request.bookingId {
                bookingId = savedBooking
            } else {
                let draftBody = try JSONEncoder().encode(BookingDraftRequest(
                    searchSessionId: request.offerReference.searchId, offerId: request.offerReference.offerId
                ))
                let draftResponse = try await transport.send(HTTPRequest(
                    target: .mobile("bookings/drafts"), method: .post, body: draftBody, authorization: .bearer(token)
                ))
                if let mapped = Self.error(for: draftResponse.statusCode) { return mapped }
                guard let draft = try? JSONDecoder().decode(BookingResponse.self, from: draftResponse.data) else {
                    return .unknownError
                }
                bookingId = draft.id
            }
            let body = try JSONEncoder().encode(PassengerRequest(
                contact: .init(email: request.contact.email,
                               phone: request.contact.countryDialCode + request.contact.phoneNumber),
                passengers: zip(request.passengers, uploadIds).map(PassengerPayload.init)
            ))
            let readyResponse = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(bookingId)/passengers"), method: .patch,
                body: body, authorization: .bearer(token)
            ))
            if let mapped = Self.error(for: readyResponse.statusCode) { return mapped }
            guard let ready = try? JSONDecoder().decode(BookingResponse.self, from: readyResponse.data) else {
                return .unknownError
            }
            let formatted = String(format: "%@ %.2f", ready.currency, Double(ready.amountMinor) / 100)
            return .success(reviewId: ready.id,
                            total: Money(amount: ready.amountMinor, currency: ready.currency, formatted: formatted))
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut { return .networkUnavailable }
        catch { return .unknownError }
    }

    private static func error(for status: Int) -> PassengerDetailsResult? {
        switch status {
        case 200..<300: nil
        case 401: .authRequired
        case 404: .offerUnavailable
        case 410: .offerExpired
        default: .unknownError
        }
    }
}

private struct BookingDraftRequest: Encodable { let searchSessionId: String; let offerId: String }
private struct BookingResponse: Decodable { let amountMinor: Int; let currency: String; let id: String; let status: String }
private struct PassengerRequest: Encodable { let contact: ContactPayload; let passengers: [PassengerPayload] }
private struct ContactPayload: Encodable { let email: String; let phone: String }
private struct PassengerPayload: Encodable {
    let title, gender, firstName, lastName, dateOfBirth, type, nationality: String
    let passportNumber, passportExpiryDate, passportIssuingCountry, passportUploadId: String
    init(_ pair: (PassengerDetailsDraft, String)) {
        let (value, uploadId) = pair
        title = value.title.uppercased()
        gender = switch value.gender.lowercased() {
        case "male": "M"
        case "female": "F"
        default: "X"
        }
        firstName = value.firstName; lastName = value.lastName; dateOfBirth = value.dateOfBirth?.iso8601 ?? ""
        type = switch value.passengerType { case .adult: "ADT"; case .child: "CNN"; case .infant: "INF" }
        nationality = value.nationalityCountryCode; passportNumber = value.passportNumber
        passportExpiryDate = value.passportExpiryDate?.iso8601 ?? ""
        passportIssuingCountry = value.passportIssuingCountryCode; passportUploadId = uploadId
    }
}
