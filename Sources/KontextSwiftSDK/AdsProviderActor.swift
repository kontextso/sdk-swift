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

    private let numberOfRelevantMessages = 30

    private var resolvedAdvertisingId: String?
    private var resolvedVendorId: String?

    /// Events published to interstitial and inline components
    private let inlineEventSubject = PassthroughSubject<InlineAdEvent, Never>()
    private let interstitialEventSubject = PassthroughSubject<InterstitialAdEvent, Never>()
    private var interstitialTimeoutTask: Task<Void, Never>?

    /// Initial configuration passed down by AdsProvider.
    private let configuration: AdsProviderConfiguration
    private let adsServerAPI: AdsServerAPI
    private let urlOpener: URLOpening
    private let skAdNetworkManager: any SKAdNetworkManaging
    private let skOverlayPresenter: any SKOverlayPresenting
    private let skStoreProductPresenter: any SKStoreProductPresenting
    private weak var delegate: AdsProviderActingDelegate?
    private var skanOwner: (stateId: UUID, bidId: String)?

    // stateId waiting for start after init
    private var pendingStart: UUID?

    init(
        configuration: AdsProviderConfiguration,
        sessionId: String? = nil,
        isDisabled: Bool,
        adsServerAPI: AdsServerAPI,
        urlOpener: URLOpening,
        skAdNetworkManager: any SKAdNetworkManaging = DefaultSKAdNetworkManager.shared,
        skOverlayPresenter: any SKOverlayPresenting = DefaultSKOverlayPresenter(),
        skStoreProductPresenter: any SKStoreProductPresenting = DefaultSKStoreProductPresenter()
    ) {
        self.configuration = configuration
        self.sessionId = sessionId
        self.isDisabled = isDisabled
        self.adsServerAPI = adsServerAPI
        self.urlOpener = urlOpener
        self.skAdNetworkManager = skAdNetworkManager
        self.skOverlayPresenter = skOverlayPresenter
        self.skStoreProductPresenter = skStoreProductPresenter
        delegate = nil
        messages = []
        bids = []
        states = []
        lastPreloadUserMessageId = ""
        preloadTimeout = 60
    }
}

private struct NormalizedSKOverlayRequest {
    let skan: Skan
    let position: SKOverlayDisplayPosition
    let dismissible: Bool
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
        let newUserMessages = messages.filter { $0.role == .user }

        let messagesToSend = Array(messages.suffix(numberOfRelevantMessages))

        guard let lastUserMessage = newUserMessages.last else {
            return
        }

        let shouldPreload = lastPreloadUserMessageId != lastUserMessage.id
        self.messages = messages

        if shouldPreload {
            await reset()
            notifyAdsCleared()
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
                isDisabled: isDisabled,
                advertisingId: resolvedAdvertisingId,
                vendorId: resolvedVendorId,
                api: adsServerAPI,
                messages: messagesToSend
            )

            guard preloadedData.permanentError != true else {
                notifyAdNotAvailable(messageId: lastUserMessage.id, skipCode: preloadedData.skipCode)
                isDisabled = true
                await reset()
                return
            }

            bids = preloadedData.bids ?? []
            sessionId = preloadedData.sessionId

            // Skip everything else if ads are disabled manually
            if isDisabled {
                return
            }

            // Skip response
            if preloadedData.skip == true {
                notifyAdNotAvailable(messageId: lastUserMessage.id, skipCode: preloadedData.skipCode ?? "unknown")
                return
            }

            // No bids are available, report status.
            guard let bids = preloadedData.bids, !bids.isEmpty else {
                notifyAdNotAvailable(messageId: lastUserMessage.id, skipCode: preloadedData.skipCode)
                return
            }

            await bindBidsToLastUserMessage()
            await bindBidsToLastAssistantMessage()
        } catch {
            notifyAdNotAvailable(messageId: lastUserMessage.id)
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

    func reset() async {
        await cleanupSKAdNetwork()
        await dismissSKOverlay()
        await dismissSKStoreProduct()
        bids = []
        states = []
    }

    func setIFA(advertisingId: String?, vendorId: String?) {
        resolvedAdvertisingId = advertisingId
        resolvedVendorId = vendorId
    }
}

// MARK: Data processing
private extension AdsProviderActor {
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
                show: true,
                preferredHeight: nil, // Use default preferred height
                webViewData: await prepareWebViewData(
                    stateId: stateId,
                    messageId: lastMessageId,
                    bid: bid
                )
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

    func notifyAdsCleared() {
        delegate?.adsProviderActing(
            self,
            didReceiveEvent: AdsEvent.cleared
        )
    }

