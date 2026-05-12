import Foundation
import KontextKit
import UIKit
import WebKit

/// Public ad handle returned by `session.createAd()`.
///
/// Represents a single ad instance for a specific assistant message.
/// The publisher creates it via `session.createAd()` and renders it
/// in a SwiftUI view via `InlineAdView(ad:)`.
@MainActor
public final class Ad: ObservableObject, Identifiable {
    /// Stable identifier for SwiftUI list-diffing (`ForEach`). Set
    /// once at init; since `Session.createAd` is idempotent for the
    /// same `(messageId, code)` pair, the same logical ad always has
    /// the same `id`.
    public let id = UUID()

    /// The id of the message this ad is bound to. By convention the
    /// **assistant** message — `Session.updateBids()` only ever
    /// assigns bids to the latest assistant message, so an ad created
    /// with any other id will resolve no bid.
    public let messageId: String

    /// The placement code for this ad.
    public let code: String

    /// The theme for this ad.
    public let theme: String?

    /// The computed iframe URL, set when a bid becomes available.
    @Published public private(set) var iframeUrl: String?

    /// The current ad height reported by the iframe.
    @Published public private(set) var height: CGFloat = 0

    /// Whether the ad iframe is visible.
    @Published public private(set) var isVisible: Bool = false

    /// Whether the ad has been destroyed.
    public private(set) var destroyed = false

    /// Whether a modal is currently being requested.
    @Published public private(set) var modalUrl: String?

    /// Callback for when the ad requests a modal to be presented.
    /// Parameters: (modalUrl, timeoutMs)
    public var onRequestModal: ((String, Int) -> Void)?

    /// Callback for when the modal should be dismissed.
    public var onDismissModal: (() -> Void)?

    let session: Session
    fileprivate let omManager: OMManaging
    fileprivate var omSession: OMSession?
    fileprivate var unsubscribe: (() -> Void)?
    fileprivate var modalTimeoutTask: Task<Void, Never>?

    /// Whether SKAN impression has been initialized for this ad.
    fileprivate var skanInitialized = false

    /// Whether SKAN impression has been started (tracking window open).
    fileprivate var skanStarted = false

    /// Whether SKAN start was requested before init completed.
    fileprivate var skanPendingStart = false

    /// In-flight SKAN init or start Task. `cleanupSKAdNetwork` awaits
    /// this before invoking `endImpression`/`dispose` so the iOS
    /// SKAdNetwork API isn't called concurrently for the same impression.
    fileprivate var skanInFlightTask: Task<Void, Never>?

    /// Saved brightness before modal open (for restore on close).
    fileprivate var savedBrightness: Double?

    /// The current bid for this ad, if resolved.
    fileprivate var currentBid: Bid?

    /// The WebView that the next `startOMSession` call should attach
    /// to. Updated by every `AdWebView.init` (inline AND modal); last
    /// writer wins, by design.
    ///
    /// Each ad creates exactly one OMID session, on one of two
    /// mutually exclusive paths:
    ///
    /// **Immediate-trigger ads** (`bid.impressionTrigger != .component`):
    /// 1. Inline `AdWebView.init` → `currentWebView = inline`.
    /// 2. `ad-done-iframe` → `handleAdDoneIframe` → `startOMSession`
    ///    attaches OMID to the inline WebView.
    ///
    /// **Component-trigger ads** (banner-then-modal interstitials):
    /// 1. Inline `AdWebView.init` → `currentWebView = inline` (banner).
    /// 2. `ad-done-iframe` → `handleAdDoneIframe` bails early —
    ///    component-trigger ads defer OMID to the modal.
    /// 3. User opens modal → modal `AdWebView.init` →
    ///    `currentWebView = modal` (overwrites).
    /// 4. `ad-done-component-iframe` → `handleAdDoneComponentIframe` →
    ///    `startOMSession` attaches OMID to the modal WebView.
    ///
    /// `handleAdDoneComponentIframe` additionally guards on
    /// `omSession == nil`, so the two paths can never both create a
    /// session for the same ad.
    ///
    /// `weak` to avoid keeping a discarded modal WebView alive after
    /// dismissal — the WebView's owning view (SwiftUI/UIKit hierarchy)
    /// is the actual lifecycle root.
    weak var currentWebView: WKWebView?

    /// Internal -- use `session.createAd()` instead.
    init(session: Session, messageId: String, options: AdOptions? = nil, omManager: OMManaging? = nil) {
        self.session = session
        self.messageId = messageId
        self.code = options?.code ?? Constants.defaultPlacementCode
        self.theme = options?.theme
        self.omManager = omManager ?? session.omManager

        // Subscribe before the synchronous `checkBid()` so that if the
        // first attempt has no bid yet, future bid updates re-trigger
        // us. Both calls are MainActor-synchronous, so nothing can
        // interleave between them — but matching sdk-js's order keeps
        // the two implementations easy to diff and is defensive
        // against any future indirect-trigger code paths.
        unsubscribe = session.subscribeBidUpdates { [weak self] in
            self?.checkBid()
        }
        checkBid()

        session.config.onDebugEvent?("Ad: mount", [
            "messageId": messageId,
            "code": code,
            "theme": theme as Any,
        ])
    }

