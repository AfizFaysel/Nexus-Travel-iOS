import Testing
@testable import NexusTravel

@MainActor
struct PaymentProofViewModelTests {
    @Test func successPublishesUploadedCopy() async throws {
        let repository = PaymentProofFakeRepository(result: .success)
        let viewModel = PaymentProofViewModel(bookingId: "b-1", repository: repository, statusCheck: heldBookingStatus)
        try await viewModel.verifyStatus()
        viewModel.select(.init(uriString: "file:///proof.pdf", displayName: "proof.pdf", mimeType: "application/pdf"))
        try await viewModel.upload()
        #expect(viewModel.state.uploaded)
        #expect(viewModel.state.message == "Receipt uploaded.")
    }

    @Test(arguments: [PaymentProofUploadResult.networkUnavailable, .failed])
    func transientFailureOffersRetry(_ result: PaymentProofUploadResult) async throws {
        let viewModel = PaymentProofViewModel(bookingId: "b-1", repository: PaymentProofFakeRepository(result: result), statusCheck: heldBookingStatus)
        try await viewModel.verifyStatus()
        viewModel.select(.init(uriString: "file:///proof.pdf", displayName: "proof.pdf", mimeType: "application/pdf"))
        try await viewModel.upload()
        #expect(viewModel.state.canRetry)
    }

    @Test(arguments: [PaymentProofUploadResult.invalidDocument, .authRequired])
    func nonTransientFailureDoesNotOfferRetry(_ result: PaymentProofUploadResult) async throws {
        let viewModel = PaymentProofViewModel(bookingId: "b-1", repository: PaymentProofFakeRepository(result: result), statusCheck: heldBookingStatus)
        try await viewModel.verifyStatus()
        viewModel.select(.init(uriString: "file:///proof.pdf", displayName: "proof.pdf", mimeType: "application/pdf"))
        try await viewModel.upload()
        #expect(!viewModel.state.canRetry)
    }
    @Test func unknownHoldBlocksProofEvenWithSelectedFile() async throws {
        let repository = PaymentProofFakeRepository(result: .success)
        let viewModel = PaymentProofViewModel(bookingId: "b-1", repository: repository, statusCheck: { _ in
            .success(.init(outcome: .unknown, bookingReference: nil))
        })
        try await viewModel.verifyStatus()
        viewModel.select(.init(uriString: "file:///proof.pdf", displayName: "proof.pdf", mimeType: "application/pdf"))
        try await viewModel.upload()
        #expect(!viewModel.state.canUploadProof)
        #expect(!viewModel.state.uploaded)
        #expect(await repository.uploadCount == 0)
    }

}
private func heldBookingStatus(_ bookingId: String) async throws -> BookingStatusResult {
    .success(.init(outcome: .held, bookingReference: "ABC123"))
}
private actor PaymentProofFakeRepository: PaymentProofRepository {
    let result: PaymentProofUploadResult
    private(set) var uploadCount = 0
    init(result: PaymentProofUploadResult) { self.result = result }
    func upload(bookingId: String, document: PaymentProofAttachment) async throws -> PaymentProofUploadResult {
        uploadCount += 1
        return result
    }
}
