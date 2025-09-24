import Foundation
@preconcurrency import OMSDK_Megabrainco

enum OMEvent: Sendable {
    case didStart(WKWebView, URL?)    
}

protocol OMServicing: Sendable {
    @discardableResult
    func activate() -> Bool

    func createSession(_ webView: WKWebView, url: URL?) throws -> OMSession
}

final class OMService: OMServicing {
    enum OMError: Error {
        case sdkIsNotActive
        case partnerIsNotAvailable
        case sessionCreationFailed(String)
    }

    /// Used to identify integration
    private let partner = OMIDMegabraincoPartner(
        name: "Kontextso",
        versionString: Constants.version
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
    func createSession(_ webView: WKWebView, url: URL?) throws -> OMSession {
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

            let configuration = try OMIDMegabraincoAdSessionConfiguration(
                creativeType: .htmlDisplay,
                impressionType: .beginToRender,
                impressionOwner: .javaScriptOwner,
                mediaEventsOwner: .noneOwner,
                isolateVerificationScripts: false
            )

            let session = try OMIDMegabraincoAdSession(
                configuration: configuration,
                adSessionContext: context
            )

            session.mainAdView = webView
            return OMSession(session: session, webView: webView)
        } catch {
            throw OMError.sessionCreationFailed(error.localizedDescription)
        }
    }
}

// MARK: - Private

private extension OMService {
    var isActive: Bool {
        OMIDMegabraincoSDK.shared.isActive
    }
}

// MARK: - OMSession

struct OMSession {
    private let session: OMIDMegabraincoAdSession
    private let webView: WKWebView

    init(session: OMIDMegabraincoAdSession, webView: WKWebView) {
        self.session = session
        self.webView = webView
    }

    func start() {
        session.start()
    }

    func finish() {
        session.finish()
    }
}
