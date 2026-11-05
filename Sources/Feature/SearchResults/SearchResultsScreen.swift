import SwiftUI

struct SearchResultsScreenRoute: View {
    @State private var viewModel: SearchResultsViewModel
    @State private var eventTask: Task<Void, Never>?
    let router: Router

    init(viewModel: SearchResultsViewModel, router: Router) {
        _viewModel = State(initialValue: viewModel)
        self.router = router
    }

    var body: some View {
        SearchResultsScreen(state: viewModel.uiState, onEvent: send)
            .task {
                do { try await viewModel.loadResults() } catch is CancellationError { return } catch { return }
                if let unavailableOffer = router.unavailableOffer {
                    viewModel.markOfferUnavailable(unavailableOffer)
                }
            }
            .onChange(of: router.unavailableOffer) { _, reference in
                if let reference { viewModel.markOfferUnavailable(reference) }
            }
            .onDisappear { eventTask?.cancel() }
    }

    private func send(_ event: SearchResultsUiEvent) {
        eventTask?.cancel()
        eventTask = Task {
            await viewModel.onEvent(event)
            while let navigation = viewModel.consumeNavigationEvent() {
                switch navigation {
                case .back, .toModifySearch, .toNearbyDates: router.pop()
                case let .toFlightDetails(reference):
                    router.push(.flightDetails(FlightDetailsRoute(reference: reference)))
                }
            }
            eventTask = nil
        }
    }
}

struct SearchResultsScreen: View {
    let state: SearchResultsUiState
    let onEvent: (SearchResultsUiEvent) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let spacing = NexusAdaptiveSpacing(
                screenWidth: geometry.size.width,
                screenHeight: geometry.size.height
            )
            let metrics = spacing.map {
                SearchResultRowMetrics(maxWidth: geometry.size.width, spacing: $0)
            }

            VStack(spacing: NexusSpacing.space4) {
                SearchResultsHeader(state: state, metrics: metrics, onEvent: onEvent)
                content(metrics: metrics)
            }
            .frame(maxWidth: NexusLayout.homeContentMaxWidthWide)
            .frame(maxWidth: .infinity)
        }
        .background(NexusSemanticColors.backgroundPage)
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder private func content(metrics: SearchResultRowMetrics?) -> some View {
        switch state.resultState {
        case .loading: loading
        case .content: results(metrics: metrics)
        case .empty: empty
        case .error: error
        }
    }

    private var loading: some View {
        ScrollView {
            LazyVStack(spacing: NexusSpacing.space0) {
                SearchResultsCountRow(count: "Searching live fares…")
                ForEach(0..<3, id: \.self) { index in
                    SearchResultSkeleton(reduceMotion: reduceMotion)
                    if index < 2 { Divider().padding(.horizontal, NexusLayout.screenMarginCompact) }
                }
            }
        }
        .accessibilityLabel("Searching live fares")
    }

    private func results(metrics: SearchResultRowMetrics?) -> some View {
        ScrollView {
            LazyVStack(spacing: NexusSpacing.space0) {
                SearchResultsCountRow(count: state.resultCountLabel())
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if let warning = state.freshnessWarning(at: context.date) {
                        NexusBanner(text: warning, status: .warning, trailingAction: {
                            NexusTextButton("Search again") { onEvent(.modifyClicked) }
                        })
                        .padding(.horizontal, NexusLayout.screenMarginCompact)
                    }
                }
                if let notice = state.unavailableOfferNotice {
                    NexusBanner(text: notice, status: .warning, trailingAction: {
                        NexusTextButton("Search again") { onEvent(.modifyClicked) }
                    })
                        .padding(.horizontal, NexusLayout.screenMarginCompact)
                }
                if !state.selectedFilters.isEmpty {
                    SearchResultsFilterBanner(filters: state.selectedFilters) {
                        onEvent(.clearFiltersClicked)
                    }
                    .padding(.horizontal, NexusLayout.screenMarginCompact)
                    .padding(.bottom, NexusSpacing.space4)
                }
                ForEach(Array(state.visibleFlights.enumerated()), id: \.element.id) { index, offer in
                    SearchResultOfferRow(
                        offer: offer,
                        tripType: state.querySummary?.tripType ?? .roundTrip,
                        metrics: metrics
                    ) {
                        onEvent(.flightCardClicked(offer.reference))
                    }
                    if index < state.visibleFlights.count - 1 {
                        Divider()
                            .opacity(0.42)
                            .padding(.horizontal, metrics?.horizontalMargin ?? NexusLayout.screenMarginCompact)
                    }
                }
            }
            .padding(.bottom, NexusSpacing.space24)
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No flights found", systemImage: NexusIconName.search.systemName)
        } description: {
            Text(state.unavailableOfferNotice ?? (state.selectedFilters.isEmpty
                 ? "We couldn't find available flights for these dates. Try adjusting your search to see more options."
                 : "We couldn't find available flights for these filters. Try adjusting your search to see more options."))
        } actions: {
            NexusPrimaryButton("Try searching nearby dates", fillsWidth: true) { onEvent(.nearbyDatesClicked) }
            NexusTextButton("Modify search") { onEvent(.modifyClicked) }
        }
        .padding(NexusLayout.screenMargin)
    }

    private var error: some View {
        VStack {
            NexusFeedbackPanel(
                title: "Connection lost",
                message: state.errorMessage ?? "Could not load flights. Please retry.",
                primaryActionLabel: "Retry Search", onPrimaryAction: { onEvent(.retryClicked) }
            )
            NexusTextButton("Change search") { onEvent(.modifyClicked) }
        }
        .padding(NexusLayout.screenMargin)
    }
}

