import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct PaymentProofScreenRoute: View {
    @State private var viewModel: PaymentProofViewModel
    @State private var uploadTask: Task<Void, Never>?
    let router: Router; let bookingId: String
    init(viewModel: PaymentProofViewModel, router: Router, bookingId: String) {
        _viewModel = State(initialValue: viewModel); self.router = router; self.bookingId = bookingId
    }
    var body: some View {
        PaymentProofScreen(viewModel: viewModel, onBack: { router.pop() }, onUpload: upload,
                           onViewTrip: { router.push(.tripDetail(.init(tripId: bookingId))) },
                           onCheckStatus: { start { try await viewModel.verifyStatus() } })
            .task { try? await viewModel.verifyStatus() }
            .onDisappear { uploadTask?.cancel() }
    }
    private func upload() {
        start { try await viewModel.submit() }
    }

    private func start(_ operation: @escaping @MainActor () async throws -> Void) {
        guard uploadTask == nil else { return }
        uploadTask = Task {
            defer { uploadTask = nil }
            try? await operation()
        }
    }
}

struct PaymentProofScreen: View {
    @Bindable var viewModel: PaymentProofViewModel
    let onBack, onUpload, onViewTrip, onCheckStatus: () -> Void
    @State private var importsDocument = false
    @FocusState private var linkIsFocused: Bool

    private var linkIsEditable: Bool { viewModel.state.canUploadProof && !viewModel.state.uploading }

