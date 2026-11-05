import Testing
@testable import NexusTravel

struct HomeModelsTests {
    @Test func airportDisplayNameUsesCityAndCode() {
        let airport = Airport(code: "ADD", city: "Addis Ababa", name: "Bole", country: "Ethiopia")
        #expect(airport.displayName == "Addis Ababa (ADD)")
    }

    @Test func cabinClassLabelsMatchAndroidCopy() {
        #expect(CabinClass.economy.label == "Economy")
        #expect(CabinClass.premiumEconomy.label == "Premium Economy")
        #expect(CabinClass.business.label == "Business")
        #expect(CabinClass.first.label == "First")
    }

    @Test func homeStateDefaultsMatchAndroid() {
        let state = HomeUiState()
        #expect(state.isLoading)
        #expect(state.userName == "Traveler")
        #expect(state.tripType == .oneWay)
        #expect(state.origin == nil)
        #expect(state.destination == nil)
        #expect(state.departureDate == nil)
        #expect(state.returnDate == nil)
        #expect(state.travelers == TravelerCounts())
        #expect(state.childAges.isEmpty)
        #expect(state.infantAges.isEmpty)
        #expect(state.cabinClass == .economy)
        #expect(state.multiCityLegs.isEmpty)
        #expect(state.trendingEscapes.isEmpty)
        #expect(state.airports.isEmpty)
        #expect(state.airportQuery.isEmpty)
        #expect(state.validationError == nil)
        #expect(!state.isSearching)
        #expect(state.message == nil)
    }
}