    /// Destroys the ad -- removes event listeners, cleans up resources.
    /// After calling `destroy()`, this ad instance cannot be reused.
    public func destroy() {
        guard !destroyed else { return }
        destroyed = true
        session.config.onDebugEvent?("Ad: destroy", ["messageId": messageId, "code": code])

        // 1) Detach listeners FIRST so we don't react to inbound bid
        //    updates mid-teardown (sdk-js parity).
        unsubscribe?()
        unsubscribe = nil

        // 2) Universal per-ad teardown — covers timer, brightness, OMID
        //    session, SKAN impression, audio session, dismiss callback,
        //    and SKOverlay. Idempotent: safe even when no modal is open
        //    (and for inline ads where tearDown is reached only via
        //    destroy(), it still ends the SKAN impression correctly).
        tearDown()

        // 3) Unregister from session bookkeeping. Order matters:
        //    `removeAd` first so `removePreload`'s "any ads still
        //    referencing this messageId?" guard sees the post-removal
        //    state. Mirrors sdk-js's Ad.destroy().
        session.removeAd(messageId: messageId, code: code)
        session.removePreload(messageId)
    }

    // MARK: - Iframe Event Handling

    /// Called by `AdWebView` when a postMessage event is received from the iframe.
    func handleIframeEvent(_ event: IframeEvent) {
        guard !destroyed else { return }

        switch event {
        case .initIframe:
            handleInitIframe()
        case .resizeIframe(let d):
            handleResizeIframe(data: d)
        case .showIframe:
            handleShowIframe()
        case .hideIframe:
            handleHideIframe()
        case .eventIframe(let d):
            handleEventIframe(data: d)
        case .errorIframe:
            handleErrorIframe()
        case .clickIframe(let d):
            handleClickIframe(data: d)
        case .adDoneIframe(let d):
            handleAdDoneIframe(data: d)
        case .openComponentIframe(let d):
            handleOpenComponentIframe(data: d)
        case .initComponentIframe:
            handleInitComponentIframe()
        case .closeComponentIframe:
            handleCloseComponentIframe()
        case .errorComponentIframe(let d):
            handleErrorComponentIframe(data: d)
        case .adDoneComponentIframe:
            handleAdDoneComponentIframe()
        case .openSKOverlayIframe(let d):
            handleOpenSKOverlayIframe(data: d)
        case .closeSKOverlayIframe:
            handleCloseSKOverlayIframe()
        }
    }

}

// MARK: - Bid Resolution

private extension Ad {
    /// Server path segment for the iframe URL — matches sdk-js's
    /// `kind: 'frame' | 'modal'` parameter on `buildIframeUrl`.
    enum IframeKind: String {
        case frame
        case modal
    }

    func checkBid() {
        guard !destroyed else { return }
        guard let bid = session.bid(messageId: messageId, code: code) else { return }
        guard iframeUrl == nil else { return } // Already resolved

        self.currentBid = bid
        self.iframeUrl = buildIframeUrl(kind: .frame, bid: bid)
    }

    /// Builds the iframe URL for the given bid. `componentParams` is
    /// modal-only (KON-1305) and serialized as a JSON-encoded
    /// `componentParams` query param — sdk-js's `buildIframeUrl`
    /// has the same shape.
    ///
    /// Centralized here so `checkBid` and `openModal` can't drift on
    /// the URL format. Returns nil if `URLComponents` fails to parse
    /// the resulting string (extremely unlikely for a well-formed
    /// `adServerUrl` + UUID bidId).
    func buildIframeUrl(
        kind: IframeKind,
        bid: Bid,
        componentParams: [String: Any]? = nil
    ) -> String? {
        let adServerUrl = session.config.adServerUrl
        // Swift's UUID.uuidString is uppercase; sdk-js / RFC 4122 use
        // lowercase. Use lowercase on the wire so the ad-server's
        // bidId lookup matches sdk-js's case convention.
        var components = URLComponents(string: "\(adServerUrl)/api/\(kind.rawValue)/\(bid.bidId.uuidString.lowercased())")
        var queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "messageId", value: messageId),
            URLQueryItem(name: "sdk", value: SDKInfo.current.name),
        ]
        if let theme = theme {
            queryItems.append(URLQueryItem(name: "theme", value: theme))
        }
        components?.queryItems = queryItems

        guard var url = components?.url?.absoluteString else { return nil }

        // componentParams: append as a JSON-encoded query param for the
        // modal URL. Done after `URLComponents` has serialized the
        // standard params so `addingPercentEncoding(.urlQueryAllowed)`
        // controls the encoding (matches sdk-js's `encodeURIComponent`
        // form, which the ad-server's modal-side parser expects).
        if let params = componentParams,
           let jsonData = try? JSONSerialization.data(withJSONObject: params),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            url += "&componentParams=\(encoded)"
        }

        return url
    }
}

