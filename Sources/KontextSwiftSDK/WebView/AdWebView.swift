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

        let contentController = WKUserContentController()
        contentController.addUserScript(userScript)

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
        }

        observeEvents()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        scriptHandler = nil        
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        webConfiguration.userContentController
            .removeScriptMessageHandler(forName: "iframeMessage")
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
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onOMEvent(.didStart(webView, url))
    }
}

// MARK: - AdScriptMessageHandler

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
