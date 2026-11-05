# PORTING.md — Kotlin→Swift Rulebook

The translation contract for every agent. If a rule proves wrong or incomplete, fix this file **in the same commit** (upstream fix), then apply it everywhere.

## 0. Ground rules

- **Port behavior, not syntax.** Where Swift has a more idiomatic equivalent that preserves observable behavior, take it — and record it below.
- **Names stay identical.** Types/functions/state keep Kotlin names.
- **Sealed result types stay.** Kotlin product/transport outcomes remain Swift result enums. Repository seams use `throws` only when needed to preserve cancellation or local secure-storage failures outside that result model.
- **Design truth is Kotlin code only.** Legacy design images, mockups, boards, documents, and handbooks are not inputs to implementation or review.

## 1. Translation table

| Kotlin | Swift | Notes |
|---|---|---|
| `package com.nexustravel.app.x` | Folder `Sources/x/` (same tree shape) | Folders are our namespaces |
| `data class Foo(val a: A)` | `struct Foo: Equatable, Hashable, Codable, Sendable` | Value semantics both sides |
| `data object X` | enum `case x`, or `static let x` | |
| `sealed interface R { data class Success(..); data object Empty }` | `enum R: Equatable, Sendable { case success(QuerySummary, [FlightOffer]); case empty }` | Associated values; case names lowerCamel |
| `interface FooRepository` | `protocol FooRepository: Sendable` | Pre-justified seam: fake today, real API later |
| `suspend fun get(): R` | `func get() async -> R` | Add `throws` only for cancellation or local secure-storage failure; modeled outcomes stay in `R` |
| `class FakeFooRepo : FooRepo` | `struct FakeFooRepo: FooRepo` | Stateful ones stay classes; `delay(850)` → `try? await Task.sleep(for: .milliseconds(850))` |
| `class XViewModel : ViewModel()` | `@MainActor @Observable final class XViewModel` | No base class; see §2 |
| `var state by mutableStateOf(v)` + `private set` | `private(set) var state: State = v` | `@Observable` tracks automatically |
| `val uiState: StateFlow<UiState>` + `collectAsState()` | Plain property; views read directly | |
| `viewModelScope.launch { }` | Stored `Task { }` at a view lifecycle/event seam; loads triggered by view `.task {}` | View owns replacement and disappearance cancellation; never fire-and-forget |
| `LaunchedEffect(key) { }` | `.task(id: key) { }` | |
| `LaunchedEffect(Unit) { }` | `.task { }` | |
| `Channel<Event>` + `receiveAsFlow()` | Closure parameter (`onAuthenticated: (AuthSession) -> Void`) | Event buses banned |
| `rememberSaveable { mutableStateOf(x) }` | `@SceneStorage` / `@AppStorage` (primitive keys), else `@State` | |
| `AppContainer(context)` | `struct AppContainer` with lazy props, built once in `App.init` | Manual DI survives unchanged |
| `NexusViewModelFactory { ... }` | **Delete.** Construct ViewModels directly | Factory exists only for Android framework needs |
| `NavHost` + `composable<Route> { }` | `NavigationStack(path:)` + `.navigationDestination(for: Route.self)` | See §3 |
| `@Serializable data class SearchResultsRoute(val searchId: String)` | Case in `enum Route: Hashable, Codable`: `case searchResults(searchId: String)` | One Route enum mirroring NexusRoutes.kt |
| `navController.popBackStack()` | `router.pop()` | |
| `popUpTo<X> { inclusive }` / `popBackStack(X, inclusive)` | Rebuild `path` array to desired suffix | Arrays make this trivial |
| Single NavHost + bottom bar tabs (`saveState`/`restoreState`) | App-owned `MainTab` selection + one selected `NavigationStack` bound to its Router path | Stable root ViewModels, each tab path, root selections, and stable scroll targets preserve tab state while inactive roots are not rendered |
| `BuildConfig.DEBUG` | `#if DEBUG` | |
| `rememberNexusAdaptiveSpacing()` Compact/Regular/Spacious | Pure screen-geometry resolver using identical width/height thresholds | Preserve all three Kotlin modes; inject geometry so boundary behavior is unit-testable |
| hardcoded strings / `stringResource` | Inline literals, text verbatim | Gap G8 |
| `24.dp` / `sp` sizes | Same numbers as pt; type styles via DesignSystem | Dynamic Type scaled |
| `OkHttp` / `NexusHttpClientFactory` / `NexusAuthenticatedRequest` | `URLSession` + thin request builder mirroring both | |
| `NetworkFailure` sealed type | `enum NetworkFailure: Equatable, Sendable` | Port cases verbatim |
| Room `NexusDatabase` / DAOs | SwiftData `@Model` + `ModelContainer` | Only in Phase 6 if fakes prove insufficient |
| Coil ImageLoader config | `AsyncImage`; URLCache defaults | Custom cache only on measured need |
| `MainBottomBar` | Native SwiftUI `Button`s in one root-only `.safeAreaInset(edge: .bottom)` | `MainTab` selection is the only selected-state source; buttons expose labels and `.isSelected` |

## 2. Canonical ViewModel pattern

