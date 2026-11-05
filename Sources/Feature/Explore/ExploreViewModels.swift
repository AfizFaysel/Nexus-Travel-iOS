import Observation

struct ExploreUiState: Equatable, Sendable { var content: ExploreContent?; var loading = true; var refreshing = false; var error: String? }
@MainActor @Observable final class ExploreViewModel {
    private(set) var state = ExploreUiState(); private let repository: any ExploreRepository; private var generation = 0
    private var hasLoaded = false
    init(repository: any ExploreRepository) { self.repository = repository }
    func loadIfNeeded() async throws {
        guard !hasLoaded else { return }
        try await load()
        hasLoaded = true
    }

    func load(forceRefresh: Bool = false) async throws {
        generation += 1
        let request = generation
        let prior = state
        state.loading = state.content == nil
        state.refreshing = state.content != nil
        state.error = nil
        do {
            let result = try await repository.content(forceRefresh: forceRefresh)
            guard request == generation else { return }
            guard !Task.isCancelled else {
                state = prior
                throw CancellationError()
            }
            switch result {
            case let .success(value): state = .init(content: value, loading: false)
            case .empty: state = .init(content: .init(banners: [], destinations: [], packages: []), loading: false)
            default:
                state.loading = false
                state.refreshing = false
                state.error = "Could not update Explore."
            }
        } catch is CancellationError {
            if request == generation { state = prior }
            throw CancellationError()
        } catch {
            guard request == generation else { return }
            if Task.isCancelled {
                state = prior
                throw CancellationError()
            }
            state.loading = false
            state.refreshing = false
            state.error = "Could not update Explore."
        }
    }
}
enum ExploreDetailState: Equatable, Sendable { case loading; case destination(ExploreDestination, [ExplorePackage]); case package(ExplorePackage, ExploreDestination); case unavailable; case error }
@MainActor @Observable final class ExploreDetailViewModel {
    private(set) var state: ExploreDetailState = .loading
    private(set) var isSearching = false
    private(set) var searchError: String?
    private let repository: any ExploreRepository
    private let flightSearchRepository: any FlightSearchRepository
    private let today: @MainActor () -> LocalDate

    init(
        repository: any ExploreRepository,
        flightSearchRepository: any FlightSearchRepository,
        today: @escaping @MainActor () -> LocalDate
    ) {
        self.repository = repository
        self.flightSearchRepository = flightSearchRepository
        self.today = today
    }

    func loadDestination(id: String) async throws { let prior = state; do { switch try await repository.destination(id: id) { case let .success(value): state = .destination(value.destination, value.packages); case .unavailable: state = .unavailable; default: state = .error } } catch is CancellationError { state = prior; throw CancellationError() } }
    func loadPackage(id: String) async throws { let prior = state; do { switch try await repository.travelPackage(id: id) { case let .success(value): state = .package(value.package, value.destination); case .unavailable: state = .unavailable; default: state = .error } } catch is CancellationError { state = prior; throw CancellationError() } }

    func searchFlights(to airportCode: String, departureDate: LocalDate, returnDate: LocalDate, travelers: TravelerCounts) async -> String? {
        guard !isSearching else { return nil }
        guard departureDate >= today(), returnDate > departureDate,
              let request = FlightSearchRequest.make(
            tripType: .roundTrip,
            originCode: "ADD",
            destinationCode: airportCode,
            departureDate: departureDate,
            returnDate: returnDate,
            travelers: travelers.normalized(),
            cabinClass: .economy,
            cheapestFirst: true
        ) else { return nil }
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            switch try await flightSearchRepository.createSearch(request: request) {
            case let .success(searchId): return searchId
            case .networkUnavailable:
                searchError = "You're offline. Connect to search flights."
            case .unknownError:
                searchError = "Could not search flights. Try again."
            }
        } catch is CancellationError {
            return nil
        } catch {
            searchError = "Could not search flights. Try again."
        }
        return nil
    }
}
