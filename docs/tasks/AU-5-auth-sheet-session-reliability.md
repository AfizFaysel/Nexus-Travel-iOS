# AU-5 — Contextual authentication sheet and session reliability

## Outcome

Replace pushed authentication screens with one contextual native sheet for booking, trips, and profile. Preserve booking input, resume protected work once after authentication, reject expired stored tokens, and keep loading/logout state recoverable.

## Truth sources

Read completely: Android `feature/auth/Auth{ViewModel,UiState,Screens,ErrorPresenter}.kt`; backend Better Auth configuration; `docs/adr/0005-auth-signin-apple-guideline-4.8.md`; AU-4, BJ-1, and PR-1 implementations.

## Scope

- Enum-driven authentication sheet owned by the root Router.
- Context copy for booking, trips, profile, and expired sessions.
- Existing-session restoration before displaying credentials.
- Booking continuation after sheet success without losing passenger details.
- Expired-token rejection and Keychain cleanup before protected requests.
- Complete native email verification and password-reset deep-link flows, including password-reset error cleanup and logout/load race protection.
- Fixed-size loading labels, press feedback, Reduce Motion behavior, and VoiceOver error announcements.
- Typed auth links accept only configured HTTPS host/path and keep opaque tokens in memory.
- Verify links call the native verification endpoint; reset links call Better Auth password update and clear local Keychain session after success.
- Reset failures handle used/expired tokens, preserve retry for network failure, and return users to sign-in after completion.

## Tests

- Router sheet intent preserves navigation path.
- Expired stored token is rejected and cleared.
- Unexpected reset failure ends loading with actionable feedback.
- Link parser rejects wrong hosts, schemes, paths, duplicate tokens, and missing tokens.
- Reset success clears the local session; expired and replayed links return actionable feedback.
- Successful authentication clears password fields.
- Failed logout ends loading and preserves recoverable profile state.
- Latest PR-head macOS CI compile and tests required before merge.

## Exclusions

- Social login.
- Backend password-reset delivery implementation.
- New dependencies or state-management frameworks.
- PLAN completion or ARCHIVE evidence before merge and green latest-head CI.

## 2026-10-01 shared-sheet polish

- User-approved iOS visual deviation: auth-scoped heading hierarchy, wider sheet form,
  concise contextual subtitles, plain 20-point Tabler eye/eye-off with 48-point hit area.
- Reuse AuthScaffold; separate presentation layout from optional helper copy.
- Normalize content grouping and outer padding across credentials, codes and recovery.
  Native measured detents remain; accessibility uses large scrollable presentation.
- Test first: credential helper-copy and password-visibility preservation UI assertions.
  Windows cannot run SwiftUI; expected RED is missing sheet helper text. Do not use
  remote CI solely for RED. Mac build and small/large-phone screenshots required.
- No auth requests, tokens, backend behavior, Android source or global control-size changes.
- User requested agreement checkbox instead of switch. Reuse native Toggle with one
  rounded-square ToggleStyle, full-row hit target and native accessibility representation.
- Mac UI test exposed a real defect: plain eye icon reported a 20-point target despite
  its 48-point frame. Shared icon-action label now supplies a rectangular content shape;
  unchanged test passes. Password visibility preserves entered text.
- Pro Max final Mac run: 9 UI tests passed, including smallest/largest text, checkbox
  state, inline validation, OTP states and keyboard reachability. This is local RDE
  evidence, not latest PR-head CI or release completion.
- SE iOS 17.5: 8 auth UI tests passed before follow-up spacing request.
- Follow-up user choice: credential heading top inset 40 points, bottom manual inset
  zero (native safe area remains). Keep OTP's own spacing unchanged. Add bottom-gap
  regression assertion and capture new credential screenshots before final handoff.
- Follow-up spacing evidence: Pro Max and SE each passed 8 auth UI tests; result bundles
  `auth-spacing-pro-max.xcresult` and `auth-spacing-se.xcresult`. Detailed evidence/gaps
  in `artifacts/auth-sheet-polish-20261001.md`. No merge/CI/release completion claim.
