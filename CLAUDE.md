# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build
swift build

# Run all tests
swift test

# Run a single test class or method
swift test --filter AdsProviderActorTests
swift test --filter "AdsProviderActorTests/testMethodName"
```

There is no separate lint step — the project uses `.enableExperimentalFeature("StrictConcurrency")` in `Package.swift`, so Swift's strict concurrency checking acts as the linter. Fix all concurrency warnings as part of any PR.

## Architecture

The SDK delivers AI-powered ads into iOS chat UIs. It is distributed via both Swift Package Manager and CocoaPods (`KontextSwiftSDK.podspec`). Minimum deployment target: iOS 14.

### Entry Point & Public API

**`AdsProvider`** (`Sources/KontextSwiftSDK/AdsProvider.swift`) is the only public class. One instance per chat conversation. It:
- Accepts an immutable `AdsProviderConfiguration` at init
- Exposes a Combine `eventPublisher` and `AdsProviderDelegate` for events (both deliver on main thread)
- Forwards `setMessages([MessageRepresentable])` calls into the internal actor
- Creates all dependencies via `DependencyContainer.defaultContainer()`

**`AdsProviderConfiguration`** (`AdsProviderConfiguration.swift`) holds all immutable per-conversation settings including `publisherToken`, `userId`, `conversationId`, `enabledPlacementCodes`, and server URLs.

### Internal Business Logic

**`AdsProviderActor`** (`AdsProviderActor.swift`) is a Swift `actor` that owns all mutable state:
- Holds last 30 messages and detects new user messages to trigger preloads
- Manages `AdLoadingState` per placement
- Orchestrates `AdsServerAPI.preload()` calls
- Handles SKAdNetwork impression lifecycle, SKOverlay, and StoreKit product views
- Emits `AdsEvent` values to its delegate (`AdsProvider`)

### Networking Layer

**`AdsServerAPI` protocol** / **`BaseURLAdsServerAPI`** (`Networking/AdsServerAPI.swift`):
- Switches between two base URLs based on ATT status (checked via `IFACollector.isTrackingAuthorized`):
  - Tracking authorized → `server.megabrain.co`
  - No ATT → `ctx.megabrain.co`
- `preload()`: POST to `/preload` with full device/app/message context
- `frameURL()` / `componentURL()`: Build iframe/component display URLs
- `redirectURL()`: Resolves relative redirect URLs

**`Networking`** (`Networking/Networking.swift`): Low-level async/await HTTP wrapper over `URLSession`.

DTOs live in `Networking/DTO/` and map directly to/from JSON. Domain models live in `Model/`. The conversion layer is `Networking/Mapping/` and `ModelConvertible`.

### UI Components

| Component | Type | Purpose |
|---|---|---|
| `InlineAdView` | SwiftUI View | Embeds ad in chat feed; reports dimensions to server |
| `InlineAdUIView` | UIView | UIKit equivalent of `InlineAdView` |
| `InterstitialAdView` | SwiftUI View | Full-screen ad overlay |
| `AdWebViewRepresentable` | UIViewRepresentable | SwiftUI wrapper for `AdWebView` |
| `AdWebView` | WKWebView subclass | Renders ad iframe; bridges JS `postMessage` to Swift |

`InlineAdViewModel` and `InterstitialAdViewModel` hold the view state and communicate with `AdsProviderActor`.

### Privacy & Attribution

- **`IFACollector`** (`Model/Info/IFACollector.swift`): Requests ATT, collects IDFA/IDFV, determines `isTrackingAuthorized`
- **`TCFInfo`** (`Model/Info/TCFInfo.swift`): Reads IAB TCF consent string from `UserDefaults` for GDPR compliance; merged with publisher-supplied `Regulatory`
- **`SKAdNetworkManager`**, **`SKOverlayManager`**, **`SKStoreProductManager`**: Privacy-preserving install attribution and App Store overlays/product views

### Dependency Injection

**`DependencyContainer`** (`Utils/DependencyContainer.swift`) is the only place where concrete types are wired together. Tests inject mock implementations via the internal `AdsProvider.init(dependencies:)`.

### Event System

`AdsEvent` (`Model/AdsEvent.swift`) is a rich enum covering: `cleared`, `filled`, `noFill`, `adHeight`, `viewed`, `clicked`, `renderStarted`, `renderCompleted`, `error`, `videoStarted`, `videoCompleted`, `rewardGranted`, `event`.

## Release Process

See `RELEASING.md` for full steps. In short:
1. Branch `release/X.Y.Z` from `develop`
2. Update `CHANGELOG.md`, `KontextSwiftSDK.podspec` (`s.version`), and `SDKInfo.swift` (`sdkVersion`)
3. PR to `develop`, then PR to `main`
4. Annotated tag: `git tag -a X.Y.Z -m "Release X.Y.Z"`
5. Publish: `pod trunk push KontextSwiftSDK.podspec --allow-warnings`
6. Create GitHub release

Version strings must not have a `v` prefix (e.g., `2.0.0`, not `v2.0.0`).