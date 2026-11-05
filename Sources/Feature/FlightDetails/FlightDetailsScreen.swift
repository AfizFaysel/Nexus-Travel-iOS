import SwiftUI

struct FlightDetailsScreenRoute: View {
    @State private var viewModel: FlightDetailsViewModel
    @State private var eventTask: Task<Void, Never>?
    let router: Router
    let bookingFlowState: BookingFlowState
    let reference: FlightOfferReference
    init(
        viewModel: FlightDetailsViewModel,
        router: Router,
        bookingFlowState: BookingFlowState,
        reference: FlightOfferReference
    ) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
        self.bookingFlowState = bookingFlowState
        self.reference = reference
    }
    var body: some View {
        FlightDetailsScreen(state: viewModel.uiState, onEvent: send)
            .task {
                bookingFlowState.selectOffer(reference)
                do { try await viewModel.load() } catch is CancellationError { return } catch { return }
            }
            .onDisappear { eventTask?.cancel() }
    }
    private func send(_ event: FlightDetailsUiEvent) {
        eventTask?.cancel()
        eventTask = Task {
            do { try await viewModel.onEvent(event) } catch is CancellationError { return } catch { return }
            route()
            eventTask = nil
        }
    }
    private func route() {
        while let event = viewModel.consumeNavigationEvent() {
            switch event {
            case .back:
                if viewModel.uiState.canReturnToResults {
                    router.markOfferUnavailable(reference)
                }
                router.pop()
            case .toPassengerDetails:
                guard let details = viewModel.uiState.details,
                      bookingFlowState.acceptPassengerDetails(details) else { return }
                router.push(.passengerDetails(.init()))
            }
        }
    }
}

