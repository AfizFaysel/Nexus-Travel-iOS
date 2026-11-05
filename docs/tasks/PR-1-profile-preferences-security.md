# PR-1 — Profile, preferences, and security

## Outcome

Replace Profile placeholder with guest/authenticated account hub, editable profile, saved travelers, synchronized preferences, session security details, and logout.

## Truth sources

- Android `domain/profile/ProfileModels.kt`
- Android `data/profile/{RemoteProfileRepository,RemotePreferencesRepository,ProfilePreferencesStore,RemoteAccountSecurityRepository}.kt`
- Android `feature/profile/{ProfileViewModel,ProfileScreen,ProfileDetailViewModels,ProfileDetailScreens}.kt`
- Backend customer-profile controller, DTO, service, repository, and tests.
- Backend traveler-identity mobile controller/DTO/service tests.

## Acceptance

- Guest, loading, authenticated, empty, recoverable-error, refreshing, saving, and logout states are explicit.
- Profile summary/edit and saved travelers use authenticated current backend routes and strict required-field decoding.
- Name is trimmed and 2–80 characters; optional phone is empty or E.164 before network.
- Preferences persist locally first, then synchronize exact backend-supported language, currency, theme, airport, and notification fields.
- Theme applies at app root. Notification toggles request native authorization only when enabling push and provide denial fallback.
- Security shows current device/email verification and starts the same generic password-reset request used on Login. Delete-account navigation remains PR-2.
- Cancellation restores valid state; duplicate saves cannot overlap; stale responses cannot overwrite newer state.
- Icon-only controls are labeled; Dynamic Type-safe native layout; no placeholder/debug copy.
- Tests cover routes/auth/DTOs, validation, traveler masking, local preference persistence, sync rollback/error, state transitions, logout, cancellation, and stale-response protection.

## Owned paths

- `Sources/{Domain,Data}/Profile/**`
- `Sources/Feature/Profile/**`
- Profile/preference composition in `Sources/App/**`
- Matching tests and coordinator ledger updates.
