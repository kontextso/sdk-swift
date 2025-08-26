//
//  InlineAdWebView.swift
//  KontextSwiftSDK
//

import OSLog
import SwiftUI
import UIKit
import WebKit

// MARK: - InlineAdScriptMessageHandler

private final class InlineAdScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var inlineAdWebView: InlineAdWebView?

    init(inlineAdWebView: InlineAdWebView) {
        self.inlineAdWebView = inlineAdWebView
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard
            message.name == "iframeMessage",
            let inlineAdWebView
        else {
            return
        }

        do {
            let event = try InlineAdEvent(fromJSON: message.body)
            inlineAdWebView.sendIframeEvent(event: event)
        } catch {
            os_log(.error, "[InlineAd]: iframeMessage failed to decode with error: \(error)")
        }
    }
}

// MARK: - InlineAdWebView

final class InlineAdWebView: WKWebView {
    private let webConfiguration = WKWebViewConfiguration()
    private let updateIFrameData: UpdateIFrameData
    private let onIFrameEvent: (InlineAdEvent) -> Void

    private var scriptHandler: InlineAdScriptMessageHandler?

    init(
        frame: CGRect = .zero,
        updateFrameData: UpdateIFrameData,
        onIFrameEvent: @escaping (InlineAdEvent) -> Void
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

        updateIFrameData = updateFrameData
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.userContentController = contentController

        super.init(frame: frame, configuration: webConfiguration)

        isOpaque = false
        backgroundColor = .clear

        scriptHandler = InlineAdScriptMessageHandler(inlineAdWebView: self)
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
private extension InlineAdWebView {
    func sendIframeEvent(event: InlineAdEvent) {
        switch event {
        case .initIframe:
            sendUpdateIframe()
        case .showIframe, .hideIframe, .viewIframe, .clickIframe, .resizeIframe, .errorIframe, .unknown:
            break
        }
        onIFrameEvent(event)
    }

    func sendUpdateIframe() {
        let dto = UpdateIFrameDTO(
            data: UpdateIFrameDataDTO(from: updateIFrameData)
        )
        do {
            let data = try JSONEncoder().encode(dto)
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
            os_log(.error, "[InlineAd]: Failed to postMessage \(dto.type.rawValue) with error: \(error)")
        }
    }
}
