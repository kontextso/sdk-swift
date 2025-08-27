//
//  Advertisment.swift
//  KontextSwiftSDK
//

import UIKit

/// Representation of an Advertisement loaded by AdsProvider and intended for displaying
public struct Advertisement {
    /// Unique identifier generated for the advertisement
    public let id: String
    /// Id of the associated message
    public let messageId: String
    /// Placement code where the determining where the ad should be displayed
    public let placementCode: String

    let preferredHeight: CGFloat
    let bid: Bid
    let webViewData: AdLoadingState.WebViewData
}