    func notifyAdNotAvailable(messageId: String, skipCode: String? = nil) {
        delegate?.adsProviderActing(
            self,
            didReceiveEvent: .noFill(.init(messageId: messageId, skipCode: skipCode))
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
            onDispose: { [weak self] in
                Task {
                    await self?.handleInlineWebViewDispose(
                        stateId: stateId,
                        bidId: bid.bidId
                    )
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
        isDisabled: Bool,
        advertisingId: String?,
        vendorId: String?,
        api: AdsServerAPI,
        messages: [AdsMessage]
    ) async throws -> PreloadedData {
        try await withTimeout(TimeInterval(timeout)) {
            try await api.preload(
                sessionId: sessionId,
                configuration: configuration,
                isDisabled: isDisabled,
                advertisingId: advertisingId,
                vendorId: vendorId,
                messages: messages
            )
        }
    }
}

// MARK: iFrame events
private extension AdsProviderActor {
    func handleInlineIframeEvent(event: IframeEvent, stateId: UUID) async {
        guard let stateIndex = states.firstIndex(where: { $0.id == stateId }) else {
            return
        }
        var newState = states[stateIndex]

        switch event {
        case .initIframe:
            await initializeSKAdNetwork(for: newState)

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

        case .adDoneIframe:
            if newState.bid.impressionTrigger == .immediate, newState.bid.skan != nil {
                if skanOwner?.stateId == newState.id {
                    await startSKAdNetwork(for: newState)
                } else {
                    pendingStart = newState.id // init not done yet
                }
            }

        case .clickIframe(let clickData):
            Task {
                await handleClickIframe(
                    clickData,
                    source: .inline(newState),
                    fallbackURL: newState.webViewData.url
                )
            }

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
            await reset()
            notifyAboutAdChanges()

        case .openComponentIframe(let data):
            if
                newState.bid.impressionTrigger == .component,
                data.component == .modal
            {
                await startSKAdNetwork(for: newState)
            }
            Task {
                await handleComponentIframe(
                    request: .open(data),
                    source: .inline(newState)
                )
            }

        case .closeComponentIframe(let data):
            Task {
                await handleComponentIframe(
                    request: .close(data),
                    source: .inline(newState)
                )
            }

        case .eventIframe(let data):
            delegate?.adsProviderActing(self, didReceiveEvent: data.toModel())

        default:
            break
        }
    }

    func handleInlineWebViewDispose(stateId: UUID, bidId: String) async {
        await cleanupSKAdNetwork(stateId: stateId, bidId: bidId)
        await dismissSKOverlay()
        await dismissSKStoreProduct()
    }

    func handleInterstitialIframeEvent(event: IframeEvent, state: AdLoadingState) {
        switch event {
        case .initComponentIframe:
            // NOTE: Intentionally dispatched to @MainActor before sending.
            // InterstitialAdViewModel observes this subject and updates @Published properties.
            // Without this hop, the send() arrives on the actor's background executor,
            // which causes "Publishing changes from background threads" warnings and potential
            // crashes in future iOS versions. The actor isolation crossing is a known tradeoff.
            Task { @MainActor in
                await interstitialEventSubject.send(.didChangeDisplay(true))
            }
            interstitialTimeoutTask?.cancel()
            interstitialTimeoutTask = nil

        case .openComponentIframe(let data):
            Task {
                await handleComponentIframe(
                    request: .open(data),
                    source: .interstitial(state)
                )
            }

        case .closeComponentIframe(let data):
            Task {
                await handleComponentIframe(
                    request: .close(data),
                    source: .interstitial(state)
                )
            }

        case .errorComponentIframe:
            Task {
                await closeInterstitialAndNativeComponents(for: state)
            }

        case .clickIframe(let clickData):
            Task {
                await handleClickIframe(
                    clickData,
                    source: .interstitial(state),
                    fallbackURL: state.webViewData.url
                )
            }

        case .eventIframe(let data):
            delegate?.adsProviderActing(self, didReceiveEvent: data.toModel())

        default:
            break
        }
    }
}

// MARK: Components
private extension AdsProviderActor {
    func handleComponentIframe(
        request: IframeComponentRequest,
        source: IframeComponentSource
    ) async {
        switch (request.action, request.kind, source) {
        case (.open, .modal, .inline(let state)):
            guard case .open(let data) = request else {
                return
            }
            await presentInterstitialAd(data, state: state)

        case (.close, .modal, .interstitial):
            interstitialTimeoutTask?.cancel()
            interstitialTimeoutTask = nil
            Task { @MainActor in
                await inlineEventSubject.send(.didFinishInterstitialAd)
            }

        case (.open, .skoverlay, _):
            guard case .open(let data) = request else {
                return
            }
            await presentSKOverlay(from: data, source: source)

        case (.close, .skoverlay, _):
            await dismissSKOverlay()

        default:
            break
        }
    }

    func normalizeSKOverlayRequest(
        from data: IframeEvent.OpenComponentIframeDataDTO,
        source: IframeComponentSource
    ) -> NormalizedSKOverlayRequest? {
        guard let skan = bidSkan(from: source) else {
            os_log(.error, "[SKOverlay]: SKAN data is required")
            return nil
        }
        guard hasFidelity1(skan) else {
            os_log(.error, "[SKOverlay]: fidelity-1 SKAN data is required")
            return nil
        }

        let position: SKOverlayDisplayPosition
        switch data.position?.lowercased() {
        case "bottomraised":
            position = .bottomRaised
        default:
            position = .bottom
        }

        return NormalizedSKOverlayRequest(
            skan: skan,
            position: position,
            dismissible: data.dismissible ?? true
        )
    }

    func presentSKOverlay(
        from data: IframeEvent.OpenComponentIframeDataDTO,
        source: IframeComponentSource
    ) async {
        guard let request = normalizeSKOverlayRequest(from: data, source: source) else {
            return
        }

        _ = await skOverlayPresenter.present(
            skan: request.skan,
            position: request.position,
            dismissible: request.dismissible
        )
    }

    func dismissSKOverlay() async {
        _ = await skOverlayPresenter.dismiss()
    }

    func presentSKStoreProduct(
        skan: Skan
    ) async -> Bool {
        await skStoreProductPresenter.present(skan: skan)
    }

    func dismissSKStoreProduct() async {
        _ = await skStoreProductPresenter.dismiss()
    }

    func bidSkan(from source: IframeComponentSource) -> Skan? {
        switch source {
        case .inline(let state):
            state.bid.skan
        case .interstitial(let state):
            state.bid.skan
        }
    }

    func hasFidelity1(_ skan: Skan) -> Bool {
        skan.fidelities?.contains(where: { $0.fidelity == 1 }) ?? false
    }

    func closeInterstitialAndNativeComponents(for _: AdLoadingState) async {
        interstitialTimeoutTask?.cancel()
        interstitialTimeoutTask = nil

        await dismissSKOverlay()
        await dismissSKStoreProduct()

        Task { @MainActor in
            await inlineEventSubject.send(.didFinishInterstitialAd)
        }
    }
}

// MARK: SKAdNetwork
private extension AdsProviderActor {
    func initializeSKAdNetwork(for state: AdLoadingState) async {
        guard let skan = state.bid.skan else {
            return
        }

        let didInitialize = await skAdNetworkManager.initImpression(skan)
        if didInitialize {
            skanOwner = (stateId: state.id, bidId: state.bid.bidId)
            if pendingStart == state.id {
                pendingStart = nil
                await skAdNetworkManager.startImpression()
            }
        } else {
            if pendingStart == state.id {
                pendingStart = nil
            }
        }
    }

    func startSKAdNetwork(for state: AdLoadingState) async {
        guard
            skanOwner?.stateId == state.id,
            skanOwner?.bidId == state.bid.bidId
        else {
            return
        }

        await skAdNetworkManager.startImpression()
    }

    func cleanupSKAdNetwork(stateId: UUID, bidId: String) async {
        guard skanOwner?.stateId == stateId, skanOwner?.bidId == bidId else {
            return
        }

        await cleanupSKAdNetwork()
    }

    func cleanupSKAdNetwork() async {
        pendingStart = nil
        guard skanOwner != nil else {
            return
        }
        skanOwner = nil
        await skAdNetworkManager.endImpression()
        await skAdNetworkManager.dispose()
    }
}

// MARK: Present actions
private extension AdsProviderActor {
    func handleClickIframe(
        _ data: IframeEvent.ClickIframeDataDTO,
        source: IframeComponentSource,
        fallbackURL: URL?
    ) async {
        let clickedURL = resolvedClickURL(from: data, fallbackURL: fallbackURL)

        guard let skan = bidSkan(from: source), hasFidelity1(skan) else {
            openURL(clickedURL)
            return
        }

        let storeProductOpened = await presentSKStoreProduct(skan: skan)

        guard !storeProductOpened else {
            return
        }

        openURL(clickedURL)
    }

    func resolvedClickURL(
        from data: IframeEvent.ClickIframeDataDTO,
        fallbackURL: URL?
    ) -> URL? {
        if let clickDataURL = data.url {
            return adsServerAPI.redirectURL(relativeURL: clickDataURL)
        }

        return fallbackURL
    }

    func openURL(_ url: URL?) {
        guard let url else {
            return
        }

        Task { @MainActor in
            if !urlOpener.canOpenURL(url) {
                return
            }

            urlOpener.open(url, options: [:], completionHandler: nil)
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
            component: data.component.rawValue,
            otherParams: configuration.otherParams
        )

        Task { @MainActor in
            let params = await InterstitialAdView.Params(
                url: url,
                events: interstitialEventSubject.eraseToAnyPublisher(),
                onIFrameEvent: { [weak self] event in
                    Task {
                        await self?.handleInterstitialIframeEvent(
                            event: event,
                            state: state
                        )
                    }
                }
            )
            await inlineEventSubject.send(.didRequestInterstitialAd(params))
        }

        // Close interstitial ad if it init component does not
        // arrive within timeout interval.
        interstitialTimeoutTask?.cancel()
        interstitialTimeoutTask = Task {
            try? await Task.sleep(milliseconds: data.timeout + 500) // Add buffer time for displaying.

            guard !Task.isCancelled else {
                return
            }

            await closeInterstitialAndNativeComponents(for: state)
        }
    }
}
