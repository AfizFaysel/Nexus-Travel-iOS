# Nexus Travel iOS — Agent Orchestration Entry Point

Native SwiftUI rewrite of the Android app. The Android repo is the **behavioral ground truth** (read-only):

```
C:\Users\Afiz\Desktop\Nexus-Travel-Android\app\src\main\java\com\nexustravel\app\
```

Same product, same UX, Apple-platform idioms. **Feature parity, not code parity.**

## Truth sources

| Need | Path |
|---|---|
| Logic/behavior reference | `Nexus-Travel-Android\...\com\nexustravel\app\{domain,data,feature,core}` |
| Design tokens | `...\core\designsystem\{NexusColors,NexusTextStyles,NexusTokens,NexusTheme,NexusStatus}.kt` |
| Component specs and states | `...\core\designsystem\component\*.kt` |
| Design-system gallery | `...\core\designsystem\gallery\DesignSystemGalleryScreen.kt` |
| Screen composition | `...\feature\**\*.kt` |

Android Kotlin code is sole product/design truth. Legacy PNGs, mockups, boards, PDFs, DOCX files, and handbooks are excluded from token values, parity decisions, acceptance criteria, and review evidence. Apple accessibility/platform requirements may change interaction mechanics, but any visible design deviation from Android code must be explicit and tested.

## Doc map (read in this order)

1. `docs/PORTING.md` — Kotlin→Swift rulebook + gap inventory. **Before writing any Swift.**
2. `docs/CONVENTIONS.md` — architecture + style rules for all Swift code.
3. `PLAN.md` — complete roadmap, current phase, active wave, dependencies, milestones, and live checklist. Coordinator-owned.
4. Assigned `docs/tasks/<ID>-*.md` — self-contained execution contract. **Read completely before task work.**
5. `docs/adr/` — recorded decisions. Never re-litigate; propose a new ADR instead. **ADR-0005 accepts email/password-only launch.**
6. `ARCHIVE.md` — merged completion and verification evidence. Read only entries relevant to current dependencies.

## Session loop (every agent run)

1. Read this file → `PLAN.md` header/current phase → assigned task packet.
2. If coordinating, pick one dependency-ready unchecked PLAN task, mark it `🔄`, then create/complete its packet before dispatch. Feature agents never edit PLAN or ARCHIVE.
3. Read every Android/backend code truth source listed by the packet completely before writing Swift. Never consult legacy design artifacts.
4. Implement following `CONVENTIONS.md` + `PORTING.md`.
5. **Adversarial self-review** (fresh pass, assume the port is wrong): compare behavior against every packet truth source. List every mismatch; fix it or record it in PR evidence.
6. Keep planning and test-first work local. After implementation and self-review, open the PR and record the tests run for its current head and any verification gaps.
7. After merge and task verification, the coordinator marks PLAN `[x]` and appends ARCHIVE evidence.
8. If review found a defect caused by a missing/ambiguous rule: update `PORTING.md`/`CONVENTIONS.md` too. Fix upstream, not just the instance.

## Hard rules

- **Mirror names 1:1** (`HomeViewModel`, `LoginScreen`, `SearchResultsResult`…). A bug report must open the same-named file on both platforms.
- **No third-party dependencies** without an ADR. URLSession/Codable/SwiftData/AsyncImage cover current needs.
- **No magic values**: raw hex colors, font sizes, spacing numbers live only in `Sources/Core/DesignSystem/`.
- **Never edit `NexusTravel.xcodeproj`** (generated). Edit `project.yml`, regenerate.
- **Git discipline**: never `git stash`, `git reset --hard`, force-push. Commits and PR title reference task ID (`PARITY SR-1: search results screen`).
- **Never claim "verified" without evidence.** Windows cannot compile UI Swift. Link applicable Mac or device evidence for the current PR head, then record it in ARCHIVE after merge.
- One feature chunk per agent run. Parallel tasks require merged dependencies and non-overlapping owned paths declared in their packets.
- PLAN and ARCHIVE are coordinator-only during task execution. Feature PRs never edit either ledger.
- Never open a planning-only or RED-only PR. The coordinator batches PLAN, task, and ARCHIVE changes into the next completed feature PR.

## Required skill routing

Load only skills relevant to touched work, then follow their supporting references:

- Every Swift change: `ponytail`, `write-swift`, `swift-expert`, `swift-api-design-guidelines`.
- Async, actors, tasks, `Sendable`, cancellation: `swift-concurrency-pro`.
- Module/state/dependency design: `improve-codebase-architecture`, `code-structure`, `dry-principle`, `swift-architecture`.
- Every behavior change/refactor uses `test-driven-development`. Author the test first and observe expected RED when runnable locally. For Windows-only SwiftUI work, record the expected failure in a test-first commit.
- SwiftUI screen/navigation/state: `swiftui-ui-patterns`, `apple-design`; strings also load `ux-copy` + `ui-typography`.
- Motion work: `apple-design`, `improve-animations`, `animation-vocabulary`. `improve-animations` audits and writes self-contained plans only; implementation happens in a later execution pass.
- Submission/release work: `app-store-review`; fetch current Apple requirements on audit date.
- Crashes, hangs, leaks, jank, performance: `debugging-instruments`; measure before optimizing.
- Lint setup/config: `swiftlint`; adding SwiftLint itself still requires an ADR under dependency policy.

