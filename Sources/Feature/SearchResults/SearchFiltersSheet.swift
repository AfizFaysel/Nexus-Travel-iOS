import SwiftUI

struct SearchFiltersSheet: View {
    let state: SearchResultsUiState
    let onApply: (Set<SearchFilter>, Set<String>, SearchFilterOptions) -> Void
    @State private var keepsBestPrice: Bool
    @State private var stop: SearchFilter?
    @State private var airlines: Set<String>
    @State private var price: String
    @State private var duration: String
    @State private var departure: FlightTimeWindow?
    @State private var arrival: FlightTimeWindow?
    @Environment(\.dismiss) private var dismiss

    init(state: SearchResultsUiState, onApply: @escaping (Set<SearchFilter>, Set<String>, SearchFilterOptions) -> Void) {
        self.state = state
        self.onApply = onApply
        let options = state.filterOptions
        _keepsBestPrice = State(initialValue: state.selectedFilters.contains(.bestPrice))
        _stop = State(initialValue: [.nonStop, .oneStop].first { state.selectedFilters.contains($0) })
        _airlines = State(initialValue: state.selectedAirlines)
        _price = State(initialValue: options.maximumPriceMinor.map { String($0 / 100) + String(format: ".%02d", $0 % 100) } ?? "")
        _duration = State(initialValue: options.maximumDurationMinutes.map { String($0 / 60) } ?? "")
        _departure = State(initialValue: options.departureWindow ?? (state.selectedFilters.contains(.morning) ? .morning : nil))
        _arrival = State(initialValue: options.arrivalWindow)
    }

    private var filters: Set<SearchFilter> {
        var filters: Set<SearchFilter> = keepsBestPrice ? [.bestPrice] : []
        if let stop { filters.insert(stop) }
        return filters
    }

    private var options: SearchFilterOptions {
        .init(maximumPriceMinor: SearchFilterOptions.priceMinor(price),
              departureWindow: departure, arrivalWindow: arrival,
              maximumDurationMinutes: SearchFilterOptions.durationMinutes(duration))
    }

    private var airlineChoices: [SearchResultUiOffer] {
        var seen: Set<String> = []
        return state.allFlights.filter {
            !$0.airlineCode.isEmpty && seen.insert($0.airlineCode.uppercased()).inserted
        }.sorted { $0.airlineName.localizedStandardCompare($1.airlineName) == .orderedAscending }
    }

    var body: some View {
        let draft = options
        let priceInvalid = !price.isEmpty && draft.maximumPriceMinor == nil
        let durationInvalid = !duration.isEmpty && draft.maximumDurationMinutes == nil
        let count = state.allFlights.applyingSearchResultFiltersAndSort(
            filters: filters, sortOption: .recommended, airlineCodes: airlines, options: draft
        ).count

        NavigationStack {
            Form {
                Section {
                    Picker("Stops", selection: $stop) {
                        Text("Any").tag(nil as SearchFilter?)
                        Text("Non-stop").tag(SearchFilter.nonStop as SearchFilter?)
                        Text("1 stop").tag(SearchFilter.oneStop as SearchFilter?)
                    }
                    timeWindow("First leg departure", selection: $departure)
                    timeWindow("First leg arrival", selection: $arrival)
                }
                Section {
                    TextField("Maximum price (ETB)", text: $price)
                        .keyboardType(.decimalPad)
                    if priceInvalid { validation("Enter a positive amount with up to 2 decimals.") }
                    if state.allFlights.contains(where: { $0.priceCurrency != "ETB" }) {
                        Text("Price limit shows ETB fares only. Clear it to see other currencies.")
                            .foregroundStyle(NexusSemanticColors.textSecondary)
                    }
                    TextField("Maximum journey (hours)", text: $duration)
                        .keyboardType(.numberPad)
                    if durationInvalid { validation("Enter a positive whole number.") }
                } footer: {
                    Text("Each leg, including connections. Times are airport-local.")
                }
                Section("Airlines") {
                    Text("All airlines unless selected")
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                    if airlineChoices.isEmpty {
                        Text("No airlines available for this search.")
                    }
                    ForEach(airlineChoices, id: \.airlineCode) { offer in
                        let code = offer.airlineCode.uppercased()
                        Toggle(offer.airlineName.isEmpty ? code : offer.airlineName, isOn: Binding(
                            get: { airlines.contains(code) },
                            set: { selected in
                                if selected { airlines.insert(code) } else { airlines.remove(code) }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Reset", action: reset) }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: NexusSpacing.space8) {
                    if count == 0 { Text("No matching flights. Change or reset filters.") }
                    NexusPrimaryButton("Show \(count) \(count == 1 ? "flight" : "flights")",
                                       isEnabled: !priceInvalid && !durationInvalid, fillsWidth: true) {
                        onApply(filters, airlines, draft)
                    }
                    .accessibilityIdentifier("apply-search-filters")
                }
                .padding(NexusSpacing.space16)
                .background(NexusSemanticColors.surfaceBase)
            }
        }
    }

    private func timeWindow(_ title: String, selection: Binding<FlightTimeWindow?>) -> some View {
        Picker(title, selection: selection) {
            Text("Any time").tag(nil as FlightTimeWindow?)
            ForEach(FlightTimeWindow.allCases, id: \.self) { window in
                Text(window.rawValue).tag(window as FlightTimeWindow?)
            }
        }
    }

    private func validation(_ message: String) -> some View {
        Text(message).foregroundStyle(NexusSemanticColors.errorText)
    }

    private func reset() {
        keepsBestPrice = false
        stop = nil
        airlines.removeAll()
        price = ""
        duration = ""
        departure = nil
        arrival = nil
    }
}