```swift
@MainActor
@Observable
final class SearchResultsViewModel {
    private(set) var uiState: SearchResultsUiState = .loading

    private let searchId: String
    private let repository: any SearchResultsRepository

    init(searchId: String, repository: any SearchResultsRepository) {
        self.searchId = searchId
        self.repository = repository
    }

    func load() async {
        uiState = .loading
        switch await repository.getSearchResults(searchId: searchId) {
        case let .success(summary, offers): uiState = .content(/* display model */)
        case .empty:                        uiState = .empty
        case .networkUnavailable, .timeout, .unknownError:
            uiState = .error(/* presenter-mapped */)
        }
    }
}
```

- UiState mirrors Android sealed UiStates as enums: `.loading`, `.content(DisplayModel)`, `.empty`, `.error(UiError)`.
- `*DisplayMapper.kt` → `*DisplayMapper.swift` 1:1. Presenters (`AuthErrorPresenter`) port as-is.
- Views trigger loads with `.task { await viewModel.load() }`. No logic in `body`.
- Before each load, define duplicate and stale-result behavior. Cancellation restores prior valid state and never maps to user-visible failure.

## 3. Navigation pattern

```swift
enum Route: Hashable, Codable {
    case home, trips, profile
    case explore(filter: ExploreFilter)
    case searchResults(searchId: String)
    // ... mirrors NexusRoutes.kt 1:1
}

@MainActor @Observable
final class Router {
    var path: [Route] = []
    func push(_ r: Route) { path.append(r) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
}
```

- Four tabs (`MainTab`: home/explore/trips/profile) share one app-owned Router with four independent paths. Render only the selected tab in one native `NavigationStack(path:)`; stable root ViewModels and root scroll targets live above that conditional view so switching tabs preserves useful state and cancels inactive view tasks.
- The floating `MainBottomBar` appears only when the selected path is at its root. It uses native `Button`s and one `.safeAreaInset`, with no `TabView`, `UITabBar`, or UIKit appearance proxy. This avoids iPadOS-adapted top tab chrome and hidden-tab layout effects while keeping native push navigation, back gestures, and sheets.
- A cross-tab action such as Home → Travel packages updates Explore's filter and selects Explore in one synchronous Router operation. Do not push the Explore root as a child destination.
- `BookingFlowState` ports as `@MainActor @Observable final class BookingFlowState` (same fields: authenticated, offerReference, passengerDetails, submitPassengerDetailsAfterAuth…), owned by composition root, passed explicitly. It is THE seam between booking screens — never scatter its fields.
- Route is Codable → SceneStorage restoration possible later. Skip until needed.

## 4. Gap inventory

Compact choice sheets use content-measured native height detents, not a fixed `.medium`
detent; accessibility text uses scrollable `.large`. Measure intrinsic content before
any expanding frame. Simulator Keychain gates require native ad-hoc signing; unsigned
UI previews do not verify persistent-session behavior.

| ID | Gap | Decision |
|---|---|---|
| G1 | System back gesture | Free in NavigationStack; drop all BackHandler equivalents |
| G2 | Edge-to-edge / WindowInsets | Safe areas default-correct; sticky CTAs via `safeAreaInset(edge:.bottom)` |
| **G3** | **Google login button** | **Resolved: email/password-only launch.** Backend has no Google or Apple provider. Remove Google button. Do not add social login until backend token validation/revocation exists and ADR-0005 is replaced |
| G4 | Shimmer/loading effects | Rebuild with redaction/TimelineView; match `NexusMotion` durations |
| G5 | Coil disk cache tuning | URLCache defaults; tune on evidence only |
| G6 | `DesignSystemGalleryScreen` debug entry | Port in Phase 1 — visual regression harness |
| G7 | Multi-city search state | Nested struct in HomeViewModel state; pure logic ports directly |
| G8 | Localization | English inline (parity with Android today); extract when i18n scheduled |
| G9 | Android tests absent | We ARE the referee: Swift Testing suites per phase over validators/codecs/mappers/fakes; Android source is oracle |
| G10 | Android health route is `/api/v1/mobile/health` | Backend/live route is `/api/v1/health`; use backend route and add contract test |
| G11 | Account deletion modeled as immediate success | Backend queues an idempotent deletion request; model pending/completed/failure and explain retained legal records |

## 5. Backend contract

- Network contract truth: backend controllers/DTOs/e2e tests, then deployed read-only probe, then Android remote adapters.
- Backend source: `C:\Users\Afiz\Documents\nexus-travel-backend\` (read-only unless separately authorized).
- Production origin is `https://api.travelwithnexus.com`; set once in build config. Mobile prefix defaults to `/api/v1/mobile`.
- Keychain stores bearer token. `/api/auth/get-session` may return `200 null`; treat that as unauthenticated. Refresh is unsupported.
- Transport maps: cancellation, offline/DNS, connect timeout, request timeout, malformed response, `400`, `401`, `403`, ownership-hiding `404`, `409`, `422`, `429`, and `5xx`. Repositories map these to their existing sealed-result equivalents.
- Stable operation-scoped `Idempotency-Key` survives retries for hold, passport upload, and deletion.
- Signed uploads apply every server-returned required header to raw-byte PUT, without API bearer, then call authenticated completion.
- Before each remote adapter: copy backend request/response/status fixtures into a failing Swift contract test; then implement minimal adapter.

## 6. Do NOT port

- `MainActivity.kt` god-file shape (627-line nav graph). Split into: composition root in App, per-tab Routers, destination resolution per stack.
- `NexusViewModelFactory` and all factory boilerplate.
- Event channels (`Channel<*>`) — closures at call sites instead.
