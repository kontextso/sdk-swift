
import UIKit

public enum KontextError: Error {
    /// No ad was generated for a message
    case adUnavailable(messageId: String)
}

/// Event types for Publisher if that is preferred over delegate
public enum AdsProviderEvent {
    /// Sent when the available ads have changed
    case didChangeAvailableAdsTo([Advertisement])
    /// Sent when the height of a specific ad has been updated
    case didUpdateHeightForAd(Advertisement)
    /// Sent when an iFrame event occurred
    case didReceiveEvent(AdsEvent)
    /// Called when user views an ad
    case didViewAd(ViewAdEventData)
    /// Called when user clicks an ad
    case didClickAd(ClickAdEventData)
    /// Called when en error occurs in the process of preparing an advertisement.
    case didEncounterError(KontextError)
}

/// Delegate protocol to notify about ads availability and height changes
public protocol AdsProviderDelegate: AnyObject {
    /// Called when the available ads have changed
    func adsProvider(_ adsProvider: AdsProvider, didChangeAvailableAdsTo ads: [Advertisement])
    /// Called when en error occurs in the process of preparing an advertisement.
    func adsProvider(_ adsProvider: AdsProvider, didEncounterError: KontextError)
    /// Called when the height of a specific ad has been updated
    func adsProvider(_ adsProvider: AdsProvider, didUpdateHeightForAd ad: Advertisement)
    /// Called when an iFrame event occurred
    func adsProvider(_ adsProvider: AdsProvider, didReceiveEvent event: AdsEvent)
    /// Called when user views an ad
    func adsProvider(_ adsProvider: AdsProvider, didViewAd: ViewAdEventData)
    /// Called when user clicks an ad
    func adsProvider(_ adsProvider: AdsProvider, didClickAd: ClickAdEventData)
}

/// Default implementations
public extension AdsProviderDelegate {
    func adsProvider(_ adsProvider: AdsProvider, didReceiveEvent event: AdsEvent) {}
    func adsProvider(_ adsProvider: AdsProvider, didViewAd: ViewAdEventData) {}
    func adsProvider(_ adsProvider: AdsProvider, didClickAd: ClickAdEventData) {}
}
