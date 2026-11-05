import Network
import SwiftUI

struct ProfileScreenRoute: View {
    let viewModel: ProfileViewModel
    let router: Router
    let supportRepository: RemoteSupportRepository
    let appearance: ThemePreference
    let onAppearanceChange: (ThemePreference) -> Void
    @Binding var rootScrollTarget: String?
    let onSignedOut: () -> Void

    @State private var loadRequest = 0
    @State private var signOutRequested = false

    var body: some View {
        ProfileScreen(
            state: viewModel.state,
            appearance: appearance,
            onAppearanceChange: onAppearanceChange,
            supportRepository: supportRepository,
            rootScrollTarget: $rootScrollTarget,
            onSignIn: { router.presentAuthentication(for: .profile) },
            onAccountDetails: { router.push(.editProfile(.init())) },
            onSavedTravelers: { router.push(.savedTravelers(.init())) },
            onRetry: retry,
            onSignOut: viewModel.requestLogout
        )
        .task(id: loadRequest) {
            try? await viewModel.loadIfNeeded()
        }
        .task(id: viewModel.state.isRecoverableError) {
            guard viewModel.state.isRecoverableError else { return }
            await retryWhenNetworkReturns()
        }
        .task(id: signOutRequested) {
            guard signOutRequested else { return }
            defer { signOutRequested = false }
            do {
                try await viewModel.signOut()
                onSignedOut()
            } catch {}
        }
        .onChange(of: router.authPresentation) { previous, current in
            if previous == .profile && current == nil { retry() }
        }
        .alert(
            "Sign out?",
            isPresented: Binding(
                get: { viewModel.state.showLogoutConfirmation },
                set: { if !$0 { viewModel.dismissLogout() } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) { signOutRequested = true }
        } message: {
            Text("Sign in again to access your trips and saved details.")
        }
    }

    private func retry() {
        viewModel.invalidateLoadedProfile()
        loadRequest += 1
    }

    private func retryWhenNetworkReturns() async {
        let monitor = NWPathMonitor()
        let availability = AsyncStream<Bool>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "com.nexustravel.profile-connectivity"))
        }
        defer { monitor.cancel() }

        var wasOffline = false
        for await isOnline in availability {
            guard !Task.isCancelled else { return }
            if isOnline && wasOffline {
                retry()
                return
            }
            wasOffline = !isOnline
        }
    }
}

private struct ProfileScreen: View {
    let state: ProfileUiState
    let appearance: ThemePreference
    let onAppearanceChange: (ThemePreference) -> Void
    let supportRepository: RemoteSupportRepository
    @Binding var rootScrollTarget: String?
    let onSignIn: () -> Void
    let onAccountDetails: () -> Void
    let onSavedTravelers: () -> Void
    let onRetry: () -> Void
    let onSignOut: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var showsSupport = false
    @State private var hasLinkError = false

    var body: some View {
        GeometryReader { geometry in
            let spacing = NexusAdaptiveSpacing(
                screenWidth: geometry.size.width,
                screenHeight: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            )
            ScrollView {
                LazyVStack(alignment: .leading, spacing: spacing?.sectionGap ?? NexusSpacing.space32) {
                    Text("Profile")
                        .nexusTextStyle(NexusText.styles.screenTitle)
                        .foregroundStyle(NexusSemanticColors.textHeading)
                        .accessibilityAddTraits(.isHeader)
                        .id("profile.heading")
                    account
                        .id("profile.account-summary")
                    AppearanceRow(selection: appearance, onSelect: onAppearanceChange)
                        .id("profile.appearance")
                    if state.isRecoverableError {
                        recovery
                            .id("profile.error")
                    }
                    if state.profile != nil {
                        ProfileActionRow("Saved travelers", icon: .users, action: onSavedTravelers)
                            .id("profile.travelers")
                    }
                    legalAndSupport
                        .id("profile.links")
                    if state.profile != nil {
                        NexusTextButton(
                            state.signingOut ? "Signing out…" : "Sign out",
                            isEnabled: !state.signingOut,
                            action: onSignOut
                        )
                        .accessibilityIdentifier("profile-sign-out")
                        .id("profile.logout")
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, spacing?.screenMargin ?? NexusLayout.screenMargin)
                .padding(.top, spacing?.screenTopPadding ?? NexusSpacing.space24)
                .padding(.bottom, spacing?.sectionGap ?? NexusSpacing.space32)
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable { onRetry() }
            .scrollPosition(id: $rootScrollTarget, anchor: .top)
            .accessibilityIdentifier("root-profile")
            .sheet(isPresented: $showsSupport) {
                SupportOptionsSheet(
                    repository: supportRepository,
                    horizontalPadding: spacing?.bottomSheetPaddingH ?? NexusSpacing.space24
                )
            }
        }
        .background(NexusSemanticColors.backgroundPage.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var account: some View {
        if let profile = state.profile {
            AccountRow(title: profile.name, subtitle: profile.email, hint: "Account details", action: onAccountDetails)
                .accessibilityIdentifier("profile-account-details")
        } else {
            switch state.access {
            case .guest:
                AccountRow(
                    title: "Sign in to Nexus",
                    subtitle: "Manage your details and saved travelers.",
                    action: onSignIn
                )
                .accessibilityIdentifier("profile-sign-in")
            case .loading:
                ProgressView()
                    .controlSize(.large)
                    .tint(NexusSemanticColors.brandPrimary)
                    .frame(maxWidth: .infinity, minHeight: NexusSpacing.space40)
                    .accessibilityLabel("Loading profile")
            case .authenticated, .recoverableError:
                Spacer(minLength: NexusSpacing.space0)
                    .frame(height: NexusSpacing.space0)
                    .accessibilityHidden(true)
            }
        }
    }

    private var recovery: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space8) {
            Text(state.errorMessage ?? (state.profile == nil
                ? "Profile could not load."
                : "Showing saved details. Profile could not refresh."))
                .nexusTextStyle(NexusText.styles.body, matchesLineHeight: true)
                .foregroundStyle(NexusSemanticColors.textSecondary)
            NexusSecondaryButton("Retry", action: onRetry)
                .accessibilityIdentifier("profile-retry")
        }
    }

    private var legalAndSupport: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space0) {
            ProfileActionRow("Privacy policy") { openLegal(NexusLegalDestinations.privacyPolicy) }
            ProfileActionRow("Terms of service") { openLegal(NexusLegalDestinations.termsOfService) }
            ProfileActionRow("Support", icon: .headset) { showsSupport = true }
            if hasLinkError {
                Text("No browser available to open this link.")
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.errorText)
            }
        }
    }

    private func openLegal(_ url: URL?) {
        guard let url else {
            hasLinkError = true
            return
        }
        hasLinkError = false
        openURL(url) { accepted in hasLinkError = !accepted }
    }
}

