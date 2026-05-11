import Foundation
import KontextKit
import UIKit
import WebKit

/// Native↔iframe bridge for a single ad. Owns the `WKWebView`, installs
/// the postMessage handler + supporting user scripts (omsdk-v1.js,
/// bridge, console-interceptor), enforces navigation policy via
/// `WKNavigationDelegate` (cancels navigations on detached webviews to
/// prevent orphaned OMID sessions during WebKit crash recovery),
/// dispatches inbound iframe messages as typed `IframeEvent` values to
/// the owning `Ad`, and sends host→iframe messages (`update-iframe`,
/// `update-dimensions-iframe`).
///
/// Two flavours: inline (default) and interstitial (`isInterstitial: true`),
/// the latter exposing `onComponentInitialized` / `onComponentDone`
/// callbacks for `InterstitialAdView` lifecycle hooks.
///
/// See `IframeEvent` for the inbound vocabulary.
@MainActor
final class AdWebView: NSObject {
    let webView: WKWebView
    let ad: Ad

    /// Whether this is an interstitial (modal) web view.
    let isInterstitial: Bool

    /// Called when the interstitial component iframe is initialized.
    var onComponentInitialized: (() -> Void)?

    /// Called when the interstitial component ad is done rendering.
    var onComponentDone: (() -> Void)?

    /// Drops this AdWebView's registration on `Session.userEventSenders`.
    /// Set in `init`, invoked from `deinit` so events stop being
    /// forwarded to a teardown-bound iframe. `nonisolated(unsafe)`
    /// because deinit reads it from a nonisolated context — the
    /// property is set once in init (which runs on MainActor) and
    /// the captured value is invoked back on MainActor via a Task,
    /// so no concurrent access happens in practice.
    private nonisolated(unsafe) var unregisterUserEventSender: (() -> Void)?

    /// Name registered on `WKUserContentController` for native↔JS bridge.
    /// Single source of truth — interpolated into the bridge + console
    /// scripts (see `Self.bridgeScript` / `Self.consoleInterceptorScript`)
    /// so a rename here propagates everywhere.
    /// `nonisolated` because `deinit` (which references this) is not
    /// MainActor-isolated; it's a String literal, so concurrent reads
    /// are safe.
    fileprivate nonisolated static let messageHandlerName = "kontextBridge"

    init(ad: Ad, isInterstitial: Bool = false) {
        self.isInterstitial = isInterstitial
        self.ad = ad

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 15.0, *) {
            config.upgradeKnownHostsToHTTPS = false
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        // Allow Safari Web Inspector to attach in debug builds. iOS
        // 16.4+ hides WKWebView from the Develop menu unless the app
        // explicitly opts in. Off in release builds for safety.
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif
        self.webView = webView

        super.init()

        let handler = ScriptMessageHandler { [weak self] message in
            self?.handleMessage(message)
        }
        webView.configuration.userContentController.add(handler, name: Self.messageHandlerName)
        Self.injectUserScripts(
            into: webView.configuration.userContentController,
            adServerUrl: ad.session.config.adServerUrl
        )
        webView.navigationDelegate = self

        // Give the Ad a reference to the web view for OM session creation
        ad.currentWebView = webView

        // Register as a recipient of `Session.sendUserEvent` broadcasts.
        // The closure forwards into this iframe; the iframe filters by
        // the `code` field so multi-placement scenarios stay
        // independent. Mirrors sdk-js's `Ad.registerUserEventSender`.
        unregisterUserEventSender = ad.session.registerUserEventSender { [weak self] event in
            self?.sendMessage(event)
        }
    }

    deinit {
        // `removeScriptMessageHandler` is `@MainActor`-isolated, but
        // `deinit` runs on whatever thread released the last strong ref.
        // Hop to MainActor via Task instead of `assumeIsolated` — the
        // latter would crash if a future caller ever holds AdWebView
        // off-main. The captured `wv` keeps the WKWebView alive long
        // enough for the cleanup to run.
        let wv = webView
        let name = Self.messageHandlerName
        let unregister = unregisterUserEventSender
        Task { @MainActor in
            wv.configuration.userContentController.removeScriptMessageHandler(forName: name)
            unregister?()
        }
    }

    // MARK: - Loading

    func load() {
        guard let urlString = ad.iframeUrl, let url = URL(string: urlString) else {
            debug("no URL to load")
            return
        }
        debug("loading URL: \(url)")
        webView.load(URLRequest(url: url))
    }

    /// Loads a specific URL (used by InterstitialAdView for modal URLs).
    func loadURL(_ url: URL) {
        debug("loading interstitial URL: \(url)")
        webView.load(URLRequest(url: url))
    }

    fileprivate func debug(_ msg: String) {
        ad.session.config.onDebugEvent?("AdWebView: \(msg)", nil)
    }

