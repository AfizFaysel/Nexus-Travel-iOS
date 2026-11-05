import Testing
@testable import NexusTravel

struct HomeScreenStateTests {
    @Test func contentWidthExpandsOnWideDisplays() {
        #expect(HomeLayoutMetrics(screenWidth: 390).contentMaxWidth == NexusLayout.contentMaxWidth)
        #expect(HomeLayoutMetrics(screenWidth: 820).contentMaxWidth == NexusLayout.homeContentMaxWidthWide)
    }

    @Test func heroMetricsMatchAndroidWithSafeIOSHeaderAdjustment() throws {
        let compact = try #require(HomeHeroMetrics(spacing: NexusAdaptiveSpacing(screenWidth: 360, screenHeight: 720)))
        let regular = try #require(HomeHeroMetrics(spacing: NexusAdaptiveSpacing(screenWidth: 390, screenHeight: 844)))
        let spacious = try #require(HomeHeroMetrics(spacing: NexusAdaptiveSpacing(screenWidth: 430, screenHeight: 840)))

        #expect(compact.heroHeight == 220)
        #expect(regular.heroHeight == 248)
        #expect(spacious.heroHeight == 272)
        #expect(compact.headerTopPadding == 12)
        #expect(regular.headerTopPadding == 12)
        #expect(spacious.headerTopPadding == 12)
        #expect(compact.cardPadding == 16)
        #expect(regular.cardPadding == 20)
        #expect(spacious.cardPadding == 24)
    }

    @Test func presentationKindsCoverFourRequiredStates() {
        #expect(HomeScreenState(state: HomeUiState()).kind == .loading)
        #expect(HomeScreenState(state: HomeUiState(isLoading: false)).kind == .empty)
        #expect(HomeScreenState(state: HomeUiState(isLoading: false, message: "Offline")).kind == .error)
        let airport = Airport(code: "ADD", city: "Addis Ababa", name: "Bole", country: "Ethiopia")
        let escape = TrendingEscape(id: "one", airport: airport, tags: [],
                                    startingPrice: Money(amount: 0, currency: "USD", formatted: ""), imageName: "")
        #expect(HomeScreenState(state: HomeUiState(isLoading: false, trendingEscapes: [escape])).kind == .content)
    }

    @Test func transientSearchMessageDoesNotReplaceLoadedDiscovery() {
        let state = HomeUiState(
            isLoading: false,
            message: "We lost the connection. Try again.",
            loadPhase: .content
        )
        #expect(HomeScreenState(state: state).kind == .content)
    }

    @Test func everySheetHasStableIdentity() {
        let sheets: [HomeSheet] = [.originAirport, .destinationAirport, .departureDate, .returnDate,
            .multiCityOrigin(index: 0), .multiCityDestination(index: 0), .multiCityDate(index: 0),
            .travelers, .cabinClass, .hotelComingSoon]
        #expect(Set(sheets.map(\.id)).count == sheets.count)
    }
}
