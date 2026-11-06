import SwiftUI

struct PassengerResumeScreen: View {
    let bookingId: String
    let bookingRepository: any BookingRequestRepository
    let repository: any PassengerDetailsRepository
    let router: Router
    let bookingFlowState: BookingFlowState
    let today: () -> LocalDate
    let onSearchAgain: () -> Void
    @State private var draft: PassengerResumeDraft?
    @State private var unavailable = false

    var body: some View {
        Group {
            if let draft {
                PassengerDetailsScreenRoute(
                    viewModel: PassengerDetailsViewModel(
                        details: draft.flightDetails, repository: repository, bookingId: bookingId,
                        resume: draft, today: today
                    ),
                    router: router, bookingFlowState: bookingFlowState
                )
            } else if unavailable {
                NexusFeedbackPanel(
                    title: "Booking details unavailable", message: "Start a new search to continue.",
                    primaryActionLabel: "Search flights", onPrimaryAction: onSearchAgain
                )
                .padding(NexusLayout.screenMargin)
            } else {
                ProgressView().tint(NexusSemanticColors.brandPrimary)
            }
        }
        .task(id: bookingId) {
            guard draft == nil else { return }
            do {
                let saved = try await bookingRepository.getPassengerResume(bookingId: bookingId)
                try Task.checkCancellation()
                if let saved {
                    bookingFlowState.selectOffer(saved.flightDetails.reference)
                    _ = bookingFlowState.acceptPassengerDetails(saved.flightDetails)
                    draft = saved
                } else {
                    unavailable = true
                }
            } catch {
                if !Task.isCancelled { unavailable = true }
            }
        }
    }
}
