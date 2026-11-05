# AU-3: Remote email/password authentication

## Ownership and truth

- Branch `codex/au-3-remote-auth`; requires NT-1/AU-2.
- Own `Sources/Domain/Auth/AuthRepository.swift`; `Sources/Data/Auth/{API/AuthEndpoints,DTO/AuthDTOs,Mapper/AuthMappers,Repository/RemoteAuthRepository}.swift`; matching fixture/mapper/repository tests.
- Existing domain/transport/store and planning/config files read-only during implementation.
- Backend controllers/Better Auth factory/e2e/deployed probes are network truth; Android auth API/DTO/mapper/repository controls product behavior where compatible. Email/password only per ADR-0005.
- Use mandatory Swift, TDD, architecture/DRY, and concurrency skills. No UI.

## API and routes

`AuthRepository: Sendable` async throwing signInEmail, signUpEmail, getSession, getLocalSession, requestPasswordReset, signOut returning `AuthResult`. Throws only preserve cancellation and Keychain failures; transport/server outcomes map to AuthResult.

Root routes, never mobile prefix: POST `/api/auth/sign-in/email`; POST `/api/auth/sign-up/email`; GET `/api/auth/get-session`; POST `/api/auth/request-password-reset`; POST `/api/auth/sign-out`. Session/signout attach stored bearer when present.

DTO fixtures mirror current backend: token envelope has required token/user; session envelope has required session(id,userId,token,expiresAt) + user; unauthenticated session is literal `200 null`; error has message/code plus optional field errors. Ignore additive JSON; reject missing required data.

Token precedence: nonblank body token, then normalized `set-auth-token` header, then session.token, else unauthenticated. Token response uses sessionId=user.id and injected clock +30 days; session response uses server ID/expiry. Accept ISO timestamps with/without fractional seconds. No refresh behavior.

Requests trim email/name but never password; sign-up never serializes acceptedTerms. Local validation short-circuits transport.

## Errors and lifecycle

Map INVALID_EMAIL to email validation; PASSWORD_TOO_SHORT to password validation; INVALID_EMAIL_OR_PASSWORD/INVALID_CREDENTIALS invalidCredentials; USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL/USER_ALREADY_EXISTS/EMAIL_ALREADY_EXISTS emailAlreadyUsed; EMAIL_NOT_VERIFIED; UNAUTHENTICATED/401; SESSION_EXPIRED; HTTP 429 rateLimited; transport timeout/connectivity networkUnavailable; malformed/5xx/unknown/RESET_PASSWORD_DISABLED unknown. Unknown validation fields ignored. Cancellation rethrows.

Persist sign-in/up/remote-session success before returning. Local usable iff expiry strictly after injected clock and access token nonblank. getSession returns usable local immediately; otherwise clears then probes remote. `200 null`, unauthenticated, expired clear store. getLocalSession applies same rules without network. Signout always clears locally after remote attempt; storage failure propagates. No retry/refresh.

Deployed 2026-08-28 blocker: `/request-password-reset` returns `400 RESET_PASSWORD_DISABLED` because backend omits `sendResetPassword`. Test fixture maps unknown honestly; do not claim reset success or use obsolete `/forget-password`.

## TDD/exclusions

Tests-only RED then minimum GREEN. Cover routes/method/auth/body trimming; validation no-call; token precedence/missing; fixed-clock fallback; timestamp formats; null/additive/missing JSON; full error/status/network/cancellation matrix; persistence/failure; usable/expired/equal/blank local sessions; clearing rules; signout clear on success/failure; generic password-reset request response.

Exclude social auth, refresh, cookies, retry/backoff, ViewModel/screens/navigation, account deletion, backend edits, demo credentials, dependencies.