// MARK: - Per-event Iframe Handlers
//
// Grouped to mirror the IframeEvent enum + the main `handleIframeEvent`
// switch:
//   1. Inline iframe handlers   (init / resize / show / hide / event /
//                                error / click / ad-done)
//   2. Component (modal) iframe handlers
//   3. SKOverlay iframe handlers

private extension Ad {

    // MARK: Inline iframe

    func handleInitIframe() {
        // Note: do NOT set `isVisible = true` here. The iframe protocol
        // separates `init-iframe` ("loaded, send me context") from
        // `show-iframe` ("ready to be displayed") — visibility flips
        // only on the latter. None of sdk-react-native (current/v3),
        // sdk-js, or v3 sdk-swift sets visibility on init.
        //
        // `ad.render-started` is no longer synthesised here — the ad
        // emits it via `event-iframe` (handled by `handleEventIframe`'s
        // `case "ad.render-started"`), matching sdk-react-native.
        //
        // `update-iframe` is sent from `AdWebView.handleInitIframeMessage`
        // (the wire-level handler), not here, because Ad doesn't own
        // the postMessage channel. That happens BEFORE this handler
        // runs.
        session.config.onDebugEvent?("Ad: handle-init-iframe", ["messageId": messageId])
        initSKAdNetwork()
    }

    func handleResizeIframe(data: IframeEvent.ResizeData) {
        // Drop non-positive heights — the iframe collapses via the
        // dedicated `hide-iframe` message, not by sending 0/negative
        // resizes. Mirrors current sdk-react-native's `if (height > 0)`
        // guard and avoids emitting meaningless 0-height adHeight
        // events the publisher would have to filter out.
        guard data.height > 0 else { return }
        // Dedupe — avoid redundant adHeight events when the iframe
        // resends the same height. v3 sdk-swift had this. `@Published`
        // already dedupes the SwiftUI render path (assigning an equal
        // CGFloat doesn't fire objectWillChange), but `emitEvent` runs
        // unconditionally — without this guard the publisher's
        // `onEvent` and the Combine stream would see a flood of
        // duplicate `adHeight` events for any iframe that resends.
        guard data.height != height else { return }
        height = data.height
        session.config.onDebugEvent?("Ad: handle-resize-iframe", [
            "messageId": messageId,
            "height": data.height,
        ])
        guard let bidId = currentBid?.bidId else { return }
        session.emitEvent(.adHeight(.init(bidId: bidId, messageId: messageId, height: data.height)))
    }

    func handleShowIframe() {
        // v3 sdk-swift parity dedupe — `@Published` fires willSet on
        // every assignment regardless of value equality, so without
        // this guard a repeated `show-iframe` triggers redundant
        // SwiftUI re-renders and `$isVisible` Combine deliveries.
        guard !isVisible else {
            session.config.onDebugEvent?("Ad: handle-show-iframe-deduped", ["messageId": messageId])
            return
        }
        session.config.onDebugEvent?("Ad: handle-show-iframe → isVisible=true", ["messageId": messageId])
        isVisible = true
    }

    func handleHideIframe() {
        // Same dedupe rationale as `handleShowIframe`.
        guard isVisible else {
            session.config.onDebugEvent?("Ad: handle-hide-iframe-deduped", ["messageId": messageId])
            return
        }
        session.config.onDebugEvent?("Ad: handle-hide-iframe → isVisible=false", ["messageId": messageId])
        isVisible = false
        // Note: don't reset height here. Both `InlineAdView` and
        // `InlineAdUIView` already gate display on `isVisible`
        // (`isVisible ? max(height, 0) : 0`), so resetting would be
        // dead code that diverges from sdk-react-native, sdk-js, and
        // v3 sdk-swift — and could cause a "flash of small ad" if the
        // iframe ever does a hide→show cycle without resending resize.
    }

