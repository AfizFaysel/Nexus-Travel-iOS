# Nexus Travel iOS plan

Single source for roadmap, phases, milestones, dependencies, and live task status.

## Status

- `[ ]` queued
- `[ ] 🔄` active
- `[ ] ⛔` blocked
- `[x]` merged and verified for the current PR head

Only coordinator edits this file. Feature agents follow assigned `docs/tasks/<ID>-*.md` packets and never change task status themselves.

Current phase: **Phase 9 — release**

Active wave: **Wave 28 — AS-1 App Store and TestFlight gate**

## Phase 0 — Delivery foundation

Exit gate: reproducible macOS build/test, protected `main`, stateless task workflow.

- [x] [P0-1 — Bootstrap reproducible PR verification](docs/tasks/P0-1-bootstrap-ci.md)
- [x] [P0-2 — PLAN/ARCHIVE stateless agent workflow](docs/tasks/P0-2-parallel-agent-contract.md) — requires P0-1

## Phase 1 — Design system

Milestone: tokens, primitives, and gallery match Android design truth while respecting Dynamic Type and Apple accessibility.

- [x] [DS-1 — Color, spacing, radius, layout, status, and motion tokens](docs/tasks/DS-1-design-tokens.md) — requires P0-2
- [x] [DS-2 — Typography tokens and Dynamic Type](docs/tasks/DS-2-typography-dynamic-type.md) — requires P0-2
- [x] [DS-3 — Button, text field, top bar, and feedback primitives](docs/tasks/DS-3-component-primitives.md) — requires DS-1, DS-2
- [x] [DS-4 — DesignSystemGalleryScreen and icon catalog](docs/tasks/DS-4-design-system-gallery.md) — requires DS-3

Exit gate: token tests green; gallery screenshots prove Android code-defined states on Mac.

## Phase 2 — Domain models and fakes

Milestone: presentation-independent domain behavior has Swift Testing coverage.

- [x] [AU-1 — Auth models, validator, and error presenter](docs/tasks/AU-1-auth-domain.md) — requires DS-4
- [x] [HM-1 — Home models, multi-city state, and search validator](docs/tasks/HM-1-home-domain.md) — requires DS-4
- [x] [SR-1 — Search models, codec, and display mapper](docs/tasks/SR-1-search-domain.md) — requires HM-1
- [x] [FD-1 — Flight details models and mapper](docs/tasks/FD-1-flight-details-domain.md) — requires HM-1, SR-1
- [x] [BK-1 — Passenger and booking models with validation](docs/tasks/BK-1-booking-domain.md) — requires FD-1

Exit gate: Swift Testing suite green; no UI or network dependency in domain logic.

## Phase 3 — Transport and authentication

- [x] [NT-1 — App config and HTTP transport classification](docs/tasks/NT-1-http-transport.md) — requires Phase 2
- [x] [AU-2 — Keychain session store](docs/tasks/AU-2-keychain-session.md) — requires AU-1
- [x] [AU-3 — Remote email/password auth Adapter and contract fixtures](docs/tasks/AU-3-remote-auth.md) — requires NT-1, AU-2

Exit gate: backend contract fixtures green; demo email auth flow verified.

## Phase 4 — App shell and navigation

- [x] [NV-1 — Typed routes, Router, per-tab NavigationStack shell](docs/tasks/NV-1-app-shell-navigation.md) — requires AU-3
- [x] [AU-4 — Email authentication screens and session gate](docs/tasks/AU-4-auth-screens-session-gate.md) — requires AU-3, NV-1

Exit gate: independent tab-history and restoration tests green; simulator evidence archived.

## Phase 5 — Search journey

- [x] [HD-1 — Remote Home and airport data adapters](docs/tasks/HD-1-home-data.md) — requires HM-1, NT-1
- [x] [HM-2 — Home loading, content, empty, and error states](docs/tasks/HM-2-home-screen.md) — requires HM-1, NV-1, HD-1, SR-2
- [x] [SR-2 — Remote search Adapter](docs/tasks/SR-2-remote-search.md) — requires SR-1, NT-1
- [x] [SR-3 — Search results screen](docs/tasks/SR-3-search-results-screen.md) — requires SR-2, HM-2
- [x] [FD-API-1 — Remote flight details adapter](docs/tasks/FD-API-1-remote-flight-details.md) — requires FD-1, NT-1, SR-3
- [x] [FD-2 — Flight details screen](docs/tasks/FD-2-flight-details-screen.md) — requires FD-1, SR-3, FD-API-1

Exit gate: Home → search → results → details passes parity, contract, mapper, and UI-state gates.

## Phase 6 — Booking journey

- [x] [BJ-1 — Booking journey Module and valid transitions](docs/tasks/BJ-1-booking-journey.md) — requires BK-1, NV-1, AU-4
- [x] [PD-1 — Passenger details and passport signed upload](docs/tasks/PD-1-passenger-details-passport-upload.md) — requires BJ-1, NT-1
- [x] [ST-1 — Seat selection](docs/tasks/ST-1-seat-selection.md) — requires PD-1
- [x] [BR-1 — Booking review and stable hold idempotency](docs/tasks/BR-1-booking-review-hold.md) — requires ST-1
- [x] [PP-1 — Payment-proof signed upload](docs/tasks/PP-1-payment-proof-upload.md) — requires BR-1

Exit gate: transition, idempotency, upload, accessibility, and CRITICAL review gates pass.

## Phase 7 — Trips, profile, and explore

- [x] [TR-1 — Trips list, detail, and ticket](docs/tasks/TR-1-trips-detail-ticket.md) — requires Phase 3, NV-1, AU-4
- [x] [PR-1 — Profile, preferences, and security](docs/tasks/PR-1-profile-preferences-security.md) — requires Phase 3, NV-1, AU-4
- [x] [PR-2 — CRITICAL asynchronous account deletion](docs/tasks/PR-2-account-deletion.md) — requires PR-1
- [x] [EX-1 — Explore list, details, and cache](docs/tasks/EX-1-explore.md) — requires Phase 3, NV-1

Exit gate: offline/cache behavior, ownership-hiding errors, and account-deletion evidence pass.

## Phase 8 — Reliability and polish

- [x] [QA-1 — Accessibility and Dynamic Type pass](docs/tasks/QA-1-accessibility-dynamic-type.md) — requires all screens
- [x] [QA-2 — Motion audit, plans, and later execution](docs/tasks/QA-2-motion.md) — requires all screens
- [x] [QA-3 — Offline, retry, cancellation, and performance validation](docs/tasks/QA-3-reliability.md) — requires all async flows
- [ ] 🔄 [AU-5 — Contextual authentication sheet and session reliability](docs/tasks/AU-5-auth-sheet-session-reliability.md) — requires AU-4, BJ-1, PR-1

Exit gate: simulator and real-device evidence archived; no unresolved CRITICAL deviation.

## Phase 9 — Release

- [ ] 🔄 [AS-1 — Privacy, App Store, archive, and TestFlight gate](docs/tasks/AS-1-release.md) — requires Phase 8

Exit gate: current Apple-policy audit, exact Release archive validation, privacy reconciliation, demo credentials, and TestFlight evidence pass.

## Task sizing and dispatch

- One task packet = one branch = one PR = one observable behavior slice.
- Target 0.5–2 agent-hours, normally no more than 8 production and 8 test files.
- Parallel tasks must have merged dependencies and non-overlapping owned paths.
- Coordinator marks `🔄` before dispatch, creates complete packet, then assigns agent.
- The coordinator marks `[x]` and appends `ARCHIVE.md` after merge and task verification.
