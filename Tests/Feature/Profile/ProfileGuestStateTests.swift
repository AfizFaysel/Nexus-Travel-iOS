import Foundation
import Testing
@testable import NexusTravel

@MainActor
struct ProfileGuestStateTests {
    @Test func failedLocalSessionReadShowsRecoverableError() async {
        let viewModel = ProfileViewModel(repository: GuestProfileRepository(), authRepository: FailingLocalSessionRepository())

        try? await viewModel.load()

        #expect(viewModel.state.access == .recoverableError(nil))
        #expect(!viewModel.state.refreshing)
    }

    @Test func passwordResetClearsCachedAuthenticatedProfile() {
        let viewModel = ProfileViewModel(repository: GuestProfileRepository(), authRepository: FailingLocalSessionRepository())
        viewModel.clearForPasswordReset()

        #expect(viewModel.state.access == .guest)
    }

    @Test func unexpectedProfileFailureShowsRecoverableError() async {
        let viewModel = ProfileViewModel(repository: ThrowingProfileRepository(), authRepository: AuthenticatedLocalSessionRepository())

        try? await viewModel.load()

        #expect(viewModel.state.access == .recoverableError(nil))
        #expect(!viewModel.state.refreshing)
    }

    @Test func failedLogoutStopsLoadingAndKeepsAuthenticatedProfile() async {
        let profile = CustomerProfile(
            id: "traveler",
            name: "Nexus Traveler",
            email: "traveler@example.com",
            image: nil,
            phone: nil,
            travelerCount: 0,
            verifiedTravelerCount: 0,
            pendingTravelerCount: 0
        )
        let viewModel = ProfileViewModel(
            repository: ProfileRepositoryStub(profile: profile),
            authRepository: FailingSignOutRepository()
        )
        try? await viewModel.load()

        do {
            try await viewModel.signOut()
            Issue.record("Expected logout to throw")
        } catch {}

        #expect(!viewModel.state.signingOut)
        #expect(viewModel.state.access == .recoverableError(profile))
        #expect(viewModel.state.errorMessage == "We couldn’t securely sign you out. Try again.")
    }
}

private struct GuestProfileRepository: ProfileRepository {
    func profile() async throws -> ProfileResult<CustomerProfile> { .failed }
    func updateProfile(name: String, phone: String?) async throws -> ProfileResult<CustomerProfile> { .failed }
    func travelers() async throws -> ProfileResult<[SavedTraveler]> { .failed }
}

private struct ThrowingProfileRepository: ProfileRepository {
    func profile() async throws -> ProfileResult<CustomerProfile> { throw ProfileLoadError.failed }
    func updateProfile(name: String, phone: String?) async throws -> ProfileResult<CustomerProfile> { .failed }
    func travelers() async throws -> ProfileResult<[SavedTraveler]> { throw ProfileLoadError.failed }
}

struct AuthenticatedLocalSessionRepository: AuthRepository {
    func signInEmail(request: SignInRequest) async throws -> AuthResult<AuthSession> { .failure(.unknown) }
    func signUpEmail(request: SignUpRequest) async throws -> AuthResult<AuthSignUpResult> { .failure(.unknown) }
    func getSession() async throws -> AuthResult<AuthSession> { .failure(.unknown) }
    func getLocalSession() async throws -> AuthSession? {
        AuthSession(
            sessionId: "session",
            user: AuthUser(id: "user", displayName: "Traveler", email: "traveler@example.com", avatarUrl: nil),
            tokens: nil,
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
    }
    func requestPasswordReset(email: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func signOut() async throws -> AuthResult<Void> { .success(()) }
}

struct FailingLocalSessionRepository: AuthRepository {
    func signInEmail(request: SignInRequest) async throws -> AuthResult<AuthSession> { .failure(.unknown) }
    func signUpEmail(request: SignUpRequest) async throws -> AuthResult<AuthSignUpResult> { .failure(.unknown) }
    func getSession() async throws -> AuthResult<AuthSession> { .failure(.unauthenticated) }
    func getLocalSession() async throws -> AuthSession? { throw LocalSessionError.readFailed }
    func requestPasswordReset(email: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func signOut() async throws -> AuthResult<Void> { .success(()) }
}

private enum LocalSessionError: Error { case readFailed }
private enum ProfileLoadError: Error { case failed }

private struct ProfileRepositoryStub: ProfileRepository {
    let profile: CustomerProfile
    func profile() async throws -> ProfileResult<CustomerProfile> { .success(profile) }
    func updateProfile(name: String, phone: String?) async throws -> ProfileResult<CustomerProfile> { .failed }
    func travelers() async throws -> ProfileResult<[SavedTraveler]> { .success([]) }
}

private struct FailingSignOutRepository: AuthRepository {
    func signInEmail(request: SignInRequest) async throws -> AuthResult<AuthSession> { .failure(.unknown) }
    func signUpEmail(request: SignUpRequest) async throws -> AuthResult<AuthSignUpResult> { .failure(.unknown) }
    func getSession() async throws -> AuthResult<AuthSession> { .failure(.unauthenticated) }
    func getLocalSession() async throws -> AuthSession? {
        AuthSession(
            sessionId: "session",
            user: AuthUser(id: "traveler", displayName: "Nexus Traveler", email: "traveler@example.com", avatarUrl: nil),
            tokens: AuthTokenSet(accessToken: "token", refreshToken: nil),
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
    }
    func requestPasswordReset(email: String) async throws -> AuthResult<Void> { .failure(.unknown) }
    func signOut() async throws -> AuthResult<Void> { throw SignOutFailure.failed }
}

private enum SignOutFailure: Error { case failed }
