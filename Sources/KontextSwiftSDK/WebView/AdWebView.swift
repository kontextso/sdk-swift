import Combine
import OSLog
import SwiftUI
import UIKit
import WebKit

/// Events targeted for AdWebView
enum AdWebViewUpdateEvent {
    case didPrepareUpdateDimensions(UpdateDimensionsIFrameDataDTO)
}

// MARK: - AdWebView

final class AdWebView: WKWebView {
    private let webConfiguration = WKWebViewConfiguration()
    private let updateIframeData: UpdateIFrameDTO?
    private let eventPublisher: AnyPublisher<AdWebViewUpdateEvent, Never>?
    private let onIFrameEvent: (IframeEvent) -> Void
    private let onOMEvent: (OMEvent) -> Void

    private var cancellables: Set<AnyCancellable> = []
    private var scriptHandler: AdScriptMessageHandler?
    private var hasEverHadWindow = false

    init(
        frame: CGRect = .zero,
        updateIframeData: UpdateIFrameDTO?,
        eventPublisher: AnyPublisher<AdWebViewUpdateEvent, Never>? = nil,
        onIFrameEvent: @escaping (IframeEvent) -> Void,
        onOMEvent: @escaping (OMEvent) -> Void
    ) {
        self.eventPublisher = eventPublisher
        self.onIFrameEvent = onIFrameEvent
        self.onOMEvent = onOMEvent

        let contentController = WKUserContentController()

        if
            let omsdkURL = Bundle.module.url(forResource: "omsdk-v1", withExtension: "js"),
            let omsdkJS = try? String(contentsOf: omsdkURL, encoding: .utf8)
        {
            let omsdkScript = WKUserScript(
                source: omsdkJS,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            contentController.addUserScript(omsdkScript)
        }

        let js = """
        window.addEventListener('message', function(event) {
            window.webkit.messageHandlers.iframeMessage.postMessage(event.data);
        });
        """
        let userScript = WKUserScript(
            source: js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(userScript)

        #if DEBUG
        let consoleJS = """
        (function() {
            var orig = console.log.bind(console);
            console.log = function() {
                var msg = Array.prototype.slice.call(arguments).join(' ');
                if (msg.indexOf('[OMID]') !== -1) {
                    window.webkit.messageHandlers.consoleLog.postMessage(msg);
                }
                orig.apply(console, arguments);
            };
        })();
        """
        let consoleScript = WKUserScript(
            source: consoleJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(consoleScript)
        #endif

        self.updateIframeData = updateIframeData
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.userContentController = contentController

        super.init(frame: frame, configuration: webConfiguration)

        isOpaque = false
        backgroundColor = .clear
        scrollView.isScrollEnabled = false
        navigationDelegate = self

        scriptHandler = AdScriptMessageHandler(adWebView: self)
        if let scriptHandler {
            configuration.userContentController.add(scriptHandler, name: "iframeMessage")
            #if DEBUG
            configuration.userContentController.add(scriptHandler, name: "consoleLog")
            #endif
        }

        observeEvents()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        scriptHandler = nil        
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            hasEverHadWindow = true
        }
    }

    override func removeFromSuperview() {
        stopLoading()
        super.removeFromSuperview()
        webConfiguration.userContentController
            .removeScriptMessageHandler(forName: "iframeMessage")
        #if DEBUG
        webConfiguration.userContentController
            .removeScriptMessageHandler(forName: "consoleLog")
        #endif
    }

    func loadAd(from url: URL) {
        load(URLRequest(url: url))
    }
}

// MARK: - Events

private extension AdWebView {
    func observeEvents() {
        eventPublisher?
            .sink { [weak self] event in
                switch event {
                case .didPrepareUpdateDimensions(let data):
                    self?.sendUpdateIframe(data: data)
                }
            }
            .store(in: &cancellables)
    }

    func sendIframeEvent(event: IframeEvent) {
        switch event {
        case .initIframe:
            sendUpdateIframe(data: updateIframeData)
        default:
            break
        }
        onIFrameEvent(event)
    }

    func sendUpdateIframe<T: Encodable>(data: T?) {
        guard let data else {
            return
        }

        do {
            let data = try JSONEncoder().encode(data)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw EncodingError.invalidValue(
                    data,
                    EncodingError.Context(
                        codingPath: [],
                        debugDescription: "Failed to convert Data to String"
                    )
                )
            }
            // Post the message to the iframe
            let javascript = "window.postMessage(\(jsonString), '*');"
            evaluateJavaScript(javascript, completionHandler: nil)
        } catch {
            os_log(.error, "[Ad]: Failed to postMessage with error: \(error)")
        }
    }
}

// MARK: - WKNavigationDelegate

extension AdWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Cancel navigation only after the view has been in a window and was then removed —
        // this blocks WebKit's crash-recovery reload that fires ~6s after the WebContent process
        // is terminated post-ad.cleared. We allow navigations before the view has ever been
        // attached to a window (initial load), since load() may be called before the view
        // enters the hierarchy.
        guard window != nil || !hasEverHadWindow else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onOMEvent(.didStart(webView, url))
    }
}

// MARK: - AdScriptMessageHandler

private let consoleLogFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

private final class AdScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var adWebView: AdWebView?

    init(adWebView: AdWebView) {
        self.adWebView = adWebView
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        #if DEBUG
        if message.name == "consoleLog", let msg = message.body as? String {
            print("[\(consoleLogFormatter.string(from: Date()))] [WebView] \(msg)")
            return
        }
        #endif

        guard
            message.name == "iframeMessage",
            let adWebView
        else {
            return
        }

        do {
            let event = try IframeEvent(fromJSON: message.body)
            adWebView.sendIframeEvent(event: event)
        } catch {
            os_log(.error, "[Ad]: iframeMessage failed to decode with error: \(error)")
        }
    }
}
