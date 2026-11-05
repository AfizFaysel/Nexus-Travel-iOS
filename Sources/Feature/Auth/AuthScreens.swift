import SwiftUI

struct AuthRoute: View {
    @State private var viewModel: AuthViewModel
    @State private var actionTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let purpose: AuthPresentation?
    let onAuthenticated: () -> Void

    init(
        viewModel: AuthViewModel,
        purpose: AuthPresentation? = nil,
        onAuthenticated: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.purpose = purpose
        self.onAuthenticated = onAuthenticated
    }

    var body: some View {
        Group {
            if viewModel.gateState == .checking {
                ProgressView("Checking your session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if case .verificationPending = viewModel.gateState {
                VerificationPendingScreen(viewModel: viewModel, perform: perform)
            } else {
                Group {
                    if viewModel.mode == .login {
                        LoginScreen(viewModel: viewModel, subtitle: loginSubtitle, isSheet: purpose != nil, perform: perform)
                            .transition(.opacity)
                    } else {
                        SignupScreen(viewModel: viewModel, isSheet: purpose != nil, perform: perform)
                            .transition(.opacity)
                    }
                }
            }
        }
        .task {
            await run { try await viewModel.checkExistingSession() }
        }
        .onDisappear { actionTask?.cancel() }
        .interactiveDismissDisabled(viewModel.isSubmitting || viewModel.isVerifyingCode || viewModel.isResendingVerification)
        .overlay(alignment: .topTrailing) {
            if purpose != nil && !isVerificationPending {
                NexusIconActionButton("Close") { dismiss() } icon: {
                    Image(systemName: "xmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: NexusIconSize.sm, height: NexusIconSize.sm)
                }
                .disabled(viewModel.isSubmitting)
                .padding(.trailing, NexusLayout.screenMargin)
                .padding(.top, NexusSpacing.space32)
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: NexusMotion.durationFastSeconds) : NexusMotion.authModeTransition,
            value: viewModel.mode
        )
        .navigationBarBackButtonHidden(true)
    }

    private var isVerificationPending: Bool {
        if case .verificationPending = viewModel.gateState { return true }
        return false
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        actionTask?.cancel()
        actionTask = Task { await run(operation) }
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) async {
        do { try await operation() } catch is CancellationError { return } catch { return }
        while case .authenticated = viewModel.consumeEvent() { onAuthenticated() }
        actionTask = nil
    }

    private var loginSubtitle: String {
        switch purpose {
        case .booking:
            "Sign in to continue your booking."
        case .trips:
            "View your bookings and trip updates."
        case .sessionExpired:
            "Your session expired. Sign in again to continue."
        case .profile, .none:
            "View your bookings and trip updates."
        }
    }
}

struct LoginScreen: View {
    @Bindable var viewModel: AuthViewModel
    let subtitle: String?
    let isSheet: Bool
    let perform: (@escaping @MainActor () async throws -> Void) -> Void
    @State private var showingPasswordReset = false

    var body: some View {
        AuthScaffold(title: "Sign in", subtitle: subtitle,
                     layout: isSheet ? .sheet : .standard) {
            NexusAuthTextField(
                text: Binding(
                    get: { viewModel.loginState.email },
                    set: { viewModel.updateLoginEmail($0) }
                ),
                placeholder: "Email",
                label: "Email",
                error: viewModel.loginState.emailError,
                isEnabled: !viewModel.loginState.isSubmitting
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            PasswordAuthField(
                text: Binding(
                    get: { viewModel.loginState.password },
                    set: { viewModel.updateLoginPassword($0) }
                ),
                label: "Password",
                error: viewModel.loginState.passwordError,
                isEnabled: !viewModel.loginState.isSubmitting
            )
            NexusTextButton("Forgot password?") {
                viewModel.startPasswordCodeFlow()
                showingPasswordReset = true
            }
                .disabled(viewModel.loginState.isSubmitting)
                .frame(maxWidth: .infinity, alignment: .trailing)
            AuthMessage(state: viewModel.loginState)
            NexusPrimaryButton("Sign in", isLoading: viewModel.loginState.isSubmitting, loadingTitle: "Signing in…", fillsWidth: true, minHeight: NexusLayout.authControlHeight) {
                perform { try await viewModel.submitLogin() }
            }
            .padding(.top, NexusSpacing.space8)
            AuthModeSwitch(prompt: "Don’t have an account?", title: "Sign up",
                           isEnabled: !viewModel.loginState.isSubmitting, action: viewModel.showSignup)
        }
        .sheet(isPresented: $showingPasswordReset) {
            PasswordResetRequestScreen(viewModel: viewModel)
        }
    }
}

struct VerificationPendingScreen: View {
    @Bindable var viewModel: AuthViewModel
    let perform: (@escaping @MainActor () async throws -> Void) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AuthScaffold(title: "Verify your email", subtitle: nil, layout: .code) {
            AuthCodeDestination(email: email,
                isEnabled: !viewModel.isVerifyingCode && !viewModel.isResendingVerification && !viewModel.verificationSucceeded,
                onChangeEmail: viewModel.showSignInForPendingVerification)
            AuthCodeField(
                code: Binding(get: { viewModel.verificationCode }, set: { viewModel.updateVerificationCode($0) }),
                error: viewModel.verificationCodeError,
                isSuccess: viewModel.verificationSucceeded,
                isEnabled: !viewModel.verificationRequiresNewCode && !viewModel.isVerifyingCode &&
                    !viewModel.isResendingVerification && !viewModel.verificationSucceeded
            )
            if let message = viewModel.verificationCodeError ?? viewModel.verificationMessage {
                Text(message)
                    .nexusTextStyle(NexusText.styles.errorText)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(viewModel.verificationSucceeded ? NexusSemanticColors.successText :
                        (viewModel.verificationCodeError == nil && !viewModel.verificationMessageIsError ? NexusSemanticColors.textSecondary : NexusSemanticColors.errorText))
                    .accessibilityAddTraits(.updatesFrequently)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            NexusTextButton("Send new code") { perform { await viewModel.resendVerificationEmail() } }
                .disabled(viewModel.isVerifyingCode || viewModel.isResendingVerification || viewModel.verificationSucceeded)
            NexusPrimaryButton("Verify email", isLoading: viewModel.isVerifyingCode, loadingTitle: "Verifying…", fillsWidth: true, minHeight: NexusLayout.authControlHeight) {
                perform { try await viewModel.submitVerificationCode() }
            }
            .disabled(viewModel.isResendingVerification || viewModel.verificationSucceeded || viewModel.verificationRequiresNewCode)
            .padding(.top, NexusSpacing.space8)
            if viewModel.verificationOutcomeUncertain {
                NexusTextButton("Try signing in", action: viewModel.showSignInForPendingVerification)
            }
            NexusTextButton("Back to sign in", action: viewModel.showSignInForPendingVerification)
                .disabled(viewModel.isVerifyingCode || viewModel.isResendingVerification || viewModel.verificationSucceeded)
        }
        .task(id: viewModel.verificationSucceeded) {
            guard viewModel.verificationSucceeded else { return }
            try? await Task.sleep(for: .milliseconds(Int64(NexusMotion.durationSuccessMillis)))
            guard !Task.isCancelled else { return }
            viewModel.finishVerificationFeedback()
        }
    }

    private var email: String {
        guard case let .verificationPending(address) = viewModel.gateState else { return "" }
        return address
    }

}

/// Shared destination header for live code sheets and their visual previews.
private struct AuthCodeDestination: View {
    let email: String
    let isEnabled: Bool
    let onChangeEmail: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: NexusSpacing.space8) {
            Text("Enter the 6-digit code sent to")
                .nexusTextStyle(NexusText.styles.body)
                .foregroundStyle(NexusSemanticColors.textSecondary)
                .multilineTextAlignment(.center)
            emailRow
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var emailRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: NexusSpacing.space4) { emailText; changeEmailButton }
        } else {
            HStack(spacing: NexusSpacing.space12) { emailText; changeEmailButton }
        }
    }

