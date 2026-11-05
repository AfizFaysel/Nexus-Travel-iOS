import CoreGraphics
import Testing
@testable import NexusTravel

struct SearchResultsDisplayModelsTests {
    @Test func rowMetricsMatchAndroidAcrossPhoneWidths() throws {
        let compactSpacing = try #require(NexusAdaptiveSpacing(screenWidth: 360, screenHeight: 800))
        let regularSpacing = try #require(NexusAdaptiveSpacing(screenWidth: 390, screenHeight: 844))
        let spaciousSpacing = try #require(NexusAdaptiveSpacing(screenWidth: 430, screenHeight: 932))

        #expect(SearchResultRowMetrics(maxWidth: 360, spacing: compactSpacing).values == [16, 0, 14, 40, 40, 26, 72])
        #expect(SearchResultRowMetrics(maxWidth: 390, spacing: regularSpacing).values == [20, 0, 16, 44, 40, 30, 76])
        #expect(SearchResultRowMetrics(maxWidth: 430, spacing: spaciousSpacing).values == [24, 4, 18, 48, 40, 30, 78])
        #expect(SearchResultRowMetrics(maxWidth: 360, spacing: compactSpacing).usesCompactLabels)
        #expect(!SearchResultRowMetrics(maxWidth: 390, spacing: regularSpacing).usesCompactLabels)
        #expect(SearchResultRowMetrics(maxWidth: 360, spacing: compactSpacing).summaryCardMinHeight == 64)
        #expect(SearchResultRowMetrics(maxWidth: 390, spacing: regularSpacing).summaryCardMinHeight == 70)
    }

    @Test func mapsAllDisplayStringsAndLegs() throws {
        let offer = try makeOffer(price: -123, departure: "05:07", duration: 125, stops: [], reportedStops: 0, oldPrice: Money(amount: 150, currency: "USD", formatted: "USD 150"), seats: 3, badge: .lowestFare, inbound: true)
        let display = offer.toSearchResultUiOffer(tripType: .roundTrip)
        #expect(display.priceLabel == "-123")
        #expect(display.oldPriceLabel == "150")
        #expect(display.priceMetaLabel == "USD · Round trip")
        #expect(display.priceDigitCount == 3)
        #expect(display.seatsLeftLabel == "3 seats left")
        #expect(display.badgeLabel == "Lowest Fare")
        #expect(display.bookingStatusLabel == nil)
        #expect(display.outbound.departureTimeLabel == "05:07")
        #expect(display.outbound.durationLabel == "2h 5m")
        #expect(display.outbound.stopLabel == "Non-stop")
        #expect(display.outbound.compactStopLabel == "Non-stop")
        #expect(display.legs.count == 2)
        #expect(display.fastestSortKey == 245)
        #expect(display.withBookingStatus(label: "Requested").bookingStatusLabel == "Requested")
    }

    @Test func stripsOnlyExactCurrencyPrefixAndBuildsStopLabels() throws {
        var offer = try makeOffer(price: 100, departure: "12:00", duration: 60, stops: [FlightStop(airportCode: "NBO", layoverMinutes: 30)], reportedStops: 2)
        offer = FlightOffer(id: offer.id, reference: offer.reference, airline: offer.airline, flightNumber: offer.flightNumber, outbound: offer.outbound, inbound: nil, price: Money(amount: 100, currency: "USD", formatted: "KES 100"), seatsLeft: nil)
        let display = offer.toSearchResultUiOffer(tripType: .multiCity)
        #expect(display.priceLabel == "KES 100")
        #expect(display.priceMetaLabel == "USD · Multi-city")
        #expect(display.outbound.stopLabel == "2 stop · NBO")
        #expect(display.outbound.compactStopLabel == "2 stop")

        let one = try makeOffer(price: 1, departure: "12:00", duration: 60, stops: [], reportedStops: 1).toSearchResultUiOffer(tripType: .oneWay)
        let many = try makeOffer(price: 1, departure: "12:00", duration: 60, stops: [], reportedStops: 3).toSearchResultUiOffer(tripType: .oneWay)
        #expect(one.outbound.stopLabel == "1 stop")
        #expect(many.outbound.stopLabel == "3 stops")
    }

