import QuickLook
import SwiftUI

struct TripsScreenRoute: View {
    @State private var viewModel: TripsViewModel
    @State private var refreshTask: Task<Void, Never>?
    @State private var paginationTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    let router: Router

    init(viewModel: TripsViewModel, router: Router) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
    }

    private var shouldRetryWhenConnected: Bool {
        let state = viewModel.state
        return state.access == .authenticated && (state.offline || state.error != nil)
    }

    var body: some View {
        TripsScreen(
            state: viewModel.state,
            onSelect: select,
            onOpen: { router.push(.tripDetail(.init(tripId: $0))) },
            onSignIn: { router.presentAuthentication(for: .trips) },
            onRetry: refresh,
            onLoadMore: loadMore
        )
        .task { try? await viewModel.loadIfNeeded() }
        .task(id: shouldRetryWhenConnected) {
            guard shouldRetryWhenConnected, await NetworkRecovery.waitForConnectionReturn() else { return }
            refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onChange(of: router.selectedTab) { _, tab in
            if tab == .trips { refresh() }
        }
        .onDisappear {
            refreshTask?.cancel()
            paginationTask?.cancel()
        }
        .refreshable { try? await viewModel.load(forceRefresh: true) }
        .onChange(of: router.authPresentation) { previous, current in
            guard previous == .trips, current == nil else { return }
            refresh()
        }
    }

    private func select(_ view: TripView) {
        guard viewModel.state.selectedView != view else { return }
        refreshTask?.cancel()
        paginationTask?.cancel()
        refreshTask = Task { try? await viewModel.select(view) }
    }

    private func loadMore() {
        guard !viewModel.state.loadingMore else { return }
        paginationTask?.cancel()
        paginationTask = Task { try? await viewModel.loadMore() }
    }

    private func refresh() {
        paginationTask?.cancel()
        refreshTask?.cancel()
        refreshTask = Task { try? await viewModel.load(forceRefresh: true) }
    }
}

private struct TripsScreen: View {
    let state: TripsUiState
    let onSelect: (TripView) -> Void
    let onOpen: (String) -> Void
    let onSignIn: () -> Void
    let onRetry: () -> Void
    let onLoadMore: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let spacing = NexusAdaptiveSpacing(
                screenWidth: geometry.size.width,
                screenHeight: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            )
            let top = spacing?.screenTopPadding ?? NexusSpacing.space24
            let bottom = spacing?.contentBottomPaddingWithCta ?? NexusLayout.defaultContentBottomPaddingWithCta
            let margin = spacing?.screenMargin ?? NexusLayout.screenMargin
            ScrollView {
                Group {
                    if state.access == .guest {
                        guestPage(minHeight: max(0, geometry.size.height - top - bottom))
                    } else {
                        LazyVStack(alignment: .leading, spacing: NexusSpacing.space24) {
                            heading
                            switch state.access {
                            case .guest, .loading: EmptyView()
                            case .recoverableError: feedback
                            case .authenticated: tripList(width: geometry.size.width - margin - margin)
                            }
                        }
                    }
                }
                .padding(.horizontal, margin)
                .padding(.top, top)
                .padding(.bottom, bottom)
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .scrollIndicators(.hidden)
            .clipped()
            .accessibilityIdentifier("root-trips")
            .overlay {
                if state.loading && state.trips.isEmpty {
                    ProgressView()
                        .tint(NexusSemanticColors.brandPrimary)
                        .accessibilityLabel("Loading trips")
                }
            }
        }
        .background(NexusSemanticColors.backgroundPage.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var heading: some View {
        Text("Trips")
            .nexusTextStyle(NexusText.styles.screenTitle)
            .foregroundStyle(NexusSemanticColors.textHeading)
            .accessibilityAddTraits(.isHeader)
    }

    private func guestPage(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space0) {
            heading
                .padding(.bottom, NexusSpacing.space32)
            Spacer(minLength: NexusSpacing.space0)
            guestTrips
            Spacer(minLength: NexusSpacing.space24)
            Spacer(minLength: NexusSpacing.space0)
        }
        .frame(minHeight: minHeight, alignment: .topLeading)
    }

