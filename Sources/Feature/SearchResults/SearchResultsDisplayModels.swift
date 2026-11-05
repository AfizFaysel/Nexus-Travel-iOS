import Foundation
import CoreGraphics

/// Display snapshot for search results.
struct SearchResultsDisplayState: Equatable, Sendable {
    let querySummary: SearchResultsQuerySummary?
    let tripType: TripType
    let allFlights: [SearchResultUiOffer]
    let visibleFlights: [SearchResultUiOffer]
    let selectedFilters: Set<SearchFilter>
    let sortOption: SortOption
    let resultState: SearchResultsState
    let errorMessage: String?
}

/// Search-result loading/content/empty/error state.
enum SearchResultsState: Equatable, Sendable {
    case loading
    case content
    case empty
    case error
}

/// Display-ready flight offer.
struct SearchResultUiOffer: Equatable, Sendable {
    let id: String
    let reference: FlightOfferReference
    let airlineCode: String
    let airlineName: String
    let airlineLogoURL: URL?
    let flightNumber: String
    let outbound: SearchResultUiLeg
    let inbound: SearchResultUiLeg?
    let legs: [SearchResultUiLeg]
    let priceAmount: Int
    let priceLabel: String
    let oldPriceLabel: String?
    let priceMetaLabel: String
    let priceDigitCount: Int
    let seatsLeftLabel: String?
    let badgeLabel: String?
    let bookingStatusLabel: String?
    let refundable: Bool
    let bestPriceSortKey: Int
    let fastestSortKey: Int
    let departureEarlySortKey: LocalTime

    /// Returns copy with current booking-request status label.
    func withBookingStatus(label: String?) -> SearchResultUiOffer {
        SearchResultUiOffer(id: id, reference: reference, airlineCode: airlineCode, airlineName: airlineName,
            airlineLogoURL: airlineLogoURL,
            flightNumber: flightNumber, outbound: outbound, inbound: inbound, legs: legs,
            priceAmount: priceAmount, priceLabel: priceLabel, oldPriceLabel: oldPriceLabel,
            priceMetaLabel: priceMetaLabel, priceDigitCount: priceDigitCount, seatsLeftLabel: seatsLeftLabel,
            badgeLabel: badgeLabel, bookingStatusLabel: label, refundable: refundable,
            bestPriceSortKey: bestPriceSortKey, fastestSortKey: fastestSortKey,
            departureEarlySortKey: departureEarlySortKey)
    }
}

/// Display-ready flight leg.
struct SearchResultUiLeg: Equatable, Sendable {
    let departureAirportCode: String
    let arrivalAirportCode: String
    let departureTimeLabel: String
    let arrivalTimeLabel: String
    let durationLabel: String
    let stopCount: Int
    let stopLabel: String
    let compactStopLabel: String
    let departureHour: Int
}

extension FlightOffer {
    /// Maps raw offer into Android-equivalent display values.
    func toSearchResultUiOffer(tripType: TripType) -> SearchResultUiOffer {
        let displayLegs = legs.map { $0.toSearchResultUiLeg() }
        return SearchResultUiOffer(
            id: id, reference: reference, airlineCode: airline.code, airlineName: airline.name,
            airlineLogoURL: airline.logoURL,
            flightNumber: flightNumber, outbound: outbound.toSearchResultUiLeg(),
            inbound: inbound?.toSearchResultUiLeg(), legs: displayLegs, priceAmount: price.amount,
            priceLabel: price.formatted.removingPrefix("\(price.currency) "),
            oldPriceLabel: oldPrice.map { $0.formatted.removingPrefix("\($0.currency) ") },
            priceMetaLabel: "\(price.currency) · \(tripType.searchLabel)",
            priceDigitCount: String(price.amount).drop(while: { $0 == "-" }).count,
            seatsLeftLabel: seatsLeft.map { "\($0) seats left" }, badgeLabel: badge?.label,
            bookingStatusLabel: nil, refundable: refundable, bestPriceSortKey: price.amount,
            fastestSortKey: legs.reduce(0) { $0 + $1.durationMinutes },
            departureEarlySortKey: outbound.departureTime
        )
    }
}

