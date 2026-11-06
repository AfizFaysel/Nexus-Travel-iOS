import Foundation
import Observation

enum TripsAccessState: Equatable, Sendable { case guest, loading, authenticated, recoverableError }

struct TripsUiState: Equatable, Sendable {
    var trips: [CustomerTrip] = []
    var selectedView: TripView = .active
    var loading = true
    var refreshing = false
    var error: String?
    var access: TripsAccessState = .loading
    var offline = false
    var lastUpdated: Date?
    var nextCursor: String?
    var loadingMore = false

    var visibleTrips: [CustomerTrip] {
        trips.filter { ($0.listSection == .history) == (selectedView == .history) }
    }

    var sections: [TripSection] {
        switch selectedView {
        case .active: [.attention, .inProgress, .upcoming]
        case .history: [.history]
        }
    }
}

@MainActor @Observable final class TripsViewModel {
    private(set) var state = TripsUiState()
    private let repository: any TripsRepository
    private let authRepository: any AuthRepository
    private var generation = 0
    /// A forced refresh that has not finished yet; a load that supersedes it inherits the force.
    private var forcePending = false
    private var hasLoaded = false
    private var loadedPageCounts: [TripView: Int] = [:]
    private var savedPages: [TripView: TripPage] = [:]
    private var accountID: String?

    init(repository: any TripsRepository, authRepository: any AuthRepository) {
        self.repository = repository
        self.authRepository = authRepository
    }

    func select(_ view: TripView) async throws {
        guard state.selectedView != view else { return }
        let page = savedPages[view]
        state = TripsUiState(
            trips: page?.items ?? [],
            selectedView: view,
            access: state.access,
            nextCursor: page?.nextCursor
        )
        try await load()
    }

    func loadIfNeeded() async throws {
        guard !hasLoaded else { return }
        try await load()
        hasLoaded = true
    }

    func clearForLogout() {
        generation += 1
        forcePending = false
        hasLoaded = false
        accountID = nil
        loadedPageCounts.removeAll()
        savedPages.removeAll()
        state = TripsUiState(loading: false, access: .guest)
    }

    func load(forceRefresh: Bool = false) async throws {
        generation += 1
        let request = generation
        let forceRefresh = forceRefresh || forcePending
        forcePending = forceRefresh
        defer { if request == generation { forcePending = false } }
        var prior = state

        do {
            let session = try await authRepository.getLocalSession()
            try Task.checkCancellation()
            guard request == generation else { return }
            guard let session else {
                clearForLogout()
                return
            }
            if accountID != session.user.id {
                accountID = session.user.id
                loadedPageCounts.removeAll()
                savedPages.removeAll()
                state = TripsUiState(selectedView: prior.selectedView)
                prior = state
            }
        } catch is CancellationError {
            if request == generation { restore(prior) }
            throw CancellationError()
        } catch {
            guard request == generation else { return }
            if Task.isCancelled {
                restore(prior)
                throw CancellationError()
            }
            state = TripsUiState(
                selectedView: prior.selectedView,
                loading: false,
                error: "We could not access your saved session. Try again.",
                access: .recoverableError
            )
            return
        }

        state.loading = state.trips.isEmpty
        state.refreshing = !state.trips.isEmpty
        state.loadingMore = false
        state.error = nil
        state.access = .authenticated

        do {
            let result = try await loadWindow(for: prior.selectedView, forceRefresh: forceRefresh)
            try Task.checkCancellation()
            guard request == generation else { return }
            apply(result, appending: false)
            if forceRefresh, prior.selectedView == .active, case .content(_, false, _) = result {
                await refreshSupplierStatus(for: state.trips, request: request)
            }
        } catch is CancellationError {
            if request == generation { restore(prior) }
            throw CancellationError()
        } catch {
            guard request == generation else { return }
            if Task.isCancelled {
                restore(prior)
                throw CancellationError()
            }
            state.loading = false
            state.refreshing = false
            state.error = "Trips could not refresh. Try again."
        }
    }

