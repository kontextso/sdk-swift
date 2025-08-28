
import UIKit

/// Event types for Publisher if that is preferred over delegate
public enum AdsProviderEvent {
    /// Sent when the available ads have changed
    case didChangeAvailableAdsTo([Advertisement])
    /// Sent when the height of a specific ad has been updated
    case didUpdateHeightForAd(Advertisement)
}

/// Delegate protocol to notify about ads availability and height changes
public protocol AdsProviderDelegate: AnyObject {
    /// Called when the available ads have changed
    func adsProvider(_ adsProvider: AdsProvider, didChangeAvailableAdsTo ads: [Advertisement])
    /// Called when the height of a specific ad has been updated
    func adsProvider(_ adsProvider: AdsProvider, didUpdateHeightForAd ad: Advertisement)
}
