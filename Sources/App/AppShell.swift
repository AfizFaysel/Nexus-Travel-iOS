import SwiftUI

struct AppShell: View {
    @Bindable var router: Router
    @State private var homeRootScrollTarget: String?
    @State private var exploreRootScrollTarget: String?
    @State private var tripsRootScrollTarget: String?
    @State private var profileRootScrollTarget: String?
    @State private var freshSearchTask: Task<Void, Never>?
    let homeViewModel: HomeViewModel
    let exploreViewModel: ExploreViewModel
    let tripsViewModel: TripsViewModel
    let flightSearchRepository: any FlightSearchRepository
    let searchResultsRepository: any SearchResultsRepository
    let flightDetailsRepository: any FlightDetailsRepository
    let passengerDetailsRepository: any PassengerDetailsRepository
    let flightSeatsRepository: any FlightSeatsRepository
    let bookingRequestRepository: any BookingRequestRepository
    let paymentProofRepository: any PaymentProofRepository
    let tripsRepository: any TripsRepository
    let exploreRepository: any ExploreRepository
    let profileRepository: any ProfileRepository
    let securityRepository: any AccountSecurityRepository
    let airportRepository: any AirportRepository
    let profileViewModel: ProfileViewModel
    let preferencesViewModel: PreferencesViewModel
    let authRepository: any AuthRepository
    let bookingFlowState: BookingFlowState

