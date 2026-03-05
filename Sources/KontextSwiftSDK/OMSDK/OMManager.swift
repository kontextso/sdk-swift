import Foundation
@preconcurrency import OMSDK_Megabrainco

enum OMEvent: Sendable {
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
            let mediaEventsOwner: OMIDOwner
            switch creativeType {
            case .display:
                omCreativeType = .htmlDisplay
                mediaEventsOwner = .noneOwner
            case .video:
                omCreativeType = .video
                mediaEventsOwner = .javaScriptOwner
            }

            let configuration = try OMIDMegabraincoAdSessionConfiguration(
                creativeType: omCreativeType,
                impressionType: .beginToRender,
                impressionOwner: .nativeOwner,
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

    func finish() {
        session.finish()
    }

    func loaded() throws {
        try adEvents.loaded()
    }

    func impression() throws {
        try adEvents.impressionOccurred()
    }
}
