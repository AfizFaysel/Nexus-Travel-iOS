import SwiftUI
import UserNotifications

struct ProfileScreenRoute: View {
    @State private var viewModel: ProfileViewModel
    @Binding var rootScrollTarget: String?
    let router: Router
    let onSignedOut: () -> Void

    init(
        viewModel: ProfileViewModel,
        router: Router,
        rootScrollTarget: Binding<String?>,
        onSignedOut: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        _rootScrollTarget = rootScrollTarget
        self.router = router
        self.onSignedOut = onSignedOut
    }

    var body: some View {
        ProfileScreen(
            state: viewModel.state,
            router: router,
            rootScrollTarget: $rootScrollTarget,
            onLogout: viewModel.requestLogout,
            onSignIn: { router.presentAuthentication(for: .profile) },
            onRetry: { Task { try? await viewModel.load() } }
        )
        .task { try? await viewModel.loadIfNeeded() }
        .refreshable { try? await viewModel.load() }
        .onChange(of: router.authPresentation) { previous, current in
            guard previous == .profile, current == nil else { return }
            Task { try? await viewModel.load() }
        }
        .confirmationDialog(
            "Log out?",
            isPresented: Binding(
                get: { viewModel.state.showLogoutConfirmation },
                set: { if !$0 { viewModel.dismissLogout() } }
            )
        ) {
            Button("Log out", role: .destructive) {
                Task {
                    do {
                        try await viewModel.signOut()
                        onSignedOut()
                    } catch {}
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to sign in again to access trips and saved details.")
        }
    }
}
private struct ProfileScreen: View {
    let state: ProfileUiState
    let router: Router
    @Binding var rootScrollTarget: String?
    let onLogout: () -> Void
    let onSignIn: () -> Void
    let onRetry: () -> Void
    var body: some View {
        List {
            Text("Profile")
                .nexusTextStyle(NexusText.styles.screenTitle)
                .accessibilityAddTraits(.isHeader)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: NexusSpacing.space4, bottom: 0, trailing: NexusSpacing.space4))
                .id("profile.heading")
            content
        }
        .listStyle(.insetGrouped)
        .scrollTargetLayout()
        .scrollPosition(id: $rootScrollTarget, anchor: .top)
        .accessibilityIdentifier("root-profile")
        .navigationBarHidden(true)
    }
    @ViewBuilder private var content: some View {
        switch state.access {
        case .loading: ProgressView().accessibilityLabel("Loading profile").id("profile.loading")
        case .guest:
            guestProfile
                .id("profile.account")
            Section("Preferences") {
                row("Settings", icon: { NexusPlatformIcon(.settings) }) {
                    router.push(.settings(.init()))
                }
            }
            .id("profile.preferences")
        case let .recoverableError(profile):
            if let profile { header(profile) }
            NexusBanner(text: state.errorMessage ?? "Profile could not refresh.", status: .error, trailingAction: {
                NexusTextButton("Try again", action: onRetry)
            })
            .id("profile.error")
            Button(role: .destructive, action: onLogout) {
                if state.signingOut { HStack { ProgressView(); Text("Signing out…") } }
                else { Text("Log out") }
            }
            .disabled(state.signingOut)
        case let .authenticated(profile):
            header(profile)
            Section("Account") {
                row("Saved travelers", icon: { NexusPlatformIcon(.savedTravelers) }) {
                    router.push(.savedTravelers(.init()))
                }
                LabeledContent("Payment methods", value: "Coming later")
            }
            .id("profile.account")
            Section("Preferences") {
                row("Settings", icon: { NexusPlatformIcon(.settings) }) { router.push(.settings(.init())) }
                row("Notifications", icon: { NexusIcon(name: .bell) }) { router.push(.notificationSettings(.init())) }
                row("Security", icon: { NexusPlatformIcon(.password) }) { router.push(.security(.init())) }
            }
            .id("profile.preferences")
            Section {
                Button(role: .destructive, action: onLogout) {
                    if state.signingOut { HStack { ProgressView(); Text("Signing out…") } }
                    else { Text("Log out") }
                }
                .disabled(state.signingOut)
            }
            .id("profile.logout")
        }
    }
    private func header(_ profile: CustomerProfile) -> some View {
        Section {
            ViewThatFits(in: .horizontal) {
                HStack { avatar(profile); profileDetails(profile) }
                VStack(alignment: .leading) { avatar(profile); profileDetails(profile) }
            }
        }
        .id("profile.account-summary")
    }
    private var guestProfile: some View {
        HStack(spacing: NexusSpacing.space16) {
            NexusIcon(name: .profile, size: NexusIconSize.lg)
                .foregroundStyle(NexusSemanticColors.textHeading)
                .frame(width: NexusSpacing.space64, height: NexusSpacing.space64)
                .background(NexusSemanticColors.surfaceSubtle, in: Circle())
            VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                Text("Guest")
                    .nexusTextStyle(NexusText.styles.sectionTitleSmall)
                    .foregroundStyle(NexusSemanticColors.textHeading)
                Text("Sign in to access bookings")
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
            Spacer(minLength: NexusSpacing.space4)
            NexusTextButton("Sign in", action: onSignIn)
        }
        .padding(.vertical, NexusSpacing.space8)
    }
    private func avatar(_ profile: CustomerProfile) -> some View { Text(initials(profile.name)).font(.title.bold()).frame(width: 72, height: 72).foregroundStyle(.white).background(NexusSemanticColors.brandPrimary, in: Circle()).accessibilityHidden(true) }
    private func profileDetails(_ profile: CustomerProfile) -> some View { VStack(alignment: .leading) { Text(profile.name).nexusTextStyle(NexusText.styles.sectionTitle).accessibilityAddTraits(.isHeader); Text(profile.email).nexusTextStyle(NexusText.styles.bodySmall); Text("\(profile.verifiedTravelerCount) verified travelers").nexusTextStyle(NexusText.styles.caption); Button("Edit profile") { router.push(.editProfile(.init())) } } }
    private func row<Icon: View>(_ title: String, @ViewBuilder icon: () -> Icon, action: @escaping () -> Void) -> some View { Button(action: action) { Label { Text(title) } icon: { icon() } } }
}

