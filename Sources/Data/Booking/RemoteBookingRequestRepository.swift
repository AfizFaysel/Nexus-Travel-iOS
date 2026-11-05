import Foundation

struct RemoteBookingRequestRepository: BookingRequestRepository {
    private let transport: HTTPTransport
    private let tokenProvider: AuthTokenProvider
    init(transport: HTTPTransport, tokenProvider: AuthTokenProvider) {
        self.transport = transport; self.tokenProvider = tokenProvider
    }

    func getReview(reviewId: String) async throws -> BookingRequestResult {
        do {
            guard let token = try await tokenProvider.accessToken() else { return .unknownError }
            let response = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(reviewId)/review"), authorization: .bearer(token)
            ))
            switch response.statusCode {
            case 200..<300:
                guard let dto = try? JSONDecoder().decode(BookingResponseDTO.self, from: response.data) else { return .unknownError }
                return .success(dto.review)
            case 404: return .notFound
            case 410: return .expired
            default: return .unknownError
            }
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut { return .networkUnavailable }
        catch { return .unknownError }
    }

    func getStatus(reviewId: String) async throws -> BookingStatusResult {
        try await fetchStatus(reviewId: reviewId, method: .get, expectedStatusCode: 200)
    }

    func requestStatusCheck(reviewId: String) async throws -> BookingStatusResult {
        try await fetchStatus(reviewId: reviewId, method: .post, expectedStatusCode: 202)
    }

    private func fetchStatus(reviewId: String, method: HTTPMethod, expectedStatusCode: Int) async throws -> BookingStatusResult {
        do {
            guard let token = try await tokenProvider.accessToken() else { return .unknownError }
            let response = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(reviewId)/\(method == .post ? "status-check" : "status")"),
                method: method, authorization: .bearer(token)
            ))
            if response.statusCode == 404 { return .notFound }
            guard response.statusCode == expectedStatusCode,
                  let dto = try? JSONDecoder().decode(BookingStatusDTO.self, from: response.data),
                  let outcome = BookingHoldOutcome(rawValue: dto.outcomeCode) else { return .unknownError }
            let reference = dto.travelportLocator.flatMap { Self.validSupplierReference($0) ? $0 : nil }
            let actions = dto.allowedNextActions.compactMap(BookingStatusAction.init(rawValue:))
            return .success(.init(outcome: outcome, bookingReference: reference,
                                  reconciliationState: dto.reconciliationState,
                                  lastSupplierCheckedAt: dto.lastSupplierCheckedAt,
                                  allowedNextActions: actions))
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut { return .networkUnavailable }
        catch { return .unknownError }
    }

    func reprice(reviewId: String, expectedUpdatedAt: String) async throws -> BookingRepriceResult {
        do {
            guard let token = try await tokenProvider.accessToken() else { return .unknownError }
            let body = try JSONEncoder().encode(["expectedUpdatedAt": expectedUpdatedAt])
            let response = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(reviewId)/reprice"), method: .post,
                body: body, authorization: .bearer(token)
            ))
            switch response.statusCode {
            case 200..<300:
                guard let quote = try? JSONDecoder().decode(BookingPriceQuoteDTO.self, from: response.data) else { return .unknownError }
                return .success(quote.domain)
            case 410: return .expired
            case 409: return .unavailable
            default: return .unknownError
            }
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut { return .networkUnavailable }
        catch { return .unknownError }
    }

    func acceptQuote(reviewId: String, expectedUpdatedAt: String, quoteRevision: String) async throws -> BookingRequestResult {
        do {
            guard let token = try await tokenProvider.accessToken() else { return .unknownError }
            let body = try JSONEncoder().encode(["expectedUpdatedAt": expectedUpdatedAt, "quoteRevision": quoteRevision])
            let response = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(reviewId)/quote"), method: .patch,
                body: body, authorization: .bearer(token)
            ))
            switch response.statusCode {
            case 200..<300:
                guard let dto = try? JSONDecoder().decode(BookingResponseDTO.self, from: response.data) else { return .unknownError }
                return .success(dto.review)
            case 410: return .expired
            case 404: return .notFound
            case 409: return .unavailable
            default: return .unknownError
            }
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut { return .networkUnavailable }
        catch { return .unknownError }
    }

    func submitReview(reviewId: String, idempotencyKey: String) async throws -> BookingSubmitResult {
        do {
            guard let token = try await tokenProvider.accessToken(), !idempotencyKey.isEmpty else { return .unknownError }
            let response = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(reviewId)/hold"), method: .post,
                headers: ["Idempotency-Key": idempotencyKey], authorization: .bearer(token)
            ))
            switch response.statusCode {
            case 200..<300:
                guard let dto = try? JSONDecoder().decode(BookingResponseDTO.self, from: response.data) else { return .unknownError }
                if dto.status == "HOLD_UNCONFIRMED" { return .outcomeUnknown }
                if dto.status == "HOLD_CHANGE_REVIEW" { return .changedHoldReview }
                if dto.failureReasonCode == "PRICE_CHANGED" {
                    return .priceChanged(dto.failureReason ?? "Flight price changed. Search current fares before continuing.")
                }
                if dto.failureReasonCode == "FARE_UNAVAILABLE" {
                    return .fareUnavailable(dto.failureReason ?? "This fare is no longer available. Choose another flight.")
                }
                guard dto.status == "BOOKING_HELD", let reference = dto.travelportLocator,
                      Self.validSupplierReference(reference) else { return .unavailable }
                return .success(reviewId: dto.id, bookingReference: reference.trimmingCharacters(in: .whitespacesAndNewlines),
                                status: .submittedForManualReview)
            case 404: return .notFound
            case 410: return .expired
            case 409:
                let conflict = try? JSONDecoder().decode(BookingConflictDTO.self, from: response.data)
                switch conflict?.resolvedCode {
                case "PRICE_CHANGED": return .priceChanged(conflict?.resolvedMessage ?? "Flight price changed. Search current fares before continuing.")
                case "FARE_UNAVAILABLE": return .fareUnavailable(conflict?.resolvedMessage ?? "This flight is no longer available. Choose another flight.")
                default: return .unavailable
                }
            case 429: return .unavailable
            default: return .unknownError
            }
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut { return .networkUnavailable }
        catch { return .unknownError }
    }

    private static func validSupplierReference(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return !normalized.isEmpty && normalized != "UNKNOWN" && !normalized.hasPrefix("FAKE") && !normalized.hasPrefix("LOCAL")
    }
}

