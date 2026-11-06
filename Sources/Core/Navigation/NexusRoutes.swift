enum ExploreFilter: Hashable, Sendable {
    case all
    case packages
    case destinations

    var showsPackages: Bool { self != .destinations }
    var showsDestinations: Bool { self != .packages }
}

struct HomeRootRoute: Hashable, Sendable {}

struct ExploreRoute: Hashable, Sendable {
    let filter: ExploreFilter

    init(filter: ExploreFilter = .all) {
        self.filter = filter
    }
}

struct DestinationDetailRoute: Hashable, Sendable { let destinationId: String }
struct PackageDetailRoute: Hashable, Sendable { let packageId: String }
struct TripsRoute: Hashable, Sendable {}
struct TripDetailRoute: Hashable, Sendable { let tripId: String }
struct ProfileRoute: Hashable, Sendable {}
struct EditProfileRoute: Hashable, Sendable {}
struct SavedTravelersRoute: Hashable, Sendable {}
struct SettingsRoute: Hashable, Sendable {}
struct LanguageRoute: Hashable, Sendable {}
struct CurrencyRoute: Hashable, Sendable {}
struct ThemeRoute: Hashable, Sendable {}
struct HomeAirportRoute: Hashable, Sendable {}
struct NotificationSettingsRoute: Hashable, Sendable {}
struct SecurityRoute: Hashable, Sendable {}
struct DeleteAccountRoute: Hashable, Sendable {}
struct MainAuthRoute: Hashable, Sendable {}
struct SearchResultsRoute: Hashable, Sendable { let searchId: String }
struct FlightDetailsRoute: Hashable, Sendable { let reference: FlightOfferReference }
struct PassengerDetailsRoute: Hashable, Sendable { var bookingId: String? }
struct BookingAuthRoute: Hashable, Sendable {}
struct SeatSelectionRoute: Hashable, Sendable { let bookingId: String }
struct BookingReviewRoute: Hashable, Sendable { let reviewId: String }
struct PaymentProofRoute: Hashable, Sendable { let bookingId: String }

enum AppRoute: Hashable, Sendable {
    case home(HomeRootRoute)
    case explore(ExploreRoute)
    case destinationDetail(DestinationDetailRoute)
    case packageDetail(PackageDetailRoute)
    case trips(TripsRoute)
    case tripDetail(TripDetailRoute)
    case profile(ProfileRoute)
    case editProfile(EditProfileRoute)
    case savedTravelers(SavedTravelersRoute)
    case settings(SettingsRoute)
    case language(LanguageRoute)
    case currency(CurrencyRoute)
    case theme(ThemeRoute)
    case homeAirport(HomeAirportRoute)
    case notificationSettings(NotificationSettingsRoute)
    case security(SecurityRoute)
    case deleteAccount(DeleteAccountRoute)
    case mainAuth(MainAuthRoute)
    case searchResults(SearchResultsRoute)
    case flightDetails(FlightDetailsRoute)
    case passengerDetails(PassengerDetailsRoute)
    case bookingAuth(BookingAuthRoute)
    case seatSelection(SeatSelectionRoute)
    case bookingReview(BookingReviewRoute)
    case paymentProof(PaymentProofRoute)
}
