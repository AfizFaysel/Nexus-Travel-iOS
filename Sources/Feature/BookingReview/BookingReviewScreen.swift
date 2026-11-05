import SwiftUI

struct BookingReviewScreenRoute: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: BookingReviewViewModel
    @State private var eventTask: Task<Void, Never>?
    let flightDetails: FlightDetails?
    let router: Router
    let onSearchAgain: () -> Void
    init(
        viewModel: BookingReviewViewModel,
        flightDetails: FlightDetails?,
        router: Router,
        onSearchAgain: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.flightDetails = flightDetails
        self.router = router
        self.onSearchAgain = onSearchAgain
    }
    var body: some View {
        BookingReviewScreen(viewModel: viewModel, flightDetails: flightDetails, send: send)
            .task { do { try await viewModel.load() } catch is CancellationError { return } catch { return } }
            .onDisappear { eventTask?.cancel() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { eventTask?.cancel() }
            }
    }
    private func send(_ event: BookingReviewEvent) {
        guard eventTask == nil else { return }
        eventTask = Task {
            do {
                switch event {
                case .back: viewModel.back()
                case .retry: try await viewModel.load()
                case .checkStatus: try await viewModel.checkStatus()
                case .chooseAnotherFlight: viewModel.chooseAnotherFlight()
                case .reviewUpdatedPrice: try await viewModel.reviewUpdatedPrice()
                case .acceptUpdatedPrice: try await viewModel.acceptUpdatedPrice()
                case .submit: try await viewModel.submit()
                case .home: viewModel.home()
                case .payment: viewModel.payment()
                case .trip: viewModel.trip()
                }
            } catch is CancellationError { eventTask = nil; return } catch { eventTask = nil; return }
            route(); eventTask = nil
        }
    }
    private func route() {
        while let event = viewModel.consumeNavigation() {
            switch event {
            case .back: router.pop()
            case .home: router.popToRoot()
            case .chooseAnotherFlight: onSearchAgain()
            case let .payment(id): router.push(.paymentProof(.init(bookingId: id)))
            case let .trip(id): router.push(.tripDetail(.init(tripId: id)))
            }
        }
    }
}

enum BookingReviewEvent: Equatable, Sendable {
    case back, retry, checkStatus, chooseAnotherFlight, reviewUpdatedPrice, acceptUpdatedPrice
    case submit, home, payment, trip
}

