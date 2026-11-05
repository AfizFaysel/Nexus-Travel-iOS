/// Latest booking-request state associated with an offer.
struct BookingRequestSnapshot: Equatable, Hashable, Codable, Sendable {
    let offerId: String
    let reviewId: String?
    let status: BookingRequestStatus
    let bookingReference: String?

    /// Creates snapshot with no booking reference by default.
    init(offerId: String, reviewId: String?, status: BookingRequestStatus, bookingReference: String? = nil) {
        self.offerId = offerId
        self.reviewId = reviewId
        self.status = status
        self.bookingReference = bookingReference
    }

    /// Whether any booking request exists.
    var hasRequest: Bool { status != .none }
}

/// Booking-request lifecycle status.
enum BookingRequestStatus: String, Equatable, Hashable, Codable, Sendable {
    case none
    case draftSaved
    case submittedForManualReview
    case agentReviewing
    case holdPending
    case holdUnconfirmed
    case holdChangeReview
    case holdFailed
    case confirmed
    case expired
    case unavailable

    /// Android-equivalent user-facing status label.
    var label: String {
        switch self {
        case .none: ""
        case .draftSaved: "Request saved"
        case .submittedForManualReview: "Manual review"
        case .agentReviewing: "Agent reviewing"
        case .holdPending: "Booking request in progress"
        case .holdUnconfirmed: "Checking airline confirmation"
        case .holdChangeReview: "Hold needs review"
        case .holdFailed: "Booking not completed"
        case .confirmed: "Confirmed"
        case .expired: "Expired"
        case .unavailable: "Unavailable"
        }
    }
}

struct BookingReviewDetails: Equatable, Sendable {
    let reviewId: String; let bookingReference: String?; let status: BookingRequestStatus
    let passengers: [BookingReviewPassenger]; let contact: BookingReviewContact
    let seats: [SeatAssignment]; let fareTotal: Money
    var updatedAt: String? = nil
    var acceptedQuoteRevision: String? = nil
    var failureReason: String? = nil
    var failureReasonCode: String? = nil
}
struct BookingReviewPassenger: Equatable, Sendable {
    let title, firstName, lastName, passportNumber, nationality: String
}
struct BookingReviewContact: Equatable, Sendable { let email, phone: String }
enum BookingRequestResult: Equatable, Sendable {
    case success(BookingReviewDetails), notFound, networkUnavailable, expired, unavailable, unknownError
}
enum BookingSubmitResult: Equatable, Sendable {
    case success(reviewId: String, bookingReference: String, status: BookingRequestStatus)
    case notFound, networkUnavailable, outcomeUnknown, changedHoldReview, expired
    case priceChanged(String), fareUnavailable(String), unavailable, unknownError
}

enum BookingHoldOutcome: String, Equatable, Sendable {
    case draft = "DRAFT"
    case pending = "PENDING"
    case unknown = "UNKNOWN"
    case notHeld = "NOT_HELD"
    case held = "HELD"
    case changedHoldReview = "CHANGED_HOLD_REVIEW"
    case expired = "EXPIRED"
    case cancelled = "CANCELLED"
    case paymentReview = "PAYMENT_REVIEW"
    case ticketPending = "TICKET_PENDING"
    case ticketed = "TICKETED"
}

enum BookingReconciliationState: String, Decodable, Equatable, Sendable {
    case notNeeded = "NOT_NEEDED"
    case queued = "QUEUED"
    case checking = "CHECKING"
    case staffReview = "STAFF_REVIEW"
    case resolved = "RESOLVED"
}

enum BookingStatusAction: String, Equatable, Sendable {
    case checkStatus = "CHECK_STATUS"
    case viewTrip = "VIEW_TRIP"
    case searchAgain = "SEARCH_AGAIN"
    case reprice = "REPRICE"
    case uploadPaymentProof = "UPLOAD_PAYMENT_PROOF"
    case viewTicket = "VIEW_TICKET"
}

struct BookingStatusSnapshot: Equatable, Sendable {
    let outcome: BookingHoldOutcome
    let bookingReference: String?
    let reconciliationState: BookingReconciliationState
    let lastSupplierCheckedAt: String?
    let allowedNextActions: [BookingStatusAction]

    init(outcome: BookingHoldOutcome, bookingReference: String?,
         reconciliationState: BookingReconciliationState = .notNeeded,
         lastSupplierCheckedAt: String? = nil,
         allowedNextActions: [BookingStatusAction] = []) {
        self.outcome = outcome
        self.bookingReference = bookingReference
        self.reconciliationState = reconciliationState
        self.lastSupplierCheckedAt = lastSupplierCheckedAt
        self.allowedNextActions = allowedNextActions
    }
}

enum BookingStatusResult: Equatable, Sendable {
    case success(BookingStatusSnapshot)
    case networkUnavailable, notFound, unknownError
}

struct BookingPriceQuote: Equatable, Sendable {
    let previousAmountMinor: Int
    let newAmountMinor: Int
    let currency: String
    let quoteRevision: String
    let updatedAt: String
    let requiresNewFlight: Bool
    let itineraryChanged: Bool?
    let seatSelectionWillBeCleared: Bool

    var previousTotal: String { String(format: "%@ %.2f", currency, Double(previousAmountMinor) / 100) }
    var newTotal: String { String(format: "%@ %.2f", currency, Double(newAmountMinor) / 100) }
}

enum BookingRepriceResult: Equatable, Sendable {
    case success(BookingPriceQuote)
    case expired, unavailable, networkUnavailable, unknownError
}

protocol BookingRequestRepository: Sendable {
    func getReview(reviewId: String) async throws -> BookingRequestResult
    func getStatus(reviewId: String) async throws -> BookingStatusResult
    func requestStatusCheck(reviewId: String) async throws -> BookingStatusResult
    func reprice(reviewId: String, expectedUpdatedAt: String) async throws -> BookingRepriceResult
    func acceptQuote(reviewId: String, expectedUpdatedAt: String, quoteRevision: String) async throws -> BookingRequestResult
    func submitReview(reviewId: String, idempotencyKey: String) async throws -> BookingSubmitResult
}