    // MARK: - Message Handling

    private func handleMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let type = dict["type"] as? String else {
            return
        }

        switch type {
        case "_console":
            handleConsoleMessage(dict)
        case "init-iframe":
            handleInitIframeMessage()
        case "resize-iframe":
            handleResizeMessage(dict)
        case "event-iframe":
            handleEventMessage(dict)
        case "show-iframe":
            ad.handleIframeEvent(.showIframe)
        case "hide-iframe":
            ad.handleIframeEvent(.hideIframe)
        case "click-iframe":
            handleClickMessage(dict)
        case "ad-done-iframe":
            handleAdDoneIframeMessage(dict)
        case "error-iframe":
            handleErrorIframeMessage()
        case "open-component-iframe":
            handleOpenComponentMessage(dict)
        case "init-component-iframe":
            ad.handleIframeEvent(.initComponentIframe)
            onComponentInitialized?()
        case "close-component-iframe":
            ad.handleIframeEvent(.closeComponentIframe)
        case "error-component-iframe":
            handleErrorComponentMessage(dict)
        case "ad-done-component-iframe":
            ad.handleIframeEvent(.adDoneComponentIframe)
            onComponentDone?()
        case "open-skoverlay-iframe":
            handleOpenSKOverlayMessage(dict)
        case "close-skoverlay-iframe":
            ad.handleIframeEvent(.closeSKOverlayIframe)
        default:
            break
        }
    }

    // MARK: - Sending Messages to Iframe

    private func sendUpdateIframe() {
        let preload = ad.session.preload(messageId: ad.messageId)
        let messages = preload?.messages.map { $0.toDTO() } ?? []

        var otherParams: [String: String] = [:]
        if let theme = ad.theme {
            otherParams["theme"] = theme
        }

        let payload = UpdateIframeMessageDTO(
            data: .init(
                messages: messages,
                sdk: SDKInfo.current.name,
                messageId: ad.messageId,
                otherParams: otherParams,
                code: ad.code
            )
        )
        postPayloadToIframe(payload)
    }

    /// Sends a dimension update to the iframe.
    ///
    /// Called periodically (every 200ms) by InlineAdView to report the
    /// container's position and size for viewport-based ad optimization.
    func sendDimensionUpdate(_ update: DimensionUpdate) {
        postPayloadToIframe(UpdateDimensionsIframeMessageDTO(data: update))
    }

    /// Sends a typed `UserEvent` into the iframe as the
    /// `user-event-iframe` wire message. Pairs with
    /// `Session.registerUserEventSender`. The wrapper is fully typed;
    /// the publisher-supplied `payload` is encoded via
    /// `AnyJSONEncodable` so the envelope still goes through
    /// `JSONEncoder`.
    func sendMessage(_ event: UserEvent) {
        postPayloadToIframe(UserEventIframeMessageDTO(
            name: event.name,
            payload: event.payload,
            code: event.code
        ))
    }

    // MARK: - Bridge Script

    /// JavaScript bridge that forwards iframe `postMessage` calls to the
    /// native handler. The expected origin is hardcoded to the SDK's
    /// configured `adServerUrl` rather than read from
    /// `window.location.origin`, so the check stays anchored to the
    /// ad-server identity even if the WKWebView ever loads a different
    /// page (defence-in-depth — the navigation policy should already
    /// prevent that).
    ///
    /// Architecture context: WKWebView loads an ad-server page whose
    /// iframe contains banner content (potentially third-party). The
    /// banner's nested iframes can't directly postMessage to the host
    /// without going through the same-origin ad-server frame, so the
    /// origin check filters out third-party traffic.
    fileprivate static func bridgeScript(adServerUrl: String) -> String {
        """
        (function() {
            var expectedOrigin = '\(adServerUrl)';
            window.addEventListener('message', function(event) {
                if (event.origin !== expectedOrigin) return;
                try {
                    var data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
                    if (data && data.type && data.type.indexOf('-iframe') !== -1) {
                        window.webkit.messageHandlers.\(messageHandlerName).postMessage(data);
                    }
                } catch(e) {
                    // Surface bridge errors via the same `_console` channel the
                    // console interceptor uses, so the SDK's `onDebugEvent`
                    // callback can see iframe-side parse failures instead of
                    // silently dropping them.
                    window.webkit.messageHandlers.\(messageHandlerName).postMessage({
                        type: '_console',
                        message: '[kontext] bridge parse error: ' + (e && e.message ? e.message : String(e))
                    });
                }
            });
        })();
        """
    }
}

// MARK: - Per-message Handlers

private extension AdWebView {
    func handleConsoleMessage(_ dict: [String: Any]) {
        let msg = dict["message"] as? String ?? ""
        debug(msg)
    }

    func handleInitIframeMessage() {
        sendUpdateIframe()
        ad.handleIframeEvent(.initIframe)
    }