struct BookingReviewScreen: View {
    @Bindable var viewModel: BookingReviewViewModel
    @State private var showsPriceDecision = false
    let flightDetails: FlightDetails?
    let send: (BookingReviewEvent) -> Void
    var body: some View {
        Group {
            switch viewModel.state.screenState {
            case .loading: ProgressView("Loading booking review").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error:
                NexusFeedbackPanel(
                    title: "Could not load booking review", message: viewModel.state.message ?? "Please retry.",
                    primaryActionLabel: viewModel.state.canRetryLoad ? "Try again" :
                        (viewModel.state.recoveryAction != nil ? "Search again" : nil),
                    onPrimaryAction: viewModel.state.canRetryLoad ? { send(.retry) } :
                        (viewModel.state.recoveryAction != nil ? { send(.chooseAnotherFlight) } : nil)
                )
                .padding(NexusSpacing.space16)
            case .content: review
            case .submitted: submitted
            }
        }
        .navigationTitle("Review booking").navigationBarBackButtonHidden()
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Back", systemImage: NexusIconName.back.systemName) { send(.back) } } }
        .onChange(of: viewModel.state.pendingPriceQuote) { _, quote in
            showsPriceDecision = quote != nil
        }
        .alert("Price changed", isPresented: $showsPriceDecision) {
            Button("Search again") { viewModel.dismissPriceQuote(); send(.chooseAnotherFlight) }
            Button("Accept new price") { send(.acceptUpdatedPrice) }
            Button("Not now", role: .cancel) { viewModel.dismissPriceQuote() }
        } message: {
            if let quote = viewModel.state.pendingPriceQuote {
                if quote.seatSelectionWillBeCleared {
                    Text("Total changed from \(quote.previousTotal) to \(quote.newTotal). Your selected seats will be cleared. No flight has been held. Accept this fare before requesting a new hold.")
                } else {
                    Text("Total changed from \(quote.previousTotal) to \(quote.newTotal). No flight has been held. Accept this fare before requesting a new hold.")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.state.screenState == .content, let details = viewModel.state.details {
                VStack(spacing: NexusSpacing.space8) {
                    ViewThatFits(in: .horizontal) { HStack { Text("Total"); Spacer(); Text(details.fareTotal.formatted).fontWeight(.bold) }; VStack(alignment: .leading) { Text("Total"); Text(details.fareTotal.formatted).fontWeight(.bold) } }
                    Text("The airline hold is requested when you tap Book flight. A ticket is issued after payment verification.")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    NexusPrimaryButton("Book flight", isEnabled: details.status == .draftSaved
                                       && !viewModel.state.bookingOutcomeUnknown
                                       && !viewModel.state.isCheckingStatus && !viewModel.state.isRepricing
                                       && !viewModel.state.isAcceptingPrice && viewModel.state.pendingPriceQuote == nil
                                       && viewModel.state.recoveryAction == nil,
                                       isLoading: viewModel.state.isSubmitting, loadingTitle: "Booking…", fillsWidth: true) { send(.submit) }
                }.padding(NexusSpacing.space16).background(.regularMaterial)
            }
        }
    }

    private var review: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NexusSpacing.space16) {
                if let flightDetails {
                    Text("\(flightDetails.originCode) → \(flightDetails.destinationCode)").font(.title2.bold())
                    Text("\(flightDetails.departureDate.reviewLabel) · \(flightDetails.travelers.summary()) · \(flightDetails.cabinLabel)").foregroundStyle(.secondary)
                }
                if let details = viewModel.state.details {
                    notice(details.status.label, statusMessage(details.status))
                    section("Passenger details", rows: details.passengers.enumerated().flatMap { index, passenger in
                        [(index == 0 ? "Passenger" : "Passenger \(index + 1)", "\(passenger.title) \(passenger.firstName) \(passenger.lastName)"),
                         ("Passport", passenger.passportNumber), ("Nationality", passenger.nationality)]
                    })
                    section("Contact details", rows: [("Email", details.contact.email), ("Mobile", details.contact.phone)])
                    section("Seats", rows: details.seats.isEmpty ? [("Seats", "Airline will assign seats")] : details.seats.map {
                        ("Passenger \($0.passengerIndex + 1)", "\($0.seatNumber) · Flight \($0.segmentId.replacingOccurrences(of: "segment-", with: ""))")
                    })
                    fareSection(details)
                    if details.status == .draftSaved {
                        notice("Next step", "If the airline confirms a hold, upload your payment receipt for verification. Your ticket is not issued yet.")
                    }
                }
                if let message = viewModel.state.message {
                    NexusFeedbackPanel(
                        title: feedbackTitle, message: message,
                        primaryActionLabel: feedbackActionLabel,
                        onPrimaryAction: feedbackAction
                    )
                    if viewModel.state.isCheckingStatus { ProgressView("Checking booking status…") }
                    if viewModel.state.isRepricing { ProgressView("Checking current fare…") }
                    if viewModel.state.isAcceptingPrice { ProgressView("Confirming updated fare…") }
                    if viewModel.state.bookingOutcomeUnknown, let bookingId = viewModel.state.details?.reviewId {
                        SupportOptionsView(bookingId: bookingId)
                    }
                    if let checkedAt = lastSupplierCheckLabel {
                        Text(checkedAt).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(NexusSpacing.space16)
        }
    }

    private var submitted: some View {
        VStack(spacing: NexusSpacing.space16) {
            NexusIcon(name: .check, size: 64).foregroundStyle(.green).accessibilityHidden(true)
            Text(viewModel.state.canUploadProof ? "Flight held" : "Booking status updated")
                .font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(viewModel.state.canUploadProof
                 ? "The airline confirmed your hold. Your ticket is not issued yet. Upload your payment receipt so our team can verify it."
                 : "View your trip for the current payment and ticket status.")
                .foregroundStyle(.secondary)
            if let reference = viewModel.state.details?.bookingReference { notice("Booking ref", reference) }
            if let checkedAt = lastSupplierCheckLabel {
                Text(checkedAt).font(.caption).foregroundStyle(.secondary)
            }
            if viewModel.state.canUploadProof {
                NexusPrimaryButton("Upload payment receipt", fillsWidth: true) { send(.payment) }
            }
            NexusSecondaryButton("View trip", fillsWidth: true) { send(.trip) }
        }.multilineTextAlignment(.center).padding(NexusSpacing.space24)
    }

    private var feedbackTitle: String {
        if viewModel.state.recoveryAction == .reviewUpdatedPrice { return "Price changed" }
        if viewModel.state.recoveryAction != nil { return "Fare needs a new search" }
        switch viewModel.state.statusOutcome {
        case .changedHoldReview: return "Hold needs review"
        case .notHeld: return "No flight was held"
        case .pending: return "Booking request in progress"
        case .unknown: return "Checking airline confirmation"
        case .expired: return "Hold expired"
        case .cancelled: return "Hold cancelled"
        default: return "Booking status needs checking"
        }
    }

    private var feedbackActionLabel: String? {
        if viewModel.state.recoveryAction == .reviewUpdatedPrice {
            return "Check current fare"
        }
        if viewModel.state.recoveryAction != nil {
            return "Search again"
        }
        if let outcome = viewModel.state.statusOutcome, [.notHeld, .expired, .cancelled].contains(outcome) {
            return viewModel.state.allowedNextActions.contains(.searchAgain) ? "Search again" : nil
        }
        if viewModel.state.bookingOutcomeUnknown {
            let mayCheckAgain = viewModel.state.allowedNextActions.contains(.checkStatus) ||
                viewModel.state.reconciliationState == .notNeeded
            return mayCheckAgain ? "Check booking status" : nil
        }
        return nil
    }

    private var feedbackAction: (() -> Void)? {
        if feedbackActionLabel == "Check current fare" { return { send(.reviewUpdatedPrice) } }
        if feedbackActionLabel == "Search again" { return { send(.chooseAnotherFlight) } }
        if feedbackActionLabel == "Check booking status" { return { send(.checkStatus) } }
        return nil
    }

    private var lastSupplierCheckLabel: String? {
        guard let value = viewModel.state.lastSupplierCheckedAt else { return nil }
        let parser = ISO8601DateFormatter()
        var date = parser.date(from: value)
        if date == nil {
            parser.formatOptions.insert(.withFractionalSeconds)
            date = parser.date(from: value)
        }
        guard let date else { return nil }
        return "Last checked with the airline: \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func section(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space12) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                ViewThatFits(in: .horizontal) { HStack(alignment: .firstTextBaseline) { Text(row.0).foregroundStyle(.secondary); Spacer(); Text(row.1).multilineTextAlignment(.trailing) }; VStack(alignment: .leading) { Text(row.0).foregroundStyle(.secondary); Text(row.1) } }
            }
        }.padding(NexusSpacing.space16).background(.background, in: .rect(cornerRadius: NexusRadius.lg))
    }
    private func fareSection(_ details: BookingReviewDetails) -> some View {
        let seatAmount = details.seats.compactMap(\.price).reduce(0) { $0 + $1.amount }
        var rows: [(String, String)] = []
        if let flightDetails, flightDetails.price.amount + seatAmount == details.fareTotal.amount {
            rows.append(("Base fare", flightDetails.priceBreakdown.baseFare.formatted))
            rows.append(("Taxes and fees", flightDetails.priceBreakdown.taxesAndFees.formatted))
            if let fee = flightDetails.priceBreakdown.serviceFee { rows.append(("Service fee", fee.formatted)) }
            if seatAmount > 0 { rows.append(("Seat fees", String(format: "%@ %.2f", details.fareTotal.currency, Double(seatAmount) / 100))) }
        }
        rows.append(("Total", details.fareTotal.formatted))
        return section("Fare summary", rows: rows)
    }
    private func notice(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space4) { Text(title).font(.headline); Text(message).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(NexusSpacing.space16)
            .background(Color.accentColor.opacity(0.1), in: .rect(cornerRadius: NexusRadius.lg))
    }
    private func statusMessage(_ status: BookingRequestStatus) -> String {
        switch status {
        case .draftSaved: "Review details before booking this flight."
        case .submittedForManualReview: "Flight held. Upload your payment receipt for verification. Your ticket is not issued yet."
        case .agentReviewing: "Our team is checking this booking."
        case .holdPending: "Booking request in progress. Don't book or pay again yet."
        case .holdUnconfirmed: "Checking airline confirmation. Don't book or pay again yet."
        case .holdChangeReview: "Hold needs review. Don't pay yet."
        case .holdFailed: "No flight was held. Your passenger details are saved."
        case .confirmed: "Booking confirmed."
        case .expired: "This fare expired. Choose another flight."
        case .unavailable: "This fare is no longer available."
        case .none: "No booking exists for this flight."
        }
    }
}

private extension LocalDate {
    var reviewLabel: String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(months[month - 1]) \(day), \(year)"
    }
}
