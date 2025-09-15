@preconcurrency import Combine
import OSLog
import UIKit

// MARK: - AdsProviderActor

actor AdsProviderActor {
    /// Represents a single session of interaction within a conversation.
    /// A new sessionId is generated each time the SDK is initialized—typically when the user opens or reloads the app.
    /// This helps us track discrete usage periods, even within the same ongoing conversation.
    private var sessionId: String?
    /// Indicates whether the ads provider is disabled.
    private var isDisabled: Bool

    private var lastPreloadUserMessageId: String
    /// Preload timeout in seconds.
    private var preloadTimeout: Int

    /// Last messages to sent to BE
    private var messages: [AdsMessage]
    private var bids: [Bid]
    private var states: [AdLoadingState]
    private var omSessions: [OMSessionState]

    private let numberOfRelevantMessages = 10

    /// Events published to interstitial and inline components
    private let inlineEventSubject = PassthroughSubject<InlineAdEvent, Never>()
    private let interstitialEventSubject = PassthroughSubject<InterstitialAdEvent, Never>()
    private var interstitialTimeoutTask: Task<Void, Never>?

    /// Initial configuration passed down by AdsProvider.
    private let configuration: AdsProviderConfiguration
    private let adsServerAPI: AdsServerAPI
    private let omService: OMServicing
    private weak var delegate: AdsProviderActingDelegate?

    init(
        configuration: AdsProviderConfiguration,
        sessionId: String? = nil,
        isDisabled: Bool,
        adsServerAPI: AdsServerAPI,
        omService: OMServicing
    ) {
        self.configuration = configuration
        self.sessionId = sessionId
        self.isDisabled = isDisabled
        self.adsServerAPI = adsServerAPI
        self.omService = omService
        delegate = nil
        messages = []
        bids = []
        states = []
        omSessions = []
        lastPreloadUserMessageId = ""
        preloadTimeout = 60
    }
}

// MARK: Implementation
extension AdsProviderActor: AdsProviderActing {
    /// Enables or Disables the generation of ads.
    func setDisabled(_ isDisabled: Bool) {
        self.isDisabled = isDisabled
    }

    func setDelegate(delegate: AdsProviderActingDelegate?) async {
        self.delegate = delegate
    }

    func setMessages(messages: [AdsMessage]) async {
        guard !isDisabled else {
            return
        }

        let newUserMessages = messages.filter { $0.role == .user }
        let messagesToSend = Array(messages.suffix(numberOfRelevantMessages))

        guard let lastUserMessage = newUserMessages.last else {
            return
        }

        let shouldPreload = lastPreloadUserMessageId != lastUserMessage.id
        self.messages = messages

        if shouldPreload {
            reset()
            notifyAboutAdChanges()
        } else {
            await bindBidsToLastAssistantMessage()
            return
        }

        lastPreloadUserMessageId = lastUserMessage.id
        do {
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

            // No bids are available, report status.
            guard preloadedData.bids != nil else {
                notifyAdNotAvailable(messageId: lastUserMessage.id)
                return
            }

            await bindBidsToLastUserMessage()
            await bindBidsToLastAssistantMessage()
        } catch {
            delegate?.adsProviderActing(
                self,
                didReceiveEvent: .error(
                    AdsEvent.ErrorData(
                        message: error.localizedDescription,
                        errCode: ""
                    )
                )
            )
        }
    }

    func reset() {
        bids = []
        states = []

        // OM requires web view to be alive 1 second after finish is called.
        Task {
            await resetOmStates()
        }
    }
}

// MARK: Data processing
private extension AdsProviderActor {
    func resetOmStates() async {
        omSessions.forEach { $0.session.finish() }
        try? await Task.sleep(seconds: 1)
        omSessions.removeAll()
    }

    func bindBidsToLastUserMessage() async {
        await bindBidsToLastMessage(
            forRole: .user,
            adDisplayPosition: .afterUserMessage
        )
    }

    func bindBidsToLastAssistantMessage() async {
        await bindBidsToLastMessage(
            forRole: .assistant,
            adDisplayPosition: .afterAssistantMessage
        )
    }

