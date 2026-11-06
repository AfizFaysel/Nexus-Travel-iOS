struct PaymentProofAttachment: Equatable, Sendable {
    let uriString, displayName: String; let mimeType: String?
}
enum PaymentProofUploadResult: Equatable, Sendable {
    case success, invalidDocument, authRequired, networkUnavailable, failed
}
struct ReceivingPaymentAccount: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let bankName: String
    let identifier: String
    let legalName: String
}

struct PaymentInstructions: Decodable, Equatable, Sendable {
    let canSubmitProof: Bool
    let amountMinor: Int
    let currency: String
    let paymentReason: String?
    let deadline: String?
    let accounts: [ReceivingPaymentAccount]
}

enum PaymentInstructionsResult: Equatable, Sendable {
    case available(PaymentInstructions)
    case offline, authRequired, unavailable, failed
}

protocol PaymentProofRepository: Sendable {
    func instructions(bookingId: String) async throws -> PaymentInstructionsResult
    func upload(bookingId: String, document: PaymentProofAttachment) async throws -> PaymentProofUploadResult
}