extension Array where Element == SearchResultUiOffer {
    /// Applies composable filters and stable Android-equivalent ordering.
    func applyingSearchResultFiltersAndSort(filters: Set<SearchFilter>, sortOption: SortOption) -> [SearchResultUiOffer] {
        let filtered = filter { offer in
            (!filters.contains(.nonStop) || offer.legs.allSatisfy { $0.stopCount == 0 })
                && (!filters.contains(.oneStop) || offer.legs.contains { $0.stopCount == 1 })
                && (!filters.contains(.morning) || (5...11).contains(offer.outbound.departureHour))
        }
        guard sortOption != .recommended else { return filtered }
        return filtered.enumerated().sorted { lhs, rhs in
            let comparison: ComparisonResult
            switch sortOption {
            case .recommended: comparison = .orderedSame
            case .bestPrice: comparison = lhs.element.bestPriceSortKey.compared(to: rhs.element.bestPriceSortKey)
            case .fastest: comparison = lhs.element.fastestSortKey.compared(to: rhs.element.fastestSortKey)
            case .departureEarly: comparison = lhs.element.departureEarlySortKey.compared(to: rhs.element.departureEarlySortKey)
            }
            return comparison == .orderedSame ? lhs.offset < rhs.offset : comparison == .orderedAscending
        }.map(\.element)
    }
}

private extension FlightLeg {
    func toSearchResultUiLeg() -> SearchResultUiLeg {
        let stopLabel: String
        if stopCount == 0 {
            stopLabel = "Non-stop"
        } else if let firstStop = stops.first {
            stopLabel = "\(stopCount) stop · \(firstStop.airportCode)"
        } else {
            stopLabel = "\(stopCount) \(stopCount == 1 ? "stop" : "stops")"
        }
        return SearchResultUiLeg(
            departureAirportCode: departureAirportCode, arrivalAirportCode: arrivalAirportCode,
            departureTimeLabel: departureTime.hhmm, arrivalTimeLabel: arrivalTime.hhmm,
            durationLabel: "\(durationMinutes / 60)h \(durationMinutes % 60)m", stopCount: stopCount,
            stopLabel: stopLabel, compactStopLabel: stopCount == 0 ? "Non-stop" : "\(stopCount) stop",
            departureHour: departureTime.hour
        )
    }
}

private extension String {
    func removingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}

private extension TripType {
    var searchLabel: String {
        switch self {
        case .oneWay: "One way"
        case .roundTrip: "Round trip"
        case .multiCity: "Multi-city"
        }
    }
}

private extension Comparable {
    func compared(to other: Self) -> ComparisonResult {
        if self < other { return .orderedAscending }
        if other < self { return .orderedDescending }
        return .orderedSame
    }
}

/// Android-mirrored responsive geometry for one search-result row.
struct SearchResultRowMetrics: Equatable {
    let usesCompactLabels: Bool
    let summaryCardMinHeight: CGFloat
    let summaryHorizontalPadding: CGFloat
    let horizontalMargin: CGFloat
    let rowInnerPadding: CGFloat
    let rowVerticalPadding: CGFloat
    let logoSlotWidth: CGFloat
    let logoSlotHeight: CGFloat
    let legLabelWidth: CGFloat
    let endpointWidth: CGFloat

    init(maxWidth: CGFloat, spacing: NexusAdaptiveSpacing) {
        let isSmallWidth = maxWidth <= 360
        let isNormalWidth = maxWidth > 360 && maxWidth <= 400

        usesCompactLabels = isSmallWidth
        summaryCardMinHeight = isSmallWidth
            ? NexusSearchResultLayout.summaryCardHeightCompact
            : NexusSearchResultLayout.summaryCardHeightRegular
        summaryHorizontalPadding = isSmallWidth ? NexusSpacing.space12 : NexusSpacing.space16
        horizontalMargin = switch spacing.mode {
        case .compact: NexusSpacing.space16
        case .regular: NexusSpacing.space20
        case .spacious: NexusSpacing.space24
        }
        rowInnerPadding = spacing.mode == .spacious ? NexusSpacing.space4 : NexusSpacing.space0
        rowVerticalPadding = switch spacing.mode {
        case .compact: NexusSearchResultLayout.rowVerticalPaddingCompact
        case .regular: NexusSearchResultLayout.rowVerticalPaddingRegular
        case .spacious: NexusSearchResultLayout.rowVerticalPaddingSpacious
        }
        logoSlotWidth = isSmallWidth
            ? NexusSearchResultLayout.logoSlotWidthCompact
            : (isNormalWidth ? NexusSearchResultLayout.logoSlotWidthRegular : NexusSearchResultLayout.logoSlotWidthSpacious)
        logoSlotHeight = NexusSearchResultLayout.logoSlotHeight
        legLabelWidth = isSmallWidth
            ? NexusSearchResultLayout.legLabelWidthCompact
            : NexusSearchResultLayout.legLabelWidthRegular
        endpointWidth = isSmallWidth
            ? NexusSearchResultLayout.endpointWidthCompact
            : (isNormalWidth ? NexusSearchResultLayout.endpointWidthRegular : NexusSearchResultLayout.endpointWidthSpacious)
    }
}