    var body: some View {
        selectedTabContent
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.showsMainBottomBar {
                MainBottomBar(selected: router.selectedTab, onSelected: router.select)
            }
        }
        .foregroundStyle(NexusSemanticColors.textPrimary)
        .tint(NexusSemanticColors.brandPrimary)
        .sheet(
            item: Binding(
                get: { router.authPresentation },
                set: { if $0 == nil { router.dismissAuthentication() } }
            )
        ) { purpose in
            AuthRoute(
                viewModel: AuthViewModel(repository: authRepository),
                purpose: purpose,
                onAuthenticated: {
                    _ = bookingFlowState.completeAuthentication()
                    router.dismissAuthentication()
                }
            )
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(NexusRadius.xxxl)
        }
        .sheet(
            item: Binding(
                get: { router.authLinkPresentation },
                set: { if $0 == nil, let route = router.authLinkPresentation { router.dismissAuthLink(route) } }
            )
        ) { route in
            AuthLinkScreen(
                viewModel: AuthViewModel(repository: authRepository),
                route: route,
                onPasswordResetComplete: {
                    bookingFlowState.completeLogout()
                    profileViewModel.clearForPasswordReset()
                    tripsViewModel.clearForLogout()
                    router.tripsPath.removeAll()
                },
                onDone: {
                    router.dismissAuthLink(route)
                    router.push(.mainAuth(MainAuthRoute()))
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onOpenURL(perform: router.handleAuthLink)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch router.selectedTab {
        case .home: homeStack
        case .explore: exploreStack
        case .trips: tripsStack
        case .profile: profileStack
        }
    }

    private var homeStack: some View {
        navigationStack(path: $router.homePath) {
            HomeRoute(viewModel: homeViewModel, router: router, rootScrollTarget: $homeRootScrollTarget)
        }
    }

    private var exploreStack: some View {
        navigationStack(path: $router.explorePath) {
            ExploreScreenRoute(viewModel: exploreViewModel, router: router, rootScrollTarget: $exploreRootScrollTarget)
        }
    }

    private var tripsStack: some View {
        navigationStack(path: $router.tripsPath) {
            TripsScreenRoute(viewModel: tripsViewModel, router: router, rootScrollTarget: $tripsRootScrollTarget)
        }
    }

    private var profileStack: some View {
        navigationStack(path: $router.profilePath) {
            ProfileScreenRoute(
                viewModel: profileViewModel,
                router: router,
                rootScrollTarget: $profileRootScrollTarget,
                onSignedOut: {
                    bookingFlowState.completeLogout()
                    bookingFlowState.clear()
                    tripsViewModel.clearForLogout()
                    router.tripsPath.removeAll()
                }
            )
        }
    }

    private func navigationStack<Root: View>(
        path: Binding<[AppRoute]>,
        @ViewBuilder root: () -> Root
    ) -> some View {
        NavigationStack(path: path) {
            root().appDestinations(
                router: router,
                flightSearchRepository: flightSearchRepository,
                searchResultsRepository: searchResultsRepository,
                flightDetailsRepository: flightDetailsRepository,
                passengerDetailsRepository: passengerDetailsRepository,
                flightSeatsRepository: flightSeatsRepository,
                bookingRequestRepository: bookingRequestRepository,
                paymentProofRepository: paymentProofRepository,
                tripsRepository: tripsRepository,
                exploreRepository: exploreRepository,
                profileRepository: profileRepository,
                securityRepository: securityRepository,
                airportRepository: airportRepository,
                profileViewModel: profileViewModel,
                preferencesViewModel: preferencesViewModel,
                authRepository: authRepository,
                bookingFlowState: bookingFlowState,
                onSearchAgain: startFreshSearch
            )
        }
    }

    private func startFreshSearch() {
        guard freshSearchTask == nil else { return }
        bookingFlowState.clear()
        router.popToRoot()
        freshSearchTask = Task { @MainActor in
            let searchId = await homeViewModel.searchAgain()
            guard !Task.isCancelled else { freshSearchTask = nil; return }
            if let searchId {
                router.push(.searchResults(.init(searchId: searchId)))
            }
            freshSearchTask = nil
        }
    }
}

private struct MainBottomBar: View {
    let selected: MainTab
    let onSelected: (MainTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                item(tab)
            }
        }
        .frame(height: NexusLayout.mainBottomBarHeight)
        .padding(.horizontal, NexusSpacing.space12)
        .background(NexusSemanticColors.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xxxl))
        .overlay {
            RoundedRectangle(cornerRadius: NexusRadius.xxxl)
                .stroke(NexusSemanticColors.borderDefault.opacity(0.2), lineWidth: NexusBorder.hairline)
        }
        .shadow(
            color: Color.black.opacity(NexusElevation.mainBottomBarAmbientOpacity),
            radius: NexusElevation.mainBottomBarAmbientRadius,
            y: NexusElevation.mainBottomBarAmbientY
        )
        .shadow(
            color: Color.black.opacity(NexusElevation.mainBottomBarContactOpacity),
            radius: NexusElevation.mainBottomBarContactRadius,
            y: NexusElevation.mainBottomBarContactY
        )
        .padding(.horizontal, NexusSpacing.space16)
        .padding(.vertical, NexusSpacing.space12)
        .background(NexusSemanticColors.backgroundPage.ignoresSafeArea(edges: .bottom))
    }

    private func item(_ tab: MainTab) -> some View {
        let isSelected = selected == tab
        return Button { onSelected(tab) } label: {
            VStack(spacing: 0) {
                NexusIcon(
                    name: tab.icon,
                    size: isSelected ? NexusIconSize.lg : NexusIconSize.md
                )
                Text(tab.label)
                    .nexusTextStyle(
                        NexusText.styles.statusBadge.withFontWeight(isSelected ? .semibold : .medium)
                    )
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .foregroundStyle(isSelected ? NexusSemanticColors.brandPrimary : NexusColors.slate500)
            .frame(maxWidth: .infinity, minHeight: NexusLayout.touchRecommended)
            .contentShape(Rectangle())
        }
        .buttonStyle(MainBottomBarItemStyle())
        .accessibilityLabel(tab.label)
        .accessibilityIdentifier("main-tab-\(tab.label.lowercased())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MainBottomBarItemStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: NexusRadius.lg)
                    .fill(configuration.isPressed ? NexusSemanticColors.surfaceHover : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: NexusMotion.durationFastSeconds),
                value: configuration.isPressed
            )
    }
}

private struct AppTabRoot: View {
    let tab: MainTab

    var body: some View {
        ContentUnavailableView(
            tab.label,
            systemImage: tab.icon.systemName,
            description: Text("Content is unavailable.")
        )
        .navigationTitle(tab.label)
    }
}

