import Observation
import Foundation

enum ProfileAccessState: Equatable, Sendable {
    case guest
    case loading
    case authenticated(CustomerProfile)
    case recoverableError(CustomerProfile?)
}

struct ProfileUiState: Equatable, Sendable {
    var access: ProfileAccessState = .loading
    var travelers: [SavedTraveler] = []
    var refreshing = false
    var signingOut = false
    var showLogoutConfirmation = false
    var errorMessage: String?

    var profile: CustomerProfile? {
        switch access {
        case let .authenticated(profile): profile
        case let .recoverableError(profile): profile
        case .guest, .loading: nil
        }
    }

    var isRecoverableError: Bool {
        if case .recoverableError = access { return true }
        return false
    }
}

@MainActor @Observable final class ProfileViewModel {
    private(set) var state = ProfileUiState()
    private let repository: any ProfileRepository
    private let authRepository: any AuthRepository
    private var loadGeneration = 0
    private var hasLoaded = false
    private var accountID: String?

    init(repository: any ProfileRepository, authRepository: any AuthRepository) { self.repository = repository; self.authRepository = authRepository }

    func loadIfNeeded() async throws {
        guard !hasLoaded else { return }
        try await load()
    }

    func invalidateLoadedProfile() { hasLoaded = false }

    func load() async throws {
        guard !state.signingOut else { return }
        loadGeneration += 1
        let request = loadGeneration
        var prior = state
        prior.refreshing = false
        var cached: CustomerProfile?

        do {
            let session = try await authRepository.getLocalSession()
            try Task.checkCancellation()
            guard request == loadGeneration else { return }
            if accountID != session?.user.id {
                accountID = session?.user.id
                prior = ProfileUiState()
                state = prior
            }
            guard session != nil else {
                state = ProfileUiState(access: .guest)
                hasLoaded = true
                return
            }

            cached = state.profile
            state.access = cached == nil ? .loading : state.access
            state.refreshing = cached != nil

            async let profileResult = repository.profile()
            async let travelersResult = repository.travelers()
            let (profile, travelers) = try await (profileResult, travelersResult)
            try Task.checkCancellation()
            guard request == loadGeneration else { return }

            if case let .success(value) = profile {
                state = ProfileUiState(access: .authenticated(value), travelers: travelers.value ?? [])
            } else {
                state = ProfileUiState(access: .recoverableError(cached), travelers: prior.travelers)
            }
            hasLoaded = true
        } catch is CancellationError {
            if request == loadGeneration { state = prior }
            throw CancellationError()
        } catch {
            guard request == loadGeneration else { return }
            if Task.isCancelled {
                state = prior
                throw CancellationError()
            }
            state = ProfileUiState(access: .recoverableError(cached), travelers: cached == nil ? [] : prior.travelers)
            hasLoaded = true
        }
    }

    func requestLogout() { state.showLogoutConfirmation = true }
    func dismissLogout() { state.showLogoutConfirmation = false }

    func clearForPasswordReset() {
        loadGeneration += 1
        accountID = nil
        state = ProfileUiState(access: .guest)
        hasLoaded = false
    }

    func signOut() async throws {
        guard !state.signingOut else { return }
        loadGeneration += 1
        let prior = state
        state.signingOut = true
        state.showLogoutConfirmation = false
        do {
            _ = try await authRepository.signOut()
            clearForPasswordReset()
        } catch is CancellationError {
            state = prior
            hasLoaded = false
            throw CancellationError()
        } catch {
            state = ProfileUiState(
                access: .recoverableError(prior.profile),
                travelers: prior.travelers,
                errorMessage: "We couldn’t securely sign you out. Try again."
            )
            throw error
        }
    }

}
private extension ProfileResult { var value: Value? { if case let .success(value) = self { value } else { nil } } }

