import Foundation

@MainActor
struct AppDependencies {
    let transport: HTTPTransport
    let sessionStore: any AuthSessionStore
    let airportCache: AirportCache
    let searchResultsCache: SearchResultsCache
    let flightSearchRepository: RemoteFlightSearchRepository
    let searchResultsRepository: RemoteSearchResultsRepository
    let flightDetailsRepository: RemoteFlightDetailsRepository
    let passengerDetailsRepository: RemotePassengerDetailsRepository
    let flightSeatsRepository: RemoteFlightSeatsRepository
    let bookingRequestRepository: RemoteBookingRequestRepository
    let paymentProofRepository: RemotePaymentProofRepository
    let tripsRepository: RemoteTripsRepository
    let exploreRepository: RemoteExploreRepository
    let profileRepository: RemoteProfileRepository
    let preferencesRepository: RemotePreferencesRepository
    let securityRepository: RemoteAccountSecurityRepository
    let airportRepository: RemoteAirportRepository
    let appTheme: AppTheme
    let profileViewModel: ProfileViewModel
    let preferencesViewModel: PreferencesViewModel
    let authRepository: RemoteAuthRepository
    let homeViewModel: HomeViewModel
    let exploreViewModel: ExploreViewModel
    let tripsViewModel: TripsViewModel

    init(sessionStore: any AuthSessionStore = KeychainAuthSessionStore()) {
        let sharedTransport = HTTPTransport()
        let sharedSessionStore = sessionStore
        let sharedAirportCache = AirportCache()
        let sharedSearchResultsCache = SearchResultsCache()
        let sharedAuthRepository = RemoteAuthRepository(
            transport: sharedTransport,
            sessionStore: sharedSessionStore
        )
        let sharedAirportRepository = RemoteAirportRepository(
            transport: sharedTransport,
            cache: sharedAirportCache
        )
        let sharedTokenProvider = AuthTokenProvider(sessionStore: sharedSessionStore)
        let sharedPreferencesStore = ProfilePreferencesStore()
        let sharedAppTheme = AppTheme()
        let sharedProfileRepository = RemoteProfileRepository(transport: sharedTransport, tokenProvider: sharedTokenProvider)
        let sharedPreferencesRepository = RemotePreferencesRepository(transport: sharedTransport, tokenProvider: sharedTokenProvider, store: sharedPreferencesStore)
        let sharedSecurityRepository = RemoteAccountSecurityRepository(transport: sharedTransport, tokenProvider: sharedTokenProvider)
        let sharedTripsRepository = RemoteTripsRepository(
            transport: sharedTransport, tokenProvider: AuthTokenProvider(sessionStore: sharedSessionStore),
            cache: TripCache(), ticketStore: TicketPdfStore()
        )
        let sharedExploreRepository = RemoteExploreRepository(transport: sharedTransport, cache: ExploreCache())
        let sharedFlightSearchRepository = RemoteFlightSearchRepository(
            transport: sharedTransport,
            cache: sharedSearchResultsCache
        )
        transport = sharedTransport
        self.sessionStore = sharedSessionStore
        airportCache = sharedAirportCache
        airportRepository = sharedAirportRepository
        searchResultsCache = sharedSearchResultsCache
        flightSearchRepository = sharedFlightSearchRepository
        searchResultsRepository = RemoteSearchResultsRepository(cache: sharedSearchResultsCache)
        flightDetailsRepository = RemoteFlightDetailsRepository(transport: sharedTransport)
        passengerDetailsRepository = RemotePassengerDetailsRepository(
            transport: sharedTransport,
            tokenProvider: AuthTokenProvider(sessionStore: sharedSessionStore),
            passportUploadRepository: RemotePassportUploadRepository(
                transport: sharedTransport, tokenProvider: AuthTokenProvider(sessionStore: sharedSessionStore)
            )
        )
        flightSeatsRepository = RemoteFlightSeatsRepository(
            transport: sharedTransport, tokenProvider: AuthTokenProvider(sessionStore: sharedSessionStore)
        )
        bookingRequestRepository = RemoteBookingRequestRepository(
            transport: sharedTransport, tokenProvider: AuthTokenProvider(sessionStore: sharedSessionStore)
        )
        paymentProofRepository = RemotePaymentProofRepository(
            transport: sharedTransport, tokenProvider: AuthTokenProvider(sessionStore: sharedSessionStore)
        )
        tripsRepository = sharedTripsRepository
        exploreRepository = sharedExploreRepository
        profileRepository = sharedProfileRepository
        preferencesRepository = sharedPreferencesRepository
        securityRepository = sharedSecurityRepository
        appTheme = sharedAppTheme
        profileViewModel = ProfileViewModel(repository: sharedProfileRepository, authRepository: sharedAuthRepository)
        preferencesViewModel = PreferencesViewModel(repository: sharedPreferencesRepository, onTheme: { sharedAppTheme.preference = $0 })
        authRepository = sharedAuthRepository
        homeViewModel = HomeViewModel(
            homeRepository: RemoteHomeRepository(
                transport: sharedTransport,
                airportRepository: sharedAirportRepository
            ),
            airportRepository: sharedAirportRepository,
            flightSearchRepository: sharedFlightSearchRepository,
            authRepository: sharedAuthRepository,
            today: Self.currentLocalDate
        )
        exploreViewModel = ExploreViewModel(repository: sharedExploreRepository)
        tripsViewModel = TripsViewModel(repository: sharedTripsRepository, authRepository: sharedAuthRepository)
    }

    private static func currentLocalDate() -> LocalDate {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        guard let year = components.year, let month = components.month, let day = components.day,
              let date = LocalDate(year: year, month: month, day: day) else {
            preconditionFailure("Current Gregorian date must be representable.")
        }
        return date
    }
}

/// Process-local auth storage used by isolated UI tests.
actor VolatileAuthSessionStore: AuthSessionStore {
    private var session: StoredAuthSession?

    func read() -> StoredAuthSession? { session }
    func write(_ session: StoredAuthSession) { self.session = session }
    func clear() { session = nil }
}
