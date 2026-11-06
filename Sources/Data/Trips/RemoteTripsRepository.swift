import CryptoKit
import Foundation

struct RemoteTripsRepository: TripsRepository {
    private let transport: HTTPTransport; private let tokenProvider: AuthTokenProvider
    private let cache: TripCache; private let ticketStore: TicketPdfStore
    init(transport: HTTPTransport, tokenProvider: AuthTokenProvider, cache: TripCache, ticketStore: TicketPdfStore) {
        self.transport = transport; self.tokenProvider = tokenProvider; self.cache = cache; self.ticketStore = ticketStore
    }
    func trips(view: TripView, forceRefresh: Bool, cursor: String?) async throws -> TripPageState {
        guard let token = try await tokenProvider.accessToken() else { return .authRequired }

        let accountScope = SHA256.hash(data: Data(token.utf8)).description
        let key = "trips:view:\(view.rawValue):\(accountScope)"
        if cursor == nil, !forceRefresh, let entry = await cache.fresh(key: key),
           let page = try? Self.decodePage(entry.data, offline: false, fetchedAt: entry.fetchedAt) {
            return .content(page, offline: false, lastUpdated: entry.fetchedAt)
        }

        var query = [URLQueryItem(name: "view", value: view.rawValue), URLQueryItem(name: "limit", value: "20")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }

        do {
            let response = try await transport.send(HTTPRequest(
                target: .mobile("trips"), queryItems: query, authorization: .bearer(token)
            ))
            try Task.checkCancellation()
            if response.statusCode == 401 { return .authRequired }
            if response.statusCode == 403 || response.statusCode == 404 {
                return .error("Could not access trips. Try again.", cached: TripPage(items: [], nextCursor: nil))
            }
            guard (200..<300).contains(response.statusCode) else { return .error("Could not refresh trips. Try again.") }
            let now = Date()
            let page = try Self.decodePage(response.data, offline: false, fetchedAt: now)
            if cursor == nil { await cache.put(key: key, data: response.data) }
            return .content(page, offline: false, lastUpdated: now)
        } catch is CancellationError {
            throw CancellationError()
        } catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut {
            try Task.checkCancellation()
            if cursor == nil, let entry = await cache.stale(key: key),
               let page = try? Self.decodePage(entry.data, offline: true, fetchedAt: entry.fetchedAt) {
                return .content(page, offline: true, lastUpdated: entry.fetchedAt)
            }
            return .error("Check your connection and try again.")
        } catch {
            try Task.checkCancellation()
            return .error("Could not refresh trips. Try again.")
        }
    }

