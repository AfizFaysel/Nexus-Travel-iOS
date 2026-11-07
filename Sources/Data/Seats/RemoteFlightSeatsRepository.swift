import Foundation

/// Backend adapter for booking seat maps and assignments.
struct RemoteFlightSeatsRepository: FlightSeatsRepository {
    private let transport: HTTPTransport
    private let tokenProvider: AuthTokenProvider

    init(transport: HTTPTransport, tokenProvider: AuthTokenProvider) {
        self.transport = transport; self.tokenProvider = tokenProvider
    }

    func load(bookingId: String) async throws -> FlightSeatsResult {
        do {
            guard let token = try await tokenProvider.accessToken() else { return .authRequired }
            let response = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(bookingId)/seat-map"), authorization: .bearer(token)
            ))
            switch response.statusCode {
            case 200..<300:
                guard let dto = try? JSONDecoder().decode(SeatMapDTO.self, from: response.data) else {
                    return .temporarilyUnavailable
                }
                return .success(dto.domain)
            case 401: return .authRequired
            case 404: return .notFound
            case 410: return .offerUnavailable
            default: return .temporarilyUnavailable
            }
        } catch is CancellationError { throw CancellationError() }
        catch { return .temporarilyUnavailable }
    }

    func save(bookingId: String, assignments: [SeatAssignment]) async throws -> SaveSeatsResult {
        let payload = SaveAssignmentsDTO(assignments: assignments.map {
            .init(passengerIndex: $0.passengerIndex, segmentId: $0.segmentId, seatNumber: $0.seatNumber)
        })
        return try await change(bookingId: bookingId, method: .put, body: JSONEncoder().encode(payload))
    }

    func clear(bookingId: String) async throws -> SaveSeatsResult {
        try await change(bookingId: bookingId, method: .delete, body: nil)
    }

    private func change(bookingId: String, method: HTTPMethod, body: Data?) async throws -> SaveSeatsResult {
        do {
            guard let token = try await tokenProvider.accessToken() else { return .authRequired }
            let response = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(bookingId)/seats"), method: method,
                body: body, authorization: .bearer(token)
            ))
            switch response.statusCode {
            case 200..<300:
                guard let dto = try? JSONDecoder().decode(SeatSelectionDTO.self, from: response.data) else {
                    return .unknownError
                }
                return .success(dto.domain)
            case 401: return .authRequired
            case 409: return .seatUnavailable
            case 410: return .offerUnavailable
            default: return .unknownError
            }
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut { return .networkUnavailable }
        catch { return .unknownError }
    }
}

private struct SeatMapDTO: Decodable {
    let availability: String; let segments: [SegmentDTO]
    let currency: String?
    let passengerCount: Int?
    let travelers: [TravelerDTO]?

    struct TravelerDTO: Decodable {
        let passengerIndex: Int
        let seatEligible: Bool
    }
    var domain: FlightSeatMap {
        let mappedAvailability: SeatMapAvailability = switch availability {
        case "AVAILABLE": .available; case "NOT_SUPPORTED": .notSupported
        case "TEMPORARILY_UNAVAILABLE": .temporarilyUnavailable; default: .notProvided
        }
        return FlightSeatMap(
            availability: mappedAvailability, segments: segments.map(\.domain), currency: currency,
            travelers: travelers?.map { .init(passengerIndex: $0.passengerIndex, seatEligible: $0.seatEligible) },
            passengerCount: passengerCount
        )
    }
}
private struct SegmentDTO: Decodable {
    let segmentId, airlineName, aircraftName: String; let cabins: [CabinDTO]
    var domain: SeatMapSegment { .init(id: segmentId, airlineName: airlineName, aircraftName: aircraftName, cabins: cabins.map(\.domain)) }
}
private struct CabinDTO: Decodable {
    let name: String; let columns: [String]; let rows: [RowDTO]
    var domain: SeatCabin { .init(name: name, columns: columns, rows: rows.map(\.domain)) }
}
private struct RowDTO: Decodable {
    let number: Int; let seats: [SeatDTO]
    var domain: SeatRow { .init(number: number, seats: seats.map(\.domain)) }
}
private struct SeatDTO: Decodable {
    let number, status, position: String; let features: [String]; let price: SeatMoneyDTO?
    var domain: FlightSeat {
        let mappedStatus: FlightSeatStatus = switch status {
        case "AVAILABLE": .available; case "SELECTED": .selected; case "OCCUPIED": .occupied
        case "RESTRICTED": .restricted; default: .blocked
        }
        let mappedPosition: SeatPosition = switch position {
        case "WINDOW": .window; case "AISLE": .aisle; default: .middle
        }
        return .init(number: number, status: mappedStatus, position: mappedPosition,
              features: Set(features.compactMap { $0 == "EXTRA_LEGROOM" ? .extraLegroom : $0 == "EXIT_ROW" ? .exitRow : nil }),
              price: price?.money)
    }
}
private struct SeatMoneyDTO: Decodable {
    let amountMinor: Int; let currency: String
    var money: Money { .init(amount: amountMinor, currency: currency, formatted: moneyText(amountMinor, currency)) }
}
private struct SaveAssignmentsDTO: Encodable { let assignments: [AssignmentDTO] }
private struct AssignmentDTO: Encodable { let passengerIndex: Int; let segmentId, seatNumber: String }
private struct SeatSelectionDTO: Decodable {
    let assignments: [SavedAssignmentDTO]; let currency: String; let seatFeeAmountMinor: Int
    var domain: SeatSelection {
        .init(assignments: assignments.map { $0.domain(currency: currency) },
              feeTotal: .init(amount: seatFeeAmountMinor, currency: currency,
                              formatted: moneyText(seatFeeAmountMinor, currency)))
    }
}
private struct SavedAssignmentDTO: Decodable {
    let passengerIndex: Int; let segmentId, seatNumber: String; let priceAmountMinor: Int
    func domain(currency: String) -> SeatAssignment {
        .init(passengerIndex: passengerIndex, segmentId: segmentId, seatNumber: seatNumber,
              price: priceAmountMinor > 0 ? .init(amount: priceAmountMinor, currency: currency,
                                                 formatted: moneyText(priceAmountMinor, currency)) : nil)
    }
}
private func moneyText(_ amount: Int, _ currency: String) -> String {
    String(format: "%@ %.2f", currency, Double(amount) / 100)
}
