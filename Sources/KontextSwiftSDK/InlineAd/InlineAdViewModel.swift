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
    private var cancellables: Set<AnyCancellable> = []

    @Published private var bid: Bid?
    @Published private var iframeHeight: CGFloat = 0
    @Published private var showIframe: Bool = false

    @Published private(set) var iframeEvent: AdEvent?
    @Published private(set) var url: URL?
    @Published private(set) var interstitialInput: InterstitialAdViewModel.Input?
    @Published private(set) var preferredHeight: CGFloat = 0

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

        bindData()
    }

    func send(_ action: InlineAdViewModel.Action) {
        switch action {
        case .didReceiveAdEvent(let inlineAdEvent):
            onAdEventAction(adEvent: inlineAdEvent)
        }
    }
}

// MARK: Data binding
private extension InlineAdViewModel {
    func bindData() {
        // Find relevant bid
        let bid = sharedStorage
            .$bids
            .receive(on: RunLoop.main)
            .map { [weak self] bid in bid.first { $0.code == self?.code } }
            .combineLatest(
                sharedStorage.$lastUserMessageId,
                sharedStorage.$lastAssistantMessageId,
                sharedStorage.$relevantAssistantMessageId
            )
            .map { [weak self] bid, lastUserMessageId, lastAssistantMessageId, relevantAssistantMessageId -> Bid? in
                guard let self, let bid else {
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

        bid.assign(to: &$bid)

        // Generate URL for WebView frame
        bid.map { [weak self] bid -> URL? in
                guard let self, let bid else {
                    return nil
                }
                return self.adsServerAPI.frameURL(
                    messageId: self.messageId,
                    bidId: bid.bidId,
                    bidCode: bid.code,
                    otherParams: otherParams
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

// MARK: Action
extension InlineAdViewModel {
    enum Action {
        case didReceiveAdEvent(AdEvent)
    }
}

// MARK: Action handler
private extension InlineAdViewModel {
    func onAdEventAction(adEvent: AdEvent) {
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

        case .openComponentIframe(let data):
            guard let bid else {
                return
            }

            interstitialInput = .init(
                id: bid.bidId,
                code: bid.code,
                messageId: messageId,
                component: data.component,
                timeoutInMilliseconds: data.timeout,
                otherParams: otherParams,
                adsServerAPI: adsServerAPI,
                onEvent: onInterstitialEvent
            )

        default:
            break
        }
    }

    func onInterstitialEvent(_ event: InterstitialAdViewModel.Event) {
        switch event {
        case .didFinishAd:
            interstitialInput = nil
        }
    }
}