    func requestSupplierRefresh(bookingIDs: [String]) async throws -> TripSupplierRefreshResult {
        guard !bookingIDs.isEmpty else { return .accepted(pending: false) }
        guard let token = try await tokenProvider.accessToken() else { return .authRequired }
        let response = try await transport.send(HTTPRequest(
            target: .mobile("trips/refresh"),
            method: .post,
            body: JSONEncoder().encode(TripRefreshRequestDTO(bookingIds: bookingIDs)),
            authorization: .bearer(token)
        ))
        try Task.checkCancellation()
        switch response.statusCode {
        case 202:
            let dto = try JSONDecoder().decode(TripRefreshResponseDTO.self, from: response.data)
            let requestedIDs = Set(bookingIDs)
            return .accepted(pending: dto.items.contains {
                requestedIDs.contains($0.bookingId) && ["QUEUED", "ALREADY_RUNNING", "CHECKING"].contains($0.status)
            })
        case 401: return .authRequired
        case 403, 404: return .unavailable
        default: return .failed
        }
    }

    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult {
        guard let token = try await tokenProvider.accessToken() else { return .authRequired }
        let scope = SHA256.hash(data: Data(token.utf8)).description
        let key = "trips:detail:\(scope):\(id)"
        if !forceRefresh, let entry = await cache.fresh(key: key), let trip = try? Self.decodeTrip(entry.data, offline: false, fetchedAt: entry.fetchedAt) { return .success(trip) }
        do {
            let response = try await transport.send(HTTPRequest(target: .mobile("trips/\(id)"), authorization: .bearer(token)))
            try Task.checkCancellation()
            if response.statusCode == 401 { return .authRequired }
            if response.statusCode == 403 || response.statusCode == 404 { return .notFound }
            guard (200..<300).contains(response.statusCode) else { return .failed }
            let trip = try Self.decodeTrip(response.data, offline: false, fetchedAt: Date()); await cache.put(key: key, data: response.data); return .success(trip)
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut {
            if let entry = await cache.stale(key: key), let trip = try? Self.decodeTrip(entry.data, offline: true, fetchedAt: entry.fetchedAt) { return .success(trip) }
            return .networkUnavailable
        } catch { return .failed }
    }
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult {
        do {
            guard let token = try await tokenProvider.accessToken() else { return .authRequired }
            let response = try await transport.send(HTTPRequest(target: .mobile("bookings/\(id)/ticket-document"), authorization: .bearer(token)))
            if response.statusCode == 401 { return .authRequired }; if response.statusCode == 404 { return .unavailable }
            guard (200..<300).contains(response.statusCode), let dto = try? JSONDecoder().decode(TicketDocumentDTO.self, from: response.data), let url = URL(string: dto.downloadUrl) else { return .unknownError }
            return .success(url)
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut { return .networkUnavailable }
        catch { return .unknownError }
    }
    func cachedTicketPdf(id: String, version: String?) async throws -> CachedTicketResult? {
        guard let token = try await tokenProvider.accessToken() else { return nil }
        let scope = SHA256.hash(data: Data(token.utf8)).description
        return ticketStore.cached(id: "\(scope):\(id)", version: version)
    }

    func cacheTicketPdf(id: String, downloadURL: URL, version: String? = nil) async throws -> CachedTicketResult {
        do {
            guard let token = try await tokenProvider.accessToken() else { return .unknownError }
            let response = try await transport.send(HTTPRequest(target: .absolute(downloadURL), authorization: .none))
            try Task.checkCancellation()
            guard response.statusCode == 200 else { return .networkUnavailable }
            guard try await tokenProvider.accessToken() == token else { return .unknownError }
            try Task.checkCancellation()
            let scope = SHA256.hash(data: Data(token.utf8)).description
            do {
                return .success(try ticketStore.store(id: "\(scope):\(id)", version: version, data: response.data))
            } catch {
                return .storageUnavailable
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut {
            return .networkUnavailable
        } catch {
            return .unknownError
        }
    }
    private static func decodePage(_ data: Data, offline: Bool, fetchedAt: Date) throws -> TripPage { let dto = try JSONDecoder().decode(TripPageDTO.self, from: data); return .init(items: dto.items.map { $0.domain(offline: offline, fetchedAt: fetchedAt) }, nextCursor: dto.nextCursor) }
    private static func decodeTrip(_ data: Data, offline: Bool, fetchedAt: Date) throws -> CustomerTrip { try JSONDecoder().decode(TripDTO.self, from: data).domain(offline: offline, fetchedAt: fetchedAt) }
}

private struct TripRefreshRequestDTO: Encodable { let bookingIds: [String] }
private struct TripRefreshResponseDTO: Decodable {
    struct Item: Decodable { let bookingId: String; let status: String }
    let items: [Item]
}
private struct TripSupplierCheckDTO: Decodable { let state: String }
private struct TripPageDTO: Decodable { let items: [TripDTO]; let nextCursor: String? }
private struct TicketDocumentDTO: Decodable { let downloadUrl: String }
private struct TripDTO: Decodable {
    let id: String; let group: TripGroup; let status, paymentStatus, paymentProofStatus, ticketingStatus: String
    let amountMinor: Int?; let currency, holdExpiresAt: String?; let ticketDocumentAvailable: Bool; let nextAction: String?; let createdAt: String; let updatedAt: String?
    let itinerary: [String: JSONValue]?; let normalizedItinerary: [String: JSONValue]?
    let presentation: TripSummary.Presentation?; let paymentVerification: TripSummary.Verification?
    let supplierCheck: TripSupplierCheckDTO?
    let travelportLocator: String?
    let travelerCount: Int?
    let travelers: [TripDetail.Traveler]?
    let seatReservation: TripSeatReservationDTO?
    let confirmedChange: TripItineraryChangeDTO?
    let ticketDocument: TripDetail.TicketDocument?
    let lastSupplierCheckedAt: String?
    let ticketEmailStatus: String?
    let abandonedAt: String?
    let resumeTarget: String?
    let contractVersion: Int?; let seats: [String: JSONValue]?; let tickets: [TripTicketDTO]?
    func domain(offline: Bool, fetchedAt: Date) -> CustomerTrip {
        let itinerary = normalizedItinerary ?? itinerary
        let origin = itinerary?["departureAirportCode"]?.string ?? itinerary?["origin"]?.string ?? itinerary?["from"]?.string ?? itinerary?["departureAirport"]?.string
        let destination = itinerary?["arrivalAirportCode"]?.string ?? itinerary?["destination"]?.string ?? itinerary?["to"]?.string ?? itinerary?["arrivalAirport"]?.string
        let segments = itinerary?["segments"]?.array?.compactMap { $0.object }.map(Self.segment) ?? []
        let assignments = seats?["assignments"]?.array?.compactMap { $0.object }.compactMap { value -> TripSeatAssignment? in guard let number = value["seatNumber"]?.string else { return nil }; return .init(passengerIndex: value["passengerIndex"]?.int, segmentId: value["segmentId"]?.string, seatNumber: number) } ?? []
        let summary = TripSummary(
            presentation: contractVersion.map { (1...2).contains($0) } == false ? nil : presentation,
            route: .init(
                origin: itinerary?["departureCity"]?.string ?? origin ?? segments.first?.origin,
                destination: itinerary?["arrivalCity"]?.string ?? destination ?? segments.last?.destination
            ),
            departureDate: itinerary?["departureDate"]?.string ?? segments.first?.departureTime,
            returnDate: itinerary?["returnDate"]?.string,
            carrier: itinerary?["marketingCarrier"]?.string ?? segments.first?.carrier,
            airline: itinerary?["airlineName"]?.string,
            logoURL: itinerary?["airlineLogoUrl"]?.string.flatMap { URL(string: $0) },
            tripType: itinerary?["tripType"]?.string,
            verification: paymentVerification,
            supplierCheckState: supplierCheck?.state
        )
        let change = confirmedChange.flatMap { change -> TripDetail.ItineraryChange? in
            let current = (change.current ?? []).map(Self.segment)
            guard !current.isEmpty else { return nil }
            return .init(previous: (change.previous ?? []).map(Self.segment), current: current)
        }
        let detail = TripDetail(
            reference: travelportLocator, travelerCount: travelerCount, travelers: travelers ?? [],
            seatState: seatReservation.flatMap { TripDetail.SeatState(rawValue: $0.state) },
            confirmedChange: change, ticketDocument: ticketDocument,
            lastSupplierCheckedAt: lastSupplierCheckedAt, ticketEmailStatus: ticketEmailStatus,
            abandonedAt: abandonedAt, originCode: origin, destinationCode: destination, resumeTarget: resumeTarget.flatMap(TripDetail.ResumeTarget.init(rawValue:))
        )
        return CustomerTrip(
            id: id, group: group, status: status, paymentStatus: paymentStatus,
            paymentProofStatus: paymentProofStatus, ticketingStatus: ticketingStatus, amountMinor: amountMinor,
            currency: currency, holdExpiresAt: holdExpiresAt,
            ticketDocumentAvailable: ticketDocument?.available ?? ticketDocumentAvailable,
            nextAction: nextAction ?? "VIEW_TRIP", createdAt: createdAt, updatedAt: updatedAt,
            itineraryLabel: origin.flatMap { start in destination.map { "\(start) to \($0)" } } ?? "Trip itinerary",
            segments: segments, seats: assignments,
            tickets: tickets?.map {
                TripTicket(ticketNumber: $0.ticketNumber, passengerIndices: $0.passengerIndices ?? [],
                           associationConfidence: $0.associationConfidence, status: $0.status)
            } ?? [],
            summary: summary, detail: detail, offline: offline, fetchedAt: fetchedAt
        )
    }
    private static func segment(_ value: [String: JSONValue]) -> TripSegment {
        TripSegment(
            origin: value["departureAirportCode"]?.string ?? value["origin"]?.string ?? value["from"]?.string,
            destination: value["arrivalAirportCode"]?.string ?? value["destination"]?.string ?? value["to"]?.string,
            departureTime: value["departureTime"]?.string ?? value["departureAt"]?.string,
            arrivalTime: value["arrivalTime"]?.string ?? value["arrivalAt"]?.string,
            carrier: value["marketingCarrier"]?.string ?? value["carrier"]?.string ?? value["carrierCode"]?.string,
            flightNumber: value["flightNumber"]?.string ?? value["number"]?.string,
            id: value["id"]?.string,
            legID: value["legId"]?.string,
            legIndex: value["legIndex"]?.int,
            originCity: value["departureCity"]?.string,
            destinationCity: value["arrivalCity"]?.string,
            departureDate: value["departureDate"]?.string,
            arrivalDate: value["arrivalDate"]?.string,
            airline: value["airlineName"]?.string,
            operatingCarrier: value["operatingCarrier"]?.string,
            operatingAirline: value["operatingCarrierName"]?.string,
            durationMinutes: value["durationMinutes"]?.int,
            departureTerminal: value["departureTerminal"]?.string,
            arrivalTerminal: value["arrivalTerminal"]?.string,
            baggage: value["baggage"]?.string ?? value["baggage"]?.object?["description"]?.string
        )
    }

}
private struct TripTicketDTO: Decodable {
    let ticketNumber: String?
    let passengerIndices: [Int]?
    let associationConfidence: String?
    let status: String?
}
private struct TripSeatReservationDTO: Decodable { let state: String }
private struct TripItineraryChangeDTO: Decodable {
    let previous: [[String: JSONValue]]?
    let current: [[String: JSONValue]]?
}
private enum JSONValue: Decodable { case string(String), number(Double), object([String: JSONValue]), array([JSONValue]), bool(Bool), null
    init(from decoder: Decoder) throws { let c = try decoder.singleValueContainer(); if c.decodeNil() { self = .null } else if let v = try? c.decode(String.self) { self = .string(v) } else if let v = try? c.decode(Int.self) { self = .number(Double(v)) } else if let v = try? c.decode(Double.self) { self = .number(v) } else if let v = try? c.decode(Bool.self) { self = .bool(v) } else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) } else { self = .array(try c.decode([JSONValue].self)) } }
    var string: String? { if case let .string(v) = self { v } else { nil } }; var int: Int? { if case let .number(v) = self { Int(v) } else { nil } }; var object: [String: JSONValue]? { if case let .object(v) = self { v } else { nil } }; var array: [JSONValue]? { if case let .array(v) = self { v } else { nil } }
}
