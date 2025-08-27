//
//  InlinedAdViewModel.swift
//  KontextSwiftSDK
//

import Combine
import Foundation
import OSLog
import UIKit

@MainActor
final class InlineAdViewModel: ObservableObject {
    private let code: String
    private let messageId: String
    private let otherParams: [String: String]
//    private let adsProviderActing: AdsProviderActing

    private var messages: [AdsMessage] = []

//    @Published private var iframeHeight: CGFloat
//    @Published private var showIframe: Bool
//    @Published private(set) var iframeEvent: InlineAdEvent?
//    @Published private(set) var url: URL?
//    @Published private(set) var preferredHeight: CGFloat

    let ad: Ad

    init(
        ad: Ad
    ) {
        self.ad = ad
        messages = []
//        url = nil
//        preferredHeight = 0
//        iframeHeight = 0
//        showIframe = false
        code = ad.bid.code
        messageId = ad.messageId
        otherParams = [:] // Resolve other params if needed

    }
}

