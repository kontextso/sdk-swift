//
//  AdLoadingState.swift
//  KontextSwiftSDK
//

import UIKit

struct AdLoadingState {
    let id: String
    let bid: Bid
    let messageId: String
    var show: Bool
    var preferredHeight: CGFloat?
    let webViewData: AdLoadingState.WebViewData
}

extension AdLoadingState {
    struct WebViewData {
        let url: URL?
        let updateData: UpdateIFrameData
        let onIFrameEvent: (InlineAdEvent) -> Void
    }
}