## Architecture and code shape

- Choose smallest architecture that makes state ownership, dependencies, effects, navigation, and tests explicit.
- Preserve Android names and feature-level MVVM where ViewModels contain real presentation/orchestration behavior. Delete forwarding-only layers; do not introduce TCA/VIPER/Clean Architecture without measured pressure plus ADR.
- Views express state. Business rules, networking, persistence, formatting, and navigation orchestration stay outside `body`.
- Dependencies enter through initializers. `@Environment` is for true app-wide dependencies/config only; no service locator or global mutable state.
- Name injected properties/parameters by product role, not concrete type (`repository`, `sessionStore`, `clock`). Add feature qualifiers only to disambiguate multiple roles. Protocols use role nouns; concrete Adapters add mechanism prefixes (`Remote`, `Fake`, `Keychain`). Never use `I` prefixes or `Protocol`/`Impl` suffixes unless Swift API naming requires collision resolution.
- Concrete type first. Add protocol seam only when two adapters exist or repository fake/remote pairing already proves variation.
- DRY Rule of Three for operational logic. Configuration has one source immediately. Never merge coincidentally similar domain behavior.
- Actions/flows own product meaning, state transitions, auth/ownership policy, retry classification, and user-facing errors. Shared modules own reusable mechanics with explicit inputs and structured outputs; they never mutate domain persistence implicitly.
- One tested vertical slice at a time. No big-bang migration.

## Swift language and API rules

- Use Xcode 26.6 and XcodeGen 2.44.1 for the current project baseline. Do not use unreleased language features.
- Default data to `struct`/`enum`, `let`, value semantics, and invalid-state-eliminating enums. Use `class` only for identity/shared lifecycle; mark non-subclassed classes `final`.
- No `!`, `try!`, implicitly unwrapped optionals, `Any`, unsafe pointers, or `@unchecked Sendable` without a documented invariant and targeted justification.
- Use Swift API Design Guidelines: clarity at call site over brevity; role-based names; grammatical argument labels; imperative mutating verbs; result-describing nonmutating names; `make` factories; assertion-reading Booleans.
- Every public declaration gets a one-sentence `///` summary. Document parameters/results/errors plus any non-O(1) computed property complexity.
- Prefer native Foundation/SwiftUI APIs. No wrapper around an existing native async API, no speculative abstraction, no third-party package without ADR.
- Use `Logger`/`OSSignposter`, never `print`; default interpolated user/token/request data private. Include correlation ID for network workflows.

## Swift concurrency rules

- Swift 6 strict concurrency. Enable Approachable Concurrency; app/UI target default isolation is `MainActor` when supported by chosen toolchain.
- `async` expresses suspension, not automatic background work. URLSession already offloads I/O. Use `@concurrent` only for measured CPU work and only when supported by project toolchain.
- Prefer structured concurrency: `async let` for fixed children, bounded task groups for dynamic children. `Task {}` only at lifecycle/event seams with owned cancellation; `Task.detached` requires written justification.
- Treat every `await` as reentrancy point: leave state valid, re-check assumptions after suspension, never hold locks across it.
- Fix sendability by removing sharing, using value types, or actor isolation. Never silence diagnostics with `@unchecked Sendable`.
- Cancellation is behavior: propagate it, check it in long loops, cancel view-owned work on disappearance/input change, and never convert cancellation into user-visible failure.
- No timing-based async tests. Use controllable adapters/continuations and Swift Testing (`@Test`, `#expect`, `#require`) for new logic; XCTest remains for UI automation/performance metrics.

## SwiftUI and Apple interaction rules

- iOS 17+ Observation: root owns `@Observable` reference model with `@State`; children receive it explicitly. Use `@Binding` only for parent-owned value mutation.
- One `NavigationStack` per tab with typed routes and independent history. Model mutually exclusive sheets/alerts/routes as enums, not Boolean piles. Prefer `.sheet(item:)`.
- Async screens use `.task`/`.task(id:)` and explicit loading/content/empty/error states. Preserve cancellation and prevent stale response overwrite.
- Prefer native controls, sheets, materials, haptics, gestures, safe areas, Dynamic Type, Dark Mode, VoiceOver, and system typography before custom implementations.
- Feedback starts immediately. Gesture-driven motion tracks 1:1, preserves velocity, remains interruptible, and enters/exits through spatially symmetric paths.
- Default motion is restrained, critically damped spring behavior. Bounce only follows user momentum. High-frequency actions get shorter/subtler motion.
- Respect Reduce Motion, Reduce Transparency, and Increased Contrast. Reduced motion keeps comprehension via short crossfades/static transitions; never remove necessary feedback.
- Motion must serve feedback, orientation, continuity, or perceived performance. No decorative looping motion in core booking flow.
- Motion audit order: purpose/frequency, easing/duration, physicality/origin, interruptibility, performance, accessibility, cohesion/tokens, missed opportunities. Confirm every finding at file/line before planning.