struct FlightDetailsScreen: View {
    let state: FlightDetailsUiState
    let onEvent: (FlightDetailsUiEvent) -> Void
    var body: some View {
        Group {
            if state.isLoading { ProgressView("Loading flight details...").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let error = state.errorMessage {
                NexusFeedbackPanel(title: state.errorTitle, message: error,
                                   primaryActionLabel: state.canReturnToResults ? "Back to results" : state.canRetryLoad ? "Try again" : nil,
                                   onPrimaryAction: state.canReturnToResults ? { onEvent(.backClicked) } : state.canRetryLoad ? { onEvent(.retryClicked) } : nil)
                    .padding(NexusLayout.screenMargin)
            }
            else if let details = state.details { content(details) }
            else { ContentUnavailableView("Flight details unavailable", systemImage: NexusIconName.flight.systemName, description: Text("Choose another flight and try again.")) }
        }
        .navigationTitle("Flight Details")
        .navigationBarBackButtonHidden()
        .toolbar {
            NexusTopBar("Flight Details")
            ToolbarItem(placement: .topBarLeading) {
                NexusIconActionButton("Back", action: { onEvent(.backClicked) }) {
                    NexusIcon(name: .back)
                }
            }
        }
        .alert("Fare changed", isPresented: .constant(state.pendingPriceChange != nil)) { Button("Review", role: .cancel) { onEvent(.dismissPriceChangeClicked) }; Button("Continue") { onEvent(.acceptPriceChangeClicked) } } message: { if let change = state.pendingPriceChange { Text("Price changed from \(change.previousPrice) to \(change.updatedPrice).") } }
    }
    private func content(_ details: FlightDetails) -> some View {
        GeometryReader { geometry in
            let spacing = NexusAdaptiveSpacing(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
            ScrollView {
                VStack(alignment: .leading, spacing: spacing?.mode == .compact ? NexusSpacing.space16 : NexusSpacing.space24) {
                    airlineHeader(details)
                    if let display = state.display {
                        ForEach(Array(display.legs.enumerated()), id: \.offset) { index, leg in
                            FlightDetailsTimeline(leg: leg, showsLegLabel: display.legs.count > 1, index: index)
                        }
                    }
                    if let warning = state.warningMessage { NexusBanner(text: warning, status: .warning) }
                    Divider().overlay(NexusSemanticColors.borderDefault)
                    baggageAndFareRules(details)
                    Divider().overlay(NexusSemanticColors.borderDefault)
                    aircraftDetails(details.aircraft)
                    if let message = state.actionMessage, state.requiresRevalidation {
                        NexusBanner(text: message, status: .warning, trailingAction: {
                            NexusTextButton("Try again") { onEvent(.retryClicked) }
                        })
                    } else if let message = state.actionMessage {
                        Text(message).nexusTextStyle(NexusText.styles.bodySmall)
                            .foregroundStyle(NexusSemanticColors.textSecondary)
                    }
                }
                .frame(maxWidth: NexusLayout.contentMaxWidth, alignment: .leading)
                .padding(.horizontal, spacing?.screenMargin ?? NexusLayout.screenMargin)
                .padding(.top, NexusSpacing.space8)
                .padding(.bottom, NexusSpacing.space16)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                FlightDetailsStickyCTA(
                    price: state.display?.totalPrice,
                    spacing: spacing,
                    safeAreaBottom: geometry.safeAreaInsets.bottom,
                    isRevalidating: state.isRevalidating,
                    isEnabled: !state.requiresRevalidation,
                    onContinue: { onEvent(.continueClicked) }
                )
            }
        }
        .background(NexusSemanticColors.surfaceBase)
    }

    private func airlineHeader(_ details: FlightDetails) -> some View {
        HStack(spacing: NexusSpacing.space16) {
            AsyncImage(url: details.airline.logoURL) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Text(details.airline.code)
                        .nexusTextStyle(NexusText.styles.label)
                        .foregroundStyle(NexusSemanticColors.brandPrimary)
                }
            }
            .frame(width: NexusSpacing.space56, height: NexusSpacing.space56)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: NexusSpacing.space2) {
                Text(details.airline.name)
                    .nexusTextStyle(NexusText.styles.sectionTitle)
                    .foregroundStyle(NexusSemanticColors.textHeading)
                Text(state.display?.flightMeta ?? details.flightNumber)
                Text(state.display?.dateTravelerMeta ?? "")
            }
            .nexusTextStyle(NexusText.styles.bodySmall)
            .foregroundStyle(NexusSemanticColors.textSecondary)
            Spacer(minLength: NexusSpacing.space0)
        }
    }

    private func baggageAndFareRules(_ details: FlightDetails) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space12) {
            Text("Baggage allowance")
                .nexusTextStyle(NexusText.styles.sectionTitle)
                .foregroundStyle(NexusSemanticColors.textHeading)
                .accessibilityAddTraits(.isHeader)
            BaggageAllowanceColumns(baggage: details.baggage)
            if !details.baggage.detail.isEmpty {
                Text(details.baggage.detail)
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
                    .padding(.top, NexusSpacing.space8)
            }
            Divider().overlay(NexusSemanticColors.borderDefault)
                .padding(.top, NexusSpacing.space12)
            fareRules(details.fareRules)
        }
    }

    private func fareRules(_ rules: FareRulesSummary) -> some View {
        let expanded = state.expandedSections.contains(.fareRules)
        return VStack(alignment: .leading, spacing: NexusSpacing.space8) {
            Button { onEvent(.sectionToggled(.fareRules)) } label: {
                HStack(spacing: NexusSpacing.space8) {
                    VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                        Text("Fare rules")
                            .nexusTextStyle(NexusText.styles.sectionTitleSmall)
                            .foregroundStyle(NexusSemanticColors.textPrimary)
                        Text(rules.refundableLabel)
                            .nexusTextStyle(NexusText.styles.bodySmall)
                            .foregroundStyle(NexusSemanticColors.textSecondary)
                    }
                    Spacer(minLength: NexusSpacing.space0)
                    NexusIcon(name: .chevronDown, size: NexusIconSize.sm)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(NexusSemanticColors.textTertiary)
                }
                .frame(minHeight: NexusLayout.touchMin)
                .padding(.vertical, NexusSpacing.space16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fare rules")
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            if expanded {
                VStack(alignment: .leading, spacing: NexusSpacing.space16) {
                    if rules.sections.isEmpty {
                        Text(rules.changeLabel)
                        Text(rules.cancellationLabel)
                    } else {
                        ForEach(Array(rules.sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: NexusSpacing.space8) {
                                Text(section.title)
                                    .nexusTextStyle(NexusText.styles.listTitle)
                                ForEach(section.items, id: \.self) { Text($0) }
                            }
                        }
                    }
                }
                .nexusTextStyle(NexusText.styles.body)
                .foregroundStyle(NexusSemanticColors.textPrimary)
            }
        }
    }

    private func aircraftDetails(_ aircraft: AircraftSummary) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space4) {
            Text("Aircraft details")
                .nexusTextStyle(NexusText.styles.sectionTitle)
                .foregroundStyle(NexusSemanticColors.textHeading)
                .accessibilityAddTraits(.isHeader)
            Text(aircraft.aircraftName)
                .nexusTextStyle(NexusText.styles.listTitle)
                .foregroundStyle(NexusSemanticColors.textPrimary)
                .padding(.top, NexusSpacing.space8)
            if !aircraft.operatingAirline.isEmpty {
                Text(aircraft.operatingAirline)
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
            if !aircraft.note.isEmpty {
                Text(aircraft.note)
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
        }
    }
}

