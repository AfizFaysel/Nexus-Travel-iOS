# Custom tab container implementation record

Accepted architecture: [ADR-0007](../adr/0007-custom-tab-container.md).

The former fallback proposal is superseded. Main navigation now renders only the selected tab's native `NavigationStack`; `Router` owns tab selection and independent paths, root ViewModels are created once in `AppDependencies`, and the floating bar uses one root-only `.safeAreaInset`.

State carried across tab switches: each tab path, root ViewModel state, Explore filter, Trips group, and stable root scroll target. Explore package navigation uses synchronous `Router.showExplore(filter:)`. No process-death restoration is added.

## Verification record

- RED, iPhone 16e / iOS 18.6: custom root/selection UI test failed before implementation because stable root identifiers were absent. The hidden native `TabView` passed `app.tabBars.count == 0`; this check does not detect an accessibility-hidden UIKit tab bar.
- GREEN focused Router, Explore, Home, Trips, and UI tests: passed on Bitrise RDE (iPhone 16e, iOS 18.6); 296 unit tests passed, 8 UI tests passed, 5 credential/service-dependent UI tests skipped.
- iPad landscape acceptance passed on Bitrise RDE (iPad Pro 13-inch M5, iPadOS 26.5), including centered Home search card, four visible custom tabs, one selected tab, and no native tab bar.
- Full hosted CI passed on PR head `4f88dea` (GitHub Actions run `35196649432`, macOS 26): build/tests, privacy-manifest validation, and gallery evidence all green.
- Interactive screenshots captured for iPhone SE 3, iPhone 11, iPhone 16e, iPhone 17 Pro Max, and iPad portrait/landscape under `artifacts/screenshots/custom-tab-evidence/final-2026-09-17/`; iPad landscape acceptance metrics confirm a 1376×1032 window, centered search card, and four equal tab frames.
