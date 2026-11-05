import Foundation
import Observation

enum AuthPresentation: String, Identifiable, Equatable, Sendable {
    case booking
    case profile
    case trips
    case sessionExpired

    var id: String { rawValue }
}

enum MainTab: CaseIterable, Hashable, Sendable {
    case home
    case explore
    case trips
    case profile

    var label: String {
        switch self {
        case .home: "Home"
        case .explore: "Explore"
        case .trips: "Trips"
        case .profile: "Profile"
        }
    }

    var icon: NexusIconName {
        switch self {
        case .home: .home
        case .explore: .map
        case .trips: .trips
        case .profile: .profile
        }
    }
}

@MainActor
@Observable
final class Router {
    private(set) var selectedTab: MainTab = .home
    var exploreFilter: ExploreFilter = .all
    var homePath: [AppRoute] = []
    var explorePath: [AppRoute] = []
    var tripsPath: [AppRoute] = []
    var profilePath: [AppRoute] = []
    private(set) var pendingTab: MainTab?
    private(set) var authPresentation: AuthPresentation?
    private(set) var authLinkPresentation: AuthLinkRoute?
    private(set) var unavailableOffer: FlightOfferReference?

    var showsMainBottomBar: Bool {
        selectedPath.isEmpty
    }

    func select(_ tab: MainTab) {
        if tab == selectedTab {
            popToRoot()
        } else {
            selectedTab = tab
        }
    }

    func showExplore(filter: ExploreFilter) {
        exploreFilter = filter
        selectedTab = .explore
    }

    func push(_ route: AppRoute) {
        selectedPath.append(route)
    }

    func pop() {
        guard !selectedPath.isEmpty else { return }
        selectedPath.removeLast()
    }

    func markOfferUnavailable(_ reference: FlightOfferReference) {
        unavailableOffer = reference
    }

    func popToRoot() {
        selectedPath.removeAll()
    }

    func beginMainAuth(returningTo tab: MainTab) {
        pendingTab = tab
        push(.mainAuth(MainAuthRoute()))
    }

    func completeMainAuth() {
        if selectedPath.last == .mainAuth(MainAuthRoute()) {
            pop()
        }
        selectedTab = pendingTab ?? .home
        pendingTab = nil
    }

    func completeBookingAuth() {
        if selectedPath.last == .bookingAuth(BookingAuthRoute()) {
            pop()
        }
    }

    func presentAuthentication(for purpose: AuthPresentation) {
        authPresentation = purpose
    }

    func dismissAuthentication() {
        authPresentation = nil
    }

    func handleAuthLink(_ url: URL) {
        guard let route = AuthLinkRoute(url: url) else { return }
        guard authLinkPresentation != route else { return }
        authPresentation = nil
        authLinkPresentation = route
    }

    func dismissAuthLink(_ route: AuthLinkRoute) {
        guard authLinkPresentation == route else { return }
        authLinkPresentation = nil
    }

    private var selectedPath: [AppRoute] {
        get {
            switch selectedTab {
            case .home: homePath
            case .explore: explorePath
            case .trips: tripsPath
            case .profile: profilePath
            }
        }
        set {
            switch selectedTab {
            case .home: homePath = newValue
            case .explore: explorePath = newValue
            case .trips: tripsPath = newValue
            case .profile: profilePath = newValue
            }
        }
    }
}