private struct BookingStatusDTO: Decodable {
    let outcomeCode: String
    let travelportLocator: String?
    let reconciliationState: BookingReconciliationState
    let lastSupplierCheckedAt: String?
    let allowedNextActions: [String]
}

private struct BookingPriceQuoteDTO: Decodable {
    let previousAmountMinor, newAmountMinor: Int
    let currency, quoteRevision, updatedAt: String
    let requiresNewFlight: Bool
    let itineraryChanged: Bool?
    let seatSelectionWillBeCleared: Bool
    var domain: BookingPriceQuote {
        .init(previousAmountMinor: previousAmountMinor, newAmountMinor: newAmountMinor,
              currency: currency, quoteRevision: quoteRevision, updatedAt: updatedAt,
              requiresNewFlight: requiresNewFlight, itineraryChanged: itineraryChanged,
              seatSelectionWillBeCleared: seatSelectionWillBeCleared)
    }
}

private struct BookingConflictDTO: Decodable {
    let code: String?
    let message: String?
    let nested: Nested?

    struct Nested: Decodable { let code: String?; let message: String? }

    enum CodingKeys: String, CodingKey { case code, message }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        message = try? container.decode(String.self, forKey: .message)
        nested = try? container.decode(Nested.self, forKey: .message)
    }

    var resolvedCode: String? { code ?? nested?.code }
    var resolvedMessage: String? { message ?? nested?.message }
}

private struct BookingResponseDTO: Decodable {
    let amountMinor: Int; let currency, id, status: String
    let updatedAt: String?
    let travelportLocator, failureReason, failureReasonCode: String?
    let selectedOfferSnapshot: SelectedOfferSnapshotDTO?
    let passengerDetailsSnapshot: PassengerSnapshotDTO?
    let contactSnapshot: ContactSnapshotDTO?
    let seatSelectionSnapshot: SeatSelectionSnapshotDTO?
    var review: BookingReviewDetails {
        .init(reviewId: id, bookingReference: travelportLocator.flatMap { Self.validSupplierReference($0) ? $0 : nil }, status: status.bookingStatus,
              passengers: passengerDetailsSnapshot?.passengers.map(\.domain) ?? [],
              contact: contactSnapshot?.domain ?? .init(email: "", phone: ""),
              seats: seatSelectionSnapshot?.assignments.map { $0.domain(currency: seatSelectionSnapshot?.currency ?? currency) } ?? [],
              fareTotal: .init(amount: amountMinor, currency: currency, formatted: moneyLabel(amountMinor, currency)),
              updatedAt: updatedAt, acceptedQuoteRevision: selectedOfferSnapshot?.quoteRevision,
              failureReason: failureReason, failureReasonCode: failureReasonCode)
    }

    private static func validSupplierReference(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return !normalized.isEmpty && normalized != "UNKNOWN" && !normalized.hasPrefix("FAKE") && !normalized.hasPrefix("LOCAL")
    }
}
private struct SelectedOfferSnapshotDTO: Decodable { let quoteRevision: String? }
private struct PassengerSnapshotDTO: Decodable { let passengers: [PassengerReviewDTO] }
private struct PassengerReviewDTO: Decodable {
    let title, firstName, lastName, passportNumber, nationality: String
    var domain: BookingReviewPassenger { .init(title: title, firstName: firstName, lastName: lastName, passportNumber: passportNumber, nationality: nationality) }
}
private struct ContactSnapshotDTO: Decodable {
    let email, phone: String
    var domain: BookingReviewContact { .init(email: email, phone: phone) }
}
private struct SeatSelectionSnapshotDTO: Decodable { let assignments: [SeatReviewDTO]; let currency: String }
private struct SeatReviewDTO: Decodable {
    let passengerIndex, priceAmountMinor: Int; let segmentId, seatNumber: String
    func domain(currency: String) -> SeatAssignment {
        .init(passengerIndex: passengerIndex, segmentId: segmentId, seatNumber: seatNumber,
              price: priceAmountMinor > 0 ? .init(amount: priceAmountMinor, currency: currency,
                                                 formatted: moneyLabel(priceAmountMinor, currency)) : nil)
    }
}
private extension String {
    var bookingStatus: BookingRequestStatus {
        switch uppercased() {
        case "DRAFT", "PRICED", "READY_TO_HOLD": .draftSaved
        case "BOOKING_HELD": .submittedForManualReview
        case "HOLD_REQUESTED", "HOLDING_WITH_TRAVELPORT": .holdPending
        case "HOLD_UNCONFIRMED": .holdUnconfirmed
        case "HOLD_CHANGE_REVIEW": .holdChangeReview
        case "PAYMENT_CONFIRMED", "TICKETED": .confirmed
        case "HOLD_EXPIRED", "EXPIRED": .expired
        case "HOLD_FAILED": .holdFailed
        case "UNAVAILABLE": .unavailable
        default: .none
        }
    }
}
private func moneyLabel(_ amount: Int, _ currency: String) -> String { String(format: "%@ %.2f", currency, Double(amount) / 100) }
