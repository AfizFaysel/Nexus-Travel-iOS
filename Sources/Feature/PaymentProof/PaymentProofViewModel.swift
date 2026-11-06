import Observation

struct PaymentProofUiState: Equatable, Sendable {
    var selected: PaymentProofAttachment?; var uploading = false; var uploaded = false; var message: String?
    var canRetry = false
    var checkingStatus = false; var canUploadProof = false
    var instructions: PaymentInstructions?
    var selectedAccountId: String?

    var selectedAccount: ReceivingPaymentAccount? {
        instructions?.accounts.first { $0.id == selectedAccountId }
    }
}
@MainActor @Observable
final class PaymentProofViewModel {
    private(set) var state = PaymentProofUiState()
    private let bookingId: String; private let repository: any PaymentProofRepository
    private let statusCheck: @Sendable (String) async throws -> BookingStatusResult
    init(bookingId: String, repository: any PaymentProofRepository,
         statusCheck: @escaping @Sendable (String) async throws -> BookingStatusResult) {
        self.bookingId = bookingId; self.repository = repository; self.statusCheck = statusCheck
    }
    func verifyStatus() async throws {
        guard !state.checkingStatus else { return }
        state.checkingStatus = true; state.canUploadProof = false
        state.instructions = nil
        state.message = nil
        defer { state.checkingStatus = false }
        do {
            let result = try await statusCheck(bookingId)
            try Task.checkCancellation()
            switch result {
            case let .success(snapshot):
                guard snapshot.outcome == .held, snapshot.bookingReference != nil else {
                    state.message = "Do not pay or upload a receipt yet. Check your trip for the current booking status."
                    return
                }
                let instructionsResult = try await repository.instructions(bookingId: bookingId)
                try Task.checkCancellation()
                applyInstructions(instructionsResult)
            case .networkUnavailable:
                state.message = "Offline. Booking status may have changed. Check again before paying."
            case .notFound, .unknownError:
                state.message = "Could not confirm the airline hold. Check status before paying."
            }
        } catch is CancellationError { throw CancellationError() }
        catch { state.message = "Could not confirm the airline hold. Check status before paying." }
    }
    private func applyInstructions(_ result: PaymentInstructionsResult) {
        switch result {
        case let .available(instructions):
            guard instructions.canSubmitProof else {
                state.message = "Payment is not available for this booking. Return to Trips for the latest status."
                return
            }
            state.instructions = instructions
            state.canUploadProof = true
            if state.selectedAccount == nil { state.selectedAccountId = instructions.accounts.first?.id }
        case .offline:
            state.message = "Connect to the internet to confirm payment details before transferring money."
        case .authRequired:
            state.message = "Sign in again to view payment details."
        case .unavailable:
            state.message = "This booking is unavailable. Return to Trips."
        case .failed:
            state.message = "We couldn't load current payment details. Try again before transferring money."
        }
    }

    func selectAccount(_ id: String) {
        guard state.instructions?.accounts.contains(where: { $0.id == id }) == true else { return }
        state.selectedAccountId = id
    }

    func select(_ attachment: PaymentProofAttachment) {
        state.selected = attachment; state.uploaded = false; state.canRetry = false
        if state.canUploadProof { state.message = nil }
    }
    func upload() async throws {
        guard !state.uploading, state.canUploadProof, let document = state.selected else { return }
        state.uploading = true; state.message = nil; state.canRetry = false
        do {
            try await verifyStatus()
            try Task.checkCancellation()
            guard state.canUploadProof else { state.uploading = false; return }
            let result = try await repository.upload(bookingId: bookingId, document: document)
            state.uploading = false
            switch result {
            case .success: state.uploaded = true; state.message = "Receipt uploaded."
            case .invalidDocument: state.message = "Use PDF, JPG, or PNG up to 10 MB."
            case .authRequired: state.message = "Sign in again to upload payment receipt."
            case .networkUnavailable: state.message = "Connection lost. Retry upload."; state.canRetry = true
            case .failed: state.message = "Could not upload receipt. Retry."; state.canRetry = true
            }
        } catch is CancellationError { state.uploading = false; throw CancellationError() }
        catch {
            state.uploading = false
            state.message = "Could not confirm the airline hold. Check status before uploading."
        }
    }
}