private struct AppDestinations: ViewModifier {
    let router: Router
    let flightSearchRepository: any FlightSearchRepository
    let searchResultsRepository: any SearchResultsRepository
    let flightDetailsRepository: any FlightDetailsRepository
    let passengerDetailsRepository: any PassengerDetailsRepository
    let flightSeatsRepository: any FlightSeatsRepository
    let bookingRequestRepository: any BookingRequestRepository
    let paymentProofRepository: any PaymentProofRepository
    let tripsRepository: any TripsRepository
    let exploreRepository: any ExploreRepository
    let profileRepository: any ProfileRepository
    let securityRepository: any AccountSecurityRepository
    let airportRepository: any AirportRepository
    let profileViewModel: ProfileViewModel
    let preferencesViewModel: PreferencesViewModel
    let authRepository: any AuthRepository
    let bookingFlowState: BookingFlowState
    let onSearchAgain: () -> Void

    func body(content: Content) -> some View {
        content.navigationDestination(for: AppRoute.self) { route in
            switch route {
            case let .searchResults(payload):
                SearchResultsScreenRoute(
                    viewModel: SearchResultsViewModel(searchId: payload.searchId, repository: searchResultsRepository),
                    router: router
                )
            case let .flightDetails(payload):
                FlightDetailsScreenRoute(
                    viewModel: FlightDetailsViewModel(
                        reference: payload.reference,
                        repository: flightDetailsRepository
                    ),
                    router: router,
                    bookingFlowState: bookingFlowState,
                    reference: payload.reference
                )
            case .mainAuth:
                AuthRoute(
                    viewModel: AuthViewModel(repository: authRepository),
                    onAuthenticated: {
                        _ = bookingFlowState.completeAuthentication()
                        router.completeMainAuth()
                    }
                )
            case .bookingAuth:
                AuthRoute(
                    viewModel: AuthViewModel(repository: authRepository),
                    onAuthenticated: {
                        _ = bookingFlowState.completeAuthentication()
                        router.completeBookingAuth()
                    }
                )
            case .passengerDetails:
                if let details = bookingFlowState.passengerDetails {
                    PassengerDetailsScreenRoute(
                        viewModel: PassengerDetailsViewModel(
                            details: details, repository: passengerDetailsRepository,
                            today: Self.currentLocalDate
                        ), router: router, bookingFlowState: bookingFlowState
                    )
                } else {
                    ContentUnavailableView("Passenger details unavailable", systemImage: NexusPlatformIconName.passengerError.rawValue)
                }
            case let .seatSelection(route):
                SeatSelectionScreenRoute(
                    viewModel: SeatSelectionViewModel(
                        bookingId: route.bookingId,
                        passengerCount: bookingFlowState.passengerDetails?.travelers.total ?? 1,
                        repository: flightSeatsRepository
                    ), router: router
                )
            case let .bookingReview(route):
                BookingReviewScreenRoute(
                    viewModel: BookingReviewViewModel(reviewId: route.reviewId, repository: bookingRequestRepository),
                    flightDetails: bookingFlowState.passengerDetails,
                    router: router,
                    onSearchAgain: onSearchAgain
                )
            case let .paymentProof(route):
                PaymentProofScreenRoute(
                    viewModel: PaymentProofViewModel(bookingId: route.bookingId, repository: paymentProofRepository,
                                                     statusCheck: { try await bookingRequestRepository.getStatus(reviewId: $0) }),
                    router: router, bookingId: route.bookingId
                )
            case let .tripDetail(route):
                TripDetailScreenRoute(
                    viewModel: TripDetailViewModel(bookingId: route.tripId, repository: tripsRepository),
                    router: router,
                    onUploadPaymentProof: { router.push(.paymentProof(.init(bookingId: $0))) }
                )
            case let .destinationDetail(route):
                ExploreDetailScreenRoute(
                    viewModel: ExploreDetailViewModel(
                        repository: exploreRepository,
                        flightSearchRepository: flightSearchRepository,
                        today: Self.currentLocalDate
                    ),
                    mode: .destination(route.destinationId),
                    onSearchResults: { router.push(.searchResults(.init(searchId: $0))) }
                )
            case let .packageDetail(route):
                ExploreDetailScreenRoute(
                    viewModel: ExploreDetailViewModel(
                        repository: exploreRepository,
                        flightSearchRepository: flightSearchRepository,
                        today: Self.currentLocalDate
                    ),
                    mode: .package(route.packageId),
                    onSearchResults: { router.push(.searchResults(.init(searchId: $0))) }
                )
            case .editProfile:
                EditProfileScreen(viewModel: EditProfileViewModel(repository: profileRepository))
            case .savedTravelers:
                SavedTravelersScreen(travelers: profileViewModel.state.travelers)
            case .settings:
                SettingsScreen(viewModel: preferencesViewModel, router: router)
            case .theme:
                ThemeScreen(viewModel: preferencesViewModel)
            case .homeAirport:
                HomeAirportScreen(viewModel: preferencesViewModel, airports: airportRepository)
            case .notificationSettings:
                NotificationSettingsScreen(viewModel: preferencesViewModel)
            case .security:
                SecurityScreen(viewModel: AccountSecurityViewModel(repository: securityRepository), router: router, authRepository: authRepository)
            case .deleteAccount:
                DeleteAccountScreen(
                    viewModel: DeleteAccountViewModel(repository: securityRepository, clearSession: { _ = try await authRepository.signOut() }),
                    onDone: {
                        bookingFlowState.completeLogout()
                        router.popToRoot()
                    }
                )
            default:
                AppDestination(route: route)
            }
        }
    }

