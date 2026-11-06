import Foundation
import Testing
@testable import NexusTravel

@MainActor
struct TripsGuestStateTests {
    @Test func failedLocalSessionReadShowsRecoverableError() async {
        let viewModel = TripsViewModel(repository: GuestTripsRepository(), authRepository: FailingLocalSessionRepository())

        try? await viewModel.load()

        #expect(viewModel.state.access == .recoverableError)
        #expect(!viewModel.state.loading)
        #expect(viewModel.state.error != nil)
    }

    @Test func unexpectedTripsFailureStopsLoading() async {
        let viewModel = TripsViewModel(repository: ThrowingTripsRepository(), authRepository: AuthenticatedLocalSessionRepository())

        try? await viewModel.load()

        #expect(viewModel.state.access == .authenticated)
        #expect(!viewModel.state.loading)
        #expect(!viewModel.state.refreshing)
        #expect(viewModel.state.error != nil)
    }

    @Test func logoutClearsTripsStateAndAllowsFreshLoad() async throws {
        let viewModel = TripsViewModel(repository: GuestTripsRepository(), authRepository: AuthenticatedLocalSessionRepository())
        try await viewModel.loadIfNeeded()

        #expect(viewModel.state.access == .authenticated)

        viewModel.clearForLogout()

        #expect(viewModel.state.access == .guest)
        #expect(viewModel.state.trips.isEmpty)
        #expect(!viewModel.state.loading)
        try await viewModel.loadIfNeeded()
        #expect(viewModel.state.access == .authenticated)
    }

    @Test func initialLoadKeepsTheForcedRefreshItSupersedes() async throws {
        let repository = RecordingTripsRepository()
        let viewModel = TripsViewModel(repository: repository, authRepository: AuthenticatedLocalSessionRepository())

        // Selecting the Trips tab forces a refresh, then the screen's first-appearance load starts.
        let forced = Task { try await viewModel.load(forceRefresh: true) }
        while await repository.forceFlags.isEmpty { await Task.yield() }
        try await viewModel.loadIfNeeded()
        _ = try? await forced.value

        #expect(await repository.forceFlags == [true, true])
    }
}

private actor RecordingTripsRepository: TripsRepository {
    private(set) var forceFlags: [Bool] = []
    func trips(view: TripView, forceRefresh: Bool, cursor: String?) async throws -> TripPageState {
        forceFlags.append(forceRefresh)
        if forceFlags.count == 1 { try? await Task.sleep(for: .milliseconds(300)) }
        return .loading
    }
    func requestSupplierRefresh(bookingIDs: [String]) async throws -> TripSupplierRefreshResult { .accepted(pending: false) }
    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult { .failed }
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult { .unknownError }
    func cachedTicketPdf(id: String, version: String?) async throws -> CachedTicketResult? { nil }
    func cacheTicketPdf(id: String, downloadURL: URL, version: String?) async throws -> CachedTicketResult { .unknownError }
}

private struct GuestTripsRepository: TripsRepository {
    func trips(view: TripView, forceRefresh: Bool, cursor: String?) async throws -> TripPageState { .loading }
    func requestSupplierRefresh(bookingIDs: [String]) async throws -> TripSupplierRefreshResult { .accepted(pending: false) }
    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult { .failed }
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult { .unknownError }
    func cachedTicketPdf(id: String, version: String?) async throws -> CachedTicketResult? { nil }
    func cacheTicketPdf(id: String, downloadURL: URL, version: String?) async throws -> CachedTicketResult { .unknownError }
}

private struct ThrowingTripsRepository: TripsRepository {
    func trips(view: TripView, forceRefresh: Bool, cursor: String?) async throws -> TripPageState { throw TripsLoadError.failed }
    func requestSupplierRefresh(bookingIDs: [String]) async throws -> TripSupplierRefreshResult { .accepted(pending: false) }
    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult { .failed }
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult { .unknownError }
    func cachedTicketPdf(id: String, version: String?) async throws -> CachedTicketResult? { nil }
    func cacheTicketPdf(id: String, downloadURL: URL, version: String?) async throws -> CachedTicketResult { .unknownError }
}

private enum TripsLoadError: Error { case failed }