    private var emailText: some View {
        Text(verbatim: email)
            .nexusTextStyle(NexusText.styles.body)
            .foregroundStyle(NexusSemanticColors.textHeading)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .truncationMode(.middle)
    }

    private var changeEmailButton: some View {
        Button("Change email", action: onChangeEmail)
            .nexusTextStyle(NexusText.styles.link)
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
            .frame(minHeight: NexusLayout.touchMin)
            .disabled(!isEnabled)
    }
}

struct PasswordResetRequestScreen: View {
    @Bindable var viewModel: AuthViewModel
    var onSignIn: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var requestTask: Task<Void, Never>?

    var body: some View {
            Group {
                switch viewModel.passwordCodeState.step {
                case .request: requestForm
                case .code: codeForm
                case .password: passwordForm
                case .complete:
                    AuthLinkResultScreen(title: "Password updated", message: "Sign in with your new password.", actionTitle: "Sign in", layout: .code, action: signIn)
                case .uncertain:
                    AuthLinkResultScreen(title: "Update not confirmed", message: "Try signing in with your new password before requesting another code.", actionTitle: "Sign in", layout: .code, action: signIn)
                }
            }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(NexusRadius.xxxl)
        .interactiveDismissDisabled(viewModel.passwordCodeState.isSubmitting)
        .task { await viewModel.preparePasswordResetEmail() }
        .onDisappear { requestTask?.cancel(); viewModel.cancelCodeFlow() }
    }

