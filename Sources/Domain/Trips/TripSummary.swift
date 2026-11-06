import Foundation

struct TripSummary: Equatable, Sendable {
    struct Progress: Decodable, Equatable, Sendable {
        let booking: String?
        let payment: String
        let ticket: String?
    }

    struct Presentation: Decodable, Equatable, Sendable {
        let state: String
        let section: TripSection
        let primaryAction: String?
        let allowedActions: Set<String>?
        let progress: Progress
    }

    struct Route: Equatable, Sendable {
        let origin: String?
        let destination: String?

        var label: String {
            guard let origin, let destination else { return "Itinerary unavailable" }
            return "\(origin) → \(destination)"
        }
    }

    struct Verification: Decodable, Equatable, Sendable {
        let status: String
        let reason: String?
        let updatedAt: String?
    }

    let presentation: Presentation?
    let route: Route
    let departureDate: String?
    let returnDate: String?
    let carrier: String?
    let airline: String?
    let logoURL: URL?
    let tripType: String?
    let verification: Verification?
    let supplierCheckState: String?

    var supplierCheckPending: Bool {
        supplierCheckState == "QUEUED" || supplierCheckState == "CHECKING"
    }

    var dateLabel: String {
        let start = departureDate.flatMap(Self.dateLabel) ?? "Departure date unavailable"
        guard tripType == "ROUND_TRIP", let end = returnDate.flatMap(Self.dateLabel) else { return start }
        return "\(start) – \(end)"
    }

    var carrierLabel: String {
        [airline ?? carrier, tripType == "MULTI_CITY" ? "Multi-city" : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var statusLabel: String {
        switch presentation?.state {
        case "ABANDONED": "Stopped · checking airline status"
        case "CONFIRMING": "Confirming booking"
        case "PAYMENT_NEEDED": "Payment needed"
        case "PAYMENT_PROOF_REJECTED": "Proof not accepted"
        case "PAYMENT_UNDER_REVIEW": verification?.status == "REVIEW" ? "Payment under review" : "Checking payment"
        case "PREPARING_TICKET": "Preparing ticket"
        case "TICKET_DELAYED": "Ticket delayed"
        case "UNPAID_EXPIRED": "Expired"
        case "PAID_NEEDS_ATTENTION": "Needs attention"
        case "TICKET_READY": documentNeedsHelp ? "Document needs attention" : "Ticket ready"
        case "PREPARING_DOCUMENT": documentNeedsHelp ? "Document needs attention" : "Preparing document"
        case "FLIGHT_CHANGED": "Flight changed"
        case "HOLD_CHANGED": "Details changed"
        case "HOLD_FAILED": "Failed"
        case "CANCELLED": "Cancelled"
        case "DRAFT": "Booking unfinished"
        case "PAST": documentNeedsHelp ? "Document needs attention" : "Past trip"
        default: "Status unavailable"
        }
    }

    var documentNeedsHelp: Bool { presentation?.primaryAction == "GET_HELP" }

    var showsDeadline: Bool {
        presentation?.state == "PAYMENT_NEEDED" || presentation?.state == "PAYMENT_PROOF_REJECTED"
    }

    var showsVerifiedPayment: Bool {
        presentation?.state == "PAID_NEEDS_ATTENTION" && presentation?.progress.payment == "COMPLETE"
    }

    static func dateLabel(_ value: String) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(value.prefix(10))) else { return nil }
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

extension CustomerTrip {
    var listSection: TripSection {
        if let section = summary?.presentation?.section { return section }
        switch group {
        case .actionRequired: return .inProgress
        case .upcoming: return .upcoming
        case .past, .cancelled: return .history
        }
    }

    var bookingDeadlineLabel: String? {
        guard let value = holdExpiresAt else { return nil }
        let formatter = ISO8601DateFormatter()
        let date: Date?
        if let wholeSecond = formatter.date(from: value) {
            date = wholeSecond
        } else {
            formatter.formatOptions.insert(.withFractionalSeconds)
            date = formatter.date(from: value)
        }
        guard let date else { return nil }
        let display = DateFormatter()
        display.locale = Locale(identifier: "en_US_POSIX")
        display.timeZone = .gmt
        display.dateFormat = "d MMM, h:mm a"
        return "\(display.string(from: date)) UTC"
    }
}
