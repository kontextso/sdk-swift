import Foundation
@preconcurrency import OMSDK_Megabrainco

enum OMEvent: Sendable {
    case didStart(WKWebView, URL?)
}

protocol OMManaging: Sendable {
    @discardableResult
    func activate() -> Bool

    func createSession(_ webView: WKWebView, url: URL?) throws -> OMSession
}

final class OMManager: OMManaging {
    enum OMError: Error {
        case sdkIsNotActive
        case partnerIsNotAvailable
        case sessionCreationFailed(String)
    }

    /// Used to identify integration
    private let partner = OMIDMegabraincoPartner(
        name: "megabrainco",
        versionString: Constants.omIntegrationVersion
    )

    /// Activates OM SDK
    func activate() -> Bool {
        if isActive {
            return true
        }

        let result = OMIDMegabraincoSDK.shared.activate()

        print("🔍 OM SDK ACTIVATED")
        print(result)

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
                impressionOwner: .nativeOwner,
                mediaEventsOwner: .noneOwner,
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

    private var didLoad = false
    private var didImpress = false

    init(session: OMIDMegabraincoAdSession, webView: WKWebView) throws {
        self.session = session
        self.webView = webView
        self.adEvents = try OMIDMegabraincoAdEvents(adSession: session)
    }

    func start() {
        session.start()
    }

    func signalLoadedOnce() throws {
        guard !didLoad else { return }
        didLoad = true
        do {
            try adEvents.loaded()
        } catch {
            // use os_log in real code
            print("OM loaded() failed: \(error)")
        }
    }

    func signalImpressionOnce() throws {
        guard !didImpress else { return }
        didImpress = true
        do {
            try adEvents.impressionOccurred()
        } catch {
            print("OM impressionOccurred failed: \(error)")
        }
    }

    func finish() {
        session.finish()
    }
}
