import SwiftUI

struct ExploreScreenRoute: View {
    @State private var viewModel: ExploreViewModel
    @Binding var rootScrollTarget: String?
    @Bindable var router: Router

    init(viewModel: ExploreViewModel, router: Router, rootScrollTarget: Binding<String?>) {
        _viewModel = State(initialValue: viewModel)
        _rootScrollTarget = rootScrollTarget
        self.router = router
    }

    var body: some View {
        ExploreScreen(
            state: viewModel.state,
            filter: $router.exploreFilter,
            rootScrollTarget: $rootScrollTarget,
            onDestination: { router.push(.destinationDetail(.init(destinationId: $0))) },
            onPackage: { router.push(.packageDetail(.init(packageId: $0))) },
            onRetry: { Task { try? await viewModel.load(forceRefresh: true) } }
        )
        .task { try? await viewModel.loadIfNeeded() }
        .refreshable { try? await viewModel.load(forceRefresh: true) }
    }
}

private struct ExploreScreen: View {
    let state: ExploreUiState
    @Binding var filter: ExploreFilter
    @Binding var rootScrollTarget: String?
    let onDestination: (String) -> Void
    let onPackage: (String) -> Void
    let onRetry: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let spacing = NexusAdaptiveSpacing(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
            let contentWidth = min(
                geometry.size.width - 2 * (spacing?.screenMargin ?? NexusLayout.screenMargin),
                NexusLayout.homeContentMaxWidthWide
            )
            ScrollView {
                VStack(spacing: 0) {
                    if let content = state.content, !content.banners.isEmpty {
                        ExploreHeroHeader(banners: content.banners, width: geometry.size.width, action: onDestination)
                            .id("explore.hero")
                    }
                    LazyVStack(alignment: .leading, spacing: spacing?.sectionGapCompact ?? NexusSpacing.space24) {
                        if state.loading && state.content == nil {
                            ExploreLoadingView()
                        } else if let content = state.content {
                            status
                            ExploreFilterBar(selection: $filter).id("explore.filter")
                            contentView(content, contentWidth: contentWidth)
                        } else {
                            NexusFeedbackPanel(
                                title: "Explore is unavailable",
                                message: state.error ?? "Check your connection and try again.",
                                primaryActionLabel: "Try again", onPrimaryAction: onRetry
                            )
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.top, spacing?.sectionGapCompact ?? NexusSpacing.space24)
                    .padding(.bottom, NexusSpacing.space32)
                    .frame(maxWidth: .infinity)
                    .scrollTargetLayout()
                }
            }
            .scrollPosition(id: $rootScrollTarget, anchor: .top)
        }
        .accessibilityIdentifier("root-explore")
        .background(NexusSemanticColors.backgroundPage)
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder private var status: some View {
        if state.refreshing {
            Label("Refreshing deals", systemImage: NexusIconName.loading.systemName)
                .nexusTextStyle(NexusText.styles.bodySmall)
                .accessibilityAddTraits(.updatesFrequently)
        }
        if state.error != nil {
            NexusBanner(text: "Could not update. Showing saved deals.", status: .error, trailingAction: {
                NexusTextButton("Try again", action: onRetry)
            })
        }
    }

    @ViewBuilder private func contentView(_ content: ExploreContent, contentWidth: CGFloat) -> some View {
        let packages = filter.showsPackages ? content.packages : []
        let destinations = filter.showsDestinations ? content.destinations : []
        if packages.isEmpty && destinations.isEmpty {
            ContentUnavailableView(
                "No travel deals yet",
                systemImage: NexusIconName.map.systemName,
                description: Text("Check again later or pull to refresh.")
            )
        }
        if !packages.isEmpty {
            ExploreSectionHeader("Popular from Addis Ababa").id("explore.packages")
            ForEach(packages, id: \.id) { item in
                ExplorePackageCard(package: item, width: contentWidth) { onPackage(item.id) }
                    .id("explore.package.\(item.id)")
            }
        }
        if !destinations.isEmpty {
            ExploreSectionHeader("Browse destinations").id("explore.destinations")
            ScrollView(.horizontal) {
                LazyHStack(spacing: NexusSpacing.space12) {
                    ForEach(destinations, id: \.id) { item in
                        ExploreDestinationCard(destination: item, screenWidth: contentWidth) { onDestination(item.id) }
                            .id("explore.destination.\(item.id)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct ExploreFilterBar: View {
    @Binding var selection: ExploreFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: NexusSpacing.space8) {
                button("All", value: .all)
                button("Packages", value: .packages)
                button("Destinations", value: .destinations)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Explore filter")
    }

    private func button(_ title: String, value: ExploreFilter) -> some View {
        Button { selection = value } label: {
            Text(title)
                .nexusTextStyle(NexusText.styles.label)
                .foregroundStyle(selection == value ? NexusSemanticColors.actionPrimaryText : NexusSemanticColors.textPrimary)
                .padding(.horizontal, NexusSpacing.space16)
                .frame(minHeight: NexusLayout.touchMin)
                .background(selection == value ? NexusSemanticColors.actionPrimary : NexusSemanticColors.surfaceBase)
                .clipShape(Capsule())
                .overlay { Capsule().stroke(NexusSemanticColors.borderDefault, lineWidth: selection == value ? 0 : NexusBorder.hairline) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == value ? .isSelected : [])
    }
}

private struct ExploreHeroHeader: View {
    let banners: [ExploreBanner]
    let width: CGFloat
    let action: (String) -> Void
    @State private var selection: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(banners, id: \.id) { banner in
                        Button { if let id = banner.destinationId { action(id) } } label: {
                            Color.clear
                                .frame(width: width, height: NexusSpacing.space64 * 2)
                                .background {
                                    ExploreRemoteImage(urlString: banner.imageUrl)
                                        .frame(width: width, height: NexusSpacing.space64 * 2)
                                        .clipped()
                                }
                                .overlay {
                                    LinearGradient(colors: [.clear, NexusSemanticColors.overlayScrim], startPoint: .center, endPoint: .bottom)
                                }
                                .overlay(alignment: .bottomLeading) {
                                VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                                    Text(banner.title).nexusTextStyle(NexusText.styles.sectionTitle)
                                    Text(banner.subtitle).nexusTextStyle(NexusText.styles.bodySmall).lineLimit(2)
                                }
                                .frame(width: width - 2 * NexusSpacing.space16, alignment: .leading)
                                .foregroundStyle(NexusColors.white)
                                .multilineTextAlignment(.leading)
                                .padding(NexusSpacing.space16)
                                .padding(.bottom, NexusSpacing.space16)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(banner.destinationId == nil)
                        .accessibilityLabel("\(banner.title). \(banner.subtitle)")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selection)
            .accessibilityIdentifier("explore-hero")
            HStack(spacing: NexusSpacing.space8) {
                ForEach(banners, id: \.id) { banner in
                    Capsule()
                        .fill(selection == banner.id ? NexusSemanticColors.brandPrimary : NexusSemanticColors.borderDefault)
                        .frame(width: selection == banner.id ? NexusSpacing.space20 : NexusSpacing.space8, height: NexusSpacing.space4)
                        .accessibilityHidden(true)
                }
            }
            .padding(.bottom, NexusSpacing.space8)
        }
        .clipShape(.rect(bottomLeadingRadius: NexusRadius.xl, bottomTrailingRadius: NexusRadius.xl))
        .onAppear { selection = selection ?? banners.first?.id }
        .task(id: banners.map(\.id)) {
            guard !reduceMotion, banners.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                let index = banners.firstIndex { $0.id == selection } ?? 0
                withAnimation(.easeInOut(duration: Double(NexusMotion.durationBaseMillis) / 1_000)) {
                    selection = banners[(index + 1) % banners.count].id
                }
            }
        }
    }
}

private struct ExplorePackageCard: View {
    let package: ExplorePackage
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: NexusSpacing.space12) {
                ExploreRemoteImage(urlString: package.imageUrl)
                    .frame(width: width, height: NexusSpacing.space64 * 2 + NexusSpacing.space16)
                    .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xl))
                Text(package.title).nexusTextStyle(NexusText.styles.sectionTitleSmall).foregroundStyle(NexusSemanticColors.textHeading)
                HStack {
                    Label("From Addis Ababa · This week", systemImage: NexusIconName.location.systemName)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                    Spacer()
                    Text("View details")
                    NexusIcon(name: .chevronRight, size: NexusIconSize.xs)
                    .foregroundStyle(NexusSemanticColors.brandPrimary)
                }
                .nexusTextStyle(NexusText.styles.bodySmall)
                Label("Flight filters available", systemImage: NexusIconName.filter.systemName)
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
            .frame(width: width)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens package details")
    }
}

private struct ExploreDestinationCard: View {
    let destination: ExploreDestination
    let screenWidth: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: NexusSpacing.space8) {
                ExploreRemoteImage(urlString: destination.imageUrl)
                    .frame(height: NexusSpacing.space64 * 2)
                    .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
                Text(destination.title).nexusTextStyle(NexusText.styles.listTitle).foregroundStyle(NexusSemanticColors.textHeading).lineLimit(2)
                Text(destination.country).nexusTextStyle(NexusText.styles.caption).foregroundStyle(NexusSemanticColors.textSecondary).lineLimit(1)
            }
            .frame(width: min(max(screenWidth * 0.38, NexusLayout.exploreCardMinWidth), NexusLayout.exploreCardMaxWidth), alignment: .leading)
            .padding(NexusSpacing.space8)
            .background(NexusSemanticColors.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xl))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens destination details")
    }
}

