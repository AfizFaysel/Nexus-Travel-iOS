# PD-1 — Passenger details and passport signed upload

## Outcome

Replace passenger placeholder with validated passenger/contact form. Upload selected passport through backend signed-upload handshake, submit booking passengers, then route to seat selection.

## Truth sources

- Android `feature/passengerdetails/**`
- Android `domain/booking/{PassengerDetailsRepository,PassportUploadRepository}.kt`
- Android `data/booking/repository/{RemotePassengerDetailsRepository,RemotePassportUploadRepository}.kt`
- Backend `passport-upload/{passport-upload.controller,passport-upload.dto,passport-upload.service}.ts`
- Backend `bookings/{bookings.controller,bookings.dto}.ts` and `test/bookings.e2e.test.ts`

## Acceptance

- Android-equivalent validation, loading, content, error states and retry behavior.
- Show age and date validation messages beside the corresponding date input.
- A persisted passport upload satisfies document validation until the passport number changes or a replacement document is selected.
- PDF/JPEG/PNG only; nonempty and at most 10 MB.
- Stable operation-scoped idempotency key survives retry.
- Signed PUT has no bearer and includes every backend `requiredHeaders` entry.
- Cancellation propagates and stale completion cannot overwrite current state.
- Auth challenge resumes same submission; success routes with returned booking/review id.
- Icon-only controls labeled; Dynamic Type-safe native controls; no new permission.
- Unit tests cover validation, upload handshake, mappings, retry key, and ViewModel transitions.

## Owned paths

- `Sources/{Domain,Data}/Booking/**Passenger**`, `Sources/{Domain,Data}/Booking/**Passport**`
- `Sources/Feature/PassengerDetails/**`
- Passenger composition in `Sources/App/**`
- Matching tests and this coordinator ledger update.
