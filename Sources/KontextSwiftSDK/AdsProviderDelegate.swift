import UIKit

/// Delegate protocol to notify about ads availability and height changes
public protocol AdsProviderDelegate: AnyObject {
    /// Called when an ad event occurred
    func adsProvider(_ adsProvider: AdsProvider, didReceiveEvent event: AdsEvent)
}