    /// Dismisses the keyboard first so a validation error under the link field is visible.
    private func submit() {
        linkIsFocused = false
        onUpload()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusSpacing.space16) {
                Text("Upload payment receipt").font(.title.bold())
                Text("Only pay after the airline hold is confirmed. Then upload your receipt for verification.")
                    .foregroundStyle(.secondary)
                if viewModel.state.checkingStatus { ProgressView("Checking current payment details…") }
                if let instructions = viewModel.state.instructions, !viewModel.state.uploaded {
                    paymentInstructions(instructions)
                }
                if !viewModel.state.uploaded {
                    receiptInput
                }
                if let message = viewModel.state.message {
                    NexusFeedbackPanel(
                        title: viewModel.state.uploaded ? "Receipt submitted" :
                            (viewModel.state.canUploadProof ? "Receipt needs attention" : "Booking status not confirmed"),
                        message: message,
                        status: viewModel.state.uploaded ? .success :
                            (viewModel.state.canUploadProof ? .error : .warning),
                        primaryActionLabel: viewModel.state.canRetry ? "Try again" :
                            (!viewModel.state.canUploadProof ? "Check status" : nil),
                        onPrimaryAction: viewModel.state.canRetry ? onUpload :
                            (!viewModel.state.canUploadProof ? onCheckStatus : nil)
                    )
                }
            }
            .padding(NexusSpacing.space20)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Group {
                if viewModel.state.uploaded {
                    NexusPrimaryButton("View trip", fillsWidth: true, action: onViewTrip)
                } else {
                    NexusPrimaryButton(viewModel.state.receiptMethod == .file ? "Upload receipt" : "Submit receipt link",
                                       isEnabled: viewModel.state.canSubmit,
                                       isLoading: viewModel.state.uploading,
                                       loadingTitle: viewModel.state.receiptMethod == .file ? "Uploading…" : "Submitting…",
                                       fillsWidth: true, action: submit)
                }
            }
            .padding(NexusSpacing.space20)
            .background(NexusSemanticColors.surfaceBase)
        }
        .navigationTitle("Payment").navigationBarBackButtonHidden()
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Back", systemImage: NexusIconName.back.systemName, action: onBack) } }
        .fileImporter(isPresented: $importsDocument, allowedContentTypes: [.pdf, .jpeg, .png]) { result in
            guard case let .success(url) = result else { return }
            viewModel.select(.init(uriString: url.absoluteString, displayName: url.lastPathComponent,
                                   mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType))
        }
    }

    private var receiptInput: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space12) {
            Picker("Receipt method", selection: Binding(
                get: { viewModel.state.receiptMethod }, set: { viewModel.selectMethod($0) }
            )) {
                Text("Image or PDF").tag(ReceiptMethod.file)
                Text("Receipt link").tag(ReceiptMethod.link)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.state.uploading)

            switch viewModel.state.receiptMethod {
            case .file:
                Text("Receipt file").font(.headline)
                Text(viewModel.state.selected?.displayName ?? "PDF, JPG, or PNG up to 10 MB")
                    .foregroundStyle(.secondary)
                NexusSecondaryButton("Choose file", isEnabled: viewModel.state.canUploadProof && !viewModel.state.uploading,
                                     fillsWidth: true) { importsDocument = true }
            case .link:
                NexusTextField(
                    text: Binding(get: { viewModel.state.link }, set: { viewModel.updateLink($0) }),
                    label: "Payment receipt link",
                    placeholder: "Paste your bank receipt link",
                    error: viewModel.state.linkError,
                    isEnabled: linkIsEditable
                )
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($linkIsFocused)

                // Native PasteButton reads the clipboard without the "Allow Paste" prompt
                // that a custom button (Android's "Paste from clipboard") would trigger on iOS.
                PasteButton(payloadType: String.self) { @Sendable [viewModel] strings in
                    guard let text = strings.first else { return }
                    Task { @MainActor in viewModel.updateLink(text) }
                }
                .tint(NexusSemanticColors.actionPrimary)
                .disabled(!linkIsEditable)
            }
        }
        .padding(NexusSpacing.space16)
        .background(.background, in: .rect(cornerRadius: NexusRadius.lg))
    }

    private func paymentInstructions(_ instructions: PaymentInstructions) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space12) {
            copyable("Amount to transfer", (Decimal(instructions.amountMinor) / 100)
                .formatted(.currency(code: instructions.currency)))
            if let reason = instructions.paymentReason {
                copyable("Payment reason", reason)
            }
            if let deadline = instructions.deadline,
               let date = (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(deadline))
                   ?? (try? Date.ISO8601FormatStyle().parse(deadline)) {
                Text("Pay by \(date.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
            Text("Bank fees are separate.")
                .foregroundStyle(NexusSemanticColors.textSecondary)

            if let account = viewModel.state.selectedAccount {
                Divider()
                if instructions.accounts.count > 1 {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: NexusSpacing.space12) {
                            accountNames(account).fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 0)
                            bankMenu(instructions.accounts, selected: account)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                            accountNames(account)
                            bankMenu(instructions.accounts, selected: account)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                } else {
                    accountNames(account)
                }
                copyable("Account number", account.identifier)
            } else {
                Text("No receiving accounts are available. Check again before transferring money.")
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NexusSpacing.space16)
        .background(NexusSemanticColors.surfaceMuted, in: .rect(cornerRadius: NexusRadius.lg))
    }

    private func accountNames(_ account: ReceivingPaymentAccount) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space4) {
            Text(account.legalName).nexusTextStyle(NexusText.styles.sectionTitleSmall)
            Text(account.bankName).foregroundStyle(NexusSemanticColors.textSecondary)
        }
    }

    private func bankMenu(_ accounts: [ReceivingPaymentAccount], selected account: ReceivingPaymentAccount) -> some View {
        Menu {
            ForEach(accounts) { option in
                Button {
                    viewModel.selectAccount(option.id)
                } label: {
                    if option.id == account.id {
                        Label(option.bankName, systemImage: "checkmark")
                    } else {
                        Text(option.bankName)
                    }
                }
            }
        } label: {
            Text("Choose other bank")
                .nexusTextStyle(NexusText.styles.label)
                .foregroundStyle(NexusSemanticColors.link)
                .frame(minHeight: NexusLayout.touchMin)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .accessibilityValue(account.bankName)
        .accessibilityIdentifier("payment-choose-bank")
    }

    private func copyable(_ label: String, _ value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                Text(label).foregroundStyle(NexusSemanticColors.textSecondary)
                Text(value).nexusTextStyle(NexusText.styles.listTitle)
            }
            Spacer()
            Button("Copy \(label.lowercased())", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = value
            }
            .labelStyle(.iconOnly)
            .frame(minWidth: NexusLayout.touchMin, minHeight: NexusLayout.touchMin)
        }
    }
}