struct EditProfileScreen: View {
    @State private var viewModel: EditProfileViewModel
    init(viewModel: EditProfileViewModel) { _viewModel = State(initialValue: viewModel) }
    var body: some View { Form { TextField("Full name", text: Binding(get: { viewModel.state.name }, set: { name in viewModel.name(name) })); TextField("Email", text: .constant(viewModel.state.email)).disabled(true); TextField("Phone", text: Binding(get: { viewModel.state.phone }, set: { phone in viewModel.phone(phone) })).keyboardType(.phonePad); if let error = viewModel.state.error { Text(error).foregroundStyle(NexusSemanticColors.errorText) }; Button(viewModel.state.saved ? "Saved" : "Save changes") { Task { try? await viewModel.save() } }.disabled(viewModel.state.loading || viewModel.state.saving) }.navigationTitle("Edit profile").task { try? await viewModel.load() } }
}

struct SavedTravelersScreen: View { let travelers: [SavedTraveler]; var body: some View { List { if travelers.isEmpty { ContentUnavailableView("No saved travelers yet.", systemImage: NexusPlatformIconName.savedTravelers.rawValue) } else { ForEach(travelers, id: \.id) { traveler in VStack(alignment: .leading) { Text("\(traveler.firstName) \(traveler.lastName)"); Text("\(traveler.nationality) · \(traveler.passportNumber)").font(.subheadline).foregroundStyle(.secondary); Text(humanizeProfile(traveler.status)).font(.caption).foregroundStyle(NexusSemanticColors.brandPrimary) } } } }.navigationTitle("Saved travelers") } }

struct SettingsScreen: View {
    let viewModel: PreferencesViewModel; let router: Router
    var body: some View { Form { Section("Preferences") { LabeledContent("Language", value: "English"); LabeledContent("Currency", value: "INR"); NavigationLink("Theme", value: AppRoute.theme(.init())); NavigationLink("Home airport", value: AppRoute.homeAirport(.init())) }; Section("Notifications") { NavigationLink("Notification preferences", value: AppRoute.notificationSettings(.init())) }; if let error = viewModel.state.error { Text(error).foregroundStyle(.secondary) } }.navigationTitle("Settings").task { try? await viewModel.load() } }
}
struct ThemeScreen: View { let viewModel: PreferencesViewModel; var body: some View { Form { Picker("Theme", selection: Binding(get: { viewModel.state.value.theme }, set: { theme in saveTheme(theme) })) { ForEach(ThemePreference.allCases, id: \.self) { Text(humanizeProfile($0.rawValue)).tag($0) } } }.navigationTitle("Theme") }; private func saveTheme(_ theme: ThemePreference) { var next = viewModel.state.value; next.theme = theme; Task { try? await viewModel.save(next) } } }
struct NotificationSettingsScreen: View {
    let viewModel: PreferencesViewModel
    var body: some View { Form { Text("Choose which updates Nexus may send when notification delivery becomes available."); notificationToggle("Push notifications", .push); notificationToggle("Flight updates", .flight); notificationToggle("Gate changes", .gate); notificationToggle("Check-in reminders", .checkIn); notificationToggle("Payment alerts", .payment); notificationToggle("Promotional offers", .promotional) }.navigationTitle("Notifications") }
    private func notificationToggle(_ title: String, _ kind: NotificationKind) -> some View {
        Toggle(title, isOn: Binding(get: { kind.value(in: viewModel.state.value.notifications) }, set: { enabled in update(kind, enabled: enabled) })).disabled(kind != .push && !viewModel.state.value.notifications.pushEnabled)
    }
    private func update(_ kind: NotificationKind, enabled: Bool) { Task { if enabled && kind == .push { let allowed = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) == true; guard allowed else { return } }; var next = viewModel.state.value; next.notifications = kind.updated(next.notifications, enabled: enabled); try? await viewModel.save(next) } }
}
struct SecurityScreen: View {
    @State private var viewModel: AccountSecurityViewModel
    @State private var authViewModel: AuthViewModel
    @State private var showingPasswordReset = false
    private let authRepository: any AuthRepository
    let router: Router

