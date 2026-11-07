# ST-1 — Seat selection

## Outcome

Replace seat-selection placeholder with backend-driven multi-segment, multi-passenger seat selection. Save or clear optional assignments, then route to booking review.

## Truth sources

- Android `domain/seats/FlightSeatsModels.kt`
- Android `data/seats/{FlightSeatsDtos,RemoteFlightSeatsRepository}.kt`
- Android `feature/seats/{SeatSelectionViewModel,SeatSelectionScreen,SeatSelectionRoute}.kt`
- Backend `flight-seats/{flight-seats.controller,flight-seats.dto,flight-seats.service}.ts`
- Backend seat assignment policy and tests.

## Acceptance

- GET seat map, PUT assignments, and DELETE optional selection match backend routes and coded DTOs.
- Loading/content/empty/error states and Android-equivalent copy exist.
- Available/selected seats are actionable; occupied/blocked/restricted seats are not.
- One assignment per passenger and segment; one seat cannot belong to two passengers.
- Segment/passenger tabs preserve assignments; fees reflect current choices.
- Use backend traveler eligibility and retain original passenger indices. Infant passengers cannot select seats. Legacy responses use the known booking composition.
- Zero seat fees use the booking or seat-map currency. Omit the amount when no currency is known.
- Conflict keeps user on screen with seat-unavailable guidance; retry and skip work.
- Cancellation propagates; stale loads/saves do not overwrite current state.
- Every seat exposes number, position, features, price, selection, and availability to VoiceOver.
- Swift Testing covers mapper/status behavior, repository contracts, selection invariants, and transitions.

## Owned paths

- `Sources/{Domain,Data}/Seats/**`
- `Sources/Feature/SeatSelection/**`
- Seat composition in `Sources/App/**`
- Matching tests and coordinator ledger updates.
