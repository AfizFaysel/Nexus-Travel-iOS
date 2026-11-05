# PR-3 — Profile root and device appearance parity

## Outcome

Match the current Android Profile root in guest, loading, authenticated, recoverable error, and sign-out states. Keep appearance device-local and apply the Android light and charcoal roles from app startup. Verify on the installed Android app and on Bitrise simulators. Keep the evidence API fixtures outside Git.

## Truth sources

- Android `feature/profile/ProfileScreen.kt`, `ProfileViewModel.kt`, and the PreferencesViewModel in `ProfileDetailViewModels.kt`
- Android `data/profile/ProfilePreferencesStore.kt` and `RemotePreferencesRepository.kt`
- Android `MainActivity.kt` Profile route and root canvas, and `core/designsystem/NexusColors.kt`, `NexusTheme.kt`, `NexusTokens.kt`, `NexusTextStyles.kt`, and `component/NexusControls.kt`
- Android `core/config/NexusLegalDestinations.kt`, `core/support/{SupportOptionsPanel,SupportRepository,SupportDestinations}.kt`, and `core/network/NetworkRecoveryEffect.kt`
- Backend customer profile and mobile support controllers and response models
- Evidence process in `docs/plans/screen-parity-qa.md`

## Acceptance

- Profile uses the Android flat composition, exact role colors, typography, spacing, icons, actions, and copy. VoiceOver names and selection state are available and large type wraps without clipping.
- System, Light, and Dark are selectable as a guest, persist across relaunch, and are unaffected by account preferences. Shared visual values live in the central catalog.
- Open account details, saved travelers, legal destinations, and Support using their real routes. Preserve access to password reset and account deletion.
- Signed simulator artifacts show each applicable Profile state in both appearances. Include full, cropped, and scrolled evidence when content extends past the viewport. Compare the closest Android/iPhone viewport pair, then cover smaller and larger iPhones at both smaller and accessibility type sizes.

## Test-first and evidence

- Expected RED before the port: the guest Profile exposes no `Dark appearance` button, so `testGuestCanChangeAndRetainAppearance` fails before selecting it.
- Verify sign-in, Keychain persistence, and sign-out through the real API client on the fixture origin. Keep Android captures separate from iOS fixture captures and record unavailable Android states.

## Owned paths

- Profile root and appearance state under `Sources/Feature/Profile` and its app composition
- Shared role tokens, necessary icons, and existing tab bar styling where visible in the Profile comparison
- Profile support and legal wiring, simulator evidence origin configuration, and targeted Profile tests