    private func tripList(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space24) {
            tabs
            if state.offline {
                VStack(alignment: .leading, spacing: NexusSpacing.space8) {
                    NexusInlineStatusBanner(
                        text: "Offline. Saved trip status may have changed.",
                        status: .offline,
                        onRetry: onRetry
                    )
                    if let lastUpdated = state.lastUpdated {
                        Text("Last updated \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                            .nexusTextStyle(NexusText.styles.bodySmall)
                            .foregroundStyle(NexusSemanticColors.textSecondary)
                    }
                }
            } else if state.error != nil {
                feedback
            }

            if !state.loading, state.visibleTrips.isEmpty, state.error == nil {
                Text(state.selectedView == .active
                     ? "No active trips. Your next booking will appear here."
                     : "No trip history yet.")
                    .nexusTextStyle(NexusText.styles.body)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }

            ForEach(state.sections, id: \.self) { section in
                let trips = state.visibleTrips.filter { $0.listSection == section }
                if !trips.isEmpty {
                    LazyVStack(alignment: .leading, spacing: NexusSpacing.space0) {
                        if let title = section.title {
                            Text(title)
                                .nexusTextStyle(NexusText.styles.sectionTitleSmall)
                                .foregroundStyle(NexusSemanticColors.textHeading)
                                .accessibilityAddTraits(.isHeader)
                        }
                        ForEach(trips, id: \.id) { trip in
                            TripSummaryRow(trip: trip, narrow: width < NexusLayout.tripNarrowWidth) { onOpen(trip.id) }
                            Rectangle()
                                .fill(NexusSemanticColors.borderSubtle)
                                .frame(height: NexusBorder.hairline)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }

            if state.nextCursor != nil {
                NexusTextButton(
                    state.loadingMore ? "Loading more…" : "Load more trips",
                    isEnabled: !state.loadingMore && !state.offline && !state.refreshing,
                    action: onLoadMore
                )
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: NexusSpacing.space0) {
            ForEach(TripView.allCases, id: \.self) { view in
                let selected = state.selectedView == view
                Button {
                    onSelect(view)
                } label: {
                    Text(view.title)
                        .nexusTextStyle(NexusText.styles.body)
                        .foregroundStyle(selected ? NexusSemanticColors.brandPrimary : NexusSemanticColors.textSecondary)
                        .padding(.vertical, NexusSpacing.space8)
                        .frame(maxWidth: .infinity, minHeight: NexusLayout.touchRecommended)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) {
                            if selected {
                                Rectangle()
                                    .fill(NexusSemanticColors.brandPrimary)
                                    .frame(height: NexusLayout.tripTabIndicatorHeight)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var feedback: some View {
        NexusFeedbackPanel(
            title: "Trips couldn’t refresh",
            message: state.error ?? "Try again to load trips.",
            primaryActionLabel: "Try again",
            onPrimaryAction: onRetry
        )
    }

    private var guestTrips: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space0) {
            NexusIcon(name: .trips, size: NexusIconSize.xl)
                .foregroundStyle(NexusSemanticColors.brandPrimary)
                .accessibilityHidden(true)
                .padding(.bottom, NexusSpacing.space24)
            Text("Your trips, in one place")
                .nexusTextStyle(NexusText.styles.sectionTitle)
                .foregroundStyle(NexusSemanticColors.textHeading)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, NexusSpacing.space8)
            Text("Sign in to see your bookings, tickets and trip updates.")
                .nexusTextStyle(NexusText.styles.body)
                .foregroundStyle(NexusSemanticColors.textSecondary)
                .padding(.bottom, NexusSpacing.space24)
            NexusPrimaryButton(
                "Sign in",
                minWidth: NexusLayout.compactActionMinWidth,
                minHeight: NexusLayout.contextualButtonHeight,
                cornerRadius: NexusRadius.contextualButton,
                action: onSignIn
            )
            .accessibilityIdentifier("trips-sign-in")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TripSummaryRow: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let trip: CustomerTrip
    let narrow: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .trailing, spacing: NexusSpacing.space12) {
                HStack(spacing: NexusSpacing.space12) {
                    logo
                    VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                        Text(trip.summary?.route.label ?? trip.itineraryLabel)
                            .nexusTextStyle(NexusText.styles.listTitleLarge)
                            .foregroundStyle(NexusSemanticColors.textHeading)
                        secondary(trip.summary?.dateLabel ?? "Departure date unavailable")
                        secondary(airlineLabel)
                        if trip.summary?.showsDeadline == true, let deadline = trip.bookingDeadlineLabel {
                            secondary("Booking deadline: \(deadline)")
                        }
                        if !usesFooter { status }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    NexusIcon(name: .chevronRight, size: NexusIconSize.md)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                        .accessibilityHidden(true)
                }
                if usesFooter { status }
            }
            .padding(.vertical, NexusSpacing.space20)
            .frame(minHeight: NexusLayout.touchRecommended)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("View trip details")
    }

    private var usesFooter: Bool { narrow || textSize >= .xxxLarge }

    private var airlineLabel: String {
        guard let label = trip.summary?.carrierLabel, !label.isEmpty else { return "Airline unavailable" }
        return label
    }

    private var logo: some View {
        AirlineLogoBadge(
            code: trip.summary?.carrier,
            name: trip.summary?.airline,
            url: trip.summary?.logoURL,
            width: NexusLayout.tripLogoWidth,
            height: NexusLayout.tripLogoHeight
        )
    }

    private var status: some View {
        VStack(alignment: .trailing, spacing: NexusSpacing.space4) {
            Text(trip.summary?.statusLabel ?? "Status unavailable")
                .nexusTextStyle(NexusText.styles.tripStatus)
                .foregroundStyle(statusColor)
            if trip.summary?.showsVerifiedPayment == true {
                secondary("Payment verified")
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .multilineTextAlignment(.trailing)
    }

    private var statusColor: Color {
        if trip.listSection == .attention { return NexusSemanticColors.warningText }
        if trip.summary?.presentation?.state == "TICKET_READY" { return NexusSemanticColors.successText }
        return NexusSemanticColors.textPrimary
    }

    private func secondary(_ value: String) -> some View {
        Text(value)
            .nexusTextStyle(NexusText.styles.bodySmall)
            .foregroundStyle(NexusSemanticColors.textSecondary)
    }
}

struct TripDetailScreenRoute: View {
    @State private var viewModel: TripDetailViewModel; let router: Router; let onUploadPaymentProof: (String) -> Void
    @State private var previewURL: URL?
    init(viewModel: TripDetailViewModel, router: Router, onUploadPaymentProof: @escaping (String) -> Void) { _viewModel = State(initialValue: viewModel); self.router = router; self.onUploadPaymentProof = onUploadPaymentProof }
    var body: some View {
        TripDetailScreen(state: viewModel.state, onRefresh: { Task { try? await viewModel.load(forceRefresh: true) } }, onTicket: { Task { try? await viewModel.downloadTicket() } }, onUpload: { onUploadPaymentProof(viewModel.state.trip?.id ?? "") })
            .navigationTitle("Trip details").navigationBarTitleDisplayMode(.inline).task { try? await viewModel.load() }
            .onChange(of: viewModel.state.ticketToOpen) { _, value in previewURL = value; if value != nil { viewModel.ticketOpened() } }
            .quickLookPreview($previewURL)
    }
}
private struct TripDetailScreen: View {
    let state: TripDetailUiState; let onRefresh, onTicket, onUpload: () -> Void
    var body: some View { Group {
        if state.loading { ProgressView().accessibilityLabel("Loading trip") }
        else if let trip = state.trip { ScrollView { VStack(alignment: .leading, spacing: NexusSpacing.space16) {
            Text(trip.itineraryLabel).nexusTextStyle(NexusText.styles.screenTitle); Text("Ref \(trip.id.prefix(8).uppercased())").nexusTextStyle(NexusText.styles.bodySmall)
            NexusBanner(text: state.notice, status: noticeStatus(trip))
            if ["HOLD_UNCONFIRMED", "HOLD_CHANGE_REVIEW"].contains(trip.status) {
                SupportOptionsView(bookingId: trip.id)
            }
            if let error = state.error {
                NexusFeedbackPanel(title: "Trip details need attention", message: error)
            }
            detailCard("Status") { HStack { NexusStatusChip(text: trip.bookingStatusLabel, status: noticeStatus(trip)); Spacer(); Text(paymentLabel(trip)).nexusTextStyle(NexusText.styles.label) } }
            if !trip.segments.isEmpty { detailCard("Flights") { ForEach(Array(trip.segments.enumerated()), id: \.offset) { _, segment in VStack(alignment: .leading) { Text(segment.flightLabel).nexusTextStyle(NexusText.styles.label); Text([segment.origin, segment.destination].compactMap { $0 }.joined(separator: " to ")).nexusTextStyle(NexusText.styles.bodySmall) } } } }
            if !trip.seats.isEmpty { detailCard("Seats") { ForEach(Array(trip.seats.enumerated()), id: \.offset) { _, seat in Text("Seat \(seat.seatNumber)") } } }
            if !trip.tickets.isEmpty { detailCard("Tickets") { ForEach(Array(trip.tickets.enumerated()), id: \.offset) { _, ticket in Text(ticket.ticketNumber ?? "Ticket issued") } } }
            if let primary = state.primaryActionLabel { NexusPrimaryButton(primary, isLoading: state.downloadingTicket || state.refreshing, fillsWidth: true, action: action(primary)) }
            if let secondary = state.secondaryActionLabel { NexusSecondaryButton(secondary, fillsWidth: true, action: onTicket) }
        }.padding(NexusSpacing.space24) } }
        else {
            NexusFeedbackPanel(title: "Could not load trip", message: state.error ?? "Try again to load this trip.",
                               primaryActionLabel: "Try again", onPrimaryAction: onRefresh)
                .padding(NexusSpacing.space24)
        }
    }.background(NexusSemanticColors.backgroundPage) }
    private func action(_ label: String) -> () -> Void { switch label { case "View ticket", "Download again": onTicket; case "Upload payment receipt": onUpload; default: onRefresh } }
    private func detailCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: NexusSpacing.space12) { Text(title).nexusTextStyle(NexusText.styles.sectionTitle); content() }.padding(NexusSpacing.space20).frame(maxWidth: .infinity, alignment: .leading).background(NexusSemanticColors.surfaceBase).clipShape(RoundedRectangle(cornerRadius: NexusRadius.xl)) }
}
private func humanize(_ value: String) -> String { value.replacingOccurrences(of: "_", with: " ").lowercased().capitalized }
private func paymentLabel(_ trip: CustomerTrip) -> String {
    if ["HOLD_UNCONFIRMED", "HOLD_CHANGE_REVIEW", "HOLD_REQUESTED", "HOLDING_WITH_TRAVELPORT"].contains(trip.status) {
        return "Do not pay yet"
    }
    if trip.paymentStatus == "PAID" { return "Verified" }
    if trip.paymentProofStatus == "UPLOADED" { return "Receipt under review" }
    if trip.canUploadReceipt { return "Receipt needed" }
    return humanize(trip.paymentStatus)
}
private func noticeStatus(_ trip: CustomerTrip) -> NexusStatus {
    if trip.status == "TICKETED" && trip.ticketDocumentAvailable { .success }
    else if trip.status.contains("FAILED") || trip.ticketingStatus.contains("FAILED") { .error }
    else if ["HOLD_UNCONFIRMED", "HOLD_CHANGE_REVIEW", "HOLD_REQUESTED", "HOLDING_WITH_TRAVELPORT"].contains(trip.status)
                || trip.status.contains("DELAYED") || trip.ticketingStatus == "DELAYED" { .warning }
    else { .info }
}
