import Foundation
import WebKit
@preconcurrency import OMSDK_Megabrainco

enum OMEvent: Sendable {
    /// Fired by WKNavigationDelegate.didFinish — the web view's main frame HTML has loaded
    /// and the web view is ready for an OMID session to be created.
    /// Session start is deferred further: inline ads wait for adDoneIframe + 50ms,
    /// interstitials wait for initComponentIframe, so that geometry is stable before measurement begins.
    case didStart(WKWebView, URL?)
}

protocol OMManaging: Sendable {
    @discardableResult
    func activate() -> Bool

    func createSession(_ webView: WKWebView, url: URL?, creativeType: OmCreativeType) throws -> OMSession
}

final class OMManager: OMManaging {
    enum OMError: Error {
        case sdkIsNotActive
        case partnerIsNotAvailable
        case sessionCreationFailed(String)
    }

    /// Used to identify integration
    private let partner = OMIDMegabraincoPartner(
        name: Constants.omPartnerName,
        versionString: Constants.omIntegrationVersion
    )

    /// Activates OM SDK
    func activate() -> Bool {
        if isActive {
            return true
        }

        OMIDMegabraincoSDK.shared.activate()

        return isActive
    }

    /// Creates OMID context, configuration and returns a session
    func createSession(_ webView: WKWebView, url: URL?, creativeType: OmCreativeType) throws -> OMSession {
        guard isActive else {
            throw OMError.sdkIsNotActive
        }

        guard let partner else {
            throw OMError.partnerIsNotAvailable
        }

        do {
            let context = try OMIDMegabraincoAdSessionContext(
                partner: partner,
                webView: webView,
                contentUrl: url?.absoluteString,
                customReferenceIdentifier: nil
            )

            let omCreativeType: OMIDCreativeType
            let impressionOwner: OMIDOwner
            let mediaEventsOwner: OMIDOwner
            switch creativeType {
            case .display:
                omCreativeType = .htmlDisplay
                impressionOwner = .javaScriptOwner
                mediaEventsOwner = .noneOwner
            case .video:
                omCreativeType = .video
                impressionOwner = .javaScriptOwner
                mediaEventsOwner = .javaScriptOwner
            }

            let configuration = try OMIDMegabraincoAdSessionConfiguration(
                creativeType: omCreativeType,
                impressionType: .beginToRender,
                impressionOwner: impressionOwner,
                mediaEventsOwner: mediaEventsOwner,
                isolateVerificationScripts: false
            )

            let session = try OMIDMegabraincoAdSession(
                configuration: configuration,
                adSessionContext: context
            )

            session.mainAdView = webView
            return try OMSession(session: session, webView: webView)
        } catch {
            throw OMError.sessionCreationFailed(error.localizedDescription)
        }
    }
}

// MARK: - Private

private extension OMManager {
    var isActive: Bool {
        OMIDMegabraincoSDK.shared.isActive
    }
}

// MARK: - OMSession

final class OMSession {
    private let session: OMIDMegabraincoAdSession
    private let webView: WKWebView
    private let adEvents: OMIDMegabraincoAdEvents

    init(session: OMIDMegabraincoAdSession, webView: WKWebView) throws {
        self.session = session
        self.webView = webView
        self.adEvents = try OMIDMegabraincoAdEvents(adSession: session)
    }

    func start() {
        session.start()
    }

    func retire() {
        webView.evaluateJavaScript("window.postMessage({ type: 'retire-iframe' }, '*');", completionHandler: nil)
    }

    func finish() {
        session.finish()
    }

    func logError(errorType: String?, message: String?) {
        let omErrorType: OMIDErrorType = errorType == "video" ? .media : .generic
        session.logError(withType: omErrorType, message: message ?? "unknown")
    }
}
