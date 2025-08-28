import UIKit

/// Representation of an Advertisement loaded by AdsProvider and intended for displaying
public struct Advertisement: Sendable, Hashable {
    /// Unique identifier generated for the advertisement
    public let id: UUID
    /// Id of the associated message
    public let messageId: String
    /// Placement code determining where the ad should be displayed
    public let placementCode: String

    let preferredHeight: CGFloat
    let bid: Bid
    let webViewData: AdLoadingState.WebViewData
}
