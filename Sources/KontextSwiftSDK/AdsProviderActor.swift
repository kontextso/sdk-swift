@preconcurrency import Combine
import OSLog
import UIKit
import WebKit

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
    private let omService: OMManaging
    private let skAdNetworkManager: any SKAdNetworkManaging
    private let skOverlayPresenter: any SKOverlayPresenting
    private let skStoreProductPresenter: any SKStoreProductPresenting
    private weak var delegate: AdsProviderActingDelegate?
    private var skanOwner: (stateId: UUID, bidId: String)?

    // stateId waiting for start after init
    private var pendingStart: UUID?

    // Interstitial OMID: WebView reference captured on didFinish, consumed on initComponentIframe
    // so that session.start() fires only after the modal is fully visible.
    private var pendingInterstitialWebView: (webView: WKWebView, url: URL?, stateId: UUID)?

    // Inline OMID: WebView reference captured on didFinish, consumed on adDoneIframe
    // so that session.start() fires only after the ad content is fully rendered and
    // the iframe has received its container dimensions (iframeLoaded = true in JS).
    private var pendingInlineWebView: (webView: WKWebView, url: URL?, stateId: UUID, creativeType: OmCreativeType)?

    init(
        configuration: AdsProviderConfiguration,
        sessionId: String? = nil,
        isDisabled: Bool,
        adsServerAPI: AdsServerAPI,
        urlOpener: URLOpening,
        omService: OMManaging,
        skAdNetworkManager: any SKAdNetworkManaging = DefaultSKAdNetworkManager.shared,
        skOverlayPresenter: any SKOverlayPresenting,
        skStoreProductPresenter: any SKStoreProductPresenting
    ) {
        self.configuration = configuration
        self.sessionId = sessionId
        self.isDisabled = isDisabled
        self.adsServerAPI = adsServerAPI
        self.urlOpener = urlOpener
        self.omService = omService
        self.skAdNetworkManager = skAdNetworkManager
        self.skOverlayPresenter = skOverlayPresenter
        self.skStoreProductPresenter = skStoreProductPresenter
        bids = []
        messages = []
        states = []
        omSessions = []
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
            // Finish OM sessions while the WebView is still in the view hierarchy,
            // then wait 1 second for the sessionFinish JS to execute before removing the WebView.
            let sessionsToFinish = omSessions
            omSessions = []
            await MainActor.run {
                for state in sessionsToFinish {
                    state.session.retire()
                    state.session.finish()
                    os_log("[\(ts)] [OMID] Session finished (\(state.creativeType.rawValue)) for stateId: \(state.stateId)")
                }
            }
            await reset()
            notifyAdsCleared()
        } else {
            await bindBidsToLastAssistantMessage()
            return
        }

        lastPreloadUserMessageId = lastUserMessage.id
        do {
            async let sleep: Void = Task.sleep(seconds: 1)
            async let preload = preloadWithTimeout(
                timeout: preloadTimeout,
                sessionId: sessionId,
                configuration: configuration,
                isDisabled: isDisabled,
                advertisingId: resolvedAdvertisingId,
                vendorId: resolvedVendorId,
                api: adsServerAPI,
                messages: messagesToSend
            )
            let (_, preloadedData) = try await (sleep, preload)

            // Bail out if a newer setMessages call arrived while we were suspended.
            // The new call has already overwritten lastPreloadUserMessageId, so our
            // preload results are stale and should not be bound.
            guard lastPreloadUserMessageId == lastUserMessage.id else { return }

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

private let tsFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

private var ts: String { tsFormatter.string(from: Date()) }

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
        var newStates: [AdLoadingState] = []
        for bid in uniqueBids {
            newStates.append(AdLoadingState(
                id: bid.bidId,
                bid: bid,
                messageId: lastMessageId,
                webViewData: await prepareWebViewData(
                    stateId: bid.bidId,
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
                bidId: bid.bidId.uuidString.lowercased(),
                bidCode: bid.code,
                otherParams: configuration.otherParams
            ),
            updateData: UpdateIFrameDTO(data: IframeEvent.UpdateIFrameDataDTO(
                sdk: await SDKInfo.current().name,
                code: bid.code,
                messageId: messageId,
                messages: messages.suffix(numberOfRelevantMessages).map { MessageDTO(from: $0) },
                otherParams: configuration.otherParams
            )),
            onIFrameEvent: { [weak self] event in
                Task {
                    await self?.handleInlineIframeEvent(event: event, stateId: stateId)
                }
            },
            onOMEvent: { [weak self] event in
                // Interstitial bids: inline WebView is just a preview, OMID session
                // starts when the modal WebView loads (handled in presentInterstitialAd).
                guard bid.impressionTrigger != .component else {
                    os_log("[\(ts)] [OMID] Skipping inline OM event (impressionTrigger: component) for stateId: \(stateId)")
                    return
                }
                Task {
                    await self?.handleOMEvent(event: event, stateId: stateId)
                }
            },
            onDispose: { [weak self] in
                Task {
                    await self?.handleInlineWebViewDispose(
                        stateId: stateId,
                        bidId: bid.bidId.uuidString.lowercased()
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

        let response = try await withTimeout(TimeInterval(timeout)) {
            try await api.preload(
                sessionId: sessionId,
                configuration: configuration,
                isDisabled: isDisabled,
                advertisingId: advertisingId,
                vendorId: vendorId,
                messages: messages
            )
        }

        return response
    }
}

// MARK: iFrame events
private extension AdsProviderActor {
    private func omSession(for stateId: UUID) -> OMSession? {
        return omSessions.first(where: { $0.stateId == stateId })?.session
    }

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
            os_log(.info, "[\(ts)] [InlineAd]: View Iframe with ID: \(viewData.id)")

        case .adDoneIframe:
            // Ad content is fully rendered and iframe has received container dimensions —
            // start the deferred OMID session now so impression fires with correct geometry.
            if let pending = pendingInlineWebView, pending.stateId == newState.id {
                pendingInlineWebView = nil
                let (webView, url, stateId, creativeType) = (pending.webView, pending.url, pending.stateId, pending.creativeType)
                Task {
                    await startOMSession(webView: webView, url: url, stateId: stateId, creativeType: creativeType)
                }
            }

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

        case .errorIframe(let data):
            os_log(.error, "[InlineAd]: Error: \(data?.message ?? "unknown")")
            if let session = omSession(for: stateId) {
                await MainActor.run { session.logError(errorType: data?.errorType, message: data?.message) }
            }
            await reset()
            notifyAdsCleared()

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

        case .omidFiredIframe(let error):
            if let error {
                os_log("[\(ts)] [OMID] Iframe JS session client error for stateId: \(stateId) — \(error)")
            } else {
                os_log("[\(ts)] [OMID] Impression fired from iframe JS session client for stateId: \(stateId)")
            }

        default:
            break
        }
    }

    func handleInlineWebViewDispose(stateId: UUID, bidId: String) async {
        if pendingInlineWebView?.stateId == stateId {
            pendingInlineWebView = nil
        }
        await cleanupSKAdNetwork(stateId: stateId, bidId: bidId)
        await dismissSKOverlay()
        await dismissSKStoreProduct()
        await finishOMSession(for: stateId)
    }

    func finishOMSession(for stateId: UUID) async {
        guard let index = omSessions.firstIndex(where: { $0.stateId == stateId }) else { return }
        let state = omSessions[index]
        omSessions.remove(at: index)
        await MainActor.run {
            state.session.retire()
            state.session.finish()
        }
        os_log("[\(ts)] [OMID] Session finished (\(state.creativeType.rawValue)) for stateId: \(stateId)")
        try? await Task.sleep(seconds: 1)
    }

    func handleInterstitialIframeEvent(event: IframeEvent, state: AdLoadingState) {
        switch event {
        case .initComponentIframe:
            // Modal content is loaded — show the WebView and cancel the timeout.
            // NOTE: Intentionally dispatched to @MainActor before sending.
            Task { @MainActor in
                await interstitialEventSubject.send(.didChangeDisplay(true))
            }
            interstitialTimeoutTask?.cancel()
            interstitialTimeoutTask = nil

        case .adDoneComponentIframe:
            // Video has started playing — modal is fully visible and dimensions are stable.
            // Start the deferred OMID session now so impression fires with correct geometry.
            if let pending = pendingInterstitialWebView, pending.stateId == state.id,
               let creativeType = state.bid.om {
                pendingInterstitialWebView = nil
                let (webView, url, stateId) = (pending.webView, pending.url, pending.stateId)
                Task {
                    await startOMSession(webView: webView, url: url, stateId: stateId, creativeType: creativeType)
                }
            }

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

        case .errorComponentIframe(let data):
            let errorSession = omSession(for: state.id)
            Task {
                if let session = errorSession {
                    await MainActor.run { session.logError(errorType: data.errorType, message: data.message) }
                }
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

// MARK: OM Events
private extension AdsProviderActor {
    func handleOMEvent(event: OMEvent, stateId: UUID) async {
        // Guard against a duplicate didFinish for an already-active session.
        // In practice this cannot happen: didFinish only fires for main-frame navigations, and our
        // WKWebView loads a static shell HTML that never navigates after the initial load. The DSP ad
        // runs inside a <iframe> (subframe), so any window.location call there does not trigger
        // didFinish on the outer WKWebView. Early-return is correct here.
        if let existingIndex = omSessions.firstIndex(where: { $0.stateId == stateId }) {
            let existingSession = omSessions[existingIndex].session
            await MainActor.run {
                existingSession.finish()
            }
            omSessions.remove(at: existingIndex)
            return
        }

        switch event {
        case .didStart(let webView, let url):
            // Guard against spurious didFinish callbacks after the ad has been disposed/cleared
            guard states.contains(where: { $0.id == stateId }) else { return }
            // Killswitch: if the server didn't send an `om` object, OMID is disabled for this bid
            guard let creativeType = states.first(where: { $0.id == stateId })?.bid.om else { return }

            // For interstitial ads, defer session start until initComponentIframe fires,
            // so session.start() is called only after the modal is fully visible.
            if states.first(where: { $0.id == stateId })?.bid.impressionTrigger == .component {
                pendingInterstitialWebView = (webView: webView, url: url, stateId: stateId)
                os_log("[\(ts)] [OMID] Deferring session start until initComponentIframe for stateId: \(stateId)")
                return
            }

            // For inline ads, defer session start until adDoneIframe fires,
            // so session.start() is called only after the ad content is fully rendered
            // and the iframe has received its container dimensions.
            pendingInlineWebView = (webView: webView, url: url, stateId: stateId, creativeType: creativeType)
            os_log("[\(ts)] [OMID] Deferring session start until adDoneIframe for stateId: \(stateId)")
        }
    }

    func startOMSession(webView: WKWebView, url: URL?, stateId: UUID, creativeType: OmCreativeType) async {
        do {

            let omSession = try await MainActor.run {
                let session = try omService.createSession(webView, url: url, creativeType: creativeType)
                session.start()
                return session
            }

            os_log("[\(ts)] [OMID] Session started (\(creativeType.rawValue)) for stateId: \(stateId)")

            let newState = OMSessionState(stateId: stateId, session: omSession, creativeType: creativeType)
            omSessions.append(newState)
        } catch {
            os_log("OM failed to start: \(String(describing: error))")
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

        case (.close, .modal, .interstitial(let state)):
            interstitialTimeoutTask?.cancel()
            interstitialTimeoutTask = nil
            await finishOMSession(for: state.id)
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

    func closeInterstitialAndNativeComponents(for state: AdLoadingState) async {
        interstitialTimeoutTask?.cancel()
        interstitialTimeoutTask = nil

        if pendingInterstitialWebView?.stateId == state.id {
            pendingInterstitialWebView = nil
        }

        await dismissSKOverlay()
        await dismissSKStoreProduct()
        await finishOMSession(for: state.id)

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
            skanOwner = (stateId: state.id, bidId: state.bid.bidId.uuidString.lowercased())
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
            skanOwner?.bidId == state.bid.bidId.uuidString.lowercased()
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
            bidId: state.bid.bidId.uuidString.lowercased(),
            bidCode: state.bid.code,
            component: data.component.rawValue,
            otherParams: configuration.otherParams
        )

        Task { @MainActor in
            guard let url else { return }
            let params = await InterstitialAdView.Params(
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
