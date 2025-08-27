//
//  Advertisment.swift
//  KontextSwiftSDK
//

import UIKit

public struct Advertisment {
    public let id: String
    public let messageId: String
    public let placementCode: String

    let preferredHeight: CGFloat
    let bid: Bid
    let webViewData: AdLoadingState.WebViewData
}