private struct SearchResultsHeader: View {
    let state: SearchResultsUiState
    let metrics: SearchResultRowMetrics?
    let onEvent: (SearchResultsUiEvent) -> Void

    var body: some View {
        VStack(spacing: NexusSpacing.space4) {
            ZStack {
                Text("Search Results")
                    .nexusTextStyle(NexusText.styles.sectionTitle)
                    .foregroundStyle(NexusSemanticColors.textHeading)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    NexusIconActionButton("Back", action: { onEvent(.backClicked) }) {
                        NexusIcon(name: .back)
                    }
                    Spacer()
                }
            }
            .frame(minHeight: NexusLayout.touchRecommended)
            .padding(.horizontal, NexusSpacing.space8)

            if let summary = state.querySummary {
                SearchResultsSummary(summary: summary, metrics: metrics) {
                    onEvent(.modifyClicked)
                }
                    .padding(.horizontal, metrics?.horizontalMargin ?? NexusLayout.screenMarginCompact)
            }

            SearchResultsFilters(state: state, onEvent: onEvent)
        }
    }
}

private struct SearchResultsSummary: View {
    let summary: SearchResultsQuerySummary
    let metrics: SearchResultRowMetrics?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: NexusSpacing.space0) {
                HStack(spacing: NexusSpacing.space8) {
                    Text(summary.originCode)
                        .nexusTextStyle(NexusText.styles.airportCode)
                    NexusIcon(name: .continue, size: NexusIconSize.sm)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                    Text(summary.destinationCode)
                        .nexusTextStyle(NexusText.styles.airportCode)
                    Spacer(minLength: NexusSpacing.space8)
                    Label(metrics?.usesCompactLabels == true ? "Edit" : "Edit search", systemImage: "pencil")
                        .nexusTextStyle(NexusText.styles.link)
                        .foregroundStyle(NexusSemanticColors.link)
                }
                .foregroundStyle(NexusSemanticColors.textHeading)

                Text(metadata)
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, metrics?.summaryHorizontalPadding ?? NexusSpacing.space16)
            .padding(.vertical, NexusSpacing.space8)
            .frame(minHeight: metrics?.summaryCardMinHeight ?? NexusSearchResultLayout.summaryCardHeightRegular)
            .background(NexusSemanticColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: NexusRadius.lg)
                    .stroke(NexusSemanticColors.borderDefault.opacity(0.55), lineWidth: NexusBorder.hairline)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("search-results-summary")
        .accessibilityLabel("Edit search: \(summary.originCode) to \(summary.destinationCode), \(metadata)")
    }

    private var metadata: String {
        let dateStyle = Date.FormatStyle().month(.abbreviated).day()
        let departure = summary.departureDate.foundationDate.formatted(dateStyle)
        let dates = summary.returnDate.map {
            "\(departure) – \($0.foundationDate.formatted(dateStyle))"
        } ?? departure
        let direction = summary.tripType == .oneWay ? " · One way" : ""
        return "\(dates) · \(summary.travelers.summary()) · \(summary.cabinClass.label)\(direction)"
    }
}

