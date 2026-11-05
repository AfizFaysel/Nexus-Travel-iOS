# ADR-0007: Fully custom main tab container

- Status: Accepted
- Date: 2026-09-16

## Context

The app needs Nexus's floating bottom navigation on iPhone and iPad. `TabView` created native tab infrastructure even when its tab bar was hidden. On iPadOS, SwiftUI could adapt that infrastructure into top tab chrome; hiding it also left layout behavior tied to the native container. The product contract matches Android: four saved root tabs, independent histories, and a bottom bar only at each tab root.

## Decision

Replace `TabView` with an exhaustive switch over `Router.selectedTab`. Render exactly one native `NavigationStack` at a time and keep its path in `Router`. Keep `MainBottomBar` outside the stack in one `.safeAreaInset(edge: .bottom)`.

`Router` owns selected tab, four paths, pending authentication return intent, and Explore's selected filter. Selecting another tab changes selection only. Reselecting the current tab clears only its path. `showExplore(filter:)` updates filter and selection synchronously without pushing a synthetic Explore root.

`AppDependencies` constructs Home, Explore, Trips, and Profile root ViewModels once. `AppShell` owns one scroll target per root; each root scroll view binds `scrollPosition(id:)` to its target and uses stable section or item identifiers. Form fields, loaded content, Explore filter, Trips group, paths, and reading target survive tab switches. Process-death restoration is outside this decision.

Only selected root view exists. Its `.task` work is cancelled when it leaves the tree. Root ViewModels load idempotently, preserve valid state on cancellation, and can be refreshed explicitly. Profile logout clears trips data and the Trips path.

## Accessibility and interaction

- Each bottom-bar item remains a native SwiftUI `Button`, with a stable identifier, visible label, minimum touch height, and `.isSelected` trait.
- Inactive tabs are absent from hit testing and accessibility because they are not rendered.
- Native `NavigationStack`, system back gesture, sheets, Dynamic Type, and safe-area behavior remain in use.
- The bar appears only while the selected tab path is empty. It reserves space through `safeAreaInset`; content gets no duplicate manual bottom inset.
- Press feedback respects Reduce Motion.

## Alternatives considered

- Hidden `TabView`: rejected because it still creates/adapts native tab infrastructure and has produced OS-dependent layout behavior.
- Four live stacks in a persistent `ZStack`: rejected because inactive roots keep lifecycle work and accessibility/hit-testing state alive.
- UIKit hosting-controller wrapper: rejected because it adds a second navigation/container lifecycle to maintain.
- Third-party tab package: rejected because SwiftUI buttons and `NavigationStack` cover the requirement without dependency or ADR overhead.

## Evidence

- RED, iPhone 16e / iOS 18.6: `testCustomTabsExposeStableRootsAndOneSelection` failed because stable root identifiers did not exist before implementation. `testNativeTabBarIsAbsent` passed with the old hidden `TabView`, confirming that `XCUIApplication.tabBars` alone cannot prove the native container was removed.
- GREEN: Bitrise RDE passed 296 unit tests and 8 iPhone 16e UI tests (5 service/credential-dependent tests skipped). iPad Pro 13-inch M5 landscape acceptance passed with centered Home card, four custom tabs, one selected state, and no native tab bar. GitHub Actions run 35196649432 passed on PR head 4f88dea, including build/tests, privacy-manifest validation, and gallery evidence. Final device screenshot matrix is stored under `artifacts/screenshots/custom-tab-evidence/final-2026-09-17/`.