    func handleEventIframe(data: IframeEvent.EventData) {
        let name = data.name
        let payload = data.payload
        session.config.onDebugEvent?("Ad: handle-event-iframe", [
            "messageId": messageId,
            "name": name,
            "payload": payload as Any,
        ])
        // bidId for events that don't carry their own — falls back to
        // the resolved bid for this Ad. Events emitted before a bid is
        // resolved (rare; iframe shouldn't be loaded yet) are dropped.
        // Iframe-supplied "id" is a wire-format string; parse it as UUID
        // so the public AdEvent payload stays typed. Unparseable strings
        // fall through to the resolved bid.
        let payloadBidId = (payload?["id"] as? String).flatMap(UUID.init(uuidString:))
        let resolvedBidId = payloadBidId ?? currentBid?.bidId

        switch name {
        case "ad.viewed":
            // sdk-js contract: every field except revenue is required.
            // If the iframe omits one, drop the event rather than emit a
            // partial payload — empty strings would mislead publishers.
            if let bidId = resolvedBidId,
               let content = payload?["content"] as? String,
               let format = payload?["format"] as? String {
                let resolvedMessageId = (payload?["messageId"] as? String) ?? messageId
                // Bid-side revenue overrides iframe-supplied revenue
                // (matches sdk-react-native). The iframe doesn't always
                // know the revenue figure; the bid does.
                let revenue = currentBid?.revenue ?? (payload?["revenue"] as? Double)
                session.emitEvent(.viewed(.init(
                    bidId: bidId,
                    content: content,
                    messageId: resolvedMessageId,
                    format: format,
                    revenue: revenue
                )))
            } else {
                session.config.onDebugEvent?("Ad: ad-viewed-dropped-missing-fields", [
                    "messageId": messageId,
                    "hasBidId": resolvedBidId != nil,
                    "hasContent": (payload?["content"] as? String) != nil,
                    "hasFormat": (payload?["format"] as? String) != nil,
                ])
            }

        case "ad.clicked":
            // Analytics-only. URL opening goes through the dedicated
            // `click-iframe` wire message (handled by `handleClickIframe`);
            // we do NOT trigger URL opening from the analytics event.
            // None of the reference SDKs (v3 sdk-rn, v3 sdk-swift,
            // v4 sdk-js) couple the two — and a well-behaved iframe
            // sends both `click-iframe` and `event-iframe(ad.clicked)`,
            // so coupling them here would open the URL twice.
            //
            // Same drop-on-incomplete contract as viewed.
            if let bidId = resolvedBidId,
               let urlVal = payload?["url"] as? String,
               let content = payload?["content"] as? String,
               let format = payload?["format"] as? String,
               let area = payload?["area"] as? String {
                let resolvedMessageId = (payload?["messageId"] as? String) ?? messageId
                session.emitEvent(.clicked(.init(
                    bidId: bidId,
                    content: content,
                    messageId: resolvedMessageId,
                    url: urlVal,
                    format: format,
                    area: area
                )))
            }

        case "ad.error":
            let message = payload?["message"] as? String ?? "Unknown error"
            let code = payload?["errCode"] as? String ?? "unknown"
            session.emitEvent(.error(.init(message: message, errCode: code)))

        case "ad.render-started":
            if let bidId = resolvedBidId {
                session.emitEvent(.renderStarted(.init(bidId: bidId)))
            }

        case "ad.render-completed":
            if let bidId = resolvedBidId {
                session.emitEvent(.renderCompleted(.init(bidId: bidId)))
            }

        case "ad.video.started":
            if let bidId = resolvedBidId {
                session.emitEvent(.videoStarted(.init(bidId: bidId)))
            }

        case "ad.video.completed":
            if let bidId = resolvedBidId {
                session.emitEvent(.videoCompleted(.init(bidId: bidId)))
            }

        case "ad.reward.granted":
            if let bidId = resolvedBidId {
                session.emitEvent(.rewardGranted(.init(bidId: bidId)))
            }

        default:
            break
        }
    }

    func handleErrorIframe() {
        session.config.onDebugEvent?("Ad: handle-error-iframe", ["messageId": messageId])
        // The `error-iframe` wire message has no data. Two side
        // effects happen here:
        //
        // 1. Log to the OM session for IAB diagnostics — the
        //    measurement system needs to see the error.
        // 2. Emit a generic `ad.error` event so the publisher's
        //    `onEvent` (and Combine `eventPublisher`) is notified.
        //    Matches v4 sdk-js's
        //    `processErrorIframeMessage` — without this, the
        //    publisher would just see the ad disappear when
        //    `AdWebView.handleErrorIframeMessage` calls `ad.destroy()`,
        //    with no idea why.
        //
        // The actual teardown (modal close, OMID retire+finish, audio
        // session, SKAN cleanup, session bookkeeping) happens in
        // `ad.destroy()`, called from `AdWebView.handleErrorIframeMessage`
        // right after this handler returns.
        omSession?.logError(errorType: nil, message: "iframe error")
        session.emitEvent(.error(.init(
            message: "Error loading iframe",
            errCode: "iframe_error"
        )))
    }

    /// Click waterfall — mirrors v3 sdk-react-native's `handleClick`:
    ///
    ///   1. SKAN fidelity-1 → SKStoreProduct with attribution
    ///   2. else-if `appStoreId` → SKStoreProduct without attribution (EXT-232)
    ///   3. else → URL flow (`openUrl`)
    ///
    /// SKAN data comes from the bid (preload), not the click message.
    /// On SKStoreProduct failure, falls through to the URL flow rather
    /// than retrying the other SKStoreProduct path — matches v3 sdk-rn's
    /// `if/else-if/else` structure.
    func handleClickIframe(data: IframeEvent.ClickData) {
        session.config.onDebugEvent?("Ad: handle-click-iframe", [
            "messageId": messageId,
            "url": data.url as Any,
            "target": data.target as Any,
        ])
        Task {
            let skan = currentBid?.skan

            if let skan = skan, skan.hasFidelity1 {
                let opened = await presentSKStoreProduct(skan: skan)
                if opened { return }
                await openUrl(data: data)
                return
            }

            if let appStoreId = data.appStoreId {
                let opened = await presentSKStoreProduct(itunesItem: appStoreId)
                if opened { return }
                await openUrl(data: data)
                return
            }

            await openUrl(data: data)
        }
    }