private struct BaggageAllowanceColumns: View {
    let baggage: BaggageSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: NexusSpacing.space16) {
                    value("Cabin baggage", baggage.cabin)
                    value("Checked baggage", baggage.checked)
                }
            } else {
                HStack(alignment: .top, spacing: NexusSpacing.space16) {
                    value("Cabin baggage", baggage.cabin).frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(NexusSemanticColors.borderDefault)
                        .frame(width: NexusBorder.hairline, height: NexusSpacing.space40)
                    value("Checked baggage", baggage.checked).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func value(_ label: String, _ amount: String) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space8) {
            Text(label).nexusTextStyle(NexusText.styles.bodySmall)
                .foregroundStyle(NexusSemanticColors.textSecondary)
            Text(amount).nexusTextStyle(NexusText.styles.body.withFontWeight(.semibold))
                .foregroundStyle(NexusSemanticColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FlightDetailsTimeline: View {
    let leg: FlightLegDisplay
    let showsLegLabel: Bool
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space12) {
            if showsLegLabel {
                VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                    Text(leg.label.isEmpty ? (index == 0 ? "Outbound" : "Return") : leg.label)
                        .nexusTextStyle(NexusText.styles.sectionTitleSmall)
                        .foregroundStyle(NexusSemanticColors.brandPrimary)
                    Text(leg.date).nexusTextStyle(NexusText.styles.bodySmall)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                }
            }
            ForEach(Array(leg.segments.enumerated()), id: \.offset) { segmentIndex, segment in
                FlightDetailsConnection(
                    segment: segment,
                    departureName: segmentIndex == 0 ? leg.departureAirportName : nil,
                    arrivalName: segmentIndex == leg.segments.count - 1 ? leg.arrivalAirportName : nil
                )
            }
        }
    }
}

