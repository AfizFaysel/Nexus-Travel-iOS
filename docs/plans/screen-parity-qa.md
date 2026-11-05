# Screen parity and visual QA

## One screen at a time

Use the latest Android Kotlin screen, state holder, route, strings, components, and tokens as the product reference. Compare them with the iOS screen before editing. List missing states, controls, routes, and behaviors in the task packet. Implement and review one slice, then put the matched evidence in Downloads for review before taking on the next screen. Record any Apple interaction or accessibility difference with its reason and a capture.

All visual token values for the screen belong in the existing central catalog under `Sources/Core/DesignSystem`. Put colors and semantic roles in `NexusColors.swift`, spacing and other dimensions in `NexusTokens.swift`, and typography in `NexusTextStyles.swift`. Reuse existing roles when their meaning matches. Move every inline visual token you encounter on the screen into the catalog, including sizes, radii, strokes, opacities, and motion values. Layout mechanics such as a zero inset or an unbounded width are SwiftUI inputs. Any exception for a visual token requires explicit user approval while working on that screen.

## Use the production request path with external responses

Run a small HTTP fixture server on the Bitrise Mac, bound to loopback. Store its scenario files, server script, and synthetic media outside all repos. Upload the pack to a temporary runner directory. The iOS app launches normally and goes through its actual Router, Keychain session flow, ViewModels, repositories, request construction, URLSession, decoders, and error mapping. Only the API origin changes in the simulator evidence configuration. Release continues to resolve requests against `https://api.travelwithnexus.com`.

The insertion point is `Sources/Core/Network/AppConfiguration.swift`. It currently resolves every relative route against a constant origin. Resolve the origin at app composition and pass it through the existing `HTTPTransport` request builder. Preserve the mobile prefix, root auth paths, absolute URL behavior, headers, and timeouts. Gate the override behind a dedicated simulator-only evidence configuration in `project.yml`. Have the capture runner pass the loopback origin through `XCUIApplication.launchEnvironment`. An evidence build should reject a missing or invalid origin and should never fall back to the live API. Accept only a loopback origin with an explicit port and no credentials, path, query, or fragment. First prove loopback with the chosen simulator runtime. If HTTP needs an ATS exception, scope it to the evidence configuration and loopback. Verify the Release build has no override or test ATS setting. [Apple launch environment](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/launchenvironment) · [Apple ATS exception domains](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSAppTransportSecurity/NSExceptionDomains)

The external server matches method, path, query and request constraints to backend controller, DTO, and e2e contracts. It responds with authored status, headers, and bytes. Record unmatched requests and fail the run. Use synthetic credentials and a fresh or explicitly signed-out simulator account for each independent scenario. Use the normal sign-in screen for authenticated cases so token handling and session restoration are part of the run. Keep fixture image URLs, upload destinations, redirects, and checkout links local to the runner. For signed uploads, exercise create, raw PUT with the returned headers and no bearer, and completion. For writes, the fixture server should enforce the same idempotency behavior the screen relies on.

Make loading deterministic with a held response released after XCTest sees and captures the loading state. Drive retries by changing the next response at the server and tapping the real Retry button. For an offline state use a controlled transport failure, such as a dropped connection, when the app distinguishes that from an HTTP error. Put the fixture controls on the runner side. Pin locale, simulator model, text size, and fixture version in the manifest. Give date-sensitive fixtures relative dates in the external pack or a deliberate run date that keeps those dates valid.

The current `HTTPDataLoading` seam already works for narrowly scoped transport and mapper tests. The DEBUG auth previews are useful for isolated layout checks. Use the external server for parity evidence because it exercises request construction, decoding, navigation, and state transitions together. A separate seeded deployment of the actual backend is appropriate for server-side integration checks when needed. Keep a separate production demo-account smoke check as required by the project, with safe operations only. Fixture evidence covers the client against the API contract. It cannot establish what a deployed service currently returns.

### Keychain signing on the runner

Keep `CODE_SIGNING_ALLOWED=YES` for simulator builds and tests. Generate the project from `project.yml` with XcodeGen 2.44.1. Xcode wires `Sources/App/NexusTravel.entitlements` to the app target and uses a simulator ad hoc signature. Check the signature with `codesign -dvv <app>` and the simulator entitlement values in Xcode's generated `NexusTravel.app-Simulated.xcent` with `plutil -p`. The expanded application identifier and Keychain access group should match. `VisualEvidence` has its own bundle identifier and Keychain group so fixtures cannot leave a session in the production app. Use the regular Keychain in the evidence app. The smoke gate is a native write/read/delete round trip followed by sign-in, process relaunch, authenticated Profile, and sign-out against the fixture server. [Apple Keychain entitlement troubleshooting](https://developer.apple.com/forums/thread/114456) · [Apple ad hoc signing](https://developer.apple.com/documentation/security/seccodesignatureflags/adhoc)

## Profile and Appearance

Android's `ProfileScreen.kt` places Appearance on the Profile root for guests and authenticated users. Its device-local store keeps System, Light, or Dark across launches and account refreshes. iOS currently applies the choice through a nested Settings flow, and the semantic colors are fixed to the light palette. Move the control to Profile, keep one device-owned preference applied at app startup, and map Android's exact light and charcoal roles centrally. Account details, Saved travelers, and Support are their own review surfaces. Preserve existing access to password reset and account deletion when reorganizing the root.

Capture each applicable row in both light and dark. Also check System follows an OS appearance change, explicit appearance overrides it, and a selected appearance survives relaunch and profile refresh.

