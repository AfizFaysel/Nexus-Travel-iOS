import Foundation
import SwiftUI

@main
@MainActor
struct NexusApp: App {
    private let launchDestination: AppLaunchDestination
    #if DEBUG
    private let authCodePreviewState: AuthCodePreviewState?
    #endif
    private let dependencies: AppDependencies?
    @State private var router: Router
    @State private var bookingFlowState: BookingFlowState

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        authCodePreviewState = arguments.first(where: { $0.hasPrefix("--auth-preview=") })
            .flatMap { AuthCodePreviewState(launchArgument: String($0.dropFirst("--auth-preview=".count))) }
        #endif
        launchDestination = AppLaunchDestination(arguments: arguments)
        #if DEBUG
        let isPreview = authCodePreviewState != nil
        #else
        let isPreview = false
        #endif
        dependencies = launchDestination.gallerySection == nil && !isPreview
            ? AppDependencies(sessionStore: arguments.contains("--reset-auth-session")
                ? VolatileAuthSessionStore()
                : KeychainAuthSessionStore())
            : nil
        _router = State(initialValue: Router())
        _bookingFlowState = State(initialValue: BookingFlowState())
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let authCodePreviewState {
                AuthCodePreviewScreen(state: authCodePreviewState)
            } else if let gallerySection = launchDestination.gallerySection {
                DesignSystemGalleryScreen(initialSection: gallerySection)
            } else if let dependencies {
                appShell(dependencies: dependencies)
            }
            #else
            if let gallerySection = launchDestination.gallerySection {
                DesignSystemGalleryScreen(initialSection: gallerySection)
            } else if let dependencies {
                appShell(dependencies: dependencies)
            }
            #endif
        }
    }

    private func appShell(dependencies: AppDependencies) -> some View {
        AppShell(router: router, homeViewModel: dependencies.homeViewModel,
                         exploreViewModel: dependencies.exploreViewModel,
                         tripsViewModel: dependencies.tripsViewModel,
                         flightSearchRepository: dependencies.flightSearchRepository,
                         searchResultsRepository: dependencies.searchResultsRepository,
                         flightDetailsRepository: dependencies.flightDetailsRepository,
                         passengerDetailsRepository: dependencies.passengerDetailsRepository,
                         flightSeatsRepository: dependencies.flightSeatsRepository,
                         bookingRequestRepository: dependencies.bookingRequestRepository,
                         paymentProofRepository: dependencies.paymentProofRepository,
                         tripsRepository: dependencies.tripsRepository,
                         exploreRepository: dependencies.exploreRepository,
                         profileRepository: dependencies.profileRepository,
                         securityRepository: dependencies.securityRepository,
                         airportRepository: dependencies.airportRepository,
                         profileViewModel: dependencies.profileViewModel,
                         preferencesViewModel: dependencies.preferencesViewModel,
                         authRepository: dependencies.authRepository,
                         bookingFlowState: bookingFlowState)
            .preferredColorScheme(dependencies.appTheme.preference == .system ? nil : dependencies.appTheme.preference == .dark ? .dark : .light)
    }
}