    /// URL fallback chain. Split out from `handleClickIframe` so the
    /// StoreKit-vs-URL decision logic stays readable — mirrors v3
    /// sdk-rn's `openUrl` helper. The URL-required guard lives here
    /// (not at the top of `handleClickIframe`) so an `appStoreId`-only
    /// click — no `url` field — can still fire SKStoreProduct.
    ///
    /// Order:
    ///   1. `target == .inApp` → in-app browser (SFSafariViewController).
    ///      `openFromURLString` rejects non-http(s) schemes (SFSafariVC
    ///      only supports http/https), so amazon://, fb://, etc. fall
    ///      through to step 2.
    ///   2. `UIApplication.shared.open` on the primary URL. Skips
    ///      `canOpenURL()` so custom schemes work without Info.plist
    ///      changes.
    ///   3. On primary failure, try `data.fallbackUrl` (deep link not
    ///      handled / app not installed).
    private func openUrl(data: IframeEvent.ClickData) async {
        guard let urlString = data.url else { return }
        let resolvedUrl = resolveAdUrl(urlString, adServerUrl: session.config.adServerUrl)

        if data.target == .inApp {
            if case .success = InAppBrowserManager.shared.openFromURLString(resolvedUrl) {
                return
            }
        }

        if let url = URL(string: resolvedUrl) {
            let opened = await UIApplication.shared.open(url)
            if opened { return }
        }

        if let fallback = data.fallbackUrl {
            let resolvedFallback = resolveAdUrl(fallback, adServerUrl: session.config.adServerUrl)
            if let url = URL(string: resolvedFallback) {
                await UIApplication.shared.open(url)
            }
        }
    }

    func handleAdDoneIframe(data: IframeEvent.AdDoneData) {
        session.config.onDebugEvent?("Ad: handle-ad-done-iframe", [
            "messageId": messageId,
            "impressionTrigger": currentBid?.impressionTrigger as Any,
            "creativeType": currentBid?.creativeType as Any,
        ])
        // `data` is parsed for protocol fidelity (id / content /
        // messageId / cachedContent) but currently unused — analytics
        // flow through the `event-iframe` channel and v4 sdk-swift
        // mirrors v4 sdk-js in deferring cached-content support.
        _ = data

        // For component-trigger ads (banner-then-modal), both OMID
        // and SKAN are deferred to the modal-open path:
        // - OMID session is started by `handleAdDoneComponentIframe`
        //   (modal `ad-done-component-iframe`).
        // - SKAN is started by `handleOpenComponentIframe` (modal
        //   `open-component-iframe`).
        //
        // Bail early so we don't create an inline OMID session here:
        // `handleAdDoneComponentIframe` guards on `omSession == nil`,
        // so a stray inline session would block the modal one from
        // starting and OMID would silently track the wrong creative.
        // Mirrors v3 sdk-swift's `pendingInlineWebView` vs
        // `pendingInterstitialWebView` split.
        guard let bid = currentBid, bid.impressionTrigger != .component else { return }

        // OMID session start (50ms delay inside `OMManager.createSession`).
        // The `omSession == nil` guard is defensive against a second
        // `ad-done-iframe` from the same iframe — without it we'd leak
        // the first session. Matches `handleAdDoneComponentIframe`.
        if omSession == nil, let creativeType = bid.creativeType {
            startOMSession(creativeType: creativeType)
        }

        // SKAN attribution. Both `nil` and `.immediate` triggers fire
        // here — matches sdk-react-native's
        // `bid?.impressionTrigger !== 'component'`.
        startSKAdNetwork()
    }

    // MARK: Component (modal) iframe

    func handleOpenComponentIframe(data: IframeEvent.OpenComponentData) {
        session.config.onDebugEvent?("Ad: handle-open-component-iframe", [
            "messageId": messageId,
            "brightnessDelta": data.brightnessDelta as Any,
        ])
        // Brightness increase for interstitials (A/B test).
        // Server's brightnessDelta is in [-1, 1] (iframe protocol);
        // KontextKit's get/setBrightness use 0–100, so scale.
        if let delta = data.brightnessDelta, delta != 0 {
            let current = BrightnessManager.get()
            savedBrightness = current
            _ = BrightnessManager.set(min(100, max(0, current + delta * 100)))
        }
        // Start SKAN if impression trigger is .component (open-component-iframe is modal-only).
        if currentBid?.impressionTrigger == .component {
            startSKAdNetwork()
        }
        openModal(data: data)
    }