private struct SearchResultsFilters: View {
    let state: SearchResultsUiState
    let onEvent: (SearchResultsUiEvent) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: NexusSpacing.space8) {
                Menu {
                    ForEach([SortOption.recommended, .bestPrice, .fastest, .departureEarly], id: \.self) { option in
                        Button(option.label) { onEvent(.sortChanged(option)) }
                    }
                } label: {
                    SearchResultsChipLabel(
                        title: state.sortOption.label,
                        selected: state.sortOption != .recommended,
                        leadingIcon: .filter,
                        showsChevron: true
                    )
                }
                .accessibilityIdentifier("search-sort")

                ForEach([SearchFilter.nonStop, .bestPrice, .morning, .oneStop], id: \.self) { filter in
                    Button { onEvent(.filterToggled(filter)) } label: {
                        SearchResultsChipLabel(
                            title: filter.label,
                            selected: state.selectedFilters.contains(filter),
                            leadingIcon: nil,
                            showsSun: filter == .morning
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search-filter-\(filter.rawValue.kebabCased)")
                    .accessibilityValue(state.selectedFilters.contains(filter) ? "Selected" : "Not selected")
                }
            }
            .padding(.horizontal, NexusLayout.screenMarginCompact)
            .padding(.vertical, NexusSpacing.space4)
        }
        .scrollIndicators(.hidden)
    }
}

private struct SearchResultsChipLabel: View {
    let title: String
    let selected: Bool
    var leadingIcon: NexusIconName?
    var showsSun = false
    var showsChevron = false

    var body: some View {
        ZStack {
            HStack(spacing: NexusSpacing.space8) {
                if let leadingIcon { NexusIcon(name: leadingIcon, size: NexusIconSize.sm) }
                if showsSun {
                    Image(systemName: "sun.max")
                        .font(.system(size: NexusIconSize.sm))
                        .accessibilityHidden(true)
                }
                Text(title).nexusTextStyle(NexusText.styles.label)
                if showsChevron { NexusIcon(name: .chevronDown, size: NexusIconSize.xs) }
            }
            .foregroundStyle(selected ? NexusSemanticColors.brandPrimary : NexusSemanticColors.textPrimary)
            .padding(.horizontal, NexusSpacing.space16)
            .frame(minHeight: NexusSpacing.space40)
            .background(selected ? NexusSemanticColors.brandSoft : NexusSemanticColors.surfaceBase)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(
                    selected ? NexusSemanticColors.brandPrimary : NexusSemanticColors.borderDefault,
                    lineWidth: selected ? NexusBorder.focus : NexusBorder.hairline
                )
            }
        }
        .frame(minHeight: NexusLayout.touchMin)
    }
}

private struct SearchResultsCountRow: View {
    let count: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { countContent; Spacer(); taxesNote }
            VStack(alignment: .leading, spacing: NexusSpacing.space4) { countContent; taxesNote }
        }
        .padding(.horizontal, NexusLayout.screenMarginCompact)
        .padding(.vertical, NexusSpacing.space8)
    }

    private var countContent: some View {
        HStack(spacing: NexusSpacing.space12) {
            Circle()
                .fill(NexusSemanticColors.brandPrimary)
                .frame(width: NexusSpacing.space8, height: NexusSpacing.space8)
            Text(count)
                .nexusTextStyle(NexusText.styles.body.withFontWeight(.semibold))
                .foregroundStyle(NexusSemanticColors.textHeading)
        }
    }

    private var taxesNote: some View {
        HStack(spacing: NexusSpacing.space4) {
            Text("Taxes & fees included")
                .nexusTextStyle(NexusText.styles.bodySmall)
            NexusIcon(name: .info, size: NexusIconSize.xs)
        }
        .foregroundStyle(NexusSemanticColors.textTertiary)
    }
}

private struct SearchResultsFilterBanner: View {
    let filters: Set<SearchFilter>
    let clear: () -> Void