    func bindBidsToLastMessage(
        forRole role: Role,
        adDisplayPosition: AdDisplayPosition
    ) async {
        // Messages have to be after the last preload user message
        guard let lastPreloadUserMessageIndex = messages.firstIndex(where: {
            $0.id == lastPreloadUserMessageId
        }) else {
            return
        }

        // Has not bind bids to last message yet
        guard !states.contains(where: {
            $0.bid.adDisplayPosition == adDisplayPosition
        }) else {
            return
        }

        let latestMessages = messages.suffix(from: lastPreloadUserMessageIndex)
        // Prepare last message id
        guard let lastMessageId = latestMessages.filter({ $0.role == role }).last?.id else {
            return
        }

        // Find all bids that are associated with the ad display position
        let bids = self.bids.filter { $0.adDisplayPosition == adDisplayPosition }
        // Only take one bid for each unique code
        let uniqueBids = Dictionary(grouping: bids, by: { $0.code }).compactMap { $0.value.first }
        // Insert new states for last message id
        let stateId = UUID()

        var newStates: [AdLoadingState] = []
        for bid in uniqueBids {
            newStates.append(AdLoadingState(
                id: stateId,
                bid: bid,
                messageId: lastMessageId,
                webViewData: await prepareWebViewData(
                    stateId: stateId,
                    messageId: lastMessageId,
                    bid: bid
                ),
                show: true,
                preferredHeight: nil, // Use default preferred height
            ))
        }

        guard !newStates.isEmpty else {
            return
        }

        states.append(contentsOf: newStates)
        notifyAboutAdChanges()
    }

    func notifyAboutAdChanges() {
        let ads = states.filter { $0.show }.map { $0.toModel() }
        delegate?.adsProviderActing(
            self,
            didReceiveEvent: AdsEvent.filled(ads)
        )
    }

    func notifyAdNotAvailable(messageId: String) {
        delegate?.adsProviderActing(
            self,
            didReceiveEvent: .noFill(.init(messageId: messageId))
        )
    }

    func prepareWebViewData(
        stateId: UUID,
        messageId: String,
        bid: Bid
    ) async -> AdLoadingState.WebViewData {
        await AdLoadingState.WebViewData(
            url: adsServerAPI.frameURL(
                messageId: messageId,
                bidId: bid.bidId,
                bidCode: bid.code,
                otherParams: configuration.otherParams
            ),
            updateData: UpdateIFrameDTO(data: IframeEvent.UpdateIFrameDataDTO(
                sdk: await SDKInfo.current().name,
                code: bid.code,
                messageId: messageId,
                messages: messages.suffix(numberOfRelevantMessages).map { MessageDTO (from: $0) },
                otherParams: configuration.otherParams
            )),
            onIFrameEvent: { [weak self] event in
                Task {
                    await self?.handleInlineIframeEvent(event: event, stateId: stateId)
                }
            },
            onOMEvent: { [weak self] event in
                Task {
                    await self?.handleOMEvent(event: event, stateId: stateId)
                }
            },
            events: inlineEventSubject.eraseToAnyPublisher()
        )
    }
}

// MARK: Preload
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
                try await Task.sleep(seconds: TimeInterval(timeout))
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