    func handleInitComponentIframe() {
        session.config.onDebugEvent?("Ad: handle-init-component-iframe", ["messageId": messageId])
        // Modal iframe initialized — cancel the safety timeout. The
        // visibility/reveal half is driven by `AdWebView.onComponentInitialized`
        // → `InterstitialAdView.componentInitialized`, not by Ad state.
        modalTimeoutTask?.cancel()
        modalTimeoutTask = nil
    }

    func handleCloseComponentIframe() {
        session.config.onDebugEvent?("Ad: handle-close-component-iframe", ["messageId": messageId])
        tearDown()
    }

    func handleErrorComponentIframe(data: IframeEvent.ErrorComponentData) {
        session.config.onDebugEvent?("Ad: handle-error-component-iframe", [
            "messageId": messageId,
            "errorType": data.errorType as Any,
            "message": data.message as Any,
        ])
        // OMID diagnostics before tearing down the session in tearDown.
        // Mirrors v3 sdk-swift's pattern.
        omSession?.logError(errorType: data.errorType, message: data.message ?? "modal component error")
        // Notify the publisher — v4 sdk-js parity. Without the emit,
        // the modal disappears with no `ad.error` event. Defaults
        // mirror v4 sdk-js's `processErrorComponentIframeMessage`.
        session.emitEvent(.error(.init(
            message: data.message ?? "Modal component error",
            errCode: data.errorType ?? "modal_component_error"
        )))
        tearDown()
    }

    func handleAdDoneComponentIframe() {
        // Start OM session for interstitial (50ms delay inside OMManager.createSession)
        session.config.onDebugEvent?("Ad: handle-ad-done-component-iframe", [
            "messageId": messageId,
            "omSessionAlreadyStarted": omSession != nil,
            "creativeType": currentBid?.creativeType as Any,
        ])
        if omSession == nil, let creativeType = currentBid?.creativeType {
            startOMSession(creativeType: creativeType)
        }
    }

    // MARK: SKOverlay iframe

    /// Presents an SKOverlay using SKAN attribution data carried on the
    /// bid (from `/preload`) — the `open-skoverlay-iframe` payload
    /// itself doesn't include SKAN data on the wire.
    ///
    /// Mirrors v3 sdk-react-native's `openSkOverlay`:
    ///
    ///   1. Bid has SKAN with fidelity-1 → present with attribution.
    ///   2. Else iframe supplied `appStoreId` → present without
    ///      attribution.
    ///   3. Else → skip; emit a debug event with the reason so
    ///      publishers can trace "why didn't the overlay open?"
    ///
    /// The `appStoreId` fallback is the iframe's value only — we
    /// intentionally do NOT fall back to `bidSkan?.itunesItem` (matches
    /// v3 sdk-rn's `appStoreIdFallback`, which reads from message data
    /// only). Iframe intent wins; bid data is for attribution, not
    /// app identification.
    func handleOpenSKOverlayIframe(data: IframeEvent.SKOverlayData) {
        let position = SKOverlayPosition(rawValue: data.position ?? "") ?? .bottom
        let dismissible = data.dismissible ?? true
        let bidSkan = currentBid?.skan

        // Skip diagnostics — mirrors v3 sdk-rn's `skip-open-skoverlay-iframe`
        // debug events. Useful when an overlay silently fails to appear:
        // the publisher can correlate the missing call with a `skan`
        // problem instead of guessing at the iframe payload.
        if bidSkan == nil && data.appStoreId == nil {
            session.config.onDebugEvent?(
                "Ad: skip-open-skoverlay-iframe",
                ["reason": "missing_skan"]
            )
            return
        }
        if bidSkan?.hasFidelity1 != true && data.appStoreId == nil {
            session.config.onDebugEvent?(
                "Ad: skip-open-skoverlay-iframe",
                ["reason": "missing_fidelity1"]
            )
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let manager = self.session.dependencies.skOverlayManager
            do {
                if let skan = bidSkan, skan.hasFidelity1 {
                    _ = try await manager.present(skan: skan, position: position, dismissible: dismissible)
                } else if let appStoreId = data.appStoreId {
                    _ = try await manager.present(itunesItem: appStoreId, position: position, dismissible: dismissible)
                }
            } catch {
                self.reportSKError(error, source: "ad-sk-overlay-present")
            }
        }
    }

    /// Handles the iframe's `close-skoverlay-iframe` event by dismissing
    /// the overlay. Thin wrapper over `dismissSKOverlay` so the switch
    /// statement's case ↔ handler mapping stays uniform.
    func handleCloseSKOverlayIframe() {
        dismissSKOverlay()
    }
}

// MARK: - OM Session