    func loadMore() async throws {
        guard !state.loadingMore, !state.loading, !state.refreshing, !state.offline,
              let cursor = state.nextCursor else { return }
        generation += 1
        let request = generation
        let view = state.selectedView
        state.loadingMore = true
        state.error = nil
        defer {
            if request == generation { state.loadingMore = false }
        }
        do {
            let result = try await repository.trips(view: view, forceRefresh: true, cursor: cursor)
            try Task.checkCancellation()
            guard request == generation else { return }
            apply(result, appending: true)
            if case let .content(page, false, _) = result {
                loadedPageCounts[view, default: 1] += 1
                state.loadingMore = false
                if view == .active {
                    await refreshSupplierStatus(for: page.items, request: request)
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            guard request == generation else { return }
            state.error = "Could not load more trips. Try again."
        }
    }

    private func loadWindow(for view: TripView, forceRefresh: Bool) async throws -> TripPageState {
        let count = loadedPageCounts[view, default: 1]
        let first = try await repository.trips(view: view, forceRefresh: forceRefresh, cursor: nil)
        guard case let .content(page, false, updated) = first, count > 1 else { return first }

        var items = page.items
        var cursor = page.nextCursor
        for _ in 1..<count {
            try Task.checkCancellation()
            guard let nextCursor = cursor else { break }
            let result = try await repository.trips(view: view, forceRefresh: true, cursor: nextCursor)
            guard case let .content(nextPage, false, _) = result else { return result }
            items.append(contentsOf: nextPage.items)
            cursor = nextPage.nextCursor
        }
        return .content(TripPage(items: items, nextCursor: cursor), offline: false, lastUpdated: updated)
    }

    private func refreshSupplierStatus(for trips: [CustomerTrip], request: Int) async {
        var seen = Set<String>()
        let bookingIDs = trips.map(\.id).filter { !$0.isEmpty && seen.insert($0).inserted }
        guard !bookingIDs.isEmpty else { return }

        do {
            var pending = false
            let batchSize = 50
            for start in stride(from: 0, to: bookingIDs.count, by: batchSize) {
                guard request == generation, !Task.isCancelled else { return }
                let end = min(start + batchSize, bookingIDs.count)
                let result = try await repository.requestSupplierRefresh(bookingIDs: Array(bookingIDs[start..<end]))
                guard request == generation, !Task.isCancelled else { return }
                switch result {
                case let .accepted(waiting): pending = pending || waiting
                case .authRequired: clearForLogout(); return
                case .unavailable:
                    state.trips = []
                    state.nextCursor = nil
                    savedPages.removeValue(forKey: .active)
                    loadedPageCounts.removeValue(forKey: .active)
                    state.error = "Could not check airline status. Try again."
                    return
                case .failed:
                    state.error = "Could not check airline status. Try again."
                    return
                }
            }
            guard pending else { return }

            for delay in [Duration.seconds(2), .seconds(3), .seconds(5)] {
                try await Task.sleep(for: delay)
                guard request == generation else { return }
                let result = try await loadWindow(for: .active, forceRefresh: true)
                guard request == generation, !Task.isCancelled else { return }
                apply(result, appending: false)
                guard case .content(_, false, _) = result,
                      state.trips.contains(where: { $0.summary?.supplierCheckPending == true }) else { return }
            }
        } catch is CancellationError {
            return
        } catch {
            guard request == generation, !Task.isCancelled else { return }
            state.error = "Could not check airline status. Try again."
        }
    }

    private func restore(_ prior: TripsUiState) {
        state = prior
        state.refreshing = false
        state.loadingMore = false
    }

    private func apply(_ result: TripPageState, appending: Bool) {
        state.loading = false
        state.refreshing = false
        switch result {
        case .loading:
            state.loading = state.trips.isEmpty
        case .authRequired:
            clearForLogout()
        case let .content(page, offline, updated):
            var seen = Set<String>()
            let visiblePage = offline ? savedPages[state.selectedView] ?? page : page
            let items = appending ? state.trips + visiblePage.items : visiblePage.items
            state.trips = items.filter { seen.insert($0.id).inserted }
            state.nextCursor = visiblePage.nextCursor
            savedPages[state.selectedView] = TripPage(items: state.trips, nextCursor: state.nextCursor)
            state.offline = offline
            state.lastUpdated = updated
        case let .error(message, cached, updated):
            if let cached {
                savedPages[state.selectedView] = cached
                if cached.items.isEmpty { loadedPageCounts.removeValue(forKey: state.selectedView) }
                state.trips = cached.items
                state.nextCursor = cached.nextCursor
                state.lastUpdated = updated
                state.offline = updated != nil
            }
            state.error = message
        }
    }
}