    var body: some View {
        HStack(spacing: NexusSpacing.space12) {
            NexusIcon(name: .filter, size: NexusIconSize.sm)
            Text("Filter applied")
                .nexusTextStyle(NexusText.styles.label)
            Text("· \(summary)")
                .nexusTextStyle(NexusText.styles.bodySmall)
                .foregroundStyle(NexusSemanticColors.textSecondary)
                .lineLimit(1)
            Spacer(minLength: NexusSpacing.space4)
            Button(action: clear) { NexusIcon(name: .close, size: NexusIconSize.sm) }
                .frame(width: NexusLayout.touchMin, height: NexusLayout.touchMin)
                .accessibilityLabel("Clear filters")
        }
        .foregroundStyle(NexusSemanticColors.brandPrimary)
        .padding(.leading, NexusSpacing.space16)
        .background(NexusSemanticColors.brandSoft)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: NexusRadius.lg)
                .stroke(NexusSemanticColors.borderFocus.opacity(0.35), lineWidth: NexusBorder.hairline)
        }
    }

    private var summary: String {
        [SearchFilter.nonStop, .bestPrice, .morning, .oneStop]
            .filter(filters.contains)
            .map(\.label)
            .joined(separator: ", ")
    }
}

private struct SearchResultOfferRow: View {
    let offer: SearchResultUiOffer
    let tripType: TripType
    let metrics: SearchResultRowMetrics?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: NexusSpacing.space12) {
                offerHeader
                ForEach(Array(visibleLegs.enumerated()), id: \.offset) { index, leg in
                    if tripType == .multiCity {
                        Text("Flight \(index + 1)")
                            .nexusTextStyle(NexusText.styles.bodySmall)
                            .foregroundStyle(NexusSemanticColors.textTertiary)
                    }
                    SearchResultLegRow(
                        leg: leg,
                        direction: tripType == .roundTrip ? (index == 0 ? "OUT" : "RET") : nil,
                        metrics: metrics
                    )
                }
                offerFooter
            }
            .padding(.horizontal, (metrics?.horizontalMargin ?? NexusLayout.screenMarginCompact) + (metrics?.rowInnerPadding ?? 0))
            .padding(.vertical, metrics?.rowVerticalPadding ?? NexusSpacing.space16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens flight details")
    }

    private var visibleLegs: [SearchResultUiLeg] {
        switch tripType {
        case .oneWay: [offer.outbound]
        case .roundTrip: offer.inbound.map { [offer.outbound, $0] } ?? [offer.outbound]
        case .multiCity: offer.legs
        }
    }

    private var offerHeader: some View {
        HStack(spacing: NexusSpacing.space12) {
            AsyncImage(url: offer.airlineLogoURL) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Text(offer.airlineCode)
                        .nexusTextStyle(NexusText.styles.label)
                        .foregroundStyle(NexusSemanticColors.brandPrimary)
                }
            }
            .frame(
                width: metrics?.logoSlotWidth ?? NexusIconSize.xxl,
                height: metrics?.logoSlotHeight ?? NexusSpacing.space40,
                alignment: .leading
            )
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: NexusSpacing.space2) {
                if !offer.airlineName.isEmpty {
                    Text(offer.airlineName)
                        .nexusTextStyle(NexusText.styles.listTitleLarge)
                        .foregroundStyle(NexusSemanticColors.textPrimary)
                        .lineLimit(1)
                }
                Text(offer.flightNumber)
                    .nexusTextStyle(NexusText.styles.bodySmall.withFontWeight(.medium))
                    .foregroundStyle(NexusSemanticColors.textTertiary)
            }
            Spacer()
            if let label = offer.bookingStatusLabel {
                Text(label)
                    .nexusTextStyle(NexusText.styles.statusBadge)
                    .foregroundStyle(NexusSemanticColors.brandPrimary)
                    .padding(.horizontal, NexusSpacing.space8)
                    .padding(.vertical, NexusSpacing.space4)
                    .background(NexusSemanticColors.brandSoft)
                    .clipShape(Capsule())
            }
            if let label = offer.badgeLabel {
                Text(label)
                    .nexusTextStyle(NexusText.styles.statusBadge)
                    .foregroundStyle(NexusSemanticColors.brandPrimary)
                    .padding(.horizontal, NexusSpacing.space8)
                    .padding(.vertical, NexusSpacing.space4)
                    .background(NexusSemanticColors.brandSoft)
                    .clipShape(Capsule())
            }
        }
    }

    private var offerFooter: some View {
        HStack(spacing: NexusSpacing.space8) {
            if let seats = offer.seatsLeftLabel {
                HStack(spacing: NexusSpacing.space4) {
                    NexusIcon(name: .seat, size: NexusIconSize.xs)
                    Text(seats).nexusTextStyle(NexusText.styles.statusBadge)
                }
                .foregroundStyle(NexusSemanticColors.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: NexusSpacing.space0) {
                if let oldPrice = offer.oldPriceLabel {
                    Text(oldPrice)
                        .strikethrough()
                        .nexusTextStyle(NexusText.styles.bodySmall)
                        .foregroundStyle(NexusSemanticColors.textTertiary)
                }
                Text(offer.priceLabel)
                    .nexusTextStyle(NexusText.styles.priceAmountSmall)
                    .foregroundStyle(NexusSemanticColors.brandPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(offer.priceMetaLabel)
                    .nexusTextStyle(NexusText.styles.currencyLabel)
                    .foregroundStyle(NexusSemanticColors.textTertiary)
            }
            NexusIcon(name: .chevronRight)
                .foregroundStyle(NexusSemanticColors.textTertiary)
        }
        .frame(minHeight: NexusLayout.touchRecommended)
    }

    private var accessibilityLabel: String {
        let legs = visibleLegs.map {
            "\($0.departureTimeLabel) \($0.departureAirportCode) to \($0.arrivalTimeLabel) \($0.arrivalAirportCode), \($0.durationLabel), \($0.stopLabel)"
        }.joined(separator: ". ")
        return "\(offer.airlineName), \(offer.flightNumber). \(legs). \(offer.priceLabel) \(offer.priceMetaLabel)"
    }
}

private struct SearchResultLegRow: View {
    let leg: SearchResultUiLeg
    let direction: String?
    let metrics: SearchResultRowMetrics?

    var body: some View {
        HStack(spacing: NexusSpacing.space8) {
            if let direction {
                Text(direction)
                    .nexusTextStyle(NexusText.styles.statusBadge)
                    .foregroundStyle(NexusSemanticColors.textTertiary)
                    .frame(
                        width: metrics?.legLabelWidth ?? NexusSearchResultLayout.legLabelWidthRegular,
                        alignment: .leading
                    )
            }
            endpoint(time: leg.departureTimeLabel, airport: leg.departureAirportCode, alignment: .leading)
            VStack(spacing: NexusSpacing.space4) {
                Text(leg.durationLabel)
                HStack(spacing: NexusSpacing.space4) {
                    Circle().frame(width: NexusSpacing.space4, height: NexusSpacing.space4)
                    Capsule()
                        .stroke(
                            NexusSemanticColors.borderDefault.opacity(0.45),
                            style: StrokeStyle(lineWidth: NexusBorder.hairline, dash: [8, 5])
                        )
                        .frame(height: NexusBorder.hairline)
                    Circle().frame(width: NexusSpacing.space4, height: NexusSpacing.space4)
                }
                .foregroundStyle(NexusSemanticColors.borderDefault)
                Text(metrics?.usesCompactLabels == true ? leg.compactStopLabel : leg.stopLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .nexusTextStyle(NexusText.styles.durationStop)
            .foregroundStyle(NexusSemanticColors.textTertiary)
            .frame(maxWidth: .infinity)
            endpoint(time: leg.arrivalTimeLabel, airport: leg.arrivalAirportCode, alignment: .trailing)
        }
    }

    private func endpoint(time: String, airport: String, alignment: Alignment) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: NexusSpacing.space2) {
            Text(time)
                .nexusTextStyle(NexusText.styles.flightTimeCompact)
                .foregroundStyle(NexusSemanticColors.textPrimary)
            Text(airport)
                .nexusTextStyle(NexusText.styles.listTitle.withFontWeight(.bold))
                .foregroundStyle(NexusSemanticColors.textTertiary)
        }
        .frame(width: metrics?.endpointWidth ?? NexusSearchResultLayout.endpointWidthRegular, alignment: alignment)
    }
}

private struct SearchResultSkeleton: View {
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space16) {
            HStack {
                placeholder(width: NexusIconSize.xl)
                placeholder(width: NexusLayout.formMaxWidth / 3)
                Spacer()
            }
            placeholder(width: NexusLayout.formMaxWidth)
            HStack { Spacer(); placeholder(width: NexusLayout.formMaxWidth / 3) }
        }
        .padding(NexusSpacing.space16)
        .opacity(reduceMotion ? 1 : 0.72)
        .accessibilityHidden(true)
    }

    private func placeholder(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: NexusRadius.sm)
            .fill(NexusSemanticColors.surfaceMuted)
            .frame(width: width, height: NexusSpacing.space24)
    }
}

private extension String {
    var kebabCased: String {
        unicodeScalars.reduce(into: "") { result, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar) {
                result += "-\(String(scalar).lowercased())"
            } else {
                result.append(Character(scalar))
            }
        }
    }
}
