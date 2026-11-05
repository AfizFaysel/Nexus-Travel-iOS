import Observation
import Foundation

enum ProfileAccessState: Equatable, Sendable { case guest, loading, authenticated(CustomerProfile), recoverableError(CustomerProfile?) }
struct ProfileUiState: Equatable, Sendable { var access: ProfileAccessState = .loading; var travelers: [SavedTraveler] = []; var refreshing = false; var signingOut = false; var showLogoutConfirmation = false; var errorMessage: String? }
@MainActor @Observable final class ProfileViewModel {
    private(set) var state = ProfileUiState()
    private let repository: any ProfileRepository
    private let authRepository: any AuthRepository
    private var loadGeneration = 0
    private var hasLoaded = false

    init(repository: any ProfileRepository, authRepository: any AuthRepository) { self.repository = repository; self.authRepository = authRepository }

    func loadIfNeeded() async throws {
        guard !hasLoaded else { return }
        try await load()
        hasLoaded = true
    }

    func load() async throws {
        loadGeneration += 1
        let request = loadGeneration
        let cached = cachedProfile
        let prior = state
        state.access = cached == nil ? .loading : state.access
        state.refreshing = cached != nil

        do {
            guard try await authRepository.getLocalSession() != nil else {
                guard request == loadGeneration else { return }
                state = ProfileUiState(access: .guest)
                return
            }

            async let profileResult = repository.profile()
            async let travelersResult = repository.travelers()
            let (profile, travelers) = try await (profileResult, travelersResult)
            guard request == loadGeneration else { return }

            if case let .success(value) = profile {
                state = ProfileUiState(access: .authenticated(value), travelers: travelers.value ?? [])
            } else {
                state = ProfileUiState(access: .recoverableError(cached))
            }
        } catch is CancellationError {
            if request == loadGeneration { state = prior }
            throw CancellationError()
        } catch {
            guard request == loadGeneration else { return }
            if Task.isCancelled {
                state = prior
                throw CancellationError()
            }
            state = ProfileUiState(access: .recoverableError(cached))
        }
    }

    func requestLogout() { state.showLogoutConfirmation = true }; func dismissLogout() { state.showLogoutConfirmation = false }
    func clearForPasswordReset() { state = ProfileUiState(access: .guest); hasLoaded = false }
    func signOut() async throws {
        guard !state.signingOut else { return }
        loadGeneration += 1
        let prior = state
        state.signingOut = true
        state.showLogoutConfirmation = false
        do {
            _ = try await authRepository.signOut()
            state = ProfileUiState(access: .guest)
            hasLoaded = false
        } catch is CancellationError {
            state = prior
            throw CancellationError()
        } catch {
            state = ProfileUiState(
                access: .recoverableError(cachedProfile),
                errorMessage: "We couldn’t securely sign you out. Try again."
            )
            throw error
        }
    }

    private var cachedProfile: CustomerProfile? {
        switch state.access {
        case let .authenticated(profile): profile
        case let .recoverableError(profile): profile
        case .guest, .loading: nil
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
    private(set) var state = PreferencesState(); private let repository: any PreferencesRepository; private let onTheme: (ThemePreference) -> Void
    init(repository: any PreferencesRepository, onTheme: @escaping (ThemePreference) -> Void) { self.repository = repository; self.onTheme = onTheme }
    func load() async throws { state.value = await repository.local(); onTheme(state.value.theme); switch try await repository.refresh() { case let .success(value): state = .init(value: value, refreshing: false); onTheme(value.theme); default: state.refreshing = false; state.error = "Using saved preferences." } }
    func save(_ value: CustomerPreferences) async throws { guard !state.saving else { return }; let prior = state.value; state.value = value; state.saving = true; state.error = nil; onTheme(value.theme); do { guard case let .success(saved) = try await repository.save(value) else { state.saving = false; state.error = "Could not sync preferences."; return }; state = .init(value: saved, refreshing: false); onTheme(saved.theme) } catch is CancellationError { state.value = prior; state.saving = false; onTheme(prior.theme); throw CancellationError() } }
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

@MainActor @Observable final class AppTheme {
    var preference: ThemePreference
    init(preference: ThemePreference = .system) { self.preference = preference }
}