| Profile state | How to reach it through the app |
| --- | --- |
| Guest | Launch without a session and open Profile. Verify the sign-in row, Appearance, legal links, and Support. |
| Loading | Sign in with the synthetic account. Hold the profile response until the loading capture is attached. |
| Signed-in content | Release valid profile and traveler responses. Verify the account row, Saved travelers, and Sign out. |
| Recoverable error without cache | Fail the initial profile request, then serve a valid response after Retry. |
| Recoverable error with cache | Load a valid profile, fail a later refresh, and verify cached details and Retry. |
| Sign-out confirmation | Open the confirmation from signed-in content. Exercise cancellation and complete sign-out against the fixture server. |

The Android Profile root has no separate empty-account screen. Capture its guest state here and capture the empty traveler list when working on Saved travelers. If support is in the first packet, add its loading, populated, empty and retry states from the public `GET /api/v1/mobile/support` contract.

## Bitrise and interactive review

Use the Bitrise CLI's macOS **device session** with the repo's Xcode 26.6 baseline and a pinned phone profile. Verify the booted runtime and use its UDID throughout. Bitrise's built-in browser viewer gives the reviewer live taps, typing, swipes, appearance switching, and screenshots. For agent exploration, read the accessibility tree from the preinstalled serve-sim service, perform a tap or gesture with its CLI, then query the tree again. Use pixels for layout review and the tree for navigation. The platform guide gives the current endpoint and commands. Use one simulator so automated actions and the viewer see the same app. [Bitrise device sessions](https://docs.bitrise.io/en/bitrise-rde/devices/device-sessions)

```powershell
bitrise-cli rde device-guide ios
bitrise-cli rde session create nexus-ios-parity-qa --workspace $workspaceId `
  --stack osx-xcode-26.6.x --machine-type g2.mac.m2pro.6c-14g `
  --device-platform ios --device-model "iPhone 16e" --auto-terminate-minutes 90 --wait
bitrise-cli rde session exec nexus-ios-parity-qa --workspace $workspaceId -- xcodebuild -version
bitrise-cli rde session upload nexus-ios-parity-qa $externalFixturePack /tmp/nexus-fixtures --workspace $workspaceId
bitrise-cli rde session download nexus-ios-parity-qa /tmp/nexus-evidence "$env:USERPROFILE/Downloads/Nexus QA" --workspace $workspaceId
```

On the Mac, `curl -fsS "http://127.0.0.1:3200/helper/$UDID/ax"` returns the foreground accessibility tree. Find a control by identifier or label, then normalize the center of its frame using the root frame. From `~/serve-sim`, send the tap with `TMPDIR=/tmp node node_modules/.bin/serve-sim tap -d "$UDID" <x> <y>`. Confirm the destination in a fresh tree. Batch commands through one `rde session exec --shell` when they share state. [Bitrise device guide](https://docs.bitrise.io/en/bitrise-rde/devices/device-sessions)

Run the existing `NexusTravelUI` scheme with XCUITest for repeatable evidence. Use the booted simulator's UDID as the destination and disable parallel testing so capture follows the shared device. Drive by accessibility identifiers and wait for the actual target state. Use `xcrun simctl ui <UDID> appearance light|dark` for the System cases and the real Appearance controls for explicit overrides. Capture full-resolution PNGs with `XCUIScreen.main.screenshot()` and kept attachments. Export them from the `.xcresult` with `xcrun xcresulttool export attachments`. Use `xcrun simctl io <UDID> screenshot` for ad hoc captures. One capture flow can cover multiple states. Add targeted behavior tests where they catch a regression, such as account refresh overwriting the device's appearance. [Apple Xcode tools](https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference) · [Apple result attachment export](https://developer.apple.com/documentation/Xcode-Release-Notes/xcode-16_3-release-notes)

For a Codex agent, CLI plus serve-sim is the shortest setup because the Mac already has the interaction tool. Bitrise's hosted MCP can simplify session control if the client is connected and authenticated. Keep CLI upload/download for local packs and evidence. Callstack's `agent-device` is a runner-side option if direct element actions or cross-platform exploration are needed. It adds a tool to maintain and is unnecessary for the first slice. Keep XCUITest as the reproducible evidence path. [Bitrise CLI](https://docs.bitrise.io/en/bitrise-rde/rde-options/bitrise-rde-cli) · [Bitrise MCP](https://docs.bitrise.io/en/bitrise-rde/rde-options/bitrise-rde-mcp-server) · [Callstack agent-device](https://oss.callstack.com/agent-device/docs/quick-start)

## Evidence in Downloads

Use `Downloads/Nexus QA`. For each screen create a dated run folder with a named folder for each capture pass and a review manifest. For each state and appearance keep the original full viewport, an app-content or relevant detail crop derived from it, and full viewports after real scrolling where the screen scrolls. Preserve each original and label derivative crops. Mark scroll as inapplicable when all content fits. Name images consistently, for example `profile-guest-dark-full.png`. Record the iOS commit, Android source commit and installed build version, runner and OS, fixture-pack hash, scenario, appearance, viewport, scroll position, and any gap. Link the result bundle from the task's PR evidence.

For Android, use existing applicable device captures whose provenance matches the current code and state. Capture missing views from the connected phone's installed Nexus Trips with ADB. Use the app's own appearance controls, preserve the original phone preference, and keep full and cropped images separately. Stream PNG bytes with `adb exec-out screencap -p` through a binary-safe redirect or Python subprocess on Windows. Mark states the installed build cannot expose. The connected device reported Nexus Trips 1.0.1 (version code 2), while the checked-out Android Gradle file declares 1.0.0 (version code 2). Record both so the phone image can be checked against the Kotlin source. [Android ADB screen capture](https://developer.android.com/tools/adb#screencap)
