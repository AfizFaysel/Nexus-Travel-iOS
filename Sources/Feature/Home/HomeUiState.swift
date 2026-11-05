/// Editable state for one multi-city flight leg.
struct MultiCityLegUiState: Equatable, Hashable, Codable, Sendable {
    let origin: Airport?
    let destination: Airport?
    let departureDate: LocalDate?
    let originAutoLinked: Bool

    /// Creates a leg with optional route and date selections.
    init(
        origin: Airport? = nil,
        destination: Airport? = nil,
        departureDate: LocalDate? = nil,
        originAutoLinked: Bool = false
    ) {
        self.origin = origin
        self.destination = destination
        self.departureDate = departureDate
        self.originAutoLinked = originAutoLinked
    }
}

/// Search validation failure shown by home.
enum HomeValidationError: Equatable, Hashable, Codable, Sendable {
    case missingOrigin
    case missingDestination
    case sameOriginDestination
    case missingDepartureDate
    case missingReturnDate
    case returnBeforeDeparture
    case departureDateInPast
    case invalidMultiCityLegs
}

enum HomeSheet: Equatable, Hashable, Codable, Identifiable, Sendable {
    case originAirport, destinationAirport, departureDate, returnDate
    case multiCityOrigin(index: Int), multiCityDestination(index: Int), multiCityDate(index: Int)
    case travelers, cabinClass, hotelComingSoon

    var id: String {
        switch self {
        case .originAirport: "originAirport"
        case .destinationAirport: "destinationAirport"
        case .departureDate: "departureDate"
        case .returnDate: "returnDate"
        case let .multiCityOrigin(index): "multiCityOrigin-\(index)"
        case let .multiCityDestination(index): "multiCityDestination-\(index)"
        case let .multiCityDate(index): "multiCityDate-\(index)"
        case .travelers: "travelers"
        case .cabinClass: "cabinClass"
        case .hotelComingSoon: "hotelComingSoon"
        }
    }
}

enum HomeService: Equatable, Hashable, Codable, Sendable { case flight }

enum HomeLoadPhase: Equatable, Hashable, Codable, Sendable { case loading, content, empty, error }

enum HomeUiEvent: Equatable, Sendable {
    case flightClicked, hotelClicked
    case tripTypeChanged(TripType)
    case originClicked, destinationClicked, swapAirportsClicked
    case departureDateClicked, returnDateClicked, travelersClicked, cabinClassClicked
    case airportSelected(Airport), airportQueryChanged(String)
    case departureDateSelected(LocalDate), returnDateSelected(LocalDate)
    case multiCityOriginClicked(index: Int), multiCityDestinationClicked(index: Int), multiCityDateClicked(index: Int)
    case multiCityDateSelected(index: Int, date: LocalDate), addMultiCityLeg, removeMultiCityLeg(index: Int)
    case travelersChanged(TravelerCounts, childAges: [Int], infantAges: [Int])
    case cabinClassChanged(CabinClass)
    case trendingEscapeClicked(TrendingEscape)
    case searchClicked, dismissSheet, clearValidationError
}

enum HomeNavigationEvent: Equatable, Sendable {
    case toSearchResults(searchId: String)
    case toDestinationDetail(destinationId: String)
}

/// Presentation-independent home fields needed by search validation and multi-city transitions.
struct HomeUiState: Equatable, Hashable, Codable, Sendable {
    var isLoading: Bool
    var userName: String
    var tripType: TripType
    var origin: Airport?
    var destination: Airport?
    var departureDate: LocalDate?
    var returnDate: LocalDate?
    var travelers: TravelerCounts
    var childAges: [Int]
    var infantAges: [Int]
    var cabinClass: CabinClass
    var multiCityLegs: [MultiCityLegUiState]
    var trendingEscapes: [TrendingEscape]
    var airports: [Airport]
    var airportQuery: String
    var activeSheet: HomeSheet?
    var validationError: HomeValidationError?
    var isSearching: Bool
    var message: String?
    var selectedService: HomeService?
    var loadPhase: HomeLoadPhase

    /// Creates home state with Android-equivalent defaults.
    init(
        isLoading: Bool = true,
        userName: String = "Traveler",
        tripType: TripType = .oneWay,
        origin: Airport? = nil,
        destination: Airport? = nil,
        departureDate: LocalDate? = nil,
        returnDate: LocalDate? = nil,
        travelers: TravelerCounts = TravelerCounts(),
        childAges: [Int] = [],
        infantAges: [Int] = [],
        cabinClass: CabinClass = .economy,
        multiCityLegs: [MultiCityLegUiState] = [],
        trendingEscapes: [TrendingEscape] = [],
        airports: [Airport] = [],
        airportQuery: String = "",
        activeSheet: HomeSheet? = nil,
        validationError: HomeValidationError? = nil,
        isSearching: Bool = false,
        message: String? = nil,
        selectedService: HomeService? = nil,
        loadPhase: HomeLoadPhase? = nil
    ) {
        self.isLoading = isLoading
        self.userName = userName
        self.tripType = tripType
        self.origin = origin
        self.destination = destination
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.travelers = travelers
        self.childAges = childAges
        self.infantAges = infantAges
        self.cabinClass = cabinClass
        self.multiCityLegs = multiCityLegs
        self.trendingEscapes = trendingEscapes
        self.airports = airports
        self.airportQuery = airportQuery
        self.activeSheet = activeSheet
        self.validationError = validationError
        self.isSearching = isSearching
        self.message = message
        self.selectedService = selectedService
        self.loadPhase = loadPhase ?? (
            isLoading ? .loading : message != nil ? .error : trendingEscapes.isEmpty ? .empty : .content
        )
    }

    /// Returns state after Android-equivalent trip-type transition.
    func settingTripType(_ tripType: TripType) -> HomeUiState {
        let legs = tripType == .multiCity && multiCityLegs.isEmpty
            ? initialMultiCityLegs(origin: origin, destination: destination, date: departureDate)
            : multiCityLegs
        let error = tripType == .oneWay && validationError == .returnBeforeDeparture
            ? nil
            : validationError
        return replacing(tripType: tripType, multiCityLegs: legs, validationError: error)
    }

    private func replacing(
        tripType: TripType,
        multiCityLegs: [MultiCityLegUiState],
        validationError: HomeValidationError?
    ) -> HomeUiState {
        HomeUiState(
            isLoading: isLoading,
            userName: userName,
            tripType: tripType,
            origin: origin,
            destination: destination,
            departureDate: departureDate,
            returnDate: returnDate,
            travelers: travelers,
            childAges: childAges,
            infantAges: infantAges,
            cabinClass: cabinClass,
            multiCityLegs: multiCityLegs,
            trendingEscapes: trendingEscapes,
            airports: airports,
            airportQuery: airportQuery,
            activeSheet: activeSheet,
            validationError: validationError,
            isSearching: isSearching,
            message: message,
            selectedService: selectedService,
            loadPhase: loadPhase
        )
    }
}
