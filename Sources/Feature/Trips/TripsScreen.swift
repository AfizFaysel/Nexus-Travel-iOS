import QuickLook
import SwiftUI

struct TripsScreenRoute: View {
    @State private var viewModel: TripsViewModel
    @State private var refreshTask: Task<Void, Never>?
    @Binding var rootScrollTarget: String?
    @Environment(\.scenePhase) private var scenePhase
    let router: Router

    init(viewModel: TripsViewModel, router: Router, rootScrollTarget: Binding<String?>) {
        _viewModel = State(initialValue: viewModel)
        _rootScrollTarget = rootScrollTarget
        self.router = router
    }

    var body: some View {
        TripsScreen(
            state: viewModel.state,
            rootScrollTarget: $rootScrollTarget,
            onSelect: { group in Task { try? await viewModel.select(group) } },
            onOpen: { router.push(.tripDetail(.init(tripId: $0))) },
            onUpload: { router.push(.paymentProof(.init(bookingId: $0))) },
            onSignIn: { router.presentAuthentication(for: .trips) },
            onRetry: { Task { try? await viewModel.load(forceRefresh: true) } }
        )
        .task { try? await viewModel.loadIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onChange(of: router.selectedTab) { _, tab in
            if tab == .trips { refresh() }
        }
        .onDisappear { refreshTask?.cancel() }
        .refreshable { try? await viewModel.load(forceRefresh: true) }
        .onChange(of: router.authPresentation) { previous, current in
            guard previous == .trips, current == nil else { return }
            Task { try? await viewModel.load(forceRefresh: true) }
        }
    }

    private func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { try? await viewModel.load(forceRefresh: true) }
    }
}

private struct TripsScreen: View {
    let state: TripsUiState
    @Binding var rootScrollTarget: String?
    let onSelect: (TripGroup) -> Void
    let onOpen: (String) -> Void
    let onUpload: (String) -> Void
    let onSignIn: () -> Void
    let onRetry: () -> Void
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: NexusSpacing.space20) {
            Text("Trips").nexusTextStyle(NexusText.styles.screenTitle).accessibilityAddTraits(.isHeader).id("trips.header")
            switch state.access {
            case .guest: guestTrips
            case .loading: ProgressView().frame(maxWidth: .infinity).accessibilityLabel("Loading trips")
            case .recoverableError:
                ContentUnavailableView("Trips are unavailable", systemImage: NexusIconName.warning.systemName, description: Text(state.error ?? "We could not access your saved session."))
                NexusSecondaryButton("Retry", fillsWidth: true, action: onRetry)
            case .authenticated:
                Picker(
                    "Trip section",
                    selection: Binding(
                        get: { state.selectedGroup },
                        set: { group in onSelect(group) }
                    )
                ) {
                    ForEach(TripGroup.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .id("trips.group")
                if state.offline {
                    NexusBanner(text: state.lastUpdated.map {
                        "Offline. Last updated \($0.formatted(date: .abbreviated, time: .shortened)). Status may have changed."
                    } ?? "Offline. Showing saved trip status; it may have changed.", status: .offline, trailingAction: {
                        Button("Try again", action: onRetry)
                            .nexusTextStyle(NexusText.styles.link)
                            .foregroundStyle(NexusSemanticColors.actionPrimaryText)
                            .frame(minHeight: NexusLayout.touchMin)
                    })
                }
                if let error = state.error {
                    NexusBanner(text: error, status: .error, trailingAction: {
                        NexusTextButton("Try again", action: onRetry)
                    })
                }
                if state.loading { ProgressView().frame(maxWidth: .infinity).accessibilityLabel("Loading trips") }
                else if state.visibleTrips.isEmpty { ContentUnavailableView("No trips in this section.", systemImage: NexusIconName.flight.systemName) }
                else { ForEach(state.visibleTrips, id: \.id) { trip in TripCard(trip: trip, onOpen: { onOpen(trip.id) }, onPrimary: { if trip.canUploadReceipt { onUpload(trip.id) } else { onOpen(trip.id) } }).id("trips.trip.\(trip.id)") } }
            }
        }.padding(NexusSpacing.space24).scrollTargetLayout() }
            .scrollPosition(id: $rootScrollTarget, anchor: .top)
            .accessibilityIdentifier("root-trips")
            .background(NexusSemanticColors.backgroundPage)
            .navigationBarHidden(true)
    }

    private var guestTrips: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space16) {
            NexusIcon(name: .trips, size: NexusIconSize.xl)
                .foregroundStyle(NexusSemanticColors.brandPrimary)
            Text("No trips yet")
                .nexusTextStyle(NexusText.styles.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            Text("Sign in to see bookings, tickets, and trip updates.")
                .nexusTextStyle(NexusText.styles.body)
                .foregroundStyle(NexusSemanticColors.textSecondary)
            NexusTextButton("Sign in to view trips", action: onSignIn)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, NexusSpacing.space64)
        .id("trips.guest")
    }

}
private struct TripCard: View {
    let trip: CustomerTrip; let onOpen, onPrimary: () -> Void
    var body: some View { VStack(alignment: .leading, spacing: NexusSpacing.space12) {
        HStack { NexusStatusChip(text: trip.group.label, status: trip.group == .actionRequired ? .warning : .success); Spacer(); Text("Ref \(trip.id.prefix(8).uppercased())").nexusTextStyle(NexusText.styles.caption) }
        Text(trip.itineraryLabel).nexusTextStyle(NexusText.styles.flightTime)
        if !trip.seats.isEmpty { Text("Seat \(trip.seats.map(\.seatNumber).joined(separator: ", "))").nexusTextStyle(NexusText.styles.bodySmall) }
        HStack { Text(trip.bookingStatusLabel); Spacer(); if let amount = trip.amountMinor { Text("\(trip.currency ?? "") \(amount / 100)").foregroundStyle(NexusSemanticColors.brandPrimary) } }
        .nexusTextStyle(NexusText.styles.label)
        Text(trip.uiState.notice)
            .nexusTextStyle(NexusText.styles.bodySmall)
            .foregroundStyle(NexusSemanticColors.textSecondary)
        ViewThatFits(in: .horizontal) {
            HStack { NexusSecondaryButton("View details", action: onOpen); Spacer(); NexusPrimaryButton(trip.canUploadReceipt ? "Upload receipt" : "View status", action: onPrimary) }
            VStack { NexusSecondaryButton("View details", fillsWidth: true, action: onOpen); NexusPrimaryButton(trip.canUploadReceipt ? "Upload receipt" : "View status", fillsWidth: true, action: onPrimary) }
        }
    }.padding(NexusSpacing.space20).background(NexusSemanticColors.surfaceBase).clipShape(RoundedRectangle(cornerRadius: NexusRadius.xl)).overlay(RoundedRectangle(cornerRadius: NexusRadius.xl).stroke(NexusSemanticColors.borderDefault)) }
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