private extension Ad {
    func startOMSession(creativeType: OMCreativeType) {
        guard let webView = currentWebView else { return }
        // `OMManager.createSession` does the 50ms geometry-stabilisation
        // sleep, ensures the AVAudioSession is active for video creatives
        // (so OMID's volume KVO fires), and calls `omSession.start()`
        // internally — no explicit `start()` here, no audio-session
        // bookkeeping here.
        Task { @MainActor in
            do {
                let omSess = try await omManager.createSession(
                    webView,
                    url: iframeUrl.flatMap(URL.init(string:)),
                    creativeType: creativeType
                )
                // If `destroy()` ran during the await, `tearDown()` already
                // retired+finished `self.omSession` — but our local `omSess`
                // wasn't assigned yet, so it'd leak (IAB OMID SDK retains
                // the session internally; in-iframe verification scripts
                // keep firing). Tear it down explicitly here.
                guard !self.destroyed else {
                    omSess.retire()
                    omSess.finish()
                    return
                }
                self.omSession = omSess
            } catch {
                session.config.onDebugEvent?("Ad: om-session-creation-error", ["error": "\(error)"])
                session.reportError(error, source: "ad-om-session-creation", bidId: currentBid?.bidId)
            }
        }
    }
}

// MARK: - SKStoreProduct / SKOverlay (action helpers)
//
// Per-event iframe handlers (`handleOpenSKOverlayIframe`,
// `handleCloseSKOverlayIframe`) live in the
// `// MARK: - Per-event Iframe Handlers` extension above. The helpers
// here are the "action" functions that those handlers (and other call
// sites — e.g. `tearDown`, the click flow) delegate the StoreKit
// work to.

private extension Ad {
    /// Presents an SKStoreProduct view controller with SKAN attribution.
    /// Reports errors to `ErrorCapture` and returns `false` so the click
    /// handler can fall through to the next strategy.
    func presentSKStoreProduct(skan: Skan) async -> Bool {
        do {
            return try await session.dependencies.skStoreProductManager.present(skan: skan)
        } catch {
            reportSKError(error, source: "ad-sk-store-product-present-skan")
            return false
        }
    }

    /// Presents the App Store product page without SKAN attribution
    /// (fallback when only an `appStoreId` is available).
    func presentSKStoreProduct(itunesItem: String) async -> Bool {
        do {
            return try await session.dependencies.skStoreProductManager.present(itunesItem: itunesItem)
        } catch {
            reportSKError(error, source: "ad-sk-store-product-present-itunes-item")
            return false
        }
    }

    /// Dismisses any currently presented SKOverlay. Internal action —
    /// called both from the `close-skoverlay-iframe` handler and from
    /// `tearDown` cleanup, hence the non-`Iframe`-suffixed name.
    ///
    /// Captures the manager by value rather than via [weak self] so
    /// the dismiss completes even if the publisher releases the Ad
    /// immediately after `destroy()` returns. SKOverlay is a UI-level
    /// resource — leaving it on screen is user-visible.
    func dismissSKOverlay() {
        let manager = session.dependencies.skOverlayManager
        Task {
            // Errors here are non-fatal (e.g. NO_OVERLAY when nothing
            // was presented) — fire-and-forget the dismiss.
            _ = try? await manager.dismiss()
        }
    }

    /// Routes a StoreKit-related error to the SDK's debug + error-capture
    /// pipelines. Mirrors the OM session error path in `startOMSession`.
    /// Includes the current bid's ID when one is resolved, so server-side
    /// error logs can cross-reference the bid that triggered the failure.
    func reportSKError(_ error: Error, source: String) {
        session.config.onDebugEvent?("Ad: \(source)-error", ["error": "\(error)"])
        session.reportError(error, source: source, bidId: currentBid?.bidId)
    }
}

// MARK: - Modal

extension Ad {
    /// Universal per-ad teardown. Despite the legacy "modal" framing,
    /// this is the single resource-release path for both inline and
    /// modal ads — for component-trigger interstitials the modal IS
    /// the ad, so modal-close events route here too.
    ///
    /// Idempotent: safe to call when no modal is open (every operation
    /// is nil-safe or guarded by a flag).
    ///
    /// Every caller (`close-component-iframe`, `error-component-iframe`,
    /// modal init-timeout, `destroy()`) goes through here so brightness,
    /// OMID session, audio-session refcount, and SKOverlay can never
    /// be missed in any one path. Step ordering matters — see comments
    /// inline (OMID retire must precede `onDismissModal` so verification
    /// scripts can flush while the WebView is still alive).
    func tearDown() {
        // 1) Cancel pending init-timeout (modal opening but not yet
        //    initialized, or opened and closing).
        modalTimeoutTask?.cancel()
        modalTimeoutTask = nil

        // 2) Clear modal URL state.
        modalUrl = nil

        // 3) Restore screen brightness if `handleOpenComponentIframe`
        //    bumped it. No-op when no bump was applied.
        restoreBrightness()

        // 4) Tear down the modal's OMID session (started from
        //    `handleAdDoneComponentIframe`). Retire before finish —
        //    OMID requires this order. Done BEFORE dismissing the
        //    cover so verification scripts can flush their final
        //    events while the WebView is still alive.
        omSession?.retire()
        omSession?.finish()
        omSession = nil

        // 5) End the SKAN impression. Parallels the OM session
        //    teardown above — Apple's contract is "endImpression when
        //    the ad is no longer onscreen", which is exactly here.
        //    Idempotent (`guard skanInitialized`), so safe across the
        //    multiple tearDown call sites (close-component-iframe,
        //    error-component-iframe, modal timeout, destroy()).
        cleanupSKAdNetwork()

        // 6) Notify the host view to dismiss the cover.
        onDismissModal?()

        // 7) Dismiss any SKOverlay opened from within the modal.
        dismissSKOverlay()
    }