// MARK: iFrame events
private extension AdsProviderActor {
    func handleInlineIframeEvent(event: IframeEvent, stateId: UUID) {
        guard let stateIndex = states.firstIndex(where: { $0.id == stateId }) else {
            return
        }
        var newState = states[stateIndex]

        switch event {
        case .initIframe:
            break // Handled by InlineAdWebView

        case .showIframe:
            if !newState.show {
                newState.show = true
                states[stateIndex] = newState
                notifyAboutAdChanges()
            }

        case .hideIframe:
            if newState.show {
                newState.show = false
                states[stateIndex] = newState
                notifyAboutAdChanges()
            }

        case .viewIframe(let viewData):
            os_log(.info, "[InlineAd]: View Iframe with ID: \(viewData.id)")

        case .clickIframe(let clickData):
            openURL(from: clickData, fallbackURL: newState.webViewData.url)

        case .resizeIframe(let resizedData):
            guard resizedData.height != newState.preferredHeight else {
                return
            }

            newState.preferredHeight = resizedData.height
            states[stateIndex] = newState

            delegate?.adsProviderActing(
                self,
                didReceiveEvent: AdsEvent.adHeight(newState.toModel())
            )

        case .errorIframe(let message):
            os_log(.error, "[InlineAd]: Error: \(message?.message ?? "unknown")")
            reset()
            notifyAboutAdChanges()

        case .openComponentIframe(let data):
            Task {
                await presentInterstitialAd(data, state: newState)
            }

        case .eventIframe(let data):
            delegate?.adsProviderActing(self, didReceiveEvent: data.toModel())

        default:
            break
        }
    }

    func handleInterstitialIframeEvent(event: IframeEvent, state: AdLoadingState) {
        switch event {
        case .initComponentIframe:
            Task { @MainActor in
                interstitialEventSubject.send(.didChangeDisplay(true))
            }
            interstitialTimeoutTask?.cancel()
            interstitialTimeoutTask = nil

        case .closeComponentIframe, .errorComponentIframe:
            Task { @MainActor in
                inlineEventSubject.send(.didFinishInterstitialAd)
            }

        case .clickIframe(let clickData):
            openURL(from: clickData, fallbackURL: state.webViewData.url)

        case .eventIframe(let data):
            delegate?.adsProviderActing(self, didReceiveEvent: data.toModel())

        default:
            break
        }
    }
}

// MARK: OM Events
private extension AdsProviderActor {
    func handleOMEvent(event: OMEvent, stateId: UUID) {
        guard let stateIndex = states.firstIndex(where: { $0.id == stateId }) else {
            return
        }

        var newState = omSessions[stateIndex]

        switch event {
        case .didStart(let webView, let url):
            do {
                let omSession = try omService.createSession(webView, url: url)
                newState = OMSessionState(stateId: stateId, session: omSession)
                omSessions[stateIndex] = newState
                omSession.start()
            } catch {
                os_log("OM failed to start: \(error)")
            }
        }
    }
}

// MARK: Present actions
private extension AdsProviderActor {
    func openURL(from data: IframeEvent.ClickIframeDataDTO, fallbackURL: URL?) {
        if let iframeClickedURL = if let clickDataURL = data.url {
            adsServerAPI.redirectURL(relativeURL: clickDataURL)
        } else {
            fallbackURL
        } {
            Task { @MainActor in
                UIApplication.shared.open(iframeClickedURL)
            }
        }
    }

    func presentInterstitialAd(
        _ data: IframeEvent.OpenComponentIframeDataDTO,
        state: AdLoadingState
    ) async {
        let url = await adsServerAPI.componentURL(
            messageId: state.messageId,
            bidId: state.bid.bidId,
            bidCode: state.bid.code,
            component: data.component,
            otherParams: configuration.otherParams
        )

        Task { @MainActor in
            let params = InterstitialAdView.Params(
                url: url,
                omService: omService,
                events: interstitialEventSubject.eraseToAnyPublisher(),
                onIFrameEvent: { [weak self] event in
                    Task {
                        await self?.handleInterstitialIframeEvent(
                            event: event,
                            state: state
                        )
                    }
                },
                onOMEvent: { [weak self] event in
                    Task {
                        await self?.handleOMEvent(
                            event: event,
                            stateId: state.id
                        )
                    }
                }
            )
            inlineEventSubject.send(.didRequestInterstitialAd(params))
        }

        // Close interstitial ad if it init component does not
        // arrive within timeout interval.
        interstitialTimeoutTask = Task { @MainActor in
            try? await Task.sleep(milliseconds: data.timeout + 500) // Add buffer time for displaying.

            guard !Task.isCancelled else {
                return
            }

            inlineEventSubject.send(.didFinishInterstitialAd)
        }
    }
}
