# Development

This guide is for contributors working on the Kontext Swift SDK locally. For an end-user integration guide, see the [docs site](https://docs.kontext.so/sdk/v4/swift).

## Prerequisites

- **macOS 14+** with **Xcode 16.0+** (the project targets the iOS 18 SDK)
- **iOS 14+ Simulator** or a physical device for the example apps. Simulators ship with Xcode; manage them via Xcode → Window → Devices & Simulators, or `xcrun simctl`.
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** for regenerating the example app `.xcodeproj` files from `project.yml`. Install: `brew install xcodegen`.
- **[SwiftLint](https://github.com/realm/SwiftLint)** for the lint job. Install: `brew install swiftlint`.

Swift 5.9 ships with Xcode 16; nothing extra to install. The SDK itself is a Swift Package — `swift build` won't work on host macOS because the library imports `UIKit`, but the SDK's tests run on the Simulator.

## Repository layout

```
sdk-swift/
├── Sources/KontextSwiftSDK/         # public SDK source (entry points, networking, WebView bridge, models)
├── Tests/KontextSwiftSDKTests/      # XCTest + swift-testing suites
├── ExampleUIKit/                    # UIKit demo app (XcodeGen)
│   ├── project.yml                  # XcodeGen input
│   └── ExampleUIKit/                # app sources
├── ExampleSecrets.swift.example     # template for the gitignored ExampleSecrets.swift (see "Setting your publisher token")
├── Package.swift                    # SPM manifest
├── KontextSwiftSDK.podspec          # CocoaPods manifest (alternative distribution)
├── .swiftlint.yml                   # SwiftLint rules
├── CLAUDE.md                        # Claude Code project context
└── RELEASING.md                     # how to cut a release
```

## Building & testing the SDK

```bash
# Build the SDK target
xcodebuild build \
  -scheme KontextSwiftSDK \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro' \
  -skipPackagePluginValidation

# Run the full test suite
xcodebuild test \
  -scheme KontextSwiftSDK \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro' \
  -skipPackagePluginValidation

# Run a single suite (swift-testing identifier)
xcodebuild test \
  -scheme KontextSwiftSDK \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro' \
  -skipPackagePluginValidation \
  -only-testing 'KontextSwiftSDKTests/BidDTOTests'
```

The exact simulator name (`iPhone 17 Pro` here) must exist on your machine. List installed simulators with:

```bash
xcrun simctl list devices available
```

## Running the example app

The demo app lives in `ExampleUIKit/`. It consumes the local SDK via SPM and demonstrates the public v4 API end-to-end.

### Setting your publisher token

The example app references `ExampleSecrets.publisherToken` at build time. The file `ExampleSecrets.swift` is **gitignored** — your token never gets committed.

1. Copy the template into place:

   ```bash
   cp ExampleSecrets.swift.example ExampleSecrets.swift
   ```

2. Edit `ExampleSecrets.swift` and replace `YOUR_PUBLISHER_TOKEN` with your real publisher token. The `iab-certification` value is the public IAB OMID-certification token — useful when running the example against the OMID validator proxy, but not for ad serving against a real publisher.

3. Build the example app — the token compiles into the binary via `ExampleSecrets.publisherToken`.

If `ExampleSecrets.swift` is missing the Xcode build fails immediately with "No such file or directory" pointing at the missing file. Run the `cp` step above and retry.

### Building & running

The example has its `.xcodeproj` checked in (regenerated from `project.yml` via XcodeGen — see "Regenerating the Xcode project" below). Open the project in Xcode and Run, or use the CLI:

```bash
xcodebuild build \
  -project ExampleUIKit/ExampleUIKit.xcodeproj \
  -scheme ExampleUIKit \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 17 Pro'
```

Run via Xcode's Run button (⌘R) or `xcrun simctl install` + `xcrun simctl launch`.

### Watching SDK logs

The SDK logs every internal event (preload start/response, bid assignment, ad mount, errors, etc.) to stdout via the publisher's `onDebugEvent` callback. The example app wires it up to `print("[kontext-debug] ...")`. Stream them live with Xcode's debug console or by tailing the simulator:

```bash
# Stream the booted simulator's stdout for the example app's bundle id
xcrun simctl spawn booted log stream \
  --predicate 'process == "ExampleUIKit"' \
  --style compact
```

To inspect WKWebView traffic (useful when debugging the iframe bridge):

1. Run the app on the Simulator (Safari Web Inspector requires an unsigned debug build, which Xcode produces by default).
2. Open Safari → Preferences → Advanced → enable "Show features for web developers".
3. Safari → Develop → \[Your Simulator] → \[your app] → \[iframe URL]. The iframe DOM, JS console, and network panel are all live.

### Booting a simulator from the CLI

```bash
# List installed simulators
xcrun simctl list devices available

# Boot one (replace the ID with one from the list above)
xcrun simctl boot 'iPhone 17 Pro'

# Open Simulator.app so the UI is visible
open -a Simulator
```

## Code style

- **Swift 5.9, iOS 14.0+ deployment target.**
- **`StrictConcurrency` experimental feature is on** (see `Package.swift`) — anything crossing actor boundaries must be `Sendable`. Treat strict-concurrency warnings as errors; they're the lint signal.
- **`@MainActor`-isolated** anything that touches UIKit or ATT. Bridges from RN / Flutter hop to MainActor explicitly.
- **No comments by default** — add one only when the *why* is non-obvious (hidden constraint, subtle invariant, workaround for a specific bug, behaviour that would surprise a reader). Don't reference PRs or tickets in code.
- **SwiftLint** runs over `Sources/` and `Tests/` per `.swiftlint.yml`. Configuration is intentionally minimal — most rules use SwiftLint defaults.

## Regenerating the Xcode project

The example app's `.xcodeproj` is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.pbxproj` is committed so cloning + opening in Xcode Just Works, but if you change `project.yml` (e.g. to add a new source file) you have to regenerate:

```bash
cd ExampleUIKit && xcodegen generate
```

Commit the regenerated `.pbxproj` alongside the `project.yml` change.

## CI

`.github/workflows/ci.yml` runs two jobs on every push and PR:

- **lint** — `swiftlint lint --strict` and `xcodebuild analyze` on the SDK target
- **test** — `xcodebuild test` on the SDK target

Both run on `macos-15` with Xcode 16.4 / iPhone 16 / iOS 18.5.

## Testing against the OMID validator

The IAB OMID validator proxy lets you observe the JS-side OMID session events for a running ad. To use it:

1. Set `ExampleSecrets.publisherToken = "iab-certification"` (the public OMID-cert token).
2. Run the example app on a Simulator with `iPhone 17 Pro` (or whichever device profile the validator expects).
3. Open https://omid-validator-proxy.fly.dev (or the local validator dashboard if you've deployed one) and connect.
4. In the chat UI, send a message containing the magic content string `kontextso ad_id:170036` — the server returns an OMID-cert ad whose iframe registers with the validator.
5. Watch the validator dashboard for the full session lifecycle: `sessionStart`, `geometryChange`, `loaded`, `impression`, video-specific events (`start`, quartiles, `complete`), `sessionFinish`.

Display sessions should produce: `sessionStart → geometryChange(100%) → loaded → impression(pIV: 100) → sessionFinish` with no extraneous events. Any `geometryChange { reasons: ["notFound"] }` between the last valid geometryChange and sessionFinish is a regression.

Video sessions should produce the same prefix plus the full media lifecycle, with the impression payload reporting non-zero `adView.geometry` (the actual video element dimensions, not 0×0).

## Cross-SDK consistency

The Swift SDK is one of three v4 SDKs (alongside [sdk-kotlin](https://github.com/kontextso/sdk-kotlin) and the in-monorepo [sdk-flutter](https://github.com/kontextso/sdk-v4/tree/main/sdk/sdk-flutter) / sdk-react-native). They share a wire protocol and a deliberate file-structure parity: `Configuration.swift` / `Configuration.kt`, `Inbound.swift` / `Inbound.kt`, `Session.swift` / `Session.kt`, etc.

When adding a new type or renaming an existing one, **match the Kotlin counterpart**. If you can't, leave a comment explaining the mismatch.

## KontextKit dependency

The shared iOS primitives — IDFA, ATT, StoreKit, OMID lifecycle, device info, in-app browser — live in [KontextKit](https://github.com/kontextso/kontextkit-ios), distributed via SPM + CocoaPods. The version is pinned in `Package.swift` and `KontextSwiftSDK.podspec`.

For local development against an unreleased KontextKit, point the SPM package at a sibling checkout:

```swift
// In Package.swift, replace the .package(url: ...) entry with:
.package(path: "../kontextkit-ios"),
```

Then revert before merging. (Package-path overrides are not committed — they don't survive consumer SPM resolution.)

## OMID xcframework

KontextKit transitively pulls `OMSDK_Kontextso.xcframework` (the binary OMID SDK from IAB). You do not need to add it to this repo or to your example app — KontextKit's `OMManager` owns the activation and exposes the public surface `sdk-swift` uses.
