import SwiftUI
import UniformTypeIdentifiers

struct PaymentProofScreenRoute: View {
    @State private var viewModel: PaymentProofViewModel
    @State private var uploadTask: Task<Void, Never>?
    let router: Router; let bookingId: String
    init(viewModel: PaymentProofViewModel, router: Router, bookingId: String) {
        _viewModel = State(initialValue: viewModel); self.router = router; self.bookingId = bookingId
    }
    var body: some View {
        PaymentProofScreen(viewModel: viewModel, onBack: { router.pop() }, onUpload: upload,
                           onViewTrip: { router.push(.tripDetail(.init(tripId: bookingId))) })
            .task { try? await viewModel.verifyStatus() }
            .onDisappear { uploadTask?.cancel() }
    }
    private func upload() {
        guard uploadTask == nil else { return }
        uploadTask = Task {
            do { try await viewModel.upload() } catch is CancellationError { uploadTask = nil; return } catch { uploadTask = nil; return }
            uploadTask = nil
        }
    }
}

struct PaymentProofScreen: View {
    @Bindable var viewModel: PaymentProofViewModel
    let onBack, onUpload, onViewTrip: () -> Void
    @State private var importsDocument = false
    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space16) {
            Text("Upload payment receipt").font(.title.bold())
            Text("Only pay after the airline hold is confirmed. Then upload your receipt for verification.")
                .foregroundStyle(.secondary)
            if viewModel.state.checkingStatus { ProgressView("Checking booking status…") }
            VStack(alignment: .leading, spacing: NexusSpacing.space12) {
                Text("Receipt file").font(.headline)
                Text(viewModel.state.selected?.displayName ?? "PDF, JPG, or PNG up to 10 MB").foregroundStyle(.secondary)
                NexusSecondaryButton("Choose file", isEnabled: viewModel.state.canUploadProof, fillsWidth: true) { importsDocument = true }
            }.padding(NexusSpacing.space16).background(.background, in: .rect(cornerRadius: NexusRadius.lg))
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
                        (!viewModel.state.canUploadProof ? { Task { try? await viewModel.verifyStatus() } } : nil)
                )
            }
            Spacer()
            if viewModel.state.uploaded {
                NexusPrimaryButton("View trip", fillsWidth: true, action: onViewTrip)
            } else {
                NexusPrimaryButton("Upload receipt", isEnabled: viewModel.state.selected != nil && viewModel.state.canUploadProof,
                                   isLoading: viewModel.state.uploading, loadingTitle: "Uploading…", fillsWidth: true, action: onUpload)
            }
        }
        .padding(NexusSpacing.space20).navigationTitle("Payment receipt").navigationBarBackButtonHidden()
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Back", systemImage: NexusIconName.back.systemName, action: onBack) } }
        .fileImporter(isPresented: $importsDocument, allowedContentTypes: [.pdf, .jpeg, .png]) { result in
            guard case let .success(url) = result else { return }
            viewModel.select(.init(uriString: url.absoluteString, displayName: url.lastPathComponent,
                                   mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType))
        }
    }
}
