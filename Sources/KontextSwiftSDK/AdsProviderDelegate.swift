import UIKit

/// Delegate protocol to notify about ads availability and height changes
public protocol AdsProviderDelegate: AnyObject {
    /// Called when the available ads have changed
    func adsProvider(_ adsProvider: AdsProvider, didChangeAvailableAdsTo ads: [Advertisement])
    /// Called when the height of a specific ad has been updated
    func adsProvider(_ adsProvider: AdsProvider, didUpdateHeightForAd ad: Advertisement)
}
