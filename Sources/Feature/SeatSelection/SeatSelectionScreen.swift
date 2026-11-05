import SwiftUI

struct SeatSelectionScreenRoute: View {
    @State private var viewModel: SeatSelectionViewModel
    @State private var eventTask: Task<Void, Never>?
    let router: Router

    init(viewModel: SeatSelectionViewModel, router: Router) {
        _viewModel = State(initialValue: viewModel); self.router = router
    }

    var body: some View {
        SeatSelectionScreen(viewModel: viewModel, send: send)
            .task { do { try await viewModel.load() } catch is CancellationError { return } catch { return } }
            .onDisappear { eventTask?.cancel() }
    }

    private func send(_ event: SeatSelectionEvent) {
        eventTask?.cancel()
        eventTask = Task {
            do {
                switch event {
                case .back: viewModel.back()
                case .retry: try await viewModel.load()
                case .continue: try await viewModel.continueToReview()
                case .skip: try await viewModel.skip()
                case let .segment(index): viewModel.selectSegment(index)
                case let .passenger(index): viewModel.selectPassenger(index)
                case let .seat(seat): viewModel.select(seat)
                }
            } catch is CancellationError { return } catch { return }
            while let destination = viewModel.consumeNavigation() {
                switch destination {
                case .back: router.pop()
                case let .review(id): router.push(.bookingReview(.init(reviewId: id)))
                }
            }
            eventTask = nil
        }
    }
}

enum SeatSelectionEvent: Sendable { case back, retry, `continue`, skip, segment(Int), passenger(Int), seat(FlightSeat) }

struct SeatSelectionScreen: View {
    @Bindable var viewModel: SeatSelectionViewModel
    let send: (SeatSelectionEvent) -> Void

    var body: some View {
        Group {
            if viewModel.state.loading {
                ProgressView("Loading seat map…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .navigationTitle("Choose seats")
        .navigationBarBackButtonHidden()
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Back", systemImage: NexusIconName.back.systemName) { send(.back) } } }
        .safeAreaInset(edge: .bottom) { actions }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: NexusSpacing.space16) {
                if viewModel.state.segments.count > 1 { segmentTabs }
                passengerTabs
                if let message = viewModel.state.message {
                    NexusFeedbackPanel(
                        title: viewModel.state.canRetryLoad ? "Seat map temporarily unavailable" : "Seat selection needs attention",
                        message: message,
                        primaryActionLabel: viewModel.state.canRetryLoad ? "Try again" : nil,
                        onPrimaryAction: viewModel.state.canRetryLoad ? { send(.retry) } : nil
                    )
                }
                if let segment = viewModel.state.segments[safe: viewModel.state.activeSegmentIndex] {
                    aircraft(segment)
                    ForEach(segment.cabins, id: \.name) { cabin in
                        Text(cabin.name).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(cabin.rows) { row in seatRow(row, segment: segment) }
                    }
                }
                Button("Skip seat selection") { send(.skip) }.disabled(viewModel.state.saving)
            }
            .padding(NexusSpacing.space16)
        }
    }

    private var segmentTabs: some View {
        Picker("Flight", selection: Binding(get: { viewModel.state.activeSegmentIndex }, set: { send(.segment($0)) })) {
            ForEach(viewModel.state.segments.indices, id: \.self) { Text("Flight \($0 + 1)").tag($0) }
        }.pickerStyle(.segmented)
    }

    private var passengerTabs: some View {
        Picker("Passenger", selection: Binding(get: { viewModel.state.activePassengerIndex }, set: { send(.passenger($0)) })) {
            ForEach(0..<viewModel.state.passengerCount, id: \.self) { Text("Passenger \($0 + 1)").tag($0) }
        }.pickerStyle(.segmented)
    }

    private func aircraft(_ segment: SeatMapSegment) -> some View {
        VStack {
            NexusIcon(name: .flight, size: NexusIconSize.lg).accessibilityHidden(true)
            if !segment.airlineName.isEmpty { Text(segment.airlineName).font(.headline) }
            Text(segment.aircraftName).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private func seatRow(_ row: SeatRow, segment: SeatMapSegment) -> some View {
        HStack(spacing: NexusSpacing.space8) {
            Text("\(row.number)").font(.caption).frame(width: 24)
            ForEach(Array(row.seats.enumerated()), id: \.element.number) { index, seat in
                if index > 0, row.seats[index - 1].position == .aisle { Spacer().frame(width: NexusSpacing.space8) }
                seatButton(seat, segment: segment)
            }
            Text("\(row.number)").font(.caption).frame(width: 24)
        }
    }

    private func seatButton(_ seat: FlightSeat, segment: SeatMapSegment) -> some View {
        let selected = viewModel.state.assignments.contains {
            $0.passengerIndex == viewModel.state.activePassengerIndex && $0.segmentId == segment.id && $0.seatNumber == seat.number
        }
        let enabled = seat.status == .available || seat.status == .selected
        return Button { send(.seat(seat)) } label: {
            Text(selected ? "✓" : String(seat.number.filter(\.isLetter)))
                .frame(minWidth: 44, minHeight: 44)
                .background(selected ? Color.accentColor : enabled ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.35))
                .foregroundStyle(selected ? .white : .primary).clipShape(.rect(cornerRadius: NexusRadius.sm))
        }
        .disabled(!enabled)
        .accessibilityLabel(seatAccessibility(seat, selected: selected, enabled: enabled))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func seatAccessibility(_ seat: FlightSeat, selected: Bool, enabled: Bool) -> String {
        var parts = ["Seat \(seat.number)", seat.position.rawValue]
        if seat.features.contains(.extraLegroom) { parts.append("extra legroom") }
        if seat.features.contains(.exitRow) { parts.append("exit row") }
        if let price = seat.price { parts.append(price.formatted) }
        if selected { parts.append("selected") } else if !enabled { parts.append("unavailable") }
        return parts.joined(separator: ", ")
    }

    private var actions: some View {
        VStack(spacing: NexusSpacing.space8) {
            HStack { Text("Seat fees"); Spacer(); Text(feeTotal.formatted).fontWeight(.semibold) }
            Text("Seat selection is optional").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            NexusPrimaryButton("Continue to review", isLoading: viewModel.state.saving, fillsWidth: true) { send(.continue) }
        }.padding(NexusSpacing.space16).background(.regularMaterial)
    }

    private var feeTotal: Money {
        let priced = viewModel.state.assignments.compactMap(\.price)
        let currency = priced.first?.currency ?? "USD"
        let amount = priced.reduce(0) { $0 + $1.amount }
        return .init(amount: amount, currency: currency,
                     formatted: String(format: "%@ %.2f", currency, Double(amount) / 100))
    }
}

private extension Array { subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil } }
