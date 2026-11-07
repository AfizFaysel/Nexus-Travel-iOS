import SwiftUI

extension CustomerTrip {
    var feedbackStatus: NexusStatus {
        let state = summary?.presentation?.state
        if detail?.abandonedAt != nil || state == "ABANDONED" {
            return switch abandonmentState {
            case .closed, .cancelled: .error
            case .supportReview: .warning
            default: .info
            }
        }
        if let state, ["PREPARING_DOCUMENT", "TICKET_READY", "PAST"].contains(state),
           presentedDetailAction == .getHelp { return .warning }
        return switch state {
        case "TICKET_READY": .success
        case "CONFIRMING", "PAYMENT_UNDER_REVIEW", "PREPARING_TICKET", "PREPARING_DOCUMENT": .info
        case "PAYMENT_NEEDED", "PAYMENT_PROOF_REJECTED", "TICKET_DELAYED",
             "PAID_NEEDS_ATTENTION", "FLIGHT_CHANGED", "HOLD_CHANGED": .warning
        case "HOLD_FAILED", "UNPAID_EXPIRED", "CANCELLED": .error
        default: .empty
        }
    }
}

extension NexusStatus {
    /// The icon a status banner shows for this tone; neutral tones show none.
    var feedbackIcon: NexusIconName? {
        switch self {
        case .success: .check
        case .info: .clock
        case .warning: .warning
        default: nil
        }
    }
}

/// The trip's route as the screen heading, with its date and traveler count underneath.
struct TripRouteHeader: View {
    let trip: CustomerTrip

    private var metadata: String {
        let date = trip.summary?.dateLabel ?? trip.segments.first?.departureDate.flatMap(TripSummary.dateLabel)
        let travelers = trip.detail?.travelerCount.map { "\($0) \($0 == 1 ? "traveler" : "travelers")" }
        return [date, travelers].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space4) {
            Text(trip.summary?.route.label ?? trip.itineraryLabel)
                .nexusTextStyle(NexusText.styles.screenTitle)
                .foregroundStyle(NexusSemanticColors.textHeading)
                .accessibilityAddTraits(.isHeader)
            if !metadata.isEmpty {
                Text(metadata)
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
        }
    }
}

struct TripStatusHeader: View {
    let trip: CustomerTrip
    let notice: String

    private var message: String {
        var lines = [notice]
        if trip.summary?.showsVerifiedPayment == true { lines.append("Payment verified") }
        if let reason = trip.verificationReasonLabel { lines.append(reason) }
        if trip.summary?.showsDeadline == true, let deadline = trip.bookingDeadlineLabel {
            lines.append("Booking deadline: \(deadline)")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        let status = trip.feedbackStatus
        VStack(alignment: .leading, spacing: NexusSpacing.space12) {
            TripRouteHeader(trip: trip)
            NexusFeedbackPanel(
                title: trip.detailStatusCopy?.title ?? trip.bookingStatusLabel,
                message: message,
                status: status,
                icon: status.feedbackIcon,
                compact: true
            )
        }
    }
}

struct TripItinerary: View {
    let segments: [TripSegment]
    let airline: String?
    let carrier: String?
    let logoURL: URL?
    let departureDate: String
    let travelerCount: Int?
    let showsTripMetadata: Bool

    init(trip: CustomerTrip) {
        self.init(segments: trip.segments, summary: trip.summary, travelerCount: trip.detail?.travelerCount, showsTripMetadata: false)
    }

