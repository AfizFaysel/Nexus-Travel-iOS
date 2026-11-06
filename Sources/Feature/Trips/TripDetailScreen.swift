import QuickLook
import SwiftUI

struct TripDetailScreenRoute: View {
    @State private var viewModel: TripDetailViewModel
    @State private var operation: Task<Void, Never>?
    @State private var previewURL: URL?
    @State private var previousTicket: URL?
    @State private var showsSavedTicketWarning = false
    @State private var sheet: DetailSheet?
    @Environment(\.dismiss) private var dismiss

    let supportRepository: RemoteSupportRepository
    let onUploadPaymentProof: (String) -> Void
    let onSearchAgain: (CustomerTrip) -> Void
    let onResume: (CustomerTrip) -> Void

    init(
        viewModel: TripDetailViewModel,
        supportRepository: RemoteSupportRepository,
        onUploadPaymentProof: @escaping (String) -> Void,
        onSearchAgain: @escaping (CustomerTrip) -> Void,
        onResume: @escaping (CustomerTrip) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.supportRepository = supportRepository
        self.onUploadPaymentProof = onUploadPaymentProof
        self.onSearchAgain = onSearchAgain
        self.onResume = onResume
    }

    var body: some View {
        TripDetailScreen(
            state: viewModel.state,
            onRefresh: { try? await viewModel.load(forceRefresh: true) },
            onRetry: retry,
            onAction: perform,
            onHelp: { sheet = .help },
            onTicket: { run { try await viewModel.downloadTicket() } },
            onBack: { dismiss() }
        )
        .toolbar { NexusTopBar("Trip details") }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(NexusSemanticColors.backgroundPage, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task { try? await viewModel.load() }
        .onDisappear { operation?.cancel() }
        .onChange(of: viewModel.state.ticketToOpen) { _, url in
            guard let url else { return }
            if viewModel.state.ticketSavedVersionWarning {
                previousTicket = url
                showsSavedTicketWarning = true
            } else {
                previewURL = url
            }
            viewModel.ticketOpened()
        }
        .quickLookPreview($previewURL)
        .alert("Saved ticket may be out of date", isPresented: $showsSavedTicketWarning, presenting: previousTicket) { url in
            Button("Open saved ticket") { previewURL = url; previousTicket = nil }
            Button("Cancel", role: .cancel) { previousTicket = nil }
        } message: { _ in
            Text("We couldn’t load the latest ticket. This saved copy may be from a previous version. Check your trip details before travel.")
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .help:
                SupportOptionsSheet(repository: supportRepository, horizontalPadding: NexusLayout.screenMargin)
            case .changes:
                TripChangeSheet(change: viewModel.state.trip?.detail?.confirmedChange, onRefresh: {
                    sheet = nil
                    retry()
                })
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !viewModel.state.loading, !viewModel.state.refreshing, !viewModel.state.downloadingTicket else { return }
        operation = Task { try? await action() }
    }

    private func retry() {
        run { try await viewModel.retry() }
    }

    private func perform(_ action: TripAction) {
        guard let trip = viewModel.state.trip,
              trip.summary?.presentation == nil || trip.detailActions.contains(action) else { return }
        switch action {
        case .checkStatus, .viewTrip, .viewTicketDetails:
            run { try await viewModel.load(forceRefresh: true) }
        case .downloadTicket:
            run { try await viewModel.downloadTicket() }
        case .uploadPaymentProof:
            if trip.canUploadReceipt { onUploadPaymentProof(trip.id) }
        case .getHelp:
            sheet = .help
        case .reviewChanges:
            sheet = .changes
        case .searchAgain:
            onSearchAgain(trip)
        case .resumeBooking:
            onResume(trip)
        case .viewPaymentProof:
            break
        }
    }

    private enum DetailSheet: String, Identifiable {
        case help
        case changes

        var id: Self { self }
    }
}

private struct TripDetailScreen: View {
    let state: TripDetailUiState
    let onRefresh: @MainActor @Sendable () async -> Void
    let onRetry: () -> Void
    let onAction: (TripAction) -> Void
    let onHelp: () -> Void
    let onTicket: () -> Void
    let onBack: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let spacing = NexusAdaptiveSpacing(
                screenWidth: geometry.size.width,
                screenHeight: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            )
            let margin = spacing?.screenMargin ?? NexusLayout.screenMargin

            Group {
                if let trip = state.trip {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: NexusSpacing.space24) {
                            TripStatusHeader(trip: trip, notice: state.notice)
                            if trip.offersDetailSupport, state.primaryAction != .getHelp {
                                NexusTextButton("Contact support", action: onHelp)
                            }
                            if trip.offline {
                                VStack(alignment: .leading, spacing: NexusSpacing.space8) {
                                    NexusInlineStatusBanner(
                                        text: "Offline. Refresh before submitting proof.",
                                        status: .offline,
                                        onRetry: onRetry
                                    )
                                    if let fetchedAt = trip.fetchedAt {
                                        detailNote("Last updated \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                                    }
                                }
                            }
                            TripItinerary(trip: trip)
                            Rectangle()
                                .fill(NexusSemanticColors.borderSubtle)
                                .frame(height: NexusBorder.hairline)
                                .accessibilityHidden(true)
                            BookingProgress(trip: trip)
                            TripPaymentReference(trip: trip)
                            travelerEvidence(trip)
                            statusEvidence(trip)
                            if let label = state.secondaryActionLabel {
                                NexusSecondaryButton(label, fillsWidth: true, action: onTicket)
                            }
                            if let error = state.error, !trip.offline || state.retryAction != .refresh {
                                NexusFeedbackPanel(
                                    title: "Action couldn’t finish",
                                    message: error,
                                    primaryActionLabel: "Try again",
                                    onPrimaryAction: onRetry
                                )
                            }
                        }
                        .padding(.horizontal, margin)
                        .padding(.vertical, NexusSpacing.space24)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable { await onRefresh() }
                    .accessibilityIdentifier("trip-detail-list")
                    .safeAreaInset(edge: .bottom, spacing: NexusSpacing.space0) {
                        if let title = state.primaryActionLabel, let action = primaryAction, action != .viewTrip {
                            NexusPrimaryButton(
                                title,
                                isEnabled: action != .uploadPaymentProof || trip.canUploadReceipt,
                                isLoading: state.refreshing || state.downloadingTicket,
                                fillsWidth: true,
                                action: { onAction(action) }
                            )
                            .accessibilityIdentifier("trip-detail-primary")
                            .padding(.horizontal, spacing?.stickyCtaPaddingH ?? margin)
                            .padding(.vertical, spacing?.stickyCtaPaddingV ?? NexusSpacing.space12)
                            .background(NexusSemanticColors.surfaceElevated.ignoresSafeArea(edges: .bottom))
                        }
                    }
                } else if state.loading {
                    ProgressView()
                        .tint(NexusSemanticColors.brandPrimary)
                        .accessibilityLabel("Loading trip")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    NexusFeedbackPanel(
                        title: "Trip unavailable",
                        message: state.error ?? "We couldn’t load this trip. Try again or return to Trips.",
                        primaryActionLabel: "Try again",
                        onPrimaryAction: onRetry,
                        secondaryActionLabel: "Back",
                        onSecondaryAction: onBack
                    )
                    .padding(margin)
                }
            }
        }
        .background(NexusSemanticColors.backgroundPage.ignoresSafeArea())
    }

    private var primaryAction: TripAction? {
        if let action = state.primaryAction { return action }
        switch state.primaryActionLabel {
        case "View ticket", "Download again": return .downloadTicket
        case "Upload payment receipt": return .uploadPaymentProof
        case "Refresh", "Check status": return .checkStatus
        default: return nil
        }
    }

    @ViewBuilder private func travelerEvidence(_ trip: CustomerTrip) -> some View {
        let travelerDetails = trip.travelerDetails
        if !travelerDetails.isEmpty {
            DetailTextSection(title: "Travelers", values: travelerDetails)
        } else if !trip.seats.isEmpty {
            DetailTextSection(title: "Seats", values: trip.seats.map(trip.seatLabel))
        }
        if let seat = trip.detail?.seatState, seat == .checking || seat == .unresolved {
            SeatReservationSection(checking: seat == .checking, onRetry: onRetry)
        }
        if travelerDetails.isEmpty, !trip.tickets.isEmpty {
            DetailTextSection(title: "Ticket numbers", values: trip.tickets.compactMap(\.detailLabel))
        }
    }

    @ViewBuilder private func statusEvidence(_ trip: CustomerTrip) -> some View {
        if let updated = trip.summary?.verification?.updatedAt.flatMap(TripDetailDate.updatedLabel) {
            detailNote("Payment status updated \(updated)")
        }
        if trip.summary?.supplierCheckPending == true {
            detailNote("Airline confirmation in progress.")
        } else if trip.summary?.supplierCheckState == "FAILED" {
            detailNote("Airline confirmation needs another check.")
        }
        if let checked = trip.detail?.lastSupplierCheckedAt.flatMap(TripDetailDate.updatedLabel) {
            detailNote("Airline confirmation checked \(checked)")
        }
        if let email = trip.detail?.ticketEmailStatus?.uppercased(), ["SENT", "DELIVERED"].contains(email) {
            detailNote(email == "DELIVERED" ? "Ticket email delivered" : "Ticket email sent")
        }
        if trip.summary?.presentation?.state == "FLIGHT_CHANGED", trip.detailActions.contains(.downloadTicket) {
            VStack(alignment: .leading, spacing: NexusSpacing.space8) {
                detailNote("Your existing ticket does not confirm acceptance of these changes.")
                NexusTextButton("Download existing ticket", action: onTicket)
            }
        }
    }

    private func detailNote(_ value: String) -> some View {
        Text(value).nexusTextStyle(NexusText.styles.bodySmall)
            .foregroundStyle(NexusSemanticColors.textSecondary)
    }
}
