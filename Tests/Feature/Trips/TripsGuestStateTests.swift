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
}

private struct GuestTripsRepository: TripsRepository {
    func trips(group: TripGroup, forceRefresh: Bool) async throws -> TripPageState { .loading }
    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult { .failed }
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult { .unknownError }
    func cacheTicketPdf(id: String, downloadURL: URL) async throws -> CachedTicketResult { .unknownError }
}

private struct ThrowingTripsRepository: TripsRepository {
    func trips(group: TripGroup, forceRefresh: Bool) async throws -> TripPageState { throw TripsLoadError.failed }
    func tripDetail(id: String, forceRefresh: Bool) async throws -> TripDetailResult { .failed }
    func resolveTicketDocument(id: String) async throws -> TicketDocumentResult { .unknownError }
    func cacheTicketPdf(id: String, downloadURL: URL) async throws -> CachedTicketResult { .unknownError }
}

private enum TripsLoadError: Error { case failed }