    @Test func filtersComposeAndMorningIncludesEndpoints() throws {
        let nonStopMorning = try makeOffer(id: "a", price: 300, departure: "05:00", duration: 180, stops: [], reportedStops: 0).toSearchResultUiOffer(tripType: .oneWay)
        let oneStopMorning = try makeOffer(id: "b", price: 100, departure: "11:59", duration: 120, stops: [], reportedStops: 1).toSearchResultUiOffer(tripType: .oneWay)
        let oneStopNoon = try makeOffer(id: "c", price: 200, departure: "12:00", duration: 60, stops: [], reportedStops: 1).toSearchResultUiOffer(tripType: .oneWay)
        let values = [nonStopMorning, oneStopMorning, oneStopNoon]
        #expect(values.applyingSearchResultFiltersAndSort(filters: [.morning], sortOption: .recommended).map(\.id) == ["a", "b"])
        #expect(values.applyingSearchResultFiltersAndSort(filters: [.oneStop, .morning], sortOption: .recommended).map(\.id) == ["b"])
        #expect(values.applyingSearchResultFiltersAndSort(filters: [.nonStop, .bestPrice], sortOption: .recommended).map(\.id) == ["a"])
    }

    @Test func sortsEveryModeStably() throws {
        let first = try makeOffer(id: "first", price: 200, departure: "09:00", duration: 120, stops: [], reportedStops: 0).toSearchResultUiOffer(tripType: .oneWay)
        let second = try makeOffer(id: "second", price: 100, departure: "08:00", duration: 180, stops: [], reportedStops: 0).toSearchResultUiOffer(tripType: .oneWay)
        let tie = try makeOffer(id: "tie", price: 100, departure: "08:00", duration: 180, stops: [], reportedStops: 0).toSearchResultUiOffer(tripType: .oneWay)
        let values = [first, second, tie]
        #expect(values.applyingSearchResultFiltersAndSort(filters: [], sortOption: .recommended).map(\.id) == ["first", "second", "tie"])
        #expect(values.applyingSearchResultFiltersAndSort(filters: [], sortOption: .bestPrice).map(\.id) == ["second", "tie", "first"])
        #expect(values.applyingSearchResultFiltersAndSort(filters: [], sortOption: .fastest).map(\.id) == ["first", "second", "tie"])
        #expect(values.applyingSearchResultFiltersAndSort(filters: [], sortOption: .departureEarly).map(\.id) == ["second", "tie", "first"])
    }

    private func makeOffer(id: String = "offer", price: Int, departure: String, duration: Int, stops: [FlightStop], reportedStops: Int?, oldPrice: Money? = nil, seats: Int? = nil, badge: FlightOfferBadge? = nil, inbound: Bool = false) throws -> FlightOffer {
        let departureTime = try #require(LocalTime(hhmm: departure))
        let arrivalTime = try #require(LocalTime(hhmm: "14:00"))
        let leg = FlightLeg(departureAirportCode: "ADD", arrivalAirportCode: "DXB", departureTime: departureTime, arrivalTime: arrivalTime, durationMinutes: duration, stops: stops, reportedStopCount: reportedStops)
        let inboundLeg = inbound ? FlightLeg(departureAirportCode: "DXB", arrivalAirportCode: "ADD", departureTime: arrivalTime, arrivalTime: departureTime, durationMinutes: 120) : nil
        let reference = FlightOfferReference(searchId: "search", offerId: id, offerToken: "token", provider: .nexusFake, contentSource: nil, responseId: nil, productIds: [], termsAndConditionsId: nil, brandRef: nil, expiresAt: nil)
        return FlightOffer(id: id, reference: reference, airline: AirlineBrand(code: "ET", name: "Ethiopian"), flightNumber: "ET600", outbound: leg, inbound: inboundLeg, price: Money(amount: price, currency: "USD", formatted: "USD \(price)"), oldPrice: oldPrice, seatsLeft: seats, badge: badge)
    }
}

private extension SearchResultRowMetrics {
    var values: [CGFloat] {
        [horizontalMargin, rowInnerPadding, rowVerticalPadding, logoSlotWidth, logoSlotHeight, legLabelWidth, endpointWidth]
    }
}
