//
//  AdsProviderActor.swift
//  KontextSwiftSDK
//

import UIKit
import OSLog

// MARK: - AdsProviderActing

protocol AdsProviderActing: Sendable {
    func setDelegate(delegate: AdsProviderDelegate?) async

    func setDisabled(_ isDisabled: Bool) async

    func setMessages(messages: [AdsMessage]) async throws

    func reset() async
}

// MARK: - AdsProviderActor

actor AdsProviderActor: AdsProviderActing {
    /// Represents a single session of interaction within a conversation.
    /// A new sessionId is generated each time the SDK is initialized—typically when the user opens or reloads the app.
    /// This helps us track discrete usage periods, even within the same ongoing conversation.
    private var sessionId: String?
    /// Indicates whether the ads provider is disabled.
    private var isDisabled: Bool

    private var lastPreloadUserMessageId: String
    /// Preload timeout in seconds.
    private var preloadTimeout: Int

    /// Initial configuration passed down by AdsProvider.
    private let configuration: AdsProviderConfiguration
    private let adsServerAPI: AdsServerAPI
    private var delegate: AdsProviderDelegate?

    /// Last messages to sent to BE
    private var messages: [AdsMessage]
    private var bids: [Bid]
    private var states: [AdState]

    init(
        configuration: AdsProviderConfiguration,
        sessionId: String? = nil,
        isDisabled: Bool,
        adsServerAPI: AdsServerAPI,
        delegate: AdsProviderDelegate?
    ) {
        self.configuration = configuration
        self.sessionId = sessionId
        self.isDisabled = isDisabled
        self.adsServerAPI = adsServerAPI
        self.delegate = delegate
        messages = []
        bids = []
        states = []
        lastPreloadUserMessageId = ""
        preloadTimeout = 60
    }

    /// Enables or Disables the generation of ads.
    func setDisabled(_ isDisabled: Bool) {
        self.isDisabled = isDisabled
    }

    func setDelegate(delegate: (any AdsProviderDelegate)?) async {
        self.delegate = delegate
    }

    func setMessages(messages: [AdsMessage]) async throws {
        guard !isDisabled else {
            return
        }

        let newUserMessages = messages.filter { $0.role == .user }
        let messagesToSend = Array(messages.suffix(10))
        guard let lastUserMessage = newUserMessages.last else {
            return
        }

        let shouldPreload = lastPreloadUserMessageId != lastUserMessage.id
        self.messages = messages

        if shouldPreload {
            reset()
            notifyDelegate()
        } else {
            bindBidsToLastAssistantMessage()
            return
        }

        lastPreloadUserMessageId = lastUserMessage.id
        let preloadedData = try await preloadWithTimeout(
            timeout: preloadTimeout,
            sessionId: sessionId,
            configuration: configuration,
            api: adsServerAPI,
            messages: messagesToSend
        )

        if preloadedData.permanentError == true {
            isDisabled = true
            reset()
        }

        bids = preloadedData.bids ?? []
        sessionId = preloadedData.sessionId
        bindBidsToLastUserMessage()
        bindBidsToLastAssistantMessage()
    }

    func bindBidsToLastUserMessage() {
        bindBidsToLastMessage(forRole: .user, adDisplayPosition: .afterUserMessage)
    }

    func bindBidsToLastAssistantMessage() {
        bindBidsToLastMessage(forRole: .assistant, adDisplayPosition: .afterAssistantMessage)
    }


    private func bindBidsToLastMessage(forRole role: Role, adDisplayPosition: AdDisplayPosition) {
        // Messages have to be after the last preload user message
        guard let lastPreloadUserMessageIndex = self.messages
            .firstIndex(where: { $0.id == lastPreloadUserMessageId })
        else {
            return
        }
        let latestMessages = self.messages.suffix(from: lastPreloadUserMessageIndex)
        // Has not bind bids to last message yet
        guard !self.states.contains(where: { $0.bid.adDisplayPosition == adDisplayPosition })
        else { return }
        // Prepare last message id
        guard let lastMessageId = latestMessages.filter { $0.role == role }.last?.id
        else { return }
        // Find all bids that are associated with the ad display position
        let bids = self.bids.filter { $0.adDisplayPosition == adDisplayPosition }
        // Only take one bid for each unique code
        let uniqueBids = Dictionary(grouping: bids, by: { $0.code }).compactMap { $0.value.first }
        // Insert new states for last message id
        let stateId: String = UUID().uuidString
        let newStates = uniqueBids.map {
            AdState(
                id: stateId,
                bid: $0,
                messageId: lastMessageId,
                webViewData: self.prepareWebViewData(
                    stateId: stateId,
                    messageId: lastMessageId,
                    bid: $0
                ),
                show: true,
                preferredHeight: nil // Use default preferred height
            )
        }
        guard !newStates.isEmpty else { return }
        self.states.append(contentsOf: newStates)
        notifyDelegate()
    }

    func notifyDelegate() {
        self.delegate?.adsProvider(didChangeAvailableAdsTo: self.states
            .filter { $0.show }
            .map { self.buildAd(for: $0) }
        )
    }

    func prepareWebViewData(stateId: String, messageId: String, bid: Bid) -> Ad.WebViewData {
        Ad.WebViewData(
            url: self.adsServerAPI.frameURL(
                messageId: messageId,
                bidId: bid.bidId,
                bidCode: bid.code
            ),
            updateData:  UpdateIFrameData(
                sdk: SDKInfo.name,
                code: bid.code,
                messageId: messageId,
                messages: messages.suffix(10).map { MessageDTO (from: $0) },
                otherParams: [:] // Resolve other params
            ),
            onIFrameEvent: { webView, event in
                self.handleIFrameEvent(on: webView, event: event, stateId: stateId)
            }
        )
    }

    func handleIFrameEvent(on webView: InlineAdWebView, event: InlineAdEvent, stateId: String) {
        guard let stateIndex = self.states.firstIndex(where: { $0.id == stateId }) else {
            return
        }
        var newState = self.states[stateIndex]

        switch event {
        case .initIframe:
            // Handled by InlineAdWebView
            newState.webView = webView
            self.states[stateIndex] = newState
        case .showIframe:
            newState.show = true
            self.states[stateIndex] = newState
        case .hideIframe:
            newState.show = false
            self.states[stateIndex] = newState
            notifyDelegate()
        case .viewIframe(let viewData):
            os_log(.info, "[InlineAd]: View Iframe with ID: \(viewData.id)")
        case .clickIframe(let clickData):
            if let iframeClickedURL = if let clickDataURL = clickData.url {
                adsServerAPI.redirectURL(relativeURL: clickDataURL)
            } else {
                newState.webViewData.url
            } {
                UIApplication.shared.open(iframeClickedURL)
            }
        case .resizeIframe(let resizedData):
            guard resizedData.height != newState.preferredHeight else { return }
            newState.preferredHeight = resizedData.height
            self.states[stateIndex] = newState
            self.delegate?.adsProvider(didUpdateHeightForAd: self.buildAd(for: newState))
        case .errorIframe(let message):
            os_log(.error, "[InlineAd]: Error: \(message.message)")
            self.reset()
            notifyDelegate()
        case .unknown:
            break
        }
    }

    func reset(){
        // Remove all WebView handlers if possible
        self.bids = []
        self.states = []
    }

    func buildAd(for state: AdState) -> Ad {
        Ad(
            id: state.id,
            messageId: state.messageId,
            placementCode: state.bid.code,
            preferredHeight: state.preferredHeight ?? 0,
            adsProviderActing: self,
            bid: state.bid,
            webViewData: state.webViewData
        )
    }
}

private extension AdsProviderActor {
    func preloadWithTimeout(
        timeout: Int,
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        api: AdsServerAPI,
        messages: [AdsMessage]
    ) async throws -> PreloadedData {
        try await withThrowingTaskGroup(of: PreloadedData.self) { group in
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                throw CancellationError()
            }
            group.addTask {
                try await api.preload(
                    sessionId: sessionId,
                    configuration: configuration,
                    messages: messages
                )
            }

            guard let data = try await group.next() else {
                throw CancellationError()
            }

            group.cancelAll()
            return data
        }
    }
}