private struct ExploreSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View { Text(title).nexusTextStyle(NexusText.styles.sectionTitle).accessibilityAddTraits(.isHeader) }
}

private struct ExploreLoadingView: View {
    var body: some View {
        VStack(spacing: NexusSpacing.space16) {
            RoundedRectangle(cornerRadius: NexusRadius.xl).frame(height: NexusSpacing.space64 * 3)
            RoundedRectangle(cornerRadius: NexusRadius.lg).frame(height: NexusSpacing.space48)
            RoundedRectangle(cornerRadius: NexusRadius.xl).frame(height: NexusSpacing.space64 * 3)
        }
        .foregroundStyle(NexusSemanticColors.surfaceMuted)
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading Explore")
    }
}

private struct ExploreRemoteImage: View {
    let urlString: String?
    var body: some View {
        AsyncImage(url: urlString.flatMap(URL.init(string:))) { phase in
            switch phase {
            case let .success(image): image.resizable().scaledToFill()
            default:
                ZStack {
                    NexusSemanticColors.surfaceMuted
                    NexusIcon(name: .map, size: NexusIconSize.lg).foregroundStyle(NexusSemanticColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }
}

struct ExploreDetailScreenRoute: View {
    enum Mode { case destination(String), package(String) }
    private enum DetailSheet: String, Identifiable {
        case dates, travelers
        var id: String { rawValue }
    }
    @State private var viewModel: ExploreDetailViewModel
    @State private var searchTask: Task<Void, Never>?
    @State private var departureDate: LocalDate?
    @State private var returnDate: LocalDate?
    @State private var adults = 1
    @State private var draftAdults = 1
    @State private var activeSheet: DetailSheet?
    @State private var editingReturnDate = false
    let mode: Mode
    let onSearchResults: (String) -> Void

    init(viewModel: ExploreDetailViewModel, mode: Mode, onSearchResults: @escaping (String) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.mode = mode
        self.onSearchResults = onSearchResults
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading: ProgressView().accessibilityLabel("Loading destination details")
            case let .destination(destination, packages):
                ExploreDetailScreen(
                    destination: destination,
                    package: nil,
                    relatedPackages: packages,
                    isSearching: viewModel.isSearching,
                    searchError: viewModel.searchError,
                    departureDate: departureDate,
                    returnDate: returnDate,
                    adults: $adults,
                    onChooseTravelers: { draftAdults = adults; activeSheet = .travelers },
                    onChooseDeparture: { editingReturnDate = false; activeSheet = .dates },
                    onChooseReturn: { editingReturnDate = departureDate != nil; activeSheet = .dates },
                    onSearchFlights: searchFlights
                )
            case let .package(package, destination):
                ExploreDetailScreen(
                    destination: destination,
                    package: package,
                    relatedPackages: [package],
                    isSearching: viewModel.isSearching,
                    searchError: viewModel.searchError,
                    departureDate: departureDate,
                    returnDate: returnDate,
                    adults: $adults,
                    onChooseTravelers: { draftAdults = adults; activeSheet = .travelers },
                    onChooseDeparture: { editingReturnDate = false; activeSheet = .dates },
                    onChooseReturn: { editingReturnDate = departureDate != nil; activeSheet = .dates },
                    onSearchFlights: searchFlights
                )
            case .unavailable: ContentUnavailableView("Destination unavailable", systemImage: NexusIconName.map.systemName)
            case .error: ContentUnavailableView("Could not load details", systemImage: NexusPlatformIconName.unavailableNetwork.rawValue)
            }
        }
        .task {
            switch mode {
            case let .destination(id): try? await viewModel.loadDestination(id: id)
            case let .package(id): try? await viewModel.loadPackage(id: id)
            }
        }
        .onDisappear { searchTask?.cancel() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .dates:
                DateSelectorSheet(
                    title: editingReturnDate ? "Select return" : "Select departure",
                    selected: editingReturnDate ? returnDate : departureDate,
                    minimum: editingReturnDate ? departureDate?.addingDays(1) : LocalDate(date: Date())
                ) { selected in
                    if !editingReturnDate {
                        departureDate = selected
                        if let returnDate, returnDate <= selected { self.returnDate = nil }
                        editingReturnDate = true
                    } else {
                        returnDate = selected
                        activeSheet = nil
                    }
                }
                .id(editingReturnDate)
                .presentationDetents([.medium, .large])
            case .travelers:
                VStack(alignment: .leading, spacing: NexusSpacing.space24) {
                    Text("Travelers").nexusTextStyle(NexusText.styles.sectionTitle)
                    Stepper("Adults: \(draftAdults)", value: $draftAdults, in: 1...TravelerCounts.maxTravelers)
                        .nexusTextStyle(NexusText.styles.listTitle)
                        .accessibilityIdentifier("destination-adults")
                    NexusPrimaryButton("Apply", fillsWidth: true) {
                        adults = draftAdults
                        activeSheet = nil
                    }
                }
                .padding(NexusSpacing.space24)
                .presentationDetents([.medium])
            }
        }
    }

    private func searchFlights(_ airportCode: String) {
        guard searchTask == nil, let departureDate, let returnDate else { return }
        searchTask = Task {
            if let searchID = await viewModel.searchFlights(
                to: airportCode, departureDate: departureDate, returnDate: returnDate,
                travelers: TravelerCounts(adults: adults)
            ) {
                onSearchResults(searchID)
            }
            searchTask = nil
        }
    }
}

private struct ExploreDetailScreen: View {
    let destination: ExploreDestination
    let package: ExplorePackage?
    let relatedPackages: [ExplorePackage]
    let isSearching: Bool
    let searchError: String?
    let departureDate: LocalDate?
    let returnDate: LocalDate?
    @Binding var adults: Int
    let onChooseTravelers: () -> Void
    let onChooseDeparture: () -> Void
    let onChooseReturn: () -> Void
    let onSearchFlights: (String) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            let panelWidth = min(geometry.size.width, NexusLayout.homeContentMaxWidthWide)
            let heroHeight = detailHeroHeight(for: geometry.size.height)
            ScrollView {
                VStack(spacing: 0) {
                    hero(width: geometry.size.width, height: heroHeight)
                    detailPanel
                        .frame(width: panelWidth)
                        .padding(.top, -NexusSpacing.space32)
                }
                .frame(width: geometry.size.width)
            }
            .background(NexusSemanticColors.backgroundPage)
            .safeAreaInset(edge: .bottom, spacing: 0) { stickyAction.frame(width: geometry.size.width) }
            .ignoresSafeArea(edges: .top)
        }
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("destination-detail-\(destination.id)")
    }

    private func detailHeroHeight(for screenHeight: CGFloat) -> CGFloat {
        if screenHeight < 700 { return NexusLayout.exploreDetailHeroCompactHeight }
        if screenHeight > 820 { return NexusLayout.exploreDetailHeroSpaciousHeight }
        return NexusLayout.exploreDetailHeroRegularHeight
    }

    private func hero(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ExploreRemoteImage(urlString: destination.gallery.first ?? destination.imageUrl)
                .frame(width: width, height: height)
            if destination.gallery.count > 1 {
                Label("\(destination.gallery.count) photos", systemImage: "photo.on.rectangle")
                    .nexusTextStyle(NexusText.styles.caption)
                    .foregroundStyle(NexusColors.white)
                    .padding(.horizontal, NexusSpacing.space12)
                    .frame(minHeight: NexusLayout.touchMin)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(NexusSpacing.space16)
            }
        }
        .accessibilityLabel("\(destination.title) destination image")
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space20) {
            detailHeader
            flightCard
            VStack(alignment: .leading, spacing: NexusSpacing.space8) {
                Text("About \(destination.title)").nexusTextStyle(NexusText.styles.sectionTitle).accessibilityAddTraits(.isHeader)
                Text(destination.summary).nexusTextStyle(NexusText.styles.body).foregroundStyle(NexusSemanticColors.textSecondary)
            }
            if !destination.highlights.isEmpty {
                VStack(alignment: .leading, spacing: NexusSpacing.space12) {
                    Text("Highlights").nexusTextStyle(NexusText.styles.sectionTitle).accessibilityAddTraits(.isHeader)
                    ForEach(destination.highlights, id: \.self) { highlight in
                        Label(highlight, systemImage: NexusIconName.check.systemName).nexusTextStyle(NexusText.styles.body)
                    }
                }
            }
            if !relatedPackages.isEmpty {
                VStack(alignment: .leading, spacing: NexusSpacing.space12) {
                    Text("Related deals").nexusTextStyle(NexusText.styles.sectionTitle).accessibilityAddTraits(.isHeader)
                    ForEach(relatedPackages, id: \.id) { Text($0.title).nexusTextStyle(NexusText.styles.listTitle) }
                }
            }
        }
        .padding(.horizontal, NexusLayout.screenMargin)
        .padding(.top, NexusSpacing.space32)
        .padding(.bottom, NexusSpacing.space32)
        .background(NexusSemanticColors.backgroundPage)
        .clipShape(.rect(topLeadingRadius: NexusRadius.xxxl, topTrailingRadius: NexusRadius.xxxl))
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space4) {
            if let package {
                Text(package.title)
                    .nexusTextStyle(NexusText.styles.label)
                    .foregroundStyle(NexusSemanticColors.brandPrimary)
                    .lineLimit(1)
            }
            Text(destination.title)
                .nexusTextStyle(NexusText.styles.displayHeroCompact)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Text(destination.country)
                .nexusTextStyle(NexusText.styles.bodyLarge)
                .foregroundStyle(NexusSemanticColors.textSecondary)
                .lineLimit(1)
            Text("From Addis Ababa • Round trip • Economy")
                .nexusTextStyle(NexusText.styles.label)
                .foregroundStyle(NexusSemanticColors.brandPrimary)
        }
    }

    private var flightCard: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space16) {
            let dateLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: NexusSpacing.space12))
                : AnyLayout(HStackLayout(spacing: NexusSpacing.space12))
            dateLayout {
                NexusSearchField(label: "Departure", value: dateValue(departureDate), icon: .calendar, action: onChooseDeparture)
                    .accessibilityIdentifier("destination-depart-date")
                Divider().overlay(NexusSemanticColors.borderDefault)
                NexusSearchField(label: "Return", value: dateValue(returnDate), icon: .calendar, action: onChooseReturn)
                    .accessibilityIdentifier("destination-return-date")
            }
            Divider().overlay(NexusSemanticColors.borderDefault)
            NexusSearchField(label: "Travelers", value: "\(adults) \(adults == 1 ? "Adult" : "Adults")", icon: .profile, showsChevron: true) {
                onChooseTravelers()
            }
            .accessibilityIdentifier("destination-travelers")
        }
        .padding(NexusSpacing.space16)
        .background(NexusSemanticColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xxxl))
        .shadow(color: NexusSemanticColors.textPrimary.opacity(0.14), radius: NexusSpacing.space8, y: NexusSpacing.space4)
    }

    private func dateValue(_ date: LocalDate?) -> String {
        date?.foundationDate.formatted(.dateTime.month(.abbreviated).day().year()) ?? "Select date"
    }

    private var dateSummary: String {
        guard let departureDate, let returnDate else { return "Select travel dates" }
        let format = Date.FormatStyle().month(.abbreviated).day()
        return "\(departureDate.foundationDate.formatted(format)) – \(returnDate.foundationDate.formatted(format))"
    }

    private var stickyAction: some View {
        VStack(spacing: NexusSpacing.space8) {
            if let searchError {
                Text(searchError)
                    .nexusTextStyle(NexusText.styles.errorText)
                    .foregroundStyle(NexusSemanticColors.errorText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("destination-search-error")
            }
            HStack(spacing: NexusSpacing.space12) {
                VStack(alignment: .leading, spacing: NexusSpacing.space2) {
                    Text(departureDate == nil || returnDate == nil ? "Flights to \(destination.title)" : dateSummary)
                        .nexusTextStyle(NexusText.styles.label)
                    Text(departureDate == nil || returnDate == nil ? "Select travel dates" : "\(adults) \(adults == 1 ? "adult" : "adults") · Economy")
                        .nexusTextStyle(NexusText.styles.caption)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                NexusPrimaryButton(
                    departureDate == nil || returnDate == nil ? "Choose dates" : "Search flights",
                    isEnabled: destination.airportCode != nil,
                    isLoading: isSearching,
                    loadingTitle: "Searching...",
                    action: departureDate == nil || returnDate == nil ? onChooseDeparture : searchFlights
                )
            }
        }
        .padding(.horizontal, NexusLayout.screenMargin)
        .padding(.vertical, NexusSpacing.space12)
        .background(.regularMaterial)
    }

    private func searchFlights() {
        guard let airportCode = destination.airportCode else { return }
        onSearchFlights(airportCode)
    }
}