private struct FlightDetailsConnection: View {
    let segment: FlightSegmentDisplay
    let departureName: String?
    let arrivalName: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var timelineWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? NexusSpacing.space64 + NexusSpacing.space48
            : NexusSpacing.space64
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space8) {
            endpoint(segment.departureAirportCode, name: departureName,
                     time: segment.departureTime, isDeparture: true)
            Text(segment.detail)
                .nexusTextStyle(NexusText.styles.bodySmall)
                .frame(width: timelineWidth)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .accessibilityHidden(true)
            endpoint(segment.arrivalAirportCode, name: arrivalName,
                     time: segment.arrivalTime, isDeparture: false)
            if let layover = segment.layover {
                Text(layover).nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
        }
        .padding(.leading, timelineWidth)
        .backgroundPreferenceValue(TimelineCodeAnchorsKey.self) { anchors in
            GeometryReader { geometry in
                Canvas { context, _ in
                    guard let departure = anchors.departure, let arrival = anchors.arrival else { return }
                    let start = geometry[departure].midY
                    let end = geometry[arrival].midY
                    let radius = NexusSpacing.space12 / 2
                    guard end > start + 2 * radius else { return }
                    let centerX = timelineWidth / 2
                    var connector = Path()
                    connector.move(to: CGPoint(x: centerX, y: start + radius))
                    connector.addLine(to: CGPoint(x: centerX, y: end - radius))
                    context.stroke(connector, with: .color(NexusSemanticColors.borderDefault),
                                   style: StrokeStyle(lineWidth: NexusBorder.hairline,
                                                      dash: [NexusSpacing.space8, NexusSpacing.space8]))
                    for y in [start, end] {
                        let dot = Path(ellipseIn: CGRect(x: centerX - radius, y: y - radius,
                                                          width: 2 * radius, height: 2 * radius))
                        context.stroke(dot, with: .color(NexusSemanticColors.brandPrimary.opacity(0.6)),
                                       lineWidth: NexusBorder.iconStroke)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .overlayPreferenceValue(TimelineCodeAnchorsKey.self) { anchors in
            GeometryReader { geometry in
                if let departure = anchors.departure, let arrival = anchors.arrival {
                    let centerY = (geometry[departure].midY + geometry[arrival].midY) / 2
                    Text(segment.detail)
                        .nexusTextStyle(NexusText.styles.bodySmall)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, NexusSpacing.space4)
                        .padding(.horizontal, NexusSpacing.space4)
                        .frame(width: timelineWidth)
                        .background(NexusSemanticColors.surfaceBase)
                        .position(x: timelineWidth / 2, y: centerY)
                }
            }
        }
    }

    @ViewBuilder private func endpoint(_ code: String, name: String?, time: String, isDeparture: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                airportLabel(code, name: name, isDeparture: isDeparture)
                Text(time).nexusTextStyle(NexusText.styles.flightTime)
            }
            .foregroundStyle(NexusSemanticColors.textHeading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: NexusSpacing.space8) {
                airportLabel(code, name: name, isDeparture: isDeparture)
                Spacer(minLength: NexusSpacing.space0)
                Text(time).nexusTextStyle(NexusText.styles.flightTime)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(NexusSemanticColors.textHeading)
        }
    }

    private func airportLabel(_ code: String, name: String?, isDeparture: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: NexusSpacing.space8) {
            codeText(code, isDeparture: isDeparture)
            if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(code) != .orderedSame {
                Text(name).nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
        }
    }

    private func codeText(_ code: String, isDeparture: Bool) -> some View {
        Text(code)
            .nexusTextStyle(NexusText.styles.airportCode)
            .anchorPreference(key: TimelineCodeAnchorsKey.self, value: .bounds) { anchor in
                isDeparture ? TimelineCodeAnchors(departure: anchor) : TimelineCodeAnchors(arrival: anchor)
            }
    }
}

private struct TimelineCodeAnchors {
    var departure: Anchor<CGRect>?
    var arrival: Anchor<CGRect>?
}

private struct TimelineCodeAnchorsKey: PreferenceKey {
    static let defaultValue = TimelineCodeAnchors()

    static func reduce(value: inout TimelineCodeAnchors, nextValue: () -> TimelineCodeAnchors) {
        let next = nextValue()
        value.departure = next.departure ?? value.departure
        value.arrival = next.arrival ?? value.arrival
    }
}

private struct FlightDetailsStickyCTA: View {
    let price: PriceDisplay?
    let spacing: NexusAdaptiveSpacing?
    let safeAreaBottom: CGFloat
    let isRevalidating: Bool
    let isEnabled: Bool
    let onContinue: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: NexusSpacing.space16) {
                priceLabel.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: NexusSpacing.space0)
                continueButton
                    .frame(width: buttonWidth)
                    .fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: NexusSpacing.space12) {
                priceLabel
                continueButton.frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: NexusLayout.contentMaxWidth)
        .padding(.horizontal, NexusLayout.screenMarginCompact)
        .padding(.top, spacing?.stickyCtaPaddingV ?? NexusSpacing.space12)
        .padding(.bottom, safeAreaBottom > 0 ? -NexusSpacing.space12 : NexusSpacing.space8)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: NexusRadius.xxl, topTrailingRadius: NexusRadius.xxl)
                .fill(NexusSemanticColors.surfaceElevated)
                .ignoresSafeArea(edges: .bottom)
        }
        .shadow(color: NexusSemanticColors.textHeading.opacity(NexusElevation.mainBottomBarAmbientOpacity),
                radius: NexusElevation.mainBottomBarAmbientRadius, y: NexusElevation.mainBottomBarAmbientY)
    }

    private var buttonWidth: CGFloat {
        switch spacing?.mode {
        case .compact: NexusLayout.stickyCtaButtonWidthCompact
        case .regular: NexusLayout.stickyCtaButtonWidthRegular
        case .spacious: NexusLayout.stickyCtaButtonWidthSpacious
        default: NexusLayout.stickyCtaButtonWidthRegular
        }
    }

    private var priceLabel: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space2) {
            Text("Total")
                .nexusTextStyle(NexusText.styles.bodySmall)
                .foregroundStyle(NexusSemanticColors.textSecondary)
            if let price {
                HStack(alignment: .firstTextBaseline, spacing: NexusSpacing.space4) {
                    Text(price.currency)
                        .nexusTextStyle(NexusText.styles.bodySmall.withFontWeight(.medium))
                    Text(price.amount)
                        .nexusTextStyle(NexusText.styles.priceAmountSmall)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(NexusSemanticColors.brandPrimary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Total \(price.currency) \(price.amount)")
            }
        }
    }

    private var continueButton: some View {
        NexusPrimaryButton("Continue", isEnabled: isEnabled, isLoading: isRevalidating,
                           loadingTitle: "Checking…", fillsWidth: true, action: onContinue) {
            NexusIcon(name: .continue, size: NexusIconSize.sm)
        }
    }
}
