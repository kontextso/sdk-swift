# Changelog

> This lists was started with version 1.1.0 and therefore no previous changes are listed here.

List of changes by respective version.

## [2.0.2](https://github.com//kontextso/sdk-swift/releases/tag/2.0.2)

Released on 2026-03-01.

### Updated

- UserAgent is now removed from request headers.


## [2.0.1](https://github.com//kontextso/sdk-swift/releases/tag/2.0.1)

Released on 2026-03-01.

### Fixed

- Fixed PrivacyInfo.xcprivacy file.


## [2.0.0](https://github.com//kontextso/sdk-swift/releases/tag/2.0.0)

Released on 2026-03-01.

### Breaking Changes

- Added new `AdsEvent.cleared` event that is emitted when previously displayed ads are removed and a new preload is in progress. Integrations using exhaustive `switch` on `AdsEvent` without a `default` case must handle the new `.cleared` case.

### Added

- SKAdNetwork (SKAN) support for privacy-preserving install attribution.
- SKOverlay and SKStoreProductViewController support for native App Store presentation.
- App Tracking Transparency (ATT) and IFA collection support.
- Transparency & Consent Framework (TCF/GDPR) support.
- `skipCode` parameter added to `AdsEvent.noFill` payload.
- Request headers added to preload API calls.

### Updated

- `isDisabled` functionality — preload request still fires when disabled for session tracking, but no ad events are emitted.
- UserAgent is now stable and consistent across all SDKs.
- Timestamp values are now consistent across all SDKs.
- Locale format updated to BCP 47 standard.

### Fixed

- Battery level no longer reports `-100` when battery state is unknown on simulator.
- Muted detection now uses `< 0.01` threshold instead of float equality.
- Date format parsing corrected.
- Component prop value parsing fixed.

## [1.2.0](https://github.com//kontextso/sdk-swift/releases/tag/1.2.0)

Released on 2025-10-02.

## Fixed

- Always send ad.no-fill event when ads are not avilable.

## [1.1.5](https://github.com//kontextso/sdk-swift/releases/tag/1.1.5)

Released on 2025-09-25.

## Updated

- Simplified README.md.

## Fixed

- SDK name and version reported to backend. It used name and version of containing app previously.

## [1.1.4](https://github.com//kontextso/sdk-swift/releases/tag/1.1.4)

Released on 2025-09-18.

## Added
 
- New parameters `format` and `area` for `AdsEvent.ClickedData`.
- New parameter `format` for `AdsEvent.ViewedData`.

## Updated

- Changed parameter `url` to non-optional for `AdsEvent.ClickedData`.


## [1.1.3](https://github.com//kontextso/sdk-swift/releases/tag/1.1.3)

Released on 2025-09-16.

## Added

- Make key properties on Advertisement's Bid public.

## [1.1.2](https://github.com//kontextso/sdk-swift/releases/tag/1.1.2)

Released on 2025-09-15.

### Added

- Exposed AdsEvent's Data properties as public.
- Tests for AdsProvider's event emitting.

### Fixed

- Decoding of Events is now using correct structure.
- Disabled scroll behaviour on WKWebView.
- Improved flaky tests.

## [1.1.1](https://github.com//kontextso/sdk-swift/releases/tag/1.1.1)

Released on 2025-09-10.

### Removed

- Removed predefined debugging messages from Example apps.
- Removed nexus-dev as value for publisherToken parameter from Example apps because it is not valid anymore.

## [1.1.0](https://github.com//kontextso/sdk-swift/releases/tag/1.1.0)

Released on 2025-09-04.

### Added

- Support for AdsEvents: `filled`, `noFill`, `adHeight`, `viewed`, `clicked`, `renderCompleted`, `error`, `videoStarted`, `videoCompleted`, `rewardGranted`, `event` (generic event).

### Removed

- `AdsProviderDelegate`'s methods for `didChangeAvailableAdsTo`, `didEncounterError`, `didUpdateHeightForAd`, `didReceiveEvent ` and respective `AdsProviderEvent`s.
