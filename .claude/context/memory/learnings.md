# Learnings

## 2026-08-24

- Backend contract truth lives in `C:\Users\Afiz\Documents\nexus-travel-backend`; similarly named Desktop folder contains no source.
- Network contract order: backend controllers/DTOs/e2e tests, deployed read-only probe, Android remote adapters.
- Android health route is stale: production/backend use `/api/v1/health`.
- Launch auth is email/password only; backend has no Google or Apple provider.
- Booking hold, passport upload, and account deletion require stable operation-scoped idempotency keys.
- Do not extract shared cache mechanics before third same-domain instance; keep different cache semantics separate.

## 2026-09-10

- Bitrise RDE browser access works through SSH local forwarding to session VNC host, then local websockify/noVNC; session hosts and passwords must remain runtime env values.

- XcodeGen: adding a standalone `.xcassets` catalog makes Xcode require configured `AppIcon`. For one custom SVG, declare its folder under target `resources` and load through `Bundle` with a native fallback.
- Bitrise RDE Windows directory upload preserves backslashes as literal remote filenames. Zip with POSIX archive paths, upload zip, then unzip remotely.

## 2026-09-14

- iPadOS 26 ignores tab visibility applied only to the outer `TabView`; `toolbarVisibility(.hidden, for: .tabBar)` on each tab's `NavigationStack` hides the elevated top bar.
- Keep iOS 17's legacy `.toolbar(.hidden, for: .tabBar)` at the `TabView` root; the child visibility modifier changes the older Home layout proposal.
- Home uses one Dynamic Type accessibility breakpoint with `AnyLayout`; wide displays use a centered 720-point outer content limit.

## 2026-09-21

- Public app artwork may remain in private R2: keep server-owned keys under strict prefixes and return 24-hour signed URLs. Airline records keep semantic `logoKey`; API resolves it to `airlines/{logoKey}.png` so clients stay storage-agnostic.
- Bitrise RDE directory upload from Windows can flatten path separators. Create a POSIX-path zip with `tar.exe`, upload it, then unzip on macOS.

## 2026-09-22

- Airline fallback artwork uses versioned private-R2 key `airlines/fallback-tail-v1.png`; R2 sends `public, max-age=31536000, immutable`, backend reuses each 24-hour signed URL for 23 hours, and changing key version invalidates native iOS URLCache and Android Coil entries without custom mobile cache code.
- Search-result row parity depends on one width/spacing-mode resolver: Android uses 12-point section gaps plus 14/16/18-point row padding. Divider has no vertical padding, follows adaptive horizontal margin, and renders at 42% opacity. A 164-point iOS row gate was incorrect; spacious one-way rows render near 196 points.
- Seat-map absence is not one Boolean. Backend already models `AVAILABLE`, `NOT_PROVIDED`, `NOT_SUPPORTED`, and `TEMPORARILY_UNAVAILABLE`; clients skip deterministic absence, but transient failure offers Retry plus Continue without seats.
- Error presentation has two shared modes: status-colored `NexusBanner` with a text retry action while content remains usable, and `NexusFeedbackPanel` for blocking failures. Screen state owns whether retry is safe; the shared view owns colors, spacing, and action layout.

## 2026-09-24

- Fare revalidation keeps HTTP 503 for compatibility, but backend emits `OFFER_UNAVAILABLE` only for confirmed inventory loss and `FARE_CONFIRMATION_FAILED` for supplier uncertainty. Both mobile clients map the code, block Continue after uncertain retry, and hide a confirmed-unavailable offer from cached search results.
- Booking safety needs one server-owned accepted quote revision and conditional state writes. A separate transition assertion before an unconditional update does not prevent seats, traveler data, payment, or expiry races after hold.

## 2026-09-25

- Flight timelines should anchor decorative dots and dashed connectors to the rendered airport-code bounds with SwiftUI anchor preferences. Fixed-height connectors drift when Dynamic Type stacks times, metadata wraps, or screen width changes. Draw in a background Canvas so decoration does not affect layout or VoiceOver.

## 2026-10-01

- Native inset sheets scale XCTest accessibility frames with sheet width. Compare control heights after normalizing by sheet-width/window-width ratio; do not inflate logical design tokens to compensate. Pro Max inset sheet measured 424/440; SE full-width sheet retained logical 60-point CTA and 44-point text-action heights.
- AuthScaffold owns measured native detents for credential, OTP and recovery sheets. Keep standalone onboarding layout separate; accessibility text uses large scrollable detent. Shared auth CTA token is 60 points, not global button default.
- A plain SwiftUI icon Button can expose only its glyph bounds despite a larger label frame. Apply contentShape(Rectangle()) inside the framed label; test the accessible hit bounds, not merely token values.
- Keep sheet-layout selection independent of helper-copy presence. Adding a subtitle must not silently select standalone branding/padding.
- iOS has no native checkbox ToggleStyle. A small custom ToggleStyle can retain native Toggle semantics with accessibilityRepresentation; explicitly choose switch style for that representation to avoid recursive style inheritance.
