import OSLog
import SwiftUI
import UIKit
import WebKit

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

// MARK: - AdWebView

final class AdWebView: WKWebView {
    private let webConfiguration = WKWebViewConfiguration()
    private let updateIframeData: IframeEvent.UpdateIFrameDataDTO?
    private let onIFrameEvent: (IframeEvent) -> Void

    private var scriptHandler: AdScriptMessageHandler?

    init(
        frame: CGRect = .zero,
        updateIframeData: IframeEvent.UpdateIFrameDataDTO?,
        onIFrameEvent: @escaping (IframeEvent) -> Void
    ) {
        self.onIFrameEvent = onIFrameEvent

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

        scriptHandler = AdScriptMessageHandler(adWebView: self)
        if let scriptHandler {
            configuration.userContentController.add(scriptHandler, name: "iframeMessage")
        }
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

// MARK: Private
private extension AdWebView {
    func sendIframeEvent(event: IframeEvent) {
        switch event {
        case .initIframe:
            sendUpdateIframe()
        default:
            break
        }
        onIFrameEvent(event)
    }

    func sendUpdateIframe() {
        guard let updateIframeData else {
            return
        }

        let updateIframe = UpdateIFrameDTO(
            data: UpdateIFrameDataDTO(from: updateIframeData)
        )
        do {
            let data = try JSONEncoder().encode(updateIframe)
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
            os_log(.error, "[Ad]: Failed to postMessage \(updateIframe.type.rawValue) with error: \(error)")
        }
    }
}
