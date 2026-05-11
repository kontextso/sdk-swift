# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kontext Swift SDK — an iOS SDK for integrating AI-powered contextual ads into chat apps. Distributed via Swift Package Manager and CocoaPods (`KontextSwiftSDK`). Minimum deployment target: iOS 14.

Currently on the **v4** API. Full integration docs: https://docs.kontext.so/sdk/v4/swift.

## Common Commands

```bash
# Build and test on a real iOS Simulator (UIKit isn't on host macOS, so
# `swift build` / `swift test` won't work).
xcodebuild build \
  -scheme KontextSwiftSDK \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' \
  -skipPackagePluginValidation

xcodebuild test \
  -scheme KontextSwiftSDK \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' \
  -skipPackagePluginValidation
```

The project uses `.enableExperimentalFeature("StrictConcurrency")` in `Package.swift`, so Swift's strict concurrency checking acts as the linter. Fix all concurrency warnings as part of any PR.

## Architecture

### Public API (v4)

**`KontextAds`** (`Sources/KontextSwiftSDK/KontextAds.swift`) — the static entry point. `KontextAds.createSession(SessionOptions(...))` returns a `Session`.

**`Session`** — one instance per chat conversation. Lifecycle:
- Constructed with immutable `SessionOptions` (publisher token, user id, conversation id, placement codes, character, regulatory, etc.) plus a `MutablePublisherOptions` for things that can change at runtime (consent, character switch).
- Caller feeds messages via `session.addMessage(Message(...))` as the chat progresses.
- For each assistant message that should host an ad, caller creates one `Ad` via `session.createAd(messageId:)`.
- Events delivered via `Session.onEvent` callback (single closure) **and** `Session.eventPublisher` (Combine), both on the main thread.

**`Ad`** — per-message ad placeholder. Rendered via:

| Component | Type | Purpose |
|---|---|---|
| `InlineAdView` | SwiftUI View | Embeds ad in chat feed; reports dimensions to server |
| `InlineAdUIView` | UIView | UIKit equivalent of `InlineAdView` |
| `InterstitialAdView` | SwiftUI View | Full-screen ad overlay |
| `AdWebView` | WKWebView subclass | Internal: renders ad iframe; bridges JS `postMessage` to Swift |

**`AdEvent`** (`Sources/KontextSwiftSDK/Model/AdEvent.swift`) — discriminated enum covering `adFilled`, `adNoFill`, `adViewed`, `adClicked`, `adRenderStarted`, `adRenderCompleted`, `adError`, `videoStarted`, `videoCompleted`, `rewardGranted`, `event`. Each case carries placement code + bid id where applicable.

**`UserEventName`** — namespaced strings for `session.sendUserEvent(name:payload:)` (forwards events into the mounted ad iframes).

### Internal organization

- `Sources/KontextSwiftSDK/` — public types (`KontextAds`, `Session`, `Ad`, `SessionOptions`, …) at the top.
- `Sources/KontextSwiftSDK/Networking/` — `Init`, `Preload`, `ErrorCapture`, `DebugCapture`, `HTTPRetry`, DTOs in `DTO/`, request collectors in `Collectors/`.
- `Sources/KontextSwiftSDK/WebView/` — `AdWebView` + the JS `postMessage` bridge.
- `Sources/KontextSwiftSDK/View/` — SwiftUI + UIKit ad views.
- `Sources/KontextSwiftSDK/Model/` — Swift-side domain models (`Message`, `Bid`, `AdEvent`, `Character`, `Regulatory`, …).
- `Sources/KontextSwiftSDK/Utils/` — `DependencyContainer` (the only place concrete types get wired), helpers.

### Networking

- `/init` (background, non-blocking at session start) — returns server-controlled flags: `enabled`, `preloadTimeout`, `reportErrors`, `reportDebug`. The two reporting flags gate **only the network leg** — local logging always runs.
- `/preload` — POST with full device/app/message context after each user message (10 ms debounce).
- `/error`, `/debug` — fire-and-forget telemetry, gated by the corresponding `/init` flag.
- `HTTPRetry.fetch(...)` — single retry-wrapped fetch used for all calls. Backoff is exponential with an injectable `sleep` for tests (wall-clock timing assertions are flaky on CI).

### Privacy & attribution

The SDK does not vendor IDFA / ATT / StoreKit / OMID code directly. Those primitives live in **[KontextKit](https://github.com/kontextso/kontextkit-ios)**, a separate platform-utility package consumed by this SDK plus the iOS halves of `sdk-react-native` and `sdk-flutter`. The Package.swift / podspec here pull KontextKit transitively — publishers don't depend on it directly.

If a primitive feels like it should be in this repo but lives in KontextKit, that's intentional. Things that touch Apple system APIs or carry IAB OMID certification go there; things specific to Kontext's wire protocol or this SDK's API surface stay here.

### Dependency injection

`Utils/DependencyContainer.swift` is the only place where concrete types are wired together. Tests inject mocks via the internal `init(dependencies:)` constructors.

## Server-controlled telemetry

The `/init` response gates two reporting legs **per-user**:

- `reportErrors` (default `true`) — sends caught errors to `/error`.
- `reportDebug` (default `false`) — sends debug events to `/debug`.

Local logging (`print` + the publisher's `onDebugEvent` callback) always runs regardless — only the network leg is gated. Stable for the session's lifetime; recreating the session re-fetches `/init`.

## Release Process

See `RELEASING.md` for the full flow. In short:

1. Branch `release/X.Y.Z` from `main`.
2. Update `CHANGELOG.md`, `KontextSwiftSDK.podspec` (`s.version`), and `Sources/KontextSwiftSDK/SDKInfo.swift` (`sdkVersion`).
3. PR to `main`, merge.
4. Annotated tag: `git tag -a X.Y.Z -m "Release X.Y.Z"` and `git push origin X.Y.Z`.
5. Publish: `pod trunk push KontextSwiftSDK.podspec --allow-warnings --use-libraries`.

Version strings have no `v` prefix (`4.0.0`, not `v4.0.0`).

## Conventions

- **Swift 5.9**, iOS 14.0+. `StrictConcurrency` experimental feature is on — anything crossing actor boundaries must be `Sendable`.
- **No comments** unless the *why* is non-obvious (hidden constraint, subtle invariant, workaround for a specific bug, behavior that would surprise a reader). Don't reference PRs or tickets in code.
- **`@MainActor`-isolated** anything that touches UIKit or ATT. Bridges hop to MainActor explicitly.

## Related repos

- [kontextkit-ios](https://github.com/kontextso/kontextkit-ios) — shared iOS primitives this SDK depends on
- [sdk-v4](https://github.com/kontextso/sdk-v4) — monorepo where v4 was developed before extraction
- [sdk-kotlin](https://github.com/kontextso/sdk-kotlin) — Kotlin counterpart