## Backend contract rules

- Contract truth order: backend controllers/DTOs/e2e tests → deployed read-only probe → Android remote adapters/DTOs. Android remains behavior/UX truth, not sole network contract.
- Backend source: `C:\Users\Afiz\Documents\nexus-travel-backend\`. It is read-only unless user explicitly scopes backend changes.
- Production origin: `https://api.travelwithnexus.com`; configure once per build environment. Mobile prefix defaults to `/api/v1/mobile`; never duplicate either string across adapters.
- Health is `/api/v1/health`, not under `/mobile`.
- Launch auth is email/password only. No Google button and no Sign in with Apple until backend provider/token validation/revocation exists and ADR-0005 is replaced.
- Store bearer token in Keychain. `200 null` from `/api/auth/get-session` means unauthenticated. No refresh-token flow exists.
- Shared transport owns bearer attachment, request execution, decoding, timeout/network classification, HTTP status, and correlation logging. Repositories own domain-result mapping.
- Preserve ownership-hiding `404`; never reveal whether another user owns a resource.
- Operation-scoped idempotency keys survive retries for booking hold, passport upload, and account deletion. Never generate a new key per retry.
- Signed upload: create with bearer → PUT raw bytes to returned URL without bearer while applying every `requiredHeaders` entry → complete with bearer.
- Ignore additive JSON fields; do not silently accept missing required fields. Contract fixtures come from backend tests before each remote adapter.

## App Store rules (verify current policy at release time)

- Policy snapshot checked 2026-08-24; current rules always override this file.
- Email/password-only launch uses company-owned account system. Adding any social login reopens Guideline 4.8 and requires equivalent privacy-preserving login plus backend support.
- Flight/travel purchase is service consumed outside app: use non-IAP payment under Guideline 3.1.3(e). Do not add digital goods to this payment path.
- Account creation requires in-app account-deletion initiation. Model deletion as asynchronous request, show pending/completed/failure honestly, explain retained legal records, preserve retry idempotency, and provide support path.
- Every release reconciles runtime behavior, `PrivacyInfo.xcprivacy`, App Store privacy labels, privacy policy, permissions, SDK manifests/signatures, and ATT state. No tracking → no ATT prompt.
- Every entitlement and permission needs active feature, least privilege, contextual request, denial fallback, and specific usage description.
- Submission gate uses current required Xcode/iOS SDK (iOS 26 SDK minimum as of 2026-04-28), exact Release archive, working demo credentials, complete flows, accurate screenshots/metadata, and accessible in-app privacy policy.

## Lint, diagnostics, and performance

- SwiftLint config must pin the version, include `Sources` and `Tests`, exclude generated build outputs, add opt-in rules one at a time, and document the strict local command.
- Never run SwiftLint autocorrect in build phase. Targeted suppressions only, with reason; never blanket-disable all rules. Baseline may shrink, never grow to hide new failures.
- Debug from first compiler error. Use LLDB `v` before `po`; expression evaluation may mutate state.
- Profile Release builds with Instruments. Time Profiler for CPU/hangs, SwiftUI/Hitches for rendering, Allocations + Leaks + Memory Graph for lifetime, Network for request timing, Power Profiler for energy.
- No performance claim without trace/device evidence. Run accessibility and motion checks on real hardware before release.

## Every screen task must satisfy ALL of these before `[x]`

1. All four UI states implemented (loading / content / empty / error) — nothing stubbed.
2. Accessibility labels on icon-only controls; Dynamic Type does not clip text.
3. New permission introduced → purpose string added in the same commit (e.g. photo library for payment proof).
4. No beta/debug/test/lorem strings anywhere user-visible.
5. Flow works under the demo account from cold launch.
6. Copy reviewed for Apple tone (load `ux-copy` + `ui-typography` skills while writing strings).

Tasks flagged **CRITICAL** in PLAN.md are Apple-review rejection risks — treat gate evidence as mandatory, not optional.

## Verification gates

| Level | Runs where | How |
|---|---|---|
| Compiles | Mac | `xcodegen generate` and `xcodebuild` with the `NexusTravel` scheme |
| Unit logic | Mac | `xcodebuild test` with the `NexusTravel` scheme |
| UI behavior | Mac and iOS Simulator | `xcodebuild test` with the `NexusTravelUI` scheme |
| Visual parity | MacinCloud or local Mac | Simulator screenshots proving Android code-defined states and token use, linked in PR and ARCHIVE after merge |
| Reliability/perf | Real device via TestFlight | SE-class/low-RAM device, large Dynamic Type, offline flows |
