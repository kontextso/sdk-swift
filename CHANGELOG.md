# Changelog

List of changes by respective version.

> This lists was started with version 1.1.0 and therefore no previous changes are listed here.

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