    func handleResizeMessage(_ dict: [String: Any]) {
        let data = dict["data"] as? [String: Any] ?? dict
        guard let resize = IframeEvent.ResizeData.from(dict: data) else { return }
        ad.handleIframeEvent(.resizeIframe(resize))
    }

    func handleEventMessage(_ dict: [String: Any]) {
        let data = dict["data"] as? [String: Any] ?? dict
        ad.handleIframeEvent(.eventIframe(.from(dict: data)))
    }

    func handleClickMessage(_ dict: [String: Any]) {
        let data = dict["data"] as? [String: Any] ?? dict
        ad.handleIframeEvent(.clickIframe(.from(dict: data)))
    }

    func handleAdDoneIframeMessage(_ dict: [String: Any]) {
        let data = dict["data"] as? [String: Any] ?? dict
        ad.handleIframeEvent(.adDoneIframe(.from(dict: data)))
    }

    func handleOpenComponentMessage(_ dict: [String: Any]) {
        let data = dict["data"] as? [String: Any] ?? dict
        ad.handleIframeEvent(.openComponentIframe(.from(dict: data)))
    }

    func handleErrorComponentMessage(_ dict: [String: Any]) {
        let data = dict["data"] as? [String: Any] ?? dict
        ad.handleIframeEvent(.errorComponentIframe(.from(dict: data)))
    }

    func handleOpenSKOverlayMessage(_ dict: [String: Any]) {
        let data = dict["data"] as? [String: Any] ?? dict
        ad.handleIframeEvent(.openSKOverlayIframe(.from(dict: data)))
    }

    func handleErrorIframeMessage() {
        ad.handleIframeEvent(.errorIframe)
        ad.destroy()
    }
}

// MARK: - Iframe postMessage helper

private extension AdWebView {
    /// Encodes a typed `Encodable` payload via `JSONEncoder` and forwards
    /// it to the iframe via `window.postMessage(...)`. On encoding
    /// failure (a real bug in our DTOs) the message is dropped and the
    /// failure is surfaced via `onDebugEvent` instead of being lost.
    func postPayloadToIframe<T: Encodable>(_ payload: T) {
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            debug("postMessage encoding failed for \(T.self)")
            return
        }
        let origin = ad.session.config.adServerUrl
        webView.evaluateJavaScript("window.postMessage(\(json), '\(origin)');", completionHandler: nil)
    }
}

// MARK: - User Script Injection

private extension AdWebView {
    static func injectUserScripts(
        into controller: WKUserContentController,
        adServerUrl: String
    ) {
        injectOMSDKScript(into: controller)
        injectBridgeScript(into: controller, adServerUrl: adServerUrl)
        injectConsoleInterceptorScript(into: controller)
    }

    static func injectOMSDKScript(into controller: WKUserContentController) {
        // Inject omsdk-v1.js at document start (before any ad content loads).
        // The script is bundled with KontextKit so all iOS SDKs share it.
        guard let omsdkJS = OMManager.omsdkScript() else { return }
        controller.addUserScript(WKUserScript(
            source: omsdkJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
    }

    static func injectBridgeScript(
        into controller: WKUserContentController,
        adServerUrl: String
    ) {
        controller.addUserScript(WKUserScript(
            source: bridgeScript(adServerUrl: adServerUrl),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
    }

    static func injectConsoleInterceptorScript(into controller: WKUserContentController) {
        let source = """
        (function() {
            var _log = console.log;
            console.log = function() {
                var msg = Array.prototype.slice.call(arguments).join(' ');
                if (msg.indexOf('[kontext') !== -1 || msg.indexOf('[OMID') !== -1) {
                    window.webkit.messageHandlers.\(messageHandlerName).postMessage({type:'_console', message: msg});
                }
                _log.apply(console, arguments);
            };
        })();
        """
        controller.addUserScript(WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
    }
}

// MARK: - WKNavigationDelegate

extension AdWebView: WKNavigationDelegate {
    /// Cancels navigations on a detached `WKWebView`. Without this guard,
    /// WebKit's crash-recovery reload can fire after the view has been
    /// removed from the hierarchy, leaving an OMID session attached to a
    /// no-longer-visible WebView (orphan-mount issue from v3 OMID
    /// certification work). Active sessions stay green; future
    /// reload attempts on detached views are dropped.
    // The closure attributes `@MainActor @Sendable` exactly mirror the
    // protocol declaration. Without them this method only "nearly
    // matches" the optional requirement — Swift never wires it as the
    // delegate callback, so the orphan-mount check is silently bypassed.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        if webView.window == nil {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: - Script Message Handler (prevents retain cycle)

private final class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
    let handler: (Any) -> Void

    init(handler: @escaping (Any) -> Void) {
        self.handler = handler
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        handler(message.body)
    }
}
