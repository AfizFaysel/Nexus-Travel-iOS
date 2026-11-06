import Testing
@testable import NexusTravel

@MainActor
struct PaymentProofViewModelTests {
    @Test func paymentInstructionsPreserveTheSelectedAccountOnRefresh() async throws {
        let instructions = PaymentInstructions(canSubmitProof: true, amountMinor: 12345, currency: "ETB",
            paymentReason: "ABC123", deadline: nil, accounts: [
                .init(id: "first", bankName: "Test Bank", identifier: "0001", legalName: "Test Account"),
                .init(id: "second", bankName: "Other Bank", identifier: "0002", legalName: "Test Account")
            ])
        let repository = PaymentProofFakeRepository(result: .success, instructions: instructions)
        let model = PaymentProofViewModel(bookingId: "b-1", repository: repository, statusCheck: heldBookingStatus)

        try await model.verifyStatus()
        #expect(model.state.selectedAccount?.id == "first")
        model.selectAccount("second")
        try await model.verifyStatus()
        #expect(model.state.selectedAccount?.id == "second")
        #expect(model.state.canUploadProof)
    }

    @Test func validatesLinksBeforeSubmittingAndTrimsInput() async throws {
        let repository = PaymentProofFakeRepository(result: .success)
        let model = PaymentProofViewModel(bookingId: "b-1", repository: repository, statusCheck: heldBookingStatus)
        try await model.verifyStatus()
        model.selectMethod(.link)
        model.updateLink("http://receipts.example.test/123")
        try await model.submit()
        #expect(model.state.linkError != nil)
        #expect(await repository.submittedLinks.isEmpty)

        model.updateLink(" https://receipts.example.test/123 ")
        try await model.submit()
        #expect(await repository.submittedLinks == ["https://receipts.example.test/123"])
        #expect(model.state.uploaded)
    }

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
    let currentInstructions: PaymentInstructions
    private(set) var uploadCount = 0

    init(result: PaymentProofUploadResult, instructions: PaymentInstructions = .init(
        canSubmitProof: true, amountMinor: 100, currency: "ETB", paymentReason: nil, deadline: nil, accounts: []
    )) {
        self.result = result
        currentInstructions = instructions
    }

    func instructions(bookingId: String) async throws -> PaymentInstructionsResult {
        .available(currentInstructions)
    }
    func submitLink(bookingId: String, url: String) async throws -> PaymentProofUploadResult {
        submittedLinks.append(url)
        return result
    }

    private(set) var submittedLinks: [String] = []

    func upload(bookingId: String, document: PaymentProofAttachment) async throws -> PaymentProofUploadResult {
        uploadCount += 1
        return result
    }
}
