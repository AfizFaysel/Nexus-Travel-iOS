import Testing
@testable import NexusTravel

struct FlightDetailsDisplayMapperTests {
    @Test func mapsExactCopyDatesTimesDurationsAndWarning() throws {
        let returnDate = try #require(LocalDate(year: 2026, month: 6, day: 8))
        let morning = FlightDetailsLeg(label: "Outbound", date: try #require(LocalDate(year: 2026, month: 6, day: 1)), departureAirportCode: "ADD", departureAirportName: "Bole", arrivalAirportCode: "DXB", arrivalAirportName: "Dubai", departureTime: try #require(LocalTime(hour: 0, minute: 5)), arrivalTime: try #require(LocalTime(hour: 12, minute: 0)), durationMinutes: 0, stopLabel: "Non-stop", segments: [])
        let evening = FlightDetailsLeg(label: "Return", date: returnDate, departureAirportCode: "DXB", departureAirportName: "Dubai", arrivalAirportCode: "ADD", arrivalAirportName: "Bole", departureTime: try #require(LocalTime(hour: 9, minute: 7)), arrivalTime: try #require(LocalTime(hour: 21, minute: 30)), durationMinutes: 125, stopLabel: "1 stop", segments: [])
        let display = try makeDetails(returnDate: returnDate, legs: [morning, evening]).toDisplayModel(warningMessage: "Price changed.")
        #expect(display.title == "ADD -> DXB")
        #expect(display.flightMeta == "ET600 · Economy")
        #expect(display.dateTravelerMeta == "Jun 1 - Jun 8 · 1 Adult · 1 Child · 1 Infant")
        #expect(display.totalPrice == PriceDisplay(currency: "ETB", amount: "56,500", formatted: "ETB 56,500"))
        #expect(display.legs.map(\.label) == ["Outbound", "Return"])
        #expect(display.legs[0].date == "Mon, Jun 1")
        #expect(display.legs[0].departureAirportName == "Bole")
        #expect(display.legs[0].arrivalAirportName == "Dubai")
        #expect(display.legs[0].departureTime == "12:05 am")
        #expect(display.legs[0].arrivalTime == "12:00 pm")
        #expect(display.legs[0].duration == "0h 0m")
        #expect(display.legs[1].departureTime == "9:07 am")
        #expect(display.legs[1].arrivalTime == "9:30 pm")
        #expect(display.legs[1].duration == "2h 5m")
        #expect(display.warning?.message == "Price changed.")

        let subHour = FlightDetailsLeg(label: "Short", date: returnDate, departureAirportCode: "DXB", departureAirportName: "Dubai", arrivalAirportCode: "SHJ", arrivalAirportName: "Sharjah", departureTime: try #require(LocalTime(hour: 13, minute: 0)), arrivalTime: try #require(LocalTime(hour: 13, minute: 45)), durationMinutes: 45, stopLabel: "Non-stop", segments: [])
        #expect(try makeDetails(legs: [subHour]).toDisplayModel().legs[0].duration == "0h 45m")
    }

    @Test func mapsOneWayAndStripsOnlyExactCurrencyPrefix() throws {
        let exact = try makeDetails(price: Money(amount: 4_633_246, currency: "INR", formatted: "INR 46,332.46")).toDisplayModel()
        let mismatch = try makeDetails(price: Money(amount: 100, currency: "USD", formatted: "KES 100")).toDisplayModel()
        #expect(exact.dateTravelerMeta.hasPrefix("Jun 1 ·"))
        #expect(exact.totalPrice.amount == "46,332.46")
        #expect(exact.warning == nil)
        #expect(mismatch.totalPrice.amount == "KES 100")
    }

    @Test func stickyPriceNeverRepeatsCurrency() throws {
        let price = Money(amount: 5_060_497, currency: "ETB", formatted: "ETB ETB 50,604.97")
        let display = try makeDetails(price: price).toDisplayModel()
        #expect(display.totalPrice.currency == "ETB")
        #expect(display.totalPrice.amount == "50,604.97")
        let noBreakSpaces = Money(amount: 5_060_497, currency: "ETB", formatted: "ETB\u{00A0}ETB\u{00A0}50,604.97")
        #expect(try makeDetails(price: noBreakSpaces).toDisplayModel().totalPrice.amount == "50,604.97")
    }

    @Test func timelineShowsOnlyDurationBetweenAirportCodes() throws {
        let date = try #require(LocalDate(year: 2026, month: 6, day: 1))
        let departure = try #require(LocalTime(hour: 5, minute: 0))
        let arrival = try #require(LocalTime(hour: 10, minute: 30))
        let segment = FlightDetailsSegment(departureAirportCode: "ADD", arrivalAirportCode: "DXB", layoverMinutes: nil,
            departureTime: departure, arrivalTime: arrival, durationMinutes: 270,
            marketingAirlineName: "flydubai", flightNumber: "FZ642", equipment: "7M8")
        let leg = FlightDetailsLeg(label: "Outbound", date: date, departureAirportCode: "ADD", departureAirportName: "ADD",
            arrivalAirportCode: "DXB", arrivalAirportName: "DXB", departureTime: departure, arrivalTime: arrival,
            durationMinutes: 270, stopLabel: "Non-stop", segments: [segment])
        let display = try makeDetails(legs: [leg]).toDisplayModel()
        #expect(display.legs[0].segments[0].detail == "4h 30m")
        #expect(display.legs[0].segments[0].departureTime == "5:00 am")
        #expect(display.legs[0].segments[0].arrivalTime == "10:30 am")
    }

    @Test func mapsEveryAirlineAssetAndFallback() throws {
        let expected = ["ET": "ic_airline_ethiopian_mark", "EK": "airline_emirates_logo", "FZ": "airline_flydubai_logo", "G9": "airline_air_arabia_logo", "EY": "airline_etihad_logo", "QR": "airline_qatar_logo", "SV": "airline_saudia_logo", "XY": "airline_flynas_logo", "MS": "airline_egyptair_logo", "TK": "airline_turkish_mark", "KQ": "airline_kenya_airways_mark", "AH": "airline_air_algerie_mark", "J4": "airline_badr_icon", "IY": "airline_yemenia_mark"]
        for (code, name) in expected {
            #expect(try makeDetails(airlineCode: code).toDisplayModel().airlineLogo == .asset(name: name))
        }
        #expect(try makeDetails(airlineCode: "ZZ").toDisplayModel().airlineLogo == .fallback)
    }
}