    init(viewModel: AccountSecurityViewModel, router: Router, authRepository: any AuthRepository) {
        _viewModel = State(initialValue: viewModel)
        _authViewModel = State(initialValue: AuthViewModel(repository: authRepository))
        self.authRepository = authRepository
        self.router = router
    }

    var body: some View {
        Form {
            Section("Current session") {
                LabeledContent("Signed-in device", value: viewModel.state.value?.device ?? "Loading")
                LabeledContent("Email verification", value: viewModel.state.value?.emailVerified == true ? "Verified" : "Not verified")
            }
            Section("Password") {
                Button("Reset password") {
                    authViewModel.startPasswordCodeFlow()
                    showingPasswordReset = true
                }
            }
            Section("Account") {
                Button("Delete account", role: .destructive) { router.push(.deleteAccount(.init())) }
            }
            if let error = viewModel.state.error { Text(error).foregroundStyle(NexusSemanticColors.errorText) }
        }
        .navigationTitle("Security")
        .task { try? await viewModel.load() }
        .sheet(isPresented: $showingPasswordReset) {
            PasswordResetRequestScreen(viewModel: authViewModel) {
                Task {
                    _ = try? await authRepository.signOut()
                    router.popToRoot()
                    router.presentAuthentication(for: .sessionExpired)
                }
            }
        }
    }
}
struct DeleteAccountScreen: View {
    @State private var viewModel: DeleteAccountViewModel
    @State private var password = ""
    @State private var confirmation = ""
    let onDone: () -> Void
    init(viewModel: DeleteAccountViewModel, onDone: @escaping () -> Void) { _viewModel = State(initialValue: viewModel); self.onDone = onDone }
    var body: some View {
        Group {
            if case .pending = viewModel.state {
                ContentUnavailableView {
                    Label("Deletion requested", systemImage: NexusPlatformIconName.deletionRequested.rawValue)
                } description: {
                    Text("Your account is signed out while deletion completes. Required booking and ticket records remain anonymized for legal purposes.")
                } actions: {
                    Button("Done", action: onDone)
                }
            } else {
                Form {
                    Section { Text("This action is permanent.").foregroundStyle(NexusSemanticColors.errorText); Text("Your sign-in, preferences, traveler profiles, and passport documents will be removed. Required booking and ticket records are retained in anonymized form.") }
                    Section("Confirm deletion") { SecureField("Current password", text: $password); TextField("Type DELETE", text: $confirmation).textInputAutocapitalization(.characters).autocorrectionDisabled() }
                    if case let .failure(message) = viewModel.state { Text(message).foregroundStyle(NexusSemanticColors.errorText) }
                    Button("Delete account", role: .destructive) { Task { await viewModel.submit(password: password, confirmation: confirmation) } }.disabled(password.isEmpty || confirmation != "DELETE" || viewModel.state == .submitting)
                }
            }
        }
        .navigationTitle("Delete account")
    }
}
struct HomeAirportScreen: View { let viewModel: PreferencesViewModel; let airports: any AirportRepository; @State private var query = ""; @State private var results: [Airport] = []; var body: some View { List { TextField("Search airport or city", text: $query); ForEach(results, id: \.code) { airport in Button { save(airport.code) } label: { HStack { VStack(alignment: .leading) { Text(airport.name); Text("\(airport.city), \(airport.country)").font(.caption) }; Spacer(); Text(airport.code) } } } }.navigationTitle("Home airport").task(id: query) { results = (try? await airports.searchAirports(query: query)) ?? [] } }; private func save(_ code: String) { var next = viewModel.state.value; next.homeAirportCode = code; Task { try? await viewModel.save(next) } } }
private func initials(_ name: String) -> String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased().isEmpty ? "N" : name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
private func humanizeProfile(_ value: String) -> String { value.replacingOccurrences(of: "_", with: " ").lowercased().capitalized }
private enum NotificationKind: Equatable {
    case push, flight, gate, checkIn, payment, promotional
    func value(in value: NotificationPreferences) -> Bool { switch self { case .push: value.pushEnabled; case .flight: value.flightUpdates; case .gate: value.gateChanges; case .checkIn: value.checkInReminders; case .payment: value.paymentAlerts; case .promotional: value.promotionalOffers } }
    func updated(_ value: NotificationPreferences, enabled: Bool) -> NotificationPreferences { var copy = value; switch self { case .push: copy.pushEnabled = enabled; case .flight: copy.flightUpdates = enabled; case .gate: copy.gateChanges = enabled; case .checkIn: copy.checkInReminders = enabled; case .payment: copy.paymentAlerts = enabled; case .promotional: copy.promotionalOffers = enabled }; return copy }
}
