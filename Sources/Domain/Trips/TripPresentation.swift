import Foundation

enum TripAction: String, Hashable, Sendable {
    case checkStatus = "CHECK_STATUS"
    case viewTrip = "VIEW_TRIP"
    case searchAgain = "SEARCH_AGAIN"
    case resumeBooking = "RESUME_BOOKING"
    case uploadPaymentProof = "UPLOAD_PAYMENT_PROOF"
    case viewPaymentProof = "VIEW_PAYMENT_PROOF"
    case reviewChanges = "REVIEW_CHANGES"
    case viewTicketDetails = "VIEW_TICKET_DETAILS"
    case downloadTicket = "DOWNLOAD_TICKET"
    case getHelp = "GET_HELP"

    var label: String {
        switch self {
        case .checkStatus: "Check status"
        case .viewTrip: "View details"
        case .searchAgain: "Search flights"
        case .resumeBooking: "Continue booking"
        case .uploadPaymentProof: "Submit payment proof"
        case .viewPaymentProof: "View submitted proof"
        case .reviewChanges: "Review changes"
        case .viewTicketDetails: "View ticket details"
        case .downloadTicket: "Download ticket"
        case .getHelp: "Get help"
        }
    }
}

extension CustomerTrip {
    var detailActions: Set<TripAction> {
        Set((summary?.presentation?.allowedActions ?? []).compactMap(TripAction.init(rawValue:)))
    }

    var presentedDetailAction: TripAction? {
        guard let raw = summary?.presentation?.primaryAction,
              let action = TripAction(rawValue: raw), detailActions.contains(action) else { return nil }
        return action
    }

    var offersDetailSupport: Bool {
        detailActions.contains(.getHelp) || abandonmentState == .supportReview
    }

    var detailStatusCopy: (title: String, explanation: String)? {
        guard let presentation = summary?.presentation else { return nil }
        if detail?.abandonedAt != nil || presentation.state == "ABANDONED" {
            let explanation = switch abandonmentState {
            case .cancelled: "The airline reservation from this attempt has been cancelled."
            case .closed: "This attempt is closed. No reservation was created."
            case .cancellationPending: "We found the earlier reservation and are checking its cancellation."
            case .supportReview: "We couldn’t confirm the reservation’s cancellation. Contact support before making another payment."
            case nil: "This booking attempt was stopped. We’re checking whether the airline created a reservation."
            }
            return ("Booking attempt stopped", explanation)
        }
        if ["PREPARING_DOCUMENT", "TICKET_READY", "PAST"].contains(presentation.state),
           presentedDetailAction == .getHelp {
            let explanation = ticketDocumentAvailable
                ? "Your ticket was issued. Its saved PDF may not reflect the latest details. Contact support."
                : "Your ticket was issued, but we couldn’t prepare its PDF. Contact support. You don’t need to pay again."
            return ("Ticket document needs attention", explanation)
        }
        if presentation.state == "PAYMENT_UNDER_REVIEW", summary?.verification?.status == "REVIEW" {
            return ("Payment under review", "Wait for our team to finish reviewing your payment proof. Don’t send another payment.")
        }

        return switch presentation.state {
        case "CONFIRMING":
            ("Confirming your booking", "Wait until your flight is confirmed and this page shows Payment needed before paying.")
        case "PAYMENT_NEEDED":
            ("Payment needed", "Submit your payment proof before the booking deadline.")
        case "PAYMENT_PROOF_REJECTED":
            ("Payment proof not accepted", "Check your payment proof and submit it again. Do not pay again.")
        case "PAYMENT_UNDER_REVIEW":
            ("Checking your payment", "Wait for the payment check to finish. Don’t send another payment while we review your proof.")
        case "PREPARING_TICKET":
            ("Preparing your ticket", "Payment verified. Ticket issuance is in progress.")
        case "TICKET_DELAYED":
            ("Ticket issuance delayed", "Ticket issuance needs more time. Contact support for help.")
        case "UNPAID_EXPIRED":
            ("Reservation expired", "This unpaid reservation expired. Search for a current fare.")
        case "PAID_NEEDS_ATTENTION":
            ("Booking needs attention", "Contact support to resolve this booking before sending any further payment.")
        case "TICKET_READY":
            ("Your ticket is ready", "Download your ticket and check your flight details.")
        case "PREPARING_DOCUMENT":
            ("Preparing your ticket document", "Your ticket was issued. Its document isn’t ready yet.")
        case "FLIGHT_CHANGED":
            ("Your flight changed", "Review the airline’s confirmed itinerary changes.")
        case "HOLD_CHANGED":
            ("Booking details changed", "Wait until our team confirms the updated booking details before paying. Check status for updates.")
        case "HOLD_FAILED":
            ("Booking failed", "This booking attempt failed. Search again for current flights.")
        case "CANCELLED":
            ("Trip cancelled", "This trip was cancelled.")
        case "DRAFT":
            ("Finish your booking", "Continue where you left off. Your flight isn’t reserved yet.")
        case "PAST":
            ("Past trip", "View your previous trip and available ticket.")
        default:
            ("Status unavailable", "Refresh to check the latest booking status.")
        }
    }

