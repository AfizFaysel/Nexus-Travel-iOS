import Observation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var uiState = HomeUiState()

    private let homeRepository: any HomeRepository
    private let airportRepository: any AirportRepository
    private let flightSearchRepository: any FlightSearchRepository
    private let authRepository: any AuthRepository
    private let searchValidator: HomeSearchValidator
    private let today: () -> LocalDate
    private var pendingNavigationEvents: [HomeNavigationEvent] = []
    private var airportSearchGeneration = 0
    private var airportSearchTask: Task<[Airport], Error>?
    private var loadGeneration = 0
    private var hasLoaded = false

    var currentDate: LocalDate { today() }

    init(
        homeRepository: any HomeRepository,
        airportRepository: any AirportRepository,
        flightSearchRepository: any FlightSearchRepository,
        authRepository: any AuthRepository,
        searchValidator: HomeSearchValidator = HomeSearchValidator(),
        today: @escaping () -> LocalDate
    ) {
        self.homeRepository = homeRepository
        self.airportRepository = airportRepository
        self.flightSearchRepository = flightSearchRepository
        self.authRepository = authRepository
        self.searchValidator = searchValidator
        self.today = today
    }

    func load() async throws {
        loadGeneration += 1
        let generation = loadGeneration
        let previousState = uiState
        let service = uiState.selectedService
        let sheet = uiState.activeSheet
        let name: String
        do {
            name = greetingName(try await authRepository.getLocalSession()?.user.displayName)
        } catch is CancellationError {
            if generation == loadGeneration { uiState = previousState }
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                if generation == loadGeneration { uiState = previousState }
                throw CancellationError()
            }
            name = "Traveler"
        }
        uiState = HomeUiState(isLoading: true, userName: name, activeSheet: sheet, selectedService: service)
        let airports: [Airport]
        do {
            airports = try await airportRepository.searchAirports(query: "")
        } catch is CancellationError {
            if generation == loadGeneration { uiState = previousState }
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                if generation == loadGeneration { uiState = previousState }
                throw CancellationError()
            }
            airports = []
        }
        let result: HomeResult<HomeContent>
        do {
            result = try await homeRepository.getHomeContent()
        } catch is CancellationError {
            if generation == loadGeneration { uiState = previousState }
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                if generation == loadGeneration { uiState = previousState }
                throw CancellationError()
            }
            result = .unknownError
        }
        let departure = today().addingDays(7)
        guard generation == loadGeneration else { return }
        switch result {
        case let .success(content):
            uiState = HomeUiState(
                isLoading: false, userName: name, origin: content.origin, destination: content.destination,
                departureDate: departure, returnDate: departure?.addingDays(7), trendingEscapes: content.trendingEscapes,
                airports: airports, activeSheet: sheet, selectedService: service,
                loadPhase: content.trendingEscapes.isEmpty ? .empty : .content
            )
        case .networkUnavailable:
            uiState = fallbackState(airports: airports, name: name,
                message: "You are offline. Check your connection and try again.", service: service, sheet: sheet)
        case .unknownError:
            uiState = fallbackState(airports: airports, name: name,
                message: "We could not load your home page. Please try again.", service: service, sheet: sheet)
        }
        hasLoaded = true
    }

    func loadIfNeeded() async throws {
        guard !hasLoaded else { return }
        try await load()
    }

    func retry() async {
        do {
            try await load()
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    func onEvent(_ event: HomeUiEvent) async {
        switch event {
        case .flightClicked:
            uiState.selectedService = .flight
            uiState.activeSheet = nil
        case .hotelClicked: open(.hotelComingSoon)
        case let .tripTypeChanged(type): uiState = uiState.settingTripType(type)
        case .originClicked: await openAirportSheet(.originAirport)
        case .destinationClicked: await openAirportSheet(.destinationAirport)
        case .swapAirportsClicked:
            (uiState.origin, uiState.destination) = (uiState.destination, uiState.origin)
            clearFeedback()
        case .departureDateClicked: open(.departureDate)
        case .returnDateClicked: open(.returnDate)
        case .travelersClicked: open(.travelers)
        case .cabinClassClicked: open(.cabinClass)
        case let .multiCityOriginClicked(index): await openAirportSheet(.multiCityOrigin(index: index))
        case let .multiCityDestinationClicked(index): await openAirportSheet(.multiCityDestination(index: index))
        case let .multiCityDateClicked(index): open(.multiCityDate(index: index))
        case let .airportSelected(airport): selectAirport(airport)
        case let .airportQueryChanged(query): await searchAirports(query: query)
        case let .departureDateSelected(date): selectDepartureDate(date)
        case let .returnDateSelected(date):
            uiState.returnDate = date
            uiState.activeSheet = nil
            uiState.validationError = searchValidator.validateDates(
                tripType: uiState.tripType, departureDate: uiState.departureDate, returnDate: date, today: today())
        case let .multiCityDateSelected(index, date):
            uiState.multiCityLegs = uiState.multiCityLegs.selectMultiCityDate(index: index, date: date)
            uiState.activeSheet = nil
            uiState.validationError = nil
        case .addMultiCityLeg: uiState.multiCityLegs = uiState.multiCityLegs.addMultiCityLeg()
        case let .removeMultiCityLeg(index): uiState.multiCityLegs = uiState.multiCityLegs.removeMultiCityLeg(index: index)
        case let .travelersChanged(travelers, childAges, infantAges):
            let normalized = travelers.normalized()
            uiState.travelers = normalized
            uiState.childAges = Array(childAges.prefix(normalized.children))
            uiState.infantAges = Array(infantAges.prefix(normalized.infants))
            uiState.activeSheet = nil
            uiState.validationError = nil
        case let .cabinClassChanged(cabin):
            uiState.cabinClass = cabin
            uiState.activeSheet = nil
        case let .trendingEscapeClicked(escape):
            pendingNavigationEvents.append(.toDestinationDetail(destinationId: escape.id))
        case .searchClicked: await searchFlights()
        case .dismissSheet:
            uiState.activeSheet = nil
            uiState.airportQuery = ""
            cancelAirportSearch()
        case .clearValidationError: uiState.validationError = nil
        }
    }

    func prefillDestination(airportCode: String) async throws {
        guard let airport = try await airport(matching: airportCode) else { return }
        uiState.destination = airport
        clearFeedback()
    }

    func prefillOrigin(airportCode: String) async throws {
        guard let airport = try await airport(matching: airportCode) else { return }
        uiState.origin = airport
        clearFeedback()
    }

    func consumeNavigationEvent() -> HomeNavigationEvent? {
        pendingNavigationEvents.isEmpty ? nil : pendingNavigationEvents.removeFirst()
    }

    func cancelAirportSearch() {
        airportSearchGeneration += 1
        airportSearchTask?.cancel()
        airportSearchTask = nil
    }

    private func fallbackState(
        airports: [Airport], name: String, message: String, service: HomeService?, sheet: HomeSheet?
    ) -> HomeUiState {
        let departure = today().addingDays(7)
        let origin = airports.first { $0.code == "ADD" } ?? airports.first
        let destination = airports.first { $0.code == "DXB" } ?? airports.first { $0.code != origin?.code }
        return HomeUiState(isLoading: false, userName: name, origin: origin, destination: destination,
                           departureDate: departure, returnDate: departure?.addingDays(7), airports: airports,
                           activeSheet: sheet, message: message, selectedService: service, loadPhase: .error)
    }

    private func open(_ sheet: HomeSheet) {
        uiState.activeSheet = sheet
        uiState.airportQuery = ""
    }

    private func openAirportSheet(_ sheet: HomeSheet) async {
        open(sheet)
        await searchAirports(query: "")
    }

    private func searchAirports(query: String) async {
        uiState.airportQuery = query
        airportSearchGeneration += 1
        let generation = airportSearchGeneration
        airportSearchTask?.cancel()
        let task = Task { try await airportRepository.searchAirports(query: query) }
        airportSearchTask = task
        do {
            let airports = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            guard generation == airportSearchGeneration, uiState.airportQuery == query else { return }
            uiState.airports = airports
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private func selectAirport(_ airport: Airport) {
        switch uiState.activeSheet {
        case .originAirport:
            uiState.origin = airport
            uiState.validationError = uiState.destination?.code == airport.code ? .sameOriginDestination : nil
        case .destinationAirport:
            uiState.destination = airport
            uiState.validationError = uiState.origin?.code == airport.code ? .sameOriginDestination : nil
        case let .multiCityOrigin(index):
            uiState.multiCityLegs = uiState.multiCityLegs.selectMultiCityOrigin(index: index, airport: airport)
            uiState.validationError = nil
        case let .multiCityDestination(index):
            uiState.multiCityLegs = uiState.multiCityLegs.selectMultiCityDestination(index: index, airport: airport)
            uiState.validationError = nil
        default: return
        }
        uiState.activeSheet = nil
        uiState.airportQuery = ""
        uiState.message = nil
    }

    private func selectDepartureDate(_ date: LocalDate) {
        if uiState.tripType == .roundTrip, let returnDate = uiState.returnDate, returnDate <= date {
            uiState.returnDate = date.addingDays(7)
        }
        uiState.departureDate = date
        uiState.activeSheet = nil
        uiState.validationError = searchValidator.validateDates(
            tripType: uiState.tripType, departureDate: date, returnDate: uiState.returnDate, today: today())
    }

    func searchAgain() async -> String? {
        await createSearch()
    }

    private func searchFlights() async {
        guard let searchId = await createSearch() else { return }
        pendingNavigationEvents.append(.toSearchResults(searchId: searchId))
    }

    private func createSearch() async -> String? {
        guard !uiState.isSearching else { return nil }
        if let error = searchValidator.validateSearch(state: uiState, today: today()) {
            uiState.validationError = error
            return nil
        }
        let state = uiState
        let legs = state.tripType == .multiCity ? state.multiCityLegs.compactMap { leg -> FlightSearchLeg? in
            guard let origin = leg.origin, let destination = leg.destination, let date = leg.departureDate else { return nil }
            return FlightSearchLeg(originCode: origin.code, destinationCode: destination.code, departureDate: date)
        } : []
        guard let origin = state.tripType == .multiCity ? state.multiCityLegs.first?.origin : state.origin,
              let destination = state.tripType == .multiCity ? state.multiCityLegs.last?.destination : state.destination,
              let departure = state.tripType == .multiCity ? state.multiCityLegs.first?.departureDate : state.departureDate,
              let request = FlightSearchRequest.make(
                tripType: state.tripType, originCode: origin.code, destinationCode: destination.code,
                departureDate: departure, returnDate: state.tripType == .roundTrip ? state.returnDate : nil,
                travelers: state.travelers, cabinClass: state.cabinClass, legs: legs,
                childAges: state.childAges, infantAges: state.infantAges)
        else { return nil }
        uiState.isSearching = true
        uiState.validationError = nil
        uiState.message = nil
        do {
            let result = try await flightSearchRepository.createSearch(request: request)
            guard !Task.isCancelled else { uiState.isSearching = false; return nil }
            switch result {
            case let .success(searchId):
                uiState.isSearching = false
                return searchId
            case .networkUnavailable: uiState.message = "We lost the connection. Try again."
            case .unknownError: uiState.message = "Could not check flights right now. Try again."
            }
        } catch is CancellationError {
            uiState.isSearching = false
            return nil
        } catch {
            guard !Task.isCancelled else { uiState.isSearching = false; return nil }
            uiState.message = "Could not check flights right now. Try again."
        }
        uiState.isSearching = false
        return nil
    }

    private func airport(matching code: String) async throws -> Airport? {
        do {
            return try await airportRepository.searchAirports(query: code)
                .first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
    }

    private func clearFeedback() {
        uiState.validationError = nil
        uiState.message = nil
    }
}

func greetingName(_ displayName: String?) -> String {
    displayName?.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? "Traveler"
}
