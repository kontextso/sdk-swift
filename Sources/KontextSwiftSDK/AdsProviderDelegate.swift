//
//  AdsProviderDelegate.swift
//  KontextSwiftSDK
//

import UIKit

public struct Ad {
    struct WebViewData {
        let url: URL?
        let updateData: UpdateIFrameData
        let onIFrameEvent: (InlineAdWebView, InlineAdEvent) -> Void
    }

    public let id: String
    public let messageId: String
    public let placementCode: String

    let preferredHeight: CGFloat
    let adsProviderActing: AdsProviderActing
    let bid: Bid
    let webViewData: WebViewData

    init(
        id: String,
        messageId: String,
        placementCode: String,
        preferredHeight: CGFloat,
        adsProviderActing: AdsProviderActing,
        bid: Bid,
        webViewData: WebViewData
    ) {
        self.id = id
        self.messageId = messageId
        self.placementCode = placementCode
        self.preferredHeight = preferredHeight
        self.adsProviderActing = adsProviderActing
        self.bid = bid
        self.webViewData = webViewData
    }
}

public protocol AdsProviderDelegate: class {
    func adsProvider(didChangeAvailableAdsTo ads: [Ad])
    func adsProvider(didUpdateHeightForAd ad: Ad)
}

struct AdState {
    let id: String
    let bid: Bid
    let messageId: String
    let webViewData: Ad.WebViewData
    var show: Bool
    var preferredHeight: CGFloat?
    var webView: InlineAdWebView?

}