    var verificationReasonLabel: String? {
        switch summary?.verification?.reason {
        case "AMOUNT_MISMATCH": "The payment amount doesn’t match this booking."
        case "AMOUNT_UNCONFIRMED": "We couldn’t confirm the amount on this receipt. Contact support to check its status."
        case "CURRENCY_UNCONFIRMED": "We couldn’t confirm the payment currency. Contact support."
        case "BANK_RECEIPT_NOT_VERIFIED": "We couldn’t confirm this receipt. Contact support to check its status."
        case "RECIPIENT_MISMATCH": "This receipt shows a receiving account that doesn’t match a registered Nexus account."
        case "PAYMENT_BEFORE_HOLD": "This payment was made before the booking was confirmed."
        case "CURRENCY_MISMATCH": "The payment currency doesn’t match this booking."
        case "TRANSACTION_ALREADY_CLAIMED": "This payment is already linked to another booking."
        case "HOLD_NOT_PAYABLE": "This reservation needs review before payment can be confirmed."
        case "PAYMENT_TIME_UNCONFIRMED": "We couldn’t confirm when this payment was made."
        case "TRANSACTION_UNCONFIRMED": "We couldn’t confirm this transaction."
        case "BOOKING_ASSOCIATION_UNCONFIRMED": "We couldn’t match this payment to your booking."
        case "RECIPIENT_UNCONFIRMED", "RECEIVING_BANK_UNCONFIRMED": "We couldn’t confirm the receiving account."
        case "UNSUPPORTED_RECEIPT_SCHEMA", "IMAGE_REQUIRES_REVIEW": "Your payment proof needs review."
        case "VERIFICATION_INTERRUPTED", "VERIFICATION_OUTCOME_UNKNOWN":
            "Wait for us to confirm your payment status. Contact support before sending another payment."
        default: nil
        }
    }

    var totalLabel: String? {
        guard let amountMinor, let currency else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let exponent = formatter.maximumFractionDigits
        guard exponent >= 0 && exponent <= 6 else { return nil }
        let amount = Decimal(amountMinor) / pow(Decimal(10), exponent)
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = exponent
        formatter.maximumFractionDigits = exponent
        guard let total = formatter.string(from: amount as NSDecimalNumber) else { return nil }
        return "\(currency) \(total)"
    }

    var travelerDetails: [String] {
        let travelers = detail?.travelers.filter { $0.passengerIndex >= 0 && $0.displayName?.isEmpty == false } ?? []
        guard !travelers.isEmpty else { return [] }
        let passengerIndices = Set(travelers.map(\.passengerIndex))
        let associated = travelers.compactMap { traveler -> String? in
            guard let name = traveler.displayName else { return nil }
            let travelerSeats = seats.filter { $0.passengerIndex == traveler.passengerIndex }.map(seatLabel)
            let travelerTickets = tickets.filter {
                $0.associationConfidence == "CONFIRMED" && $0.passengerIndices.contains(traveler.passengerIndex)
            }.compactMap(\.detailLabel)
            let evidence = travelerSeats + travelerTickets
            return "\(name): \(evidence.isEmpty ? "No seat or ticket details" : evidence.joined(separator: " · "))"
        }
        let unmatchedSeats = seats.filter { !($0.passengerIndex.map(passengerIndices.contains) ?? false) }
            .map { "Traveler association unavailable · \(seatLabel($0))" }
        let unmatchedTickets = tickets.filter {
            $0.associationConfidence != "CONFIRMED" || passengerIndices.isDisjoint(with: $0.passengerIndices)
        }.compactMap(\.detailLabel).map { "Traveler association unavailable · \($0)" }
        return associated + unmatchedSeats + unmatchedTickets
    }

    func seatLabel(_ seat: TripSeatAssignment) -> String {
        let label = "Seat \(seat.seatNumber)"
        guard let segmentID = seat.segmentId,
              let segment = segments.first(where: { $0.id == segmentID }) else { return label }
        let route = segment.origin.flatMap { origin in segment.destination.map { "\(origin)–\($0)" } }
        return [label, segment.flightLabel == "Flight" ? nil : segment.flightLabel, route]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

extension TripTicket {
    var detailLabel: String? {
        guard let ticketNumber else { return nil }
        return status == "USABLE" ? "Ticket \(ticketNumber)" : "Ticket \(ticketNumber) · status unconfirmed"
    }
}

extension TripSegment {
    var departureTimeLabel: String { Self.timeLabel(departureTime) }
    var arrivalTimeLabel: String { Self.timeLabel(arrivalTime) }

    var durationLabel: String {
        guard let durationMinutes, durationMinutes > 0 else { return "Duration unavailable" }
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        return [hours > 0 ? "\(hours)h" : nil, minutes > 0 ? "\(minutes)m" : nil]
            .compactMap { $0 }.joined(separator: " ")
    }

    func boundaryLabel(after previous: TripSegment) -> String? {
        if let legID, let previousLeg = previous.legID, legID != previousLeg {
            return legIndex.map { "Leg \($0 + 1)" } ?? "Next leg"
        }
        if let legIndex, let previousIndex = previous.legIndex, legIndex != previousIndex {
            return "Leg \(legIndex + 1)"
        }
        if let legID, legID == previous.legID { return "Connection" }
        if let legIndex, legIndex == previous.legIndex { return "Connection" }
        return nil
    }

    private static func timeLabel(_ value: String?) -> String {
        guard let value else { return "Time unavailable" }
        let clock = value.split(separator: "T").last.map(String.init) ?? value
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "HH:mm"
        guard let time = formatter.date(from: String(clock.prefix(5))) else { return "Time unavailable" }
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }
}