    private func openModal(data: IframeEvent.OpenComponentData) {
        // openModal only fires after `open-component-iframe` from a
        // loaded iframe, which means `checkBid` has already resolved
        // and stored the current bid. The guard is defensive.
        guard let bid = currentBid,
              let url = buildIframeUrl(kind: .modal, bid: bid, componentParams: data.componentParams)
        else { return }

        modalUrl = url
        onRequestModal?(url, data.timeout)

        // Auto-close modal after timeout if init-component-iframe is not received.
        // Cancellation check sits INSIDE MainActor.run so a late
        // init-component-iframe arrival can still cancel the close
        // between the post-sleep check and the actual `tearDown`
        // invocation on the main actor.
        modalTimeoutTask?.cancel()
        modalTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(data.timeout) * 1_000_000)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self?.tearDown()
            }
        }
    }

    private func restoreBrightness() {
        if let saved = savedBrightness {
            savedBrightness = nil
            _ = BrightnessManager.set(saved)
        }
    }
}

// MARK: - SKAdNetwork Impression Lifecycle

private extension Ad {
    /// Initializes the SKAN impression from the current bid's SKAN data.
    /// Called on `initIframe` event.
    func initSKAdNetwork() {
        guard let skan = currentBid?.skan else { return }

        skanInFlightTask = Task { [weak self] in
            guard let self else { return }
            do {
                let manager = self.session.dependencies.skAdNetworkManager
                try await manager.initImpression(skan: skan)
                // If `destroy()` ran during the await, `cleanupSKAdNetwork`
                // already bailed (skanInitialized was still false) — but
                // the IAB SKAdImpression is now registered with iOS. Roll
                // it back here, otherwise it's orphaned. `try?` because
                // we can't usefully report on an already-abandoned path
                // and we don't want one failure to skip dispose.
                guard !self.destroyed else {
                    try? await manager.endImpression()
                    try? await manager.dispose()
                    return
                }
                self.skanInitialized = true
                // If start was requested before init completed, start now.
                if self.skanPendingStart {
                    self.skanPendingStart = false
                    self.startSKAdNetwork()
                }
            } catch {
                self.reportSKError(error, source: "ad-skan-init")
            }
        }
    }

    /// Starts the SKAN impression tracking window.
    /// Called on `adDone` (immediate trigger) or `openComponent` (component trigger).
    func startSKAdNetwork() {
        guard !skanStarted else { return }

        if !skanInitialized {
            // Init hasn't completed yet — defer start
            skanPendingStart = true
            return
        }

        skanStarted = true
        skanInFlightTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.session.dependencies.skAdNetworkManager.startImpression()
            } catch {
                self.reportSKError(error, source: "ad-skan-start")
            }
        }
    }

    /// Ends the SKAN impression and disposes resources.
    /// Called on `destroy()`.
    ///
    /// Two steps: `endImpression()` finalizes attribution (Apple's semantic
    /// "stop tracking" call), `dispose()` releases the impression object.
    /// Mirrors v3's two-step teardown.
    func cleanupSKAdNetwork() {
        guard skanInitialized else { return }
        skanInitialized = false
        skanStarted = false
        skanPendingStart = false
        // Capture and clear the in-flight Task so its body runs to
        // completion before we call endImpression/dispose. iOS
        // SKAdNetwork is not documented to be safe under concurrent
        // start+end on the same impression.
        let inFlight = skanInFlightTask
        skanInFlightTask = nil
        // Capture dependencies by value rather than via [weak self].
        // If the publisher releases this Ad immediately after destroy()
        // returns, a [weak self] capture would resolve to nil before
        // the Task body runs and the IAB SKAdImpression would orphan
        // — the impression is registered with iOS and only this
        // endImpression+dispose pair tears it down. Session is a long-
        // lived MainActor reference; the manager protocol is Sendable.
        let manager = session.dependencies.skAdNetworkManager
        let session = session
        let bidId = currentBid?.bidId
        Task {
            await inFlight?.value
            do {
                try await manager.endImpression()
            } catch {
                session.config.onDebugEvent?("Ad: ad-skan-end-error", ["error": "\(error)"])
                session.reportError(error, source: "ad-skan-end", bidId: bidId)
            }
            do {
                try await manager.dispose()
            } catch {
                session.config.onDebugEvent?("Ad: ad-skan-dispose-error", ["error": "\(error)"])
                session.reportError(error, source: "ad-skan-dispose", bidId: bidId)
            }
        }
    }
}
