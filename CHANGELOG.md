# Changelog

## 2.1.0
* Add `requestTrackingAuthorization` option to `AdsProviderConfiguration` — set to `false` to suppress the SDK's ATT prompt and manage it yourself.
* Fix manually supplied `advertisingId`/`vendorId` now correctly take priority over automatically collected values.

## 2.0.4
* Add missing changelog entry for 2.0.3.

## 2.0.3
* Set NSPrivacyTracking to false and clear tracking domains.

## 2.0.2
* Remove UserAgent from request headers.

## 2.0.1
* Fix PrivacyInfo.xcprivacy file.

## 2.0.0
### Breaking
`AdsEvent.cleared` is a new case emitted when previously displayed ads are removed and a new preload is in progress. Integrations using exhaustive `switch` on `AdsEvent` without a `default` case must handle the new `.cleared` case.

* Added SKAdNetwork (SKAN) support for privacy-preserving install attribution.
* Added SKOverlay and SKStoreProductViewController support for native App Store presentation.
* Added App Tracking Transparency (ATT) and IFA collection support.
* Added Transparency & Consent Framework (TCF/GDPR) support.
* Added `skipCode` parameter to `AdsEvent.noFill` payload.
* Added request headers to preload API calls.
* Updated `isDisabled` — preload request still fires when disabled for session tracking, but no ad events are emitted.
* UserAgent, timestamp values and locale format (BCP 47) are now consistent across all SDKs.
* Fix battery level incorrectly reporting `-100` when battery state is unknown on simulator.
* Fix muted detection to use `< 0.01` threshold instead of float equality.
* Fix date format parsing.
* Fix component prop value parsing.

## 1.2.0
* Always send `ad.no-fill` event when ads are not available.

## 1.1.5
* Fix SDK name and version reported to backend (previously reported the containing app's values).
* Simplified README.

## 1.1.4
* Add `format` and `area` parameters to `AdsEvent.ClickedData`.
* Add `format` parameter to `AdsEvent.ViewedData`.
* Change `url` parameter on `AdsEvent.ClickedData` to non-optional.

## 1.1.3
* Make key properties on `Advertisement.Bid` public.

## 1.1.2
* Expose `AdsEvent` data properties as public.
* Add tests for `AdsProvider` event emitting.
* Fix decoding of events to use correct structure.
* Fix scroll behaviour disabled on WKWebView.
* Fix flaky tests.

## 1.1.1
* Remove predefined debugging messages from example apps.

## 1.1.0
* Add `AdsEvent` support: `filled`, `noFill`, `adHeight`, `viewed`, `clicked`, `renderCompleted`, `error`, `videoStarted`, `videoCompleted`, `rewardGranted`, `event`.
* Remove `AdsProviderDelegate` methods `didChangeAvailableAdsTo`, `didEncounterError`, `didUpdateHeightForAd`, `didReceiveEvent` and respective `AdsProviderEvent`s.