struct EditProfileState: Equatable, Sendable { var name = ""; var email = ""; var phone = ""; var loading = true; var saving = false; var saved = false; var error: String? }
@MainActor @Observable final class EditProfileViewModel {
    private(set) var state = EditProfileState(); private let repository: any ProfileRepository
    init(repository: any ProfileRepository) { self.repository = repository }
    func load() async throws { guard case let .success(value) = try await repository.profile() else { state.loading = false; state.error = "Could not load profile."; return }; state = .init(name: value.name, email: value.email, phone: value.phone ?? "", loading: false) }
    func name(_ value: String) { state.name = value; state.saved = false }; func phone(_ value: String) { state.phone = value; state.saved = false }
    func save() async throws { guard !state.saving else { return }; switch ProfileValidation.validate(name: state.name, phone: state.phone) { case .invalidName: state.error = "Enter your full name."; case .invalidPhone: state.error = "Enter phone in international format, such as +251900000000."; case let .valid(name, phone): state.saving = true; state.error = nil; defer { state.saving = false }; guard case let .success(value) = try await repository.updateProfile(name: name, phone: phone) else { state.error = "Could not save changes."; return }; state.name = value.name; state.phone = value.phone ?? ""; state.saved = true } }
}

struct PreferencesState: Equatable, Sendable { var value = CustomerPreferences(); var refreshing = true; var saving = false; var error: String? }
@MainActor @Observable final class PreferencesViewModel {
    private(set) var state = PreferencesState()
    private let repository: any PreferencesRepository

    init(repository: any PreferencesRepository) { self.repository = repository }

    func load() async throws {
        state.value = await repository.local()
        switch try await repository.refresh() {
        case let .success(value):
            state = .init(value: value, refreshing: false)
        default:
            state.refreshing = false
            state.error = "Using saved preferences."
        }
    }

    func save(_ value: CustomerPreferences) async throws {
        guard !state.saving else { return }
        let prior = state.value
        state.value = value
        state.saving = true
        state.error = nil
        do {
            guard case let .success(saved) = try await repository.save(value) else {
                state.saving = false
                state.error = "Could not sync preferences."
                return
            }
            state = .init(value: saved, refreshing: false)
        } catch is CancellationError {
            state.value = prior
            state.saving = false
            throw CancellationError()
        }
    }
}

struct SecurityState: Equatable, Sendable { var value: AccountSecurity?; var loading = true; var error: String? }
@MainActor @Observable final class AccountSecurityViewModel {
    private(set) var state = SecurityState(); private let repository: any AccountSecurityRepository
    init(repository: any AccountSecurityRepository) { self.repository = repository }
    func load() async throws { switch try await repository.security() { case let .success(value): state = .init(value: value, loading: false); default: state = .init(loading: false, error: "Could not load security details.") } }
}

enum DeleteAccountState: Equatable, Sendable {
    case idle
    case submitting
    case pending(requestId: String)
    case failure(String)
}

@MainActor @Observable final class DeleteAccountViewModel {
    private(set) var state: DeleteAccountState = .idle
    private let repository: any AccountSecurityRepository
    private let clearSession: () async throws -> Void
    private let idempotencyKey: String

    init(repository: any AccountSecurityRepository, clearSession: @escaping () async throws -> Void, idempotencyKey: String = "ios-\(UUID().uuidString)") {
        self.repository = repository
        self.clearSession = clearSession
        self.idempotencyKey = idempotencyKey
    }

    func submit(password: String, confirmation: String) async {
        guard state != .submitting else { return }
        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, password.count <= 128, confirmation == "DELETE" else {
            state = .failure("Enter your password and type DELETE exactly.")
            return
        }
        state = .submitting
        do {
            switch try await repository.deleteAccount(password: password, confirmation: confirmation, idempotencyKey: idempotencyKey) {
            case let .success(request):
                try? await clearSession()
                state = .pending(requestId: request.requestId)
            case .invalidInput:
                state = .failure("Deletion could not be started. Check your password and try again.")
            case .authRequired:
                state = .failure("Your session expired. Sign in again to delete your account.")
            case .networkUnavailable:
                state = .failure("You appear to be offline. Check your connection and try again.")
            case .notFound, .failed:
                state = .failure("Deletion could not be started. Try again later or contact Nexus support.")
            }
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failure("Deletion could not be started. Try again later or contact Nexus support.")
        }
    }
}
