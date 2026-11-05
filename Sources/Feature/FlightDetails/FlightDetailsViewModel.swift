import Observation

struct PriceChangeConfirmation: Equatable, Sendable { let previousPrice: String; let updatedPrice: String }
enum FlightDetailsSection: Hashable, Sendable { case seat, baggage, fareRules, details }
enum FlightDetailsUiEvent: Sendable { case backClicked, retryClicked, continueClicked, acceptPriceChangeClicked, dismissPriceChangeClicked, chooseSeatClicked, sectionToggled(FlightDetailsSection) }
enum FlightDetailsNavigationEvent: Equatable, Sendable { case back, toPassengerDetails }

struct FlightDetailsUiState: Equatable, Sendable {
    var isLoading = true
    var details: FlightDetails?
    var display: FlightDetailsDisplayModel?
    var expandedSections: Set<FlightDetailsSection> = []
    var errorMessage: String?
    var errorTitle = "Could not load flight details"
    var canRetryLoad = false
    var canReturnToResults = false
    var requiresRevalidation = false
    var warningMessage: String?
    var actionMessage: String?
    var isRevalidating = false
    var pendingPriceChange: PriceChangeConfirmation?
    var unacceptedPriceChange: PriceChangeConfirmation?
}

@MainActor @Observable final class FlightDetailsViewModel {
    private(set) var uiState = FlightDetailsUiState()
    private let reference: FlightOfferReference
    private let repository: any FlightDetailsRepository
    private var navigation: [FlightDetailsNavigationEvent] = []
    private var loadGeneration = 0
    init(reference: FlightOfferReference, repository: any FlightDetailsRepository) { self.reference = reference; self.repository = repository }

    func load() async throws {
        loadGeneration += 1
        let request = loadGeneration
        let previousState = uiState
        uiState.isLoading = true
        uiState.errorMessage = nil
        uiState.canRetryLoad = false
        uiState.canReturnToResults = false
        do {
            let result = try await awaitResult()
            guard request == loadGeneration else { return }
            try apply(result)
        } catch is CancellationError {
            if request == loadGeneration { uiState = previousState }
            throw CancellationError()
        } catch {
            guard request == loadGeneration else { return }
            uiState.isLoading = false
            uiState.details = nil
            uiState.display = nil
            uiState.errorMessage = "Could not load flight details. Please try again."
            uiState.canRetryLoad = true
        }
    }
    func onEvent(_ event: FlightDetailsUiEvent) async throws {
        switch event {
        case .backClicked: navigation.append(.back)
        case .retryClicked:
            if uiState.details != nil {
                try await revalidate(continuing: false)
            } else {
                try await load()
            }
        case .continueClicked:
            try await revalidate(continuing: true)
        case .acceptPriceChangeClicked:
            guard uiState.pendingPriceChange != nil, uiState.details != nil, !uiState.requiresRevalidation else { return }
            uiState.pendingPriceChange = nil
            uiState.unacceptedPriceChange = nil
            navigation.append(.toPassengerDetails)
        case .dismissPriceChangeClicked: uiState.pendingPriceChange = nil
        case .chooseSeatClicked: uiState.actionMessage = "Seat selection will be available before checkout."
        case let .sectionToggled(section):
            if uiState.expandedSections.contains(section) {
                uiState.expandedSections.remove(section)
            } else {
                uiState.expandedSections.insert(section)
            }
        }
    }
    func consumeNavigationEvent() -> FlightDetailsNavigationEvent? { navigation.isEmpty ? nil : navigation.removeFirst() }
    private func awaitResult() async throws -> FlightDetailsResult { try await repository.priceOffer(reference: reference) }
    private func revalidate(continuing: Bool) async throws {
        guard !uiState.isRevalidating else { return }
        uiState.isRevalidating = true
        uiState.actionMessage = nil
        uiState.pendingPriceChange = nil
        defer { uiState.isRevalidating = false }
        do {
            try await apply(awaitResult(), continuing: continuing)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            uiState.requiresRevalidation = true
            uiState.actionMessage = "Couldn’t confirm this fare. Try again."
        }
    }
    private func apply(_ result: FlightDetailsResult, continuing: Bool = false) throws {
        try Task.checkCancellation()
        uiState.isLoading = false
        switch result {
        case let .success(details):
            uiState.requiresRevalidation = false
            uiState.actionMessage = nil
            uiState.errorMessage = nil
            uiState.details = details
            uiState.canRetryLoad = false
            uiState.display = details.toDisplayModel()
            uiState.warningMessage = nil
            if continuing {
                if let change = uiState.unacceptedPriceChange {
                    uiState.pendingPriceChange = change
                } else {
                    navigation.append(.toPassengerDetails)
                }
            }
        case let .priceChanged(previous, details):
            let change = PriceChangeConfirmation(previousPrice: previous.formatted, updatedPrice: details.price.formatted)
            uiState.unacceptedPriceChange = change
            uiState.requiresRevalidation = false
            uiState.actionMessage = nil
            uiState.errorMessage = nil
            uiState.details = details
            uiState.canRetryLoad = false
            if continuing {
                uiState.pendingPriceChange = change
                uiState.display = details.toDisplayModel()
            } else {
                uiState.warningMessage = "Price changed from \(previous.formatted) to \(details.price.formatted)."
                uiState.display = details.toDisplayModel(warningMessage: uiState.warningMessage)
            }
        default:
            let presentation = FlightDetailsErrorPresenter.present(result: result)
            let error = presentation?.message
            uiState.pendingPriceChange = nil
            if result == .offerExpired || result == .offerUnavailable {
                uiState.unacceptedPriceChange = nil
                uiState.details = nil
                uiState.display = nil
                uiState.warningMessage = nil
                uiState.actionMessage = nil
                uiState.errorMessage = error
                uiState.errorTitle = presentation?.title ?? "Fare unavailable"
                uiState.canRetryLoad = false
                uiState.canReturnToResults = true
                uiState.requiresRevalidation = false
            } else if uiState.details != nil {
                uiState.requiresRevalidation = true
                uiState.actionMessage = error
            } else {
                uiState.details = nil
                uiState.display = nil
                uiState.errorMessage = error
                uiState.errorTitle = presentation?.title ?? "Could not load flight details"
                uiState.canRetryLoad = presentation?.primaryAction == .retry
                uiState.canReturnToResults = false
            }
        }
    }
}