private struct AccountRow: View {
    let title: String
    let subtitle: String
    var hint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NexusSpacing.space16) {
                NexusIcon(name: .profile, size: NexusIconSize.lg)
                    .foregroundStyle(NexusSemanticColors.textHeading)
                    .frame(width: NexusSpacing.space48, height: NexusSpacing.space48)
                    .background(NexusSemanticColors.surfaceSubtle, in: Circle())
                VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                    Text(title)
                        .nexusTextStyle(NexusText.styles.sectionTitleSmall)
                        .foregroundStyle(NexusSemanticColors.textHeading)
                    Text(subtitle)
                        .nexusTextStyle(NexusText.styles.body, matchesLineHeight: true)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                    if let hint {
                        Text(hint)
                            .nexusTextStyle(NexusText.styles.caption)
                            .foregroundStyle(NexusSemanticColors.link)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                NexusIcon(name: .chevronRight)
                    .foregroundStyle(NexusSemanticColors.link)
            }
            .padding(.vertical, NexusSpacing.space12)
            .contentShape(RoundedRectangle(cornerRadius: NexusRadius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(hint.map { "\(subtitle). \($0)" } ?? subtitle)
    }
}

private struct AppearanceRow: View {
    let selection: ThemePreference
    let onSelect: (ThemePreference) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: NexusSpacing.space8) {
                title.fixedSize()
                Spacer(minLength: NexusSpacing.space0)
                options
            }
            VStack(alignment: .leading, spacing: NexusSpacing.space8) {
                title
                options.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var title: some View {
        Text("Appearance")
            .nexusTextStyle(NexusText.styles.listTitle)
            .foregroundStyle(NexusSemanticColors.textSecondary)
    }

    private var options: some View {
        HStack(spacing: NexusSpacing.space4) {
            option(.system, label: "System appearance", icon: .device)
            option(.light, label: "Light appearance", icon: .sun)
            option(.dark, label: "Dark appearance", icon: .moon)
        }
    }

    private func option(_ preference: ThemePreference, label: String, icon: NexusIconName) -> some View {
        let isSelected = selection == preference
        return Button { onSelect(preference) } label: {
            NexusIcon(name: icon)
                .foregroundStyle(isSelected ? NexusSemanticColors.link : NexusSemanticColors.textSecondary)
                .frame(width: NexusLayout.touchRecommended, height: NexusLayout.touchRecommended)
                .background {
                    if isSelected { Circle().fill(NexusSemanticColors.surfaceSubtle) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ProfileActionRow: View {
    let title: String
    let icon: NexusIconName?
    let action: () -> Void

    init(_ title: String, icon: NexusIconName? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: NexusSpacing.space16) {
                if let icon {
                    NexusIcon(name: icon)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                }
                Text(title)
                    .nexusTextStyle(NexusText.styles.listTitle)
                    .foregroundStyle(NexusSemanticColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                NexusIcon(name: .chevronRight, size: NexusIconSize.sm)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
            .padding(.vertical, NexusSpacing.space12)
            .frame(minHeight: NexusLayout.touchRecommended)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
