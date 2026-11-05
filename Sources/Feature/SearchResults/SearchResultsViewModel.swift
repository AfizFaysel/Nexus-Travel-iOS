import Foundation
import Observation

struct SearchResultsUiState: Equatable, Sendable {
    var isInitialLoading = true
    var resultState: SearchResultsState = .loading
    var querySummary: SearchResultsQuerySummary?
    var allFlights: [SearchResultUiOffer] = []
    var visibleFlights: [SearchResultUiOffer] = []
    var selectedFilters: Set<SearchFilter> = []
    var sortOption: SortOption = .recommended
    var errorMessage: String?
    var unavailableOfferNotice: String?

    var resultCount: Int { visibleFlights.count }
    func resultCountLabel() -> String { "\(resultCount) \(resultCount == 1 ? "flight" : "flights") found" }
    func freshnessWarning(at now: Date) -> String? {
        guard let expiry = visibleFlights.compactMap({ $0.reference.expiresAt }).min() else { return nil }
        if expiry <= now { return "Some fares have expired. Search again before choosing a flight." }
        if expiry.timeIntervalSince(now) <= 120 { return "Fares may change soon. Search again for current options." }
        return nil
    }
}

enum SearchResultsUiEvent: Equatable, Sendable {
    case backClicked, modifyClicked, retryClicked, nearbyDatesClicked, clearFiltersClicked
    case filterToggled(SearchFilter)
    case sortChanged(SortOption)
    case flightCardClicked(FlightOfferReference)
}

enum SearchResultsNavigationEvent: Equatable, Sendable {
    case back, toModifySearch, toNearbyDates
    case toFlightDetails(FlightOfferReference)
}

@MainActor
@Observable
final class SearchResultsViewModel {
    private(set) var uiState = SearchResultsUiState()
    private let searchId: String
    private let repository: any SearchResultsRepository
    private var isLoading = false
    private var navigationEvents: [SearchResultsNavigationEvent] = []
    private var unavailableOfferIds: Set<String> = []

    init(searchId: String, repository: any SearchResultsRepository) {
        self.searchId = searchId
        self.repository = repository
    }

    func loadResults() async throws {
        guard !isLoading else { return }
        let previousState = uiState
        isLoading = true
        uiState.isInitialLoading = true
        uiState.resultState = .loading
        uiState.errorMessage = nil
        do {
            let result = try await repository.getSearchResults(searchId: searchId)
            try Task.checkCancellation()
            apply(result)
            isLoading = false
        } catch is CancellationError {
            isLoading = false
            uiState = previousState
            throw CancellationError()
        } catch {
            isLoading = false
            showError("Could not load flights. Please retry.")
        }
    }

    func onEvent(_ event: SearchResultsUiEvent) async {
        switch event {
        case .backClicked: navigationEvents.append(.back)
        case .modifyClicked: navigationEvents.append(.toModifySearch)
        case .nearbyDatesClicked: navigationEvents.append(.toNearbyDates)
        case let .flightCardClicked(reference):
            if let expiry = reference.expiresAt, expiry <= .now {
                uiState.unavailableOfferNotice = "This fare has expired. Search again for current flights."
            } else {
                navigationEvents.append(.toFlightDetails(reference))
            }
        case .retryClicked: try? await loadResults()
        case let .filterToggled(filter): toggle(filter)
        case let .sortChanged(sort): update(sort: sort)
        case .clearFiltersClicked:
            uiState.selectedFilters.removeAll()
            updateVisible()
        }
    }

    func consumeNavigationEvent() -> SearchResultsNavigationEvent? {
        navigationEvents.isEmpty ? nil : navigationEvents.removeFirst()
    }

    func markOfferUnavailable(_ reference: FlightOfferReference) {
        guard reference.searchId == searchId else { return }
        unavailableOfferIds.insert(reference.offerId)
        uiState.allFlights.removeAll { $0.reference.offerId == reference.offerId }
        uiState.unavailableOfferNotice = "That fare is no longer available. Choose another flight."
        updateVisible()
    }

    private func apply(_ result: SearchResultsResult) {
        switch result {
        case let .success(summary, offers):
            let mapped = offers.filter { !unavailableOfferIds.contains($0.id) }
                .map { $0.toSearchResultUiOffer(tripType: summary.tripType) }
            if summary.cheapestFirst {
                uiState.sortOption = .bestPrice
                uiState.selectedFilters.insert(.bestPrice)
            }
            uiState.querySummary = summary
            uiState.allFlights = mapped
            updateVisible()
            uiState.isInitialLoading = false
            uiState.errorMessage = nil
        case .empty:
            uiState.isInitialLoading = false
            uiState.resultState = .empty
            uiState.allFlights = []
            uiState.visibleFlights = []
        case .networkUnavailable: showError("Connection lost. Check your network and retry.")
        case .timeout: showError("Search timed out. Retry when connection is stable.")
        case .unknownError: showError("Could not load flights. Please retry.")
        }
    }

    private func toggle(_ filter: SearchFilter) {
        if uiState.selectedFilters.contains(filter) {
            uiState.selectedFilters.remove(filter)
        } else {
            uiState.selectedFilters.insert(filter)
            if filter == .bestPrice { uiState.sortOption = .bestPrice }
        }
        updateVisible()
    }

    private func update(sort: SortOption) {
        uiState.sortOption = sort
        updateVisible()
    }

    private func updateVisible() {
        uiState.visibleFlights = uiState.allFlights.applyingSearchResultFiltersAndSort(
            filters: uiState.selectedFilters, sortOption: uiState.sortOption
        )
        uiState.resultState = uiState.visibleFlights.isEmpty ? .empty : .content
    }

    private func showError(_ message: String) {
        uiState.isInitialLoading = false
        uiState.resultState = .error
        uiState.errorMessage = message
        uiState.visibleFlights = []
    }
}