    private var requestForm: some View {
        AuthScaffold(title: "Reset password", subtitle: "Enter your account email. We’ll send a code if an account uses it.", layout: .code) {
            NexusAuthTextField(
                text: Binding(get: { viewModel.passwordCodeState.email }, set: { viewModel.updatePasswordCodeEmail($0) }),
                placeholder: "Email",
                label: "Email",
                error: viewModel.passwordCodeState.emailError,
                isEnabled: !viewModel.passwordCodeState.isSubmitting
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            feedback
            NexusPrimaryButton("Send code", isLoading: viewModel.passwordCodeState.isSubmitting, loadingTitle: "Sending…", fillsWidth: true, minHeight: NexusLayout.authControlHeight) {
                perform { try await viewModel.requestPasswordReset() }
            }
            NexusTextButton(onSignIn == nil ? "Back to sign in" : "Close") { dismiss() }
                .disabled(viewModel.passwordCodeState.isSubmitting)
        }
    }

    private var codeForm: some View {
        AuthScaffold(title: "Enter your code", subtitle: nil, layout: .code) {
            Text("If an account uses \(viewModel.passwordCodeState.email), we’ll send a code.")
                .nexusTextStyle(NexusText.styles.body)
                .foregroundStyle(NexusSemanticColors.textSecondary)
                .multilineTextAlignment(.center)
            AuthCodeField(
                code: Binding(get: { viewModel.passwordCodeState.code }, set: { viewModel.updatePasswordCode($0) }),
                error: viewModel.passwordCodeState.codeError,
                isSuccess: false,
                isEnabled: !viewModel.passwordCodeState.requiresNewCode && !viewModel.passwordCodeState.isSubmitting
            )
            feedback
            NexusTextButton("Send new code") { perform { try await viewModel.requestPasswordReset() } }
                .disabled(viewModel.passwordCodeState.isSubmitting)
            NexusPrimaryButton("Continue", fillsWidth: true, minHeight: NexusLayout.authControlHeight, action: viewModel.continuePasswordReset)
                .disabled(viewModel.passwordCodeState.requiresNewCode || viewModel.passwordCodeState.isSubmitting)
            NexusTextButton(onSignIn == nil ? "Back to sign in" : "Close") { dismiss() }
                .disabled(viewModel.passwordCodeState.isSubmitting)
        }
    }

    private var passwordForm: some View {
        AuthScaffold(title: "New password", subtitle: "Use at least 8 characters.", layout: .code) {
            PasswordAuthField(
                text: Binding(get: { viewModel.passwordCodeState.password }, set: { viewModel.updatePasswordCodePassword($0) }),
                label: "Password",
                error: viewModel.passwordCodeState.passwordError,
                isEnabled: !viewModel.passwordCodeState.isSubmitting,
                contentType: .newPassword
            )
            PasswordAuthField(
                text: Binding(get: { viewModel.passwordCodeState.confirmPassword }, set: { viewModel.updatePasswordCodeConfirmation($0) }),
                label: "Confirm password",
                error: viewModel.passwordCodeState.confirmPasswordError,
                isEnabled: !viewModel.passwordCodeState.isSubmitting,
                contentType: .newPassword
            )
            feedback
            NexusPrimaryButton("Update password", isLoading: viewModel.passwordCodeState.isSubmitting, loadingTitle: "Updating…", fillsWidth: true, minHeight: NexusLayout.authControlHeight) {
                perform { try await viewModel.submitPasswordCodeReset() }
            }
            NexusTextButton(onSignIn == nil ? "Back to sign in" : "Close") { dismiss() }
                .disabled(viewModel.passwordCodeState.isSubmitting)
        }
    }

    @ViewBuilder private var feedback: some View {
        if let message = viewModel.passwordCodeState.codeError ?? viewModel.passwordCodeState.message {
            Text(message)
                .nexusTextStyle(NexusText.styles.errorText)
                .foregroundStyle(viewModel.passwordCodeState.codeError == nil && !viewModel.passwordCodeState.messageIsError ? NexusSemanticColors.textSecondary : NexusSemanticColors.errorText)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private func perform(_ operation: @escaping () async throws -> Void) {
        requestTask?.cancel()
        requestTask = Task { try? await operation() }
    }

    private func signIn() {
        dismiss()
        onSignIn?()
    }
}

struct AuthLinkScreen: View {
    @State private var viewModel: AuthViewModel
    @State private var submitTask: Task<Void, Never>?
    let route: AuthLinkRoute
    let onDone: () -> Void
    let onPasswordResetComplete: () -> Void

    init(
        viewModel: AuthViewModel,
        route: AuthLinkRoute,
        onPasswordResetComplete: @escaping () -> Void = {},
        onDone: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.route = route
        self.onPasswordResetComplete = onPasswordResetComplete
        self.onDone = onDone
    }

    var body: some View {
        Group {
            switch viewModel.authLinkState {
            case .idle, .verifying:
                ProgressView("Verifying your email…")
            case .verified:
                AuthLinkResultScreen(title: "Email verified", message: "Your email is verified. Sign in to continue.", actionTitle: "Sign in", action: onDone)
            case .verificationFailed:
                AuthLinkResultScreen(title: "Link unavailable", message: "This verification link may have expired or already been used. Request another email and try again.", actionTitle: "Go to sign in", action: onDone)
            case .verificationOffline:
                AuthLinkResultScreen(title: "Couldn’t verify email", message: "Check your connection and try again.", actionTitle: "Try again") {
                    submitTask?.cancel()
                    submitTask = Task { await viewModel.openAuthLink(route) }
                }
            case .resetForm:
                resetForm
            case .resetComplete:
                AuthLinkResultScreen(title: "Password updated", message: "Sign in with your new password.", actionTitle: "Sign in") {
                    onPasswordResetComplete()
                    onDone()
                }
            case .resetFailed:
                AuthLinkResultScreen(title: "Link unavailable", message: viewModel.passwordResetState.message ?? "Request a new reset link and try again.", actionTitle: "Go to sign in", action: onDone)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await viewModel.openAuthLink(route) }
        .onDisappear { submitTask?.cancel() }
    }

    private var resetForm: some View {
        AuthScaffold(title: "Create a new password", subtitle: "Choose a password with at least 8 characters.") {
            PasswordAuthField(
                text: Binding(get: { viewModel.passwordResetState.password }, set: { viewModel.updateResetPassword($0) }),
                label: "New password",
                error: viewModel.passwordResetState.passwordError,
                isEnabled: !viewModel.passwordResetState.isSubmitting,
                contentType: .newPassword
            )
            if let message = viewModel.passwordResetState.message {
                Text(message)
                    .nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.errorText)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            PasswordAuthField(
                text: Binding(get: { viewModel.passwordResetState.confirmPassword }, set: { viewModel.updateResetPasswordConfirmation($0) }),
                label: "Confirm new password",
                error: viewModel.passwordResetState.confirmPasswordError,
                isEnabled: !viewModel.passwordResetState.isSubmitting,
                contentType: .newPassword
            )
            NexusPrimaryButton("Update password", isLoading: viewModel.passwordResetState.isSubmitting, loadingTitle: "Updating…", fillsWidth: true) {
                submitTask?.cancel()
                submitTask = Task { await viewModel.submitPasswordReset() }
            }
        }
    }
}

private struct AuthLinkResultScreen: View {
    let title: String
    let message: String
    let actionTitle: String
    var layout: AuthScaffoldLayout = .standard
    let action: () -> Void

    var body: some View {
        AuthScaffold(title: title, subtitle: message, layout: layout) {
            NexusPrimaryButton(actionTitle, fillsWidth: true, minHeight: NexusLayout.authControlHeight, action: action)
        }
    }
}

struct SignupScreen: View {
    @Bindable var viewModel: AuthViewModel
    let isSheet: Bool
    let perform: (@escaping @MainActor () async throws -> Void) -> Void

    var body: some View {
        AuthScaffold(
            title: isSheet ? "Create account" : "Create your account",
            subtitle: "We’ll email you a code to verify your account.",
            layout: isSheet ? .sheet : .standard
        ) {
            NexusAuthTextField(
                text: Binding(
                    get: { viewModel.signupState.fullName },
                    set: { viewModel.updateSignupName($0) }
                ),
                placeholder: "Full name", label: "Full name", error: viewModel.signupState.fullNameError,
                isEnabled: !viewModel.signupState.isSubmitting
            )
            .textContentType(.name)
            NexusAuthTextField(
                text: Binding(
                    get: { viewModel.signupState.email },
                    set: { viewModel.updateSignupEmail($0) }
                ),
                placeholder: "Email", label: "Email", error: viewModel.signupState.emailError,
                isEnabled: !viewModel.signupState.isSubmitting
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            PasswordAuthField(
                text: Binding(
                    get: { viewModel.signupState.password },
                    set: { viewModel.updateSignupPassword($0) }
                ),
                label: "Password", error: viewModel.signupState.passwordError,
                isEnabled: !viewModel.signupState.isSubmitting, contentType: .newPassword
            )
            PasswordAuthField(
                text: Binding(
                    get: { viewModel.signupState.confirmPassword },
                    set: { viewModel.updateSignupConfirmPassword($0) }
                ),
                label: "Confirm password", error: viewModel.signupState.confirmPasswordError,
                isEnabled: !viewModel.signupState.isSubmitting, contentType: .newPassword
            )
            Toggle("I agree to the terms and privacy policy.", isOn: Binding(
                get: { viewModel.signupState.acceptedTerms },
                set: { viewModel.updateTerms($0) }
            ))
            .toggleStyle(NexusCheckboxToggleStyle(isInvalid: viewModel.signupState.termsError != nil))
            .disabled(viewModel.signupState.isSubmitting)
            .nexusTextStyle(NexusText.styles.body)
            .foregroundStyle(NexusSemanticColors.textSecondary)
            .tint(NexusSemanticColors.brandPrimary)
            if let error = viewModel.signupState.termsError {
                Text(error).nexusTextStyle(NexusText.styles.errorText).foregroundStyle(NexusSemanticColors.errorText)
            }
            AuthMessage(state: viewModel.signupState)
            NexusPrimaryButton("Create account", isLoading: viewModel.signupState.isSubmitting, loadingTitle: "Creating account…", fillsWidth: true, minHeight: NexusLayout.authControlHeight) {
                perform { try await viewModel.submitSignup() }
            }
            .padding(.top, NexusSpacing.space8)
            AuthModeSwitch(prompt: "Already have an account?", title: "Sign in",
                           isEnabled: !viewModel.signupState.isSubmitting, action: viewModel.showLogin)
        }
    }
}

private enum AuthScaffoldLayout: Equatable { case standard, sheet, code }

private struct AuthScaffold<Content: View>: View {
    @State private var contentHeight = NexusLayout.authCodeSheetInitialHeight
    @State private var adaptiveSpacing: NexusAdaptiveSpacing?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let subtitle: String?
    let layout: AuthScaffoldLayout
    let content: Content

    init(title: String, subtitle: String?, layout: AuthScaffoldLayout = .standard, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.layout = layout
        self.content = content()
    }

    @ViewBuilder var body: some View {
        if layout != .standard {
            form.presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(contentHeight), .large])
        } else {
            form
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: layout == .standard ? NexusSpacing.space16 : NexusSpacing.space24) {
                VStack(spacing: NexusSpacing.space8) {
                    if subtitle != nil && layout == .standard {
                        Text("Nexus Travel").nexusTextStyle(NexusText.styles.sectionTitle)
                            .foregroundStyle(NexusSemanticColors.brandPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Text(title).nexusTextStyle(layout == .standard ? NexusText.styles.displayHeroCompact : NexusAuthTypography.sheetTitle)
                        .foregroundStyle(NexusSemanticColors.textHeading)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, layout == .sheet ? NexusLayout.touchRecommended : NexusSpacing.space0)
                    if let subtitle {
                        Text(subtitle).nexusTextStyle(NexusText.styles.bodySmall)
                            .foregroundStyle(NexusSemanticColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(spacing: adaptiveSpacing?.formFieldGap ?? NexusSpacing.space16) { content }
            }
            .frame(maxWidth: layout == .standard ? NexusLayout.formMaxWidth : NexusLayout.authCodeMaxWidth)
            .padding(.horizontal, adaptiveSpacing?.bottomSheetPaddingH ?? NexusLayout.screenMargin)
            .padding(.top, topPadding)
            .padding(.bottom, layout == .sheet ? NexusSpacing.space0 : NexusSpacing.space16)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { height in
                if layout != .standard && height > 0 { contentHeight = height }
            }
        }
        .background(NexusSemanticColors.backgroundPage)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(layout == .code ? "auth-code-sheet" : "auth-form")
        .onGeometryChange(for: NexusAdaptiveSpacing?.self) { geometry in
            NexusAdaptiveSpacing(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
        } action: { spacing in
            adaptiveSpacing = spacing
        }
    }

    private var topPadding: CGFloat {
        switch layout {
        case .standard: NexusSpacing.space32
        case .sheet: NexusSpacing.space40
        case .code: NexusSpacing.space24
        }
    }
}

private struct PasswordAuthField: View {
    @Binding var text: String
    let label: String
    let error: String?
    var isEnabled = true
    var contentType: UITextContentType = .password
    @State private var isVisible = false

    var body: some View {
        NexusAuthTextField(
            text: $text,
            placeholder: label,
            label: label,
            error: error,
            isEnabled: isEnabled,
            isSecure: !isVisible,
            leadingIcon: { NexusPlatformIcon(.password) },
            trailingContent: {
                NexusIconActionButton(isVisible ? "Hide password" : "Show password") {
                    isVisible.toggle()
                } icon: {
                    NexusPlatformIcon(isVisible ? .revealedPassword : .concealedPassword)
                        .frame(width: NexusIconSize.sm, height: NexusIconSize.sm)
                }
            }
        )
        .textContentType(contentType)
    }
}

private struct AuthMessage: View {
    let text: String?
    let isSuccess: Bool

    init(state: LoginUiState) { text = state.message; isSuccess = state.isSuccess }
    init(state: SignupUiState) { text = state.message; isSuccess = state.isSuccess }

    var body: some View {
        if let text {
            Text(text)
                .nexusTextStyle(isSuccess ? NexusText.styles.body : NexusText.styles.errorText)
                .foregroundStyle(isSuccess ? NexusSemanticColors.successText : NexusSemanticColors.errorText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Android-named auth footer with an accessible, wrapping action.
private struct AuthModeSwitch: View {
    let prompt: String
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: NexusSpacing.space4) { promptText; actionButton }
            }
            VStack(spacing: NexusSpacing.space4) { promptText; actionButton }
        }
        .frame(maxWidth: .infinity)
    }

    private var promptText: some View {
        Text(prompt)
            .nexusTextStyle(NexusText.styles.body)
            .foregroundStyle(NexusSemanticColors.textSecondary)
            .multilineTextAlignment(.center)
    }

    private var actionButton: some View {
        NexusTextButton(title, isEnabled: isEnabled, action: action)
    }

}

#if DEBUG
/// Deterministic visual states for simulator auth-sheet screenshots.
enum AuthCodePreviewState: Equatable {
    case entry, submitting, invalid, expired, rateLimited, success

    init?(launchArgument: String) {
        switch launchArgument {
        case "entry": self = .entry
        case "submitting": self = .submitting
        case "invalid": self = .invalid
        case "expired": self = .expired
        case "rateLimited": self = .rateLimited
        case "success": self = .success
        default: return nil
        }
    }

    var message: String? {
        switch self {
        case .entry, .submitting: nil
        case .invalid: "That code didn’t work. Check the newest code and try again."
        case .expired: "Code expired. Send a new code to continue."
        case .rateLimited: "Too many attempts. Wait before trying again."
        case .success: "Email verified."
        }
    }

    var isError: Bool {
        switch self {
        case .invalid, .expired, .rateLimited: true
        default: false
        }
    }
}

struct AuthCodePreviewScreen: View {
    let state: AuthCodePreviewState
    @State private var code: String
    @State private var isPresented = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(state: AuthCodePreviewState) {
        self.state = state
        _code = State(initialValue: state == .entry ? "" : "123456")
    }

    var body: some View {
        List {
            Text("Profile")
                .nexusTextStyle(NexusText.styles.screenTitle)
                .listRowBackground(Color.clear)
            HStack(spacing: NexusSpacing.space16) {
                NexusIcon(name: .profile, size: NexusIconSize.lg)
                    .frame(width: NexusSpacing.space64, height: NexusSpacing.space64)
                    .background(NexusSemanticColors.surfaceSubtle, in: Circle())
                VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                    Text("Guest").nexusTextStyle(NexusText.styles.sectionTitleSmall)
                    Text("Sign in to access bookings")
                        .nexusTextStyle(NexusText.styles.bodySmall)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                }
                Spacer()
                Text("Sign in").foregroundStyle(NexusSemanticColors.brandPrimary)
            }
            .padding(.vertical, NexusSpacing.space8)
            Section("Preferences") { Label("Settings", systemImage: "gearshape") }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $isPresented) {
            AuthScaffold(title: "Verify your email", subtitle: nil, layout: .code) {
                AuthCodeDestination(email: "afiz@example.com", isEnabled: state != .success && state != .submitting,
                                    onChangeEmail: {})
                AuthCodeField(code: $code, error: state.isError ? state.message : nil, isSuccess: state == .success,
                              isEnabled: state != .success && state != .submitting)
                if let message = state.message {
                    Text(message)
                        .nexusTextStyle(NexusText.styles.errorText)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(state == .success ? NexusSemanticColors.successText : NexusSemanticColors.errorText)
                }
                NexusTextButton("Send new code", action: {})
                    .disabled(state == .success || state == .submitting)
                NexusPrimaryButton("Verify email", isLoading: state == .submitting, loadingTitle: "Verifying…", fillsWidth: true, minHeight: NexusLayout.authControlHeight, action: {})
                    .disabled(state == .success)
                    .padding(.top, NexusSpacing.space8)
                NexusTextButton("Back to sign in", action: {})
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(NexusRadius.xxxl)
        }
    }
}
#endif
