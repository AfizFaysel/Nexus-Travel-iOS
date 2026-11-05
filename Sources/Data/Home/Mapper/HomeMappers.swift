enum AirportMapper {
    static func map(_ dto: AirportDTO) -> Airport {
        Airport(code: dto.iataCode, city: dto.city, name: dto.name, country: dto.country)
    }
}

enum HomeContentMapper {
    static func map(_ dto: ExploreHomeDTO, origin: Airport, destination fallbackDestination: Airport) -> HomeContent {
        let escapes = dto.destinations.map { destination in
            TrendingEscape(
                id: destination.id,
                airport: Airport(
                    code: destination.airportCode ?? fallbackDestination.code,
                    city: destination.city,
                    name: destination.title,
                    country: destination.country
                ),
                tags: [destination.summary],
                startingPrice: Money(amount: 0, currency: "", formatted: ""),
                imageName: destination.imageUrl ?? ""
            )
        }
        return HomeContent(
            origin: origin,
            destination: fallbackDestination,
            departureDate: "Aug 1",
            returnDate: "Add return",
            travelersLabel: "1 Adult",
            cabinClass: "Economy",
            trendingEscapes: escapes
        )
    }
}