    private static func currentLocalDate() -> LocalDate {
        let values = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        guard let year = values.year, let month = values.month, let day = values.day,
              let date = LocalDate(year: year, month: month, day: day) else {
            preconditionFailure("Current Gregorian date must be representable.")
        }
        return date
    }
}

private struct AppDestination: View {
    let route: AppRoute

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: NexusIconName.flight.systemName,
            description: Text("Content is unavailable.")
        )
        .navigationTitle(title)
    }

    private var title: String {
        switch route {
        case .home: "Home"
        case .explore: "Explore"
        case .destinationDetail: "Destination"
        case .packageDetail: "Package"
        case .trips: "Trips"
        case .tripDetail: "Trip"
        case .profile: "Profile"
        case .editProfile: "Edit Profile"
        case .savedTravelers: "Saved Travelers"
        case .settings: "Settings"
        case .language: "Language"
        case .currency: "Currency"
        case .theme: "Theme"
        case .homeAirport: "Home Airport"
        case .notificationSettings: "Notifications"
        case .security: "Security"
        case .deleteAccount: "Delete Account"
        case .mainAuth, .bookingAuth: "Sign In"
        case .searchResults: "Search Results"
        case .flightDetails: "Flight Details"
        case .passengerDetails: "Passenger Details"
        case .seatSelection: "Seat Selection"
        case .bookingReview: "Booking Review"
        case .paymentProof: "Payment Proof"
        }
    }
}

private extension View {
    func appDestinations(
        router: Router,
        flightSearchRepository: any FlightSearchRepository,
        searchResultsRepository: any SearchResultsRepository,
        flightDetailsRepository: any FlightDetailsRepository,
        passengerDetailsRepository: any PassengerDetailsRepository,
        flightSeatsRepository: any FlightSeatsRepository,
        bookingRequestRepository: any BookingRequestRepository,
        paymentProofRepository: any PaymentProofRepository,
        tripsRepository: any TripsRepository,
        exploreRepository: any ExploreRepository,
        profileRepository: any ProfileRepository,
        securityRepository: any AccountSecurityRepository,
        airportRepository: any AirportRepository,
        profileViewModel: ProfileViewModel,
        preferencesViewModel: PreferencesViewModel,
        authRepository: any AuthRepository,
        bookingFlowState: BookingFlowState,
        onSearchAgain: @escaping () -> Void
    ) -> some View {
        modifier(AppDestinations(
            router: router,
            flightSearchRepository: flightSearchRepository,
            searchResultsRepository: searchResultsRepository,
            flightDetailsRepository: flightDetailsRepository,
            passengerDetailsRepository: passengerDetailsRepository,
            flightSeatsRepository: flightSeatsRepository,
            bookingRequestRepository: bookingRequestRepository,
            paymentProofRepository: paymentProofRepository,
            tripsRepository: tripsRepository,
            exploreRepository: exploreRepository,
            profileRepository: profileRepository,
            securityRepository: securityRepository,
            airportRepository: airportRepository,
            profileViewModel: profileViewModel,
            preferencesViewModel: preferencesViewModel,
            authRepository: authRepository,
            bookingFlowState: bookingFlowState,
            onSearchAgain: onSearchAgain
        ))
    }
}

