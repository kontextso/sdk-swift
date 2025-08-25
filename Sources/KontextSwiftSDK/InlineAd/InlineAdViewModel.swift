//
//  InlinedAdViewModel.swift
//  KontextSwiftSDK
//

import Combine
import Foundation
import OSLog

@MainActor
final class InlineAdViewModel: ObservableObject {
    private let code: String
    private let messageId: String
    private let otherParams: [String: String]

    @Published var iframeEvent: InlineAdEvent?
    @Published private(set) var bid: Bid?
    @Published private(set) var messages: [AdsMessage]
    @Published private(set) var url: URL?
    @Published private(set) var preferredHeight: CGFloat
    @Published private(set) var iframeClickedURL: URL?
    @Published private(set) var showIFrame: Bool

    private var cancellables: Set<AnyCancellable>

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
        self.code = code
        self.messageId = messageId
        self.otherParams = otherParams
        bid = nil
        messages = []
        url = nil
        preferredHeight = 0
        showIFrame = false
        cancellables = []

        // Find relevant bid
        sharedStorage
            .$bids
            .receive(on: RunLoop.main)
            .map { $0.first { $0.code == code } }
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
                && lastUserMessageId == messageId
                let isLastAssistantMessage = bid.adDisplayPosition == .afterAssistantMessage
                && (relevantAssistantMessageId ?? lastAssistantMessageId) == messageId

                if isLastUserMessage == true || isLastAssistantMessage == true {
                    return bid
                } else {
                    return nil
                }
            }
            .assign(to: &$bid)

        // Assign messages
        sharedStorage
            .$messages
            .receive(on: RunLoop.main)
            .assign(to: &$messages)

        // Generate URL for WebView frame
        $bid
            .receive(on: RunLoop.main)
            .map { bid -> URL? in
                guard let bid else {
                    return nil
                }
                return adsServerAPI.frameURL(
                    messageId: messageId,
                    bidId: bid.bidId,
                    bidCode: bid.code
                )
            }
            .assign(to: &$url)

        // Listen to iframe events and handle what's intended
        $iframeEvent
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                switch event {
                case .initIframe:
                    break // Handled by InlineAdWebView
                case .showIframe:
                    if sharedStorage.lastAssistantMessageId == messageId {
                        sharedStorage.relevantAssistantMessageId = messageId
                    }
                    self?.showIFrame = true
                case .hideIframe:
                    self?.showIFrame = false
                case .viewIframe(let viewData):
                    os_log(.info, "[InlineAd]: View Iframe with ID: \(viewData.id)")
                case .clickIframe(let clickData):
                    self?.iframeClickedURL = if let clickDataURL = clickData.url {
                        adsServerAPI.redirectURL(relativeURL: clickDataURL)
                    } else {
                        self?.url
                    }
                case .resizeIframe(let resizedData):
                    self?.preferredHeight = resizedData.height
                case .errorIframe(let message):
                    os_log(.error, "[InlineAd]: Error: \(message.message)")
                    self?.showIFrame = false
                    Task { await adsProviderActing.reset() }
                case .unknown:
                    break
                }
            }.store(in: &cancellables)
    }
}
