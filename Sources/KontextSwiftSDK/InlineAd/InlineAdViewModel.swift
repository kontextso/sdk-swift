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
    private let sharedStorage: SharedStorage
    private let adsServerAPI: AdsServerAPI
    private let adsProviderActing: AdsProviderActing

    private var messages: [AdsMessage] = []
    private var cancellables: Set<AnyCancellable>

    @Published private var iframeHeight: CGFloat
    @Published private var showIframe: Bool
    @Published private(set) var iframeEvent: InlineAdEvent?
    @Published private(set) var url: URL?
    @Published private(set) var preferredHeight: CGFloat

    var updateIFrameData: UpdateIFrameData {
        UpdateIFrameData(
            sdk: SDKInfo.name,
            code: code,
            messageId: messageId,
            messages: messages.map { MessageDTO (from: $0) },
            otherParams: otherParams
        )
    }

    init(
        sharedStorage: SharedStorage,
        adsServerAPI: AdsServerAPI,
        adsProviderActing: AdsProviderActing,
        code: String,
        messageId: String,
        otherParams: [String: String] = [:]
    ) {
        self.sharedStorage = sharedStorage
        self.adsServerAPI = adsServerAPI
        self.adsProviderActing = adsProviderActing
        self.code = code
        self.messageId = messageId
        self.otherParams = otherParams
        messages = []
        url = nil
        preferredHeight = 0
        iframeHeight = 0
        showIframe = false
        cancellables = []

        bindData()
    }

    func send(_ action: InlineAdViewModel.Action) {
        switch action {
        case .didReceiveAdEvent(let inlineAdEvent):
            onAdEventAction(adEvent: inlineAdEvent)
        }
    }
}

// MARK: Action
extension InlineAdViewModel {
    enum Action {
        case didReceiveAdEvent(InlineAdEvent)
    }
}

// MARK: Data binding
private extension InlineAdViewModel {
    func bindData() {
        // Find relevant bid
        let bid = sharedStorage
            .$bids
            .receive(on: RunLoop.main)
            .map { $0.first { $0.code == self.code } }
            .combineLatest(
                sharedStorage.$lastUserMessageId,
                sharedStorage.$lastAssistantMessageId,
                sharedStorage.$relevantAssistantMessageId
            )
            .map { bid, lastUserMessageId, lastAssistantMessageId, relevantAssistantMessageId -> Bid? in
                guard let bid else {
                    return nil
                }

                let isLastUserMessage = bid.adDisplayPosition == .afterUserMessage
                && lastUserMessageId == self.messageId
                let isLastAssistantMessage = bid.adDisplayPosition == .afterAssistantMessage
                && (relevantAssistantMessageId ?? lastAssistantMessageId) == self.messageId

                if isLastUserMessage == true || isLastAssistantMessage == true {
                    return bid
                } else {
                    return nil
                }
            }

        // Generate URL for WebView frame
        bid
            .receive(on: RunLoop.main)
            .map { bid -> URL? in
                guard let bid else {
                    return nil
                }
                return self.adsServerAPI.frameURL(
                    messageId: self.messageId,
                    bidId: bid.bidId,
                    bidCode: bid.code
                )
            }
            .assign(to: &$url)

        $showIframe.combineLatest($iframeHeight)
            .sink { [weak self] (showIFrame, iFrameHeight) in
                self?.preferredHeight = showIFrame ? iFrameHeight : 0
            }
            .store(in: &cancellables)
    }
}

// MARK: Actions
private extension InlineAdViewModel {
    func onAdEventAction(adEvent: InlineAdEvent) {
        switch adEvent {
        case .initIframe:
            break // Handled by InlineAdWebView

        case .showIframe:
            if sharedStorage.lastAssistantMessageId == messageId {
                sharedStorage.relevantAssistantMessageId = messageId
            }
            showIframe = true

        case .hideIframe:
            showIframe = false

        case .viewIframe(let viewData):
            os_log(.info, "[InlineAd]: View Iframe with ID: \(viewData.id)")

        case .clickIframe(let clickData):
            if let iframeClickedURL = if let clickDataURL = clickData.url {
                adsServerAPI.redirectURL(relativeURL: clickDataURL)
            } else {
                url
            } {
                UIApplication.shared.open(iframeClickedURL)
            }

        case .resizeIframe(let resizedData):
            iframeHeight = resizedData.height

        case .errorIframe(let message):
            os_log(.error, "[InlineAd]: Error: \(message.message)")
            showIframe = false
            Task { await adsProviderActing.reset() }
        case .unknown:
            break
        }
    }
}