    init(segments: [TripSegment], summary: TripSummary? = nil, travelerCount: Int? = nil, showsTripMetadata: Bool = true) {
        self.segments = segments
        airline = summary?.airline ?? segments.first?.airline
        carrier = summary?.carrier ?? segments.first?.carrier
        logoURL = summary?.logoURL
        departureDate = summary?.dateLabel
            ?? segments.first?.departureDate.flatMap(TripSummary.dateLabel)
            ?? "Departure date unavailable"
        self.travelerCount = travelerCount
        self.showsTripMetadata = showsTripMetadata
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space12) {
            HStack(spacing: NexusSpacing.space12) {
                AirlineLogoBadge(
                    code: carrier,
                    name: airline,
                    url: logoURL,
                    width: NexusLayout.tripLogoWidth,
                    height: NexusLayout.tripLogoHeight
                )
                VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                    Text(airline ?? carrier ?? "Airline unavailable")
                        .nexusTextStyle(NexusText.styles.listTitleLarge)
                        .foregroundStyle(NexusSemanticColors.textHeading)
                    if showsTripMetadata { note(departureDate) }
                    if showsTripMetadata, let travelerCount {
                        note("\(travelerCount) \(travelerCount == 1 ? "traveler" : "travelers")")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if segments.isEmpty {
                Text("Itinerary details unavailable. Check status to refresh.")
                    .nexusTextStyle(NexusText.styles.body)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }

            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                VStack(alignment: .leading, spacing: NexusSpacing.space12) {
                    if index > 0, let boundary = segment.boundaryLabel(after: segments[index - 1]) {
                        note(boundary)
                    }
                    if segments.count > 1 || segment.flightLabel != "Flight" {
                        note(segment.flightLabel)
                    }
                    if let operatingCarrier = segment.operatingCarrier, operatingCarrier != segment.carrier {
                        note("Operated by \(segment.operatingAirline ?? operatingCarrier)")
                    }
                    if index > 0, let date = segment.departureDate.flatMap(TripSummary.dateLabel) {
                        note(date)
                    }

                    AirportConnection(
                        segment: .init(
                            departureAirportCode: segment.origin ?? "Airport unavailable",
                            arrivalAirportCode: segment.destination ?? "Airport unavailable",
                            departureTime: segment.departureTimeLabel,
                            arrivalTime: segment.arrivalTimeLabel,
                            detail: segment.durationLabel,
                            layover: nil
                        ),
                        departureName: segment.originCity,
                        arrivalName: segment.destinationCity,
                        surface: NexusSemanticColors.backgroundPage,
                        dashLength: NexusSpacing.space4
                    )

                    if let arrival = segment.arrivalDate, arrival.prefix(10) != segment.departureDate?.prefix(10),
                       let date = TripSummary.dateLabel(arrival) {
                        note("Arrives \(date)")
                    }
                    if let departure = segment.departureTerminal { note("Departure terminal \(departure)") }
                    if let arrival = segment.arrivalTerminal { note("Arrival terminal \(arrival)") }
                    if let baggage = segment.baggage { note("Baggage: \(baggage)") }
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .nexusTextStyle(NexusText.styles.bodySmall)
            .foregroundStyle(NexusSemanticColors.textSecondary)
    }
}

struct BookingProgress: View {
    let trip: CustomerTrip

    private var steps: [(String, Bool)] {
        if let progress = trip.summary?.presentation?.progress {
            return [
                ("Flight reserved", progress.booking == "COMPLETE"),
                ("Payment verified", progress.payment == "COMPLETE"),
                ("Ticket issued", progress.ticket == "COMPLETE")
            ]
        }
        return [
            ("Flight reserved", trip.status == "BOOKING_HELD" || trip.status == "TICKETED"),
            ("Payment verified", trip.paymentStatus == "PAID"),
            ("Ticket issued", trip.status == "TICKETED")
        ]
    }

    private let pendingSteps = ["Flight reservation", "Payment verification", "Ticket issuance"]

    private var currentStep: (index: Int, label: String)? {
        switch trip.summary?.presentation?.state {
        case "CONFIRMING": (0, "Confirming reservation")
        case "PAYMENT_UNDER_REVIEW": (1, "Checking payment")
        case "PREPARING_TICKET": (2, "Preparing ticket")
        default: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                let activeLabel = currentStep.flatMap { !step.1 && $0.index == index ? $0.label : nil }
                HStack(alignment: .top, spacing: NexusSpacing.space12) {
                    NexusIcon(name: step.1 ? .check : .clock, size: NexusIconSize.md)
                        .foregroundStyle(step.1 ? NexusSemanticColors.brandPrimary : NexusSemanticColors.textSecondary)
                        .accessibilityHidden(true)
                    Text(activeLabel ?? (step.1 ? step.0 : pendingSteps[index]))
                        .nexusTextStyle(NexusText.styles.body.withFontWeight(step.1 ? .semibold : .regular))
                        .foregroundStyle(step.1 ? NexusSemanticColors.textPrimary : NexusSemanticColors.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(step.1 ? "Confirmed" : (activeLabel == nil ? "Not confirmed" : "In progress"))
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(NexusSemanticColors.borderDefault)
                        .frame(width: NexusBorder.hairline, height: NexusSpacing.space16)
                        .padding(.leading, NexusSpacing.space12)
                        .padding(.vertical, NexusSpacing.space4)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

struct TripPaymentReference: View {
    let trip: CustomerTrip

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space12) {
            if let total = trip.totalLabel {
                label("Total")
                Text(total)
                    .nexusTextStyle(NexusText.styles.priceAmountSmall)
                    .foregroundStyle(NexusSemanticColors.brandPrimary)
            }
            label("Booking reference")
            Text(trip.detail?.reference ?? trip.id)
                .nexusTextStyle(NexusText.styles.body)
                .foregroundStyle(NexusSemanticColors.textPrimary)
        }
    }

    private func label(_ value: String) -> some View {
        Text(value)
            .nexusTextStyle(NexusText.styles.bodySmall)
            .foregroundStyle(NexusSemanticColors.textSecondary)
    }
}

struct DetailTextSection: View {
    let title: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space8) {
            Text(title)
                .nexusTextStyle(NexusText.styles.sectionTitleSmall)
                .foregroundStyle(NexusSemanticColors.textHeading)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .nexusTextStyle(NexusText.styles.body)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
        }
    }
}

struct SeatReservationSection: View {
    let checking: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space8) {
            Text("Seat reservation")
                .nexusTextStyle(NexusText.styles.sectionTitle)
                .foregroundStyle(NexusSemanticColors.textHeading)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: NexusSpacing.space8) {
                if checking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(NexusSemanticColors.brandPrimary)
                        .accessibilityHidden(true)
                }
                Text(checking
                     ? "Checking your seat reservation…"
                     : "We couldn’t confirm your seat reservation yet. Check status for updates.")
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
            NexusTextButton("Check status", action: onRetry)
        }
    }
}

struct TripChangeSheet: View {
    let change: TripDetail.ItineraryChange?
    let onRefresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusSpacing.space24) {
                Text("Review changes")
                    .nexusTextStyle(NexusText.styles.screenTitle)
                    .foregroundStyle(NexusSemanticColors.textHeading)
                    .accessibilityAddTraits(.isHeader)
                if let change {
                    if change.previous.isEmpty {
                        note("Previous itinerary details aren’t available.")
                    } else {
                        heading("Previous itinerary")
                        TripItinerary(segments: change.previous)
                        Divider()
                    }
                    heading("Updated itinerary")
                    TripItinerary(segments: change.current)
                    note("Reviewing does not accept these changes. Contact support for next steps.")
                } else {
                    NexusFeedbackPanel(
                        title: "Change details unavailable",
                        message: "Refresh to retrieve confirmed itinerary changes.",
                        primaryActionLabel: "Check status",
                        onPrimaryAction: onRefresh
                    )
                }
            }
            .padding(NexusLayout.screenMargin)
        }
        .background(NexusSemanticColors.backgroundPage.ignoresSafeArea())
    }

    private func heading(_ value: String) -> some View {
        Text(value).nexusTextStyle(NexusText.styles.sectionTitleSmall)
            .foregroundStyle(NexusSemanticColors.textHeading)
            .accessibilityAddTraits(.isHeader)
    }

    private func note(_ value: String) -> some View {
        Text(value).nexusTextStyle(NexusText.styles.bodySmall)
            .foregroundStyle(NexusSemanticColors.textSecondary)
    }
}

enum TripDetailDate {
    static func updatedLabel(_ value: String) -> String? {
        let standard = Date.ISO8601FormatStyle()
        let fraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        guard let date = (try? standard.parse(value)) ?? (try? fraction.parse(value)) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter.string(from: date)
    }
}
